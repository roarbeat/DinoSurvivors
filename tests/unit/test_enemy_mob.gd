extends "res://addons/gut/test.gd"
## Tests für EnemyMob (ADR 0009).
##
## Lädt die echte enemy_mob.tscn — verifiziert Scene-Hierarchie + setup-API.

var _mob: EnemyMob
var _def: EnemyDef


func before_each() -> void:
	var packed := load("res://core/enemy/enemy_mob.tscn") as PackedScene
	_mob = packed.instantiate() as EnemyMob
	add_child(_mob)
	_def = ContentLoader.get_or_null(&"enemy", &"raptor_grunt") as EnemyDef


func after_each() -> void:
	if is_instance_valid(_mob):
		_mob.queue_free()
	_mob = null


# ---------------------------------------------------------------------------
# Scene-Setup
# ---------------------------------------------------------------------------

func test_health_component_attached() -> void:
	var hp := _mob.get_health_component()
	assert_not_null(hp)
	assert_true(hp is HealthComponent)


func test_dealer_component_attached() -> void:
	var d := _mob.get_dealer_component()
	assert_not_null(d)
	assert_true(d is DamageDealerComponent)


func test_health_is_player_false() -> void:
	assert_false(_mob.get_health_component().is_player,
		"Enemy darf NICHT is_player=true haben")


# ---------------------------------------------------------------------------
# setup()-Roundtrip
# ---------------------------------------------------------------------------

func test_setup_assigns_enemy_id_from_def() -> void:
	_mob.setup(_def, Vector2.ZERO)
	assert_eq(_mob.enemy_id, &"raptor_grunt")


func test_setup_sets_max_hp_from_def() -> void:
	_mob.setup(_def, Vector2.ZERO)
	assert_almost_eq(_mob.get_health_component().max_hp, 25.0, 0.0001)


func test_setup_sets_position() -> void:
	_mob.setup(_def, Vector2(100, 200))
	assert_eq(_mob.global_position, Vector2(100, 200))


func test_setup_dealer_default_source_id() -> void:
	_mob.setup(_def, Vector2.ZERO)
	assert_eq(_mob.get_dealer_component().default_source_id, &"raptor_grunt")


func test_setup_with_null_def_is_warning_no_crash() -> void:
	# Sollte nicht crashen
	_mob.setup(null, Vector2.ZERO)
	pass_test("kein Crash bei null def")


# ---------------------------------------------------------------------------
# Death-Pfad: enemy_died-Signal
# ---------------------------------------------------------------------------

func test_death_emits_enemy_died_with_correct_id() -> void:
	_mob.setup(_def, Vector2(50, 50))
	watch_signals(EventBus)
	# Tödlicher Schlag
	_mob.get_health_component().take_damage(DamageInfo.make(999.0, &"player"))
	assert_signal_emitted(EventBus, "enemy_died")
	var params: Array = get_signal_parameters(EventBus, "enemy_died")
	assert_eq(params[0], &"raptor_grunt")
	assert_eq(params[1], Vector2(50, 50))


func test_partial_damage_does_not_emit_enemy_died() -> void:
	_mob.setup(_def, Vector2.ZERO)
	watch_signals(EventBus)
	_mob.get_health_component().take_damage(DamageInfo.make(10.0))
	assert_signal_not_emitted(EventBus, "enemy_died")


# ---------------------------------------------------------------------------
# Movement (ADR 0017)
# ---------------------------------------------------------------------------

func _spawn_player_marker_at(pos: Vector2) -> Node2D:
	# Ein simpler Node2D in der "player"-Group für Movement-Tests.
	# Wir umgehen die ganze PlayerCharacter-Scene, weil wir nur das
	# Enemy-Movement testen.
	var marker := Node2D.new()
	marker.add_to_group(&"player")
	marker.global_position = pos
	add_child(marker)
	return marker


func _clean_player_group() -> void:
	for n in get_tree().get_nodes_in_group(&"player"):
		if is_instance_valid(n):
			n.remove_from_group(&"player")


func test_enemy_moves_toward_player() -> void:
	_clean_player_group()
	_mob.setup(_def, Vector2(100, 0))
	_spawn_player_marker_at(Vector2(0, 0))

	var x_before: float = _mob.global_position.x
	_mob._move_toward_player(0.1)  # 0.1s × 120px/s = 12px
	assert_lt(_mob.global_position.x, x_before,
		"Enemy muss sich Richtung Player (links) bewegt haben")
	# Genauer: Distanz x reduziert um speed × delta = 12
	assert_almost_eq(x_before - _mob.global_position.x, 12.0, 0.01,
		"Distanz-Reduktion = speed × delta")


