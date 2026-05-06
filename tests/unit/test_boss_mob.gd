extends "res://addons/gut/test.gd"
## BossMob-Tests (ADR 0025).

var _boss: BossMob
var _def: BossDef


func before_each() -> void:
	# Group-Pollution-Schutz (ADR 0011 gotcha)
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if is_instance_valid(n): n.remove_from_group(&"enemy")
	for n in get_tree().get_nodes_in_group(&"boss"):
		if is_instance_valid(n): n.remove_from_group(&"boss")
	for n in get_tree().get_nodes_in_group(&"player"):
		if is_instance_valid(n): n.remove_from_group(&"player")

	var packed := load("res://core/boss/boss_mob.tscn") as PackedScene
	_boss = packed.instantiate() as BossMob
	add_child(_boss)
	_def = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef


func after_each() -> void:
	if is_instance_valid(_boss): _boss.queue_free()
	_boss = null


# ---------------------------------------------------------------------------
# Scene-Setup
# ---------------------------------------------------------------------------

func test_health_and_dealer_attached() -> void:
	assert_not_null(_boss.get_health_component())
	assert_not_null(_boss.get_dealer_component())
	assert_true(_boss.get_health_component() is HealthComponent)


func test_in_enemy_group_so_player_attacks_him() -> void:
	# BossMob ist in "enemy"-Group (ADR 0025) — Auto-Attack greift
	assert_true(_boss.is_in_group(&"enemy"))


func test_in_boss_group_marker() -> void:
	assert_true(_boss.is_in_group(&"boss"),
		"BossMob muss in der boss-Group sein (für UI/Telemetrie)")


# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------

func test_setup_assigns_boss_id_and_position() -> void:
	_boss.setup(_def, Vector2(100, 200))
	assert_eq(_boss.boss_id, &"tyrannosaurus_prime")
	assert_eq(_boss.global_position, Vector2(100, 200))


func test_setup_sets_max_hp() -> void:
	_boss.setup(_def, Vector2.ZERO)
	assert_almost_eq(_boss.get_health_component().max_hp, 800.0, 0.001)


func test_setup_dealer_default_source_id() -> void:
	_boss.setup(_def, Vector2.ZERO)
	assert_eq(_boss.get_dealer_component().default_source_id, &"tyrannosaurus_prime")


func test_setup_speed_from_def() -> void:
	_boss.setup(_def, Vector2.ZERO)
	assert_almost_eq(_boss.get_speed(), 80.0, 0.001)


# ---------------------------------------------------------------------------
# Death feuert boss_defeated, NICHT enemy_died
# ---------------------------------------------------------------------------

func test_death_fires_boss_defeated() -> void:
	_boss.setup(_def, Vector2(50, 50))
	watch_signals(EventBus)
	_boss.get_health_component().take_damage(DamageInfo.make(9999.0, &"player"))
	assert_signal_emitted(EventBus, "boss_defeated")
	var params: Array = get_signal_parameters(EventBus, "boss_defeated")
	assert_eq(params[0], &"tyrannosaurus_prime")


func test_death_does_NOT_fire_enemy_died() -> void:
	_boss.setup(_def, Vector2.ZERO)
	watch_signals(EventBus)
	_boss.get_health_component().take_damage(DamageInfo.make(9999.0))
	# is_boss=true unterdrückt enemy_died
	assert_signal_not_emitted(EventBus, "enemy_died",
		"Boss-Death darf NICHT enemy_died feuern (is_boss=true)")


# ---------------------------------------------------------------------------
# Movement (analog ADR 0017)
# ---------------------------------------------------------------------------

func test_boss_moves_toward_player() -> void:
	_boss.setup(_def, Vector2(100, 0))
	var marker := Node2D.new()
	marker.add_to_group(&"player")
	marker.global_position = Vector2(0, 0)
	add_child(marker)

	var x_before := _boss.global_position.x
	_boss._move_toward_player(0.1)  # 0.1s × 80 px/s = 8px Richtung Player
	assert_lt(_boss.global_position.x, x_before)

	marker.remove_from_group(&"player")
	marker.queue_free()


func test_boss_does_not_move_when_dead() -> void:
	_boss.setup(_def, Vector2(100, 0))
	var marker := Node2D.new()
	marker.add_to_group(&"player")
	marker.global_position = Vector2.ZERO
	add_child(marker)

	_boss.get_health_component().take_damage(DamageInfo.make(9999.0))
	var pos_before := _boss.global_position
	_boss._physics_process(0.1)
	assert_eq(_boss.global_position, pos_before)

	marker.remove_from_group(&"player")
	marker.queue_free()
