extends "res://addons/gut/test.gd"
## Hit-Detection-Tests (ADR 0011) — distanz-basiert, headless.
##
## Wir umgehen _physics_process komplett und rufen _do_auto_attack() /
## _check_touch_damage() direkt — so bleiben Tests deterministisch.

var _player: PlayerCharacter
var _trex: DinoDef
var _raptor_def: EnemyDef
var _enemy_root: Node


func before_each() -> void:
	# Sauberes Setup
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()
	PlayerMutations.reset()

	# Group-Pollution-Schutz: vorherige Tests können EnemyMob-Instanzen
	# in der `enemy`-Group hinterlassen haben (queue_free ist async).
	# Wir entfernen sie aus der Group sofort und freuen uns auf later GC.
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(node):
			node.remove_from_group(&"enemy")
	for node in get_tree().get_nodes_in_group(&"player"):
		if is_instance_valid(node) and node != _player:
			node.remove_from_group(&"player")

	# Container für Enemies dieses Tests
	_enemy_root = Node2D.new()
	add_child(_enemy_root)

	# Player aus Scene
	var packed := load("res://core/player/player_character.tscn") as PackedScene
	_player = packed.instantiate() as PlayerCharacter
	add_child(_player)

	_trex = ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	_player.set_dino(_trex)
	_player.global_position = Vector2.ZERO

	_raptor_def = ContentLoader.get_or_null(&"enemy", &"raptor_grunt") as EnemyDef


func after_each() -> void:
	# Aufräumen aller Enemies + Player, damit nachfolgende Suites
	# keine Group-Reste sehen.
	if is_instance_valid(_enemy_root):
		_enemy_root.queue_free()
	_enemy_root = null
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null


func _spawn_enemy(pos: Vector2) -> EnemyMob:
	var packed := load("res://core/enemy/enemy_mob.tscn") as PackedScene
	var mob: EnemyMob = packed.instantiate()
	_enemy_root.add_child(mob)
	mob.setup(_raptor_def, pos)
	return mob


# ---------------------------------------------------------------------------
# Auto-Attack
# ---------------------------------------------------------------------------

func test_auto_attack_hits_enemy_in_range() -> void:
	# trex.pickup_radius = 80; Enemy bei (50, 0) → in range
	var enemy := _spawn_enemy(Vector2(50, 0))
	var hp_before := enemy.get_health_component().get_hp()
	var hits := _player._do_auto_attack()
	assert_eq(hits, 1, "1 Enemy in range muss getroffen werden")
	# trex.base_damage = 15 → 25 - 15 = 10
	assert_almost_eq(enemy.get_health_component().get_hp(), hp_before - 15.0, 0.001)


func test_auto_attack_misses_enemy_out_of_range() -> void:
	# Enemy bei (200, 0) — pickup_radius = 80 → außerhalb
	var enemy := _spawn_enemy(Vector2(200, 0))
	var hp_before := enemy.get_health_component().get_hp()
	var hits := _player._do_auto_attack()
	assert_eq(hits, 0)
	assert_almost_eq(enemy.get_health_component().get_hp(), hp_before, 0.001)


func test_auto_attack_hits_multiple_in_range() -> void:
	_spawn_enemy(Vector2(30, 0))
	_spawn_enemy(Vector2(0, 30))
	_spawn_enemy(Vector2(-30, 0))
	_spawn_enemy(Vector2(200, 0))   # außerhalb
	var hits := _player._do_auto_attack()
	assert_eq(hits, 3, "3 in range, 1 outside")


func test_auto_attack_skips_dead_enemies() -> void:
	var enemy := _spawn_enemy(Vector2(20, 0))
	# Enemy schon tot
	enemy.get_health_component().take_damage(DamageInfo.make(999.0))
	assert_true(enemy.get_health_component().is_dead())

	var hits := _player._do_auto_attack()
	assert_eq(hits, 0, "Tote Enemies werden nicht getroffen")