func test_enemy_speed_from_def() -> void:
	_mob.setup(_def, Vector2.ZERO)
	# raptor_grunt.speed = 120
	assert_almost_eq(_mob.get_speed(), 120.0, 0.001)


func test_enemy_does_not_move_when_dead() -> void:
	_clean_player_group()
	_mob.setup(_def, Vector2(100, 0))
	_spawn_player_marker_at(Vector2(0, 0))
	_mob.get_health_component().take_damage(DamageInfo.make(999.0))
	assert_true(_mob.get_health_component().is_dead())

	var pos_before := _mob.global_position
	_mob._physics_process(0.1)
	assert_eq(_mob.global_position, pos_before,
		"Tote Enemies dürfen sich nicht bewegen")


func test_enemy_does_not_move_without_player() -> void:
	_clean_player_group()
	_mob.setup(_def, Vector2(100, 0))
	# kein Player in Group
	var pos_before := _mob.global_position
	_mob._move_toward_player(0.1)
	assert_eq(_mob.global_position, pos_before,
		"Ohne Player in Group kein Movement")


func test_enemy_picks_nearest_player() -> void:
	_clean_player_group()
	_mob.setup(_def, Vector2(0, 0))
	_spawn_player_marker_at(Vector2(50, 0))     # näher
	_spawn_player_marker_at(Vector2(-200, 0))   # weiter

	var nearest := _mob._find_nearest_player()
	assert_not_null(nearest)
	assert_eq(nearest.global_position, Vector2(50, 0))


func test_enemy_no_movement_when_overlapping_player() -> void:
	_clean_player_group()
	_mob.setup(_def, Vector2.ZERO)
	_spawn_player_marker_at(Vector2.ZERO)
	# Beide an gleichem Ort → normalized Vector2.ZERO → kein Movement
	var pos_before := _mob.global_position
	_mob._move_toward_player(0.1)
	assert_eq(_mob.global_position, pos_before,
		"Distanz=0 → Vector2.ZERO normalized → kein Movement")


# ---------------------------------------------------------------------------
# Visuelle Differenzierung (ADR 0024)
# ---------------------------------------------------------------------------

func test_setup_applies_body_color_from_def() -> void:
	# pteranodon hat himmelblau
	var pteranodon := ContentLoader.get_or_null(&"enemy", &"pteranodon") as EnemyDef
	assert_not_null(pteranodon)
	_mob.setup(pteranodon, Vector2.ZERO)
	var body := _mob.get_node("Body") as ColorRect
	assert_almost_eq(body.color.b, 0.910, 0.01,
		"Pteranodon-Body muss blau sein")


func test_setup_applies_body_size_from_def() -> void:
	# armored_carnotaurus 28×28
	var carnot := ContentLoader.get_or_null(&"enemy", &"armored_carnotaurus") as EnemyDef
	assert_not_null(carnot)
	_mob.setup(carnot, Vector2.ZERO)
	var body := _mob.get_node("Body") as ColorRect
	assert_almost_eq(body.size.x, 28.0, 0.5,
		"Carnotaurus-Body muss 28px breit sein")


func test_setup_centers_body_around_origin() -> void:
	var alpha := ContentLoader.get_or_null(&"enemy", &"raptor_alpha") as EnemyDef
	_mob.setup(alpha, Vector2.ZERO)
	var body := _mob.get_node("Body") as ColorRect
	# raptor_alpha 22×22 → offset_left = -11, offset_right = 11
	assert_almost_eq(body.offset_left, -11.0, 0.5)
	assert_almost_eq(body.offset_right, 11.0, 0.5)


func test_setup_repositions_health_bar() -> void:
	# Carnotaurus 28×28 → HealthBar.position.y = -14 - 8 = -22
	var carnot := ContentLoader.get_or_null(&"enemy", &"armored_carnotaurus") as EnemyDef
	_mob.setup(carnot, Vector2.ZERO)
	var bar := _mob.get_node("HealthBar") as Node2D
	assert_almost_eq(bar.position.y, -22.0, 0.5,
		"HealthBar muss bei größerem Body weiter oben sitzen")


func test_default_body_color_for_legacy_enemies() -> void:
	# raptor_grunt hat keine body_color in der .tres-Datei (default greift)
	var grunt := ContentLoader.get_or_null(&"enemy", &"raptor_grunt") as EnemyDef
	assert_almost_eq(grunt.body_color.r, 0.82, 0.01,
		"raptor_grunt fällt auf Default-rot zurück")
	assert_eq(grunt.body_size, Vector2(16, 16),
		"raptor_grunt fällt auf 16×16 zurück")