func test_auto_attack_respects_mutation_modifiers() -> void:
	# +15% damage → 15 × 1.15 = 17.25
	PlayerMutations.pick(&"triceratops_horns")
	var enemy := _spawn_enemy(Vector2(20, 0))
	var hp_before := enemy.get_health_component().get_hp()
	_player._do_auto_attack()
	assert_almost_eq(enemy.get_health_component().get_hp(), hp_before - 17.25, 0.001,
		"Mutations-Multiplier muss bei Auto-Attack wirken")


# ---------------------------------------------------------------------------
# Touch-Damage
# ---------------------------------------------------------------------------

func test_touch_damage_applies_when_enemy_close() -> void:
	# Enemy bei (10, 0) — innerhalb TOUCH_HIT_RADIUS = 25
	var enemy := _spawn_enemy(Vector2(10, 0))
	var player_hp_before := _player.get_health_component().get_hp()
	var touched := _player._check_touch_damage()
	assert_true(touched, "Touch sollte passieren")
	# raptor_grunt.damage = 8
	assert_almost_eq(_player.get_health_component().get_hp(),
		player_hp_before - 8.0, 0.001)


func test_touch_damage_skips_when_outside_radius() -> void:
	_spawn_enemy(Vector2(50, 0))  # außerhalb TOUCH_HIT_RADIUS = 25
	var player_hp_before := _player.get_health_component().get_hp()
	var touched := _player._check_touch_damage()
	assert_false(touched)
	assert_almost_eq(_player.get_health_component().get_hp(),
		player_hp_before, 0.001)


func test_touch_damage_picks_nearest_only() -> void:
	# Zwei Enemies in Touch-Range — nur einer darf zuschlagen
	_spawn_enemy(Vector2(10, 0))
	_spawn_enemy(Vector2(15, 0))
	var hp_before := _player.get_health_component().get_hp()
	_player._check_touch_damage()
	# Nur 8 Damage (von einem Enemy), nicht 16
	assert_almost_eq(_player.get_health_component().get_hp(),
		hp_before - 8.0, 0.001)


# ---------------------------------------------------------------------------
# iframes
# ---------------------------------------------------------------------------

func test_iframes_block_second_touch() -> void:
	var enemy := _spawn_enemy(Vector2(10, 0))

	# Erster Touch geht durch
	_player._check_touch_damage()
	var hp_after_first := _player.get_health_component().get_hp()
	assert_true(_player.is_invulnerable())

	# Zweiter Touch direkt danach — iframes greifen
	# Wir simulieren _update_hit_detection mit delta=0
	# Direkter _check_touch_damage-Call würde iframes ignorieren —
	# der Schutz ist im _update_hit_detection (siehe Code).
	# Hier prüfen wir den is_invulnerable-State.
	assert_true(_player.is_invulnerable())
	# Nicht weiter Damage durch _update_hit_detection mit delta=0
	_player._update_hit_detection(0.0)
	assert_almost_eq(_player.get_health_component().get_hp(), hp_after_first, 0.001,
		"Während iframes darf kein neuer Touch-Damage rein")


func test_iframes_expire_after_duration() -> void:
	var enemy := _spawn_enemy(Vector2(10, 0))
	_player._check_touch_damage()
	assert_true(_player.is_invulnerable())

	# Enemy aus der Group entfernen, damit der nächste Update-Tick
	# nicht sofort wieder einen Touch verursacht (sonst werden iframes
	# direkt nach Ablauf neu gesetzt).
	enemy.remove_from_group(&"enemy")

	# Zeit ablaufen lassen
	_player._update_hit_detection(PlayerCharacter.IFRAMES_DURATION + 0.01)
	assert_false(_player.is_invulnerable(),
		"Nach IFRAMES_DURATION müssen iframes weg sein")


# ---------------------------------------------------------------------------
# Combat-Roundtrip
# ---------------------------------------------------------------------------

func test_full_combat_round_player_kills_enemy() -> void:
	# raptor 25 HP, trex 15 dmg → braucht 2 Schläge
	var enemy := _spawn_enemy(Vector2(20, 0))
	_player._do_auto_attack()
	assert_almost_eq(enemy.get_health_component().get_hp(), 10.0, 0.001)
	_player._do_auto_attack()
	assert_true(enemy.get_health_component().is_dead())
