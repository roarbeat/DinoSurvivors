extends "res://addons/gut/test.gd"
## Boss-Charge-Ability-Tests (ADR 0043).

const BOSS_MOB_SCENE: PackedScene = preload("res://core/boss/boss_mob.tscn")


# ---------------------------------------------------------------------------
# Pure-Function compute_charge_velocity
# ---------------------------------------------------------------------------

func test_compute_charge_velocity_to_right() -> void:
	var v := BossCharge.compute_charge_velocity(
		Vector2.ZERO, Vector2(100, 0), 500.0)
	assert_almost_eq(v.x, 500.0, 0.01)
	assert_almost_eq(v.y, 0.0, 0.01)


func test_compute_charge_velocity_diagonal() -> void:
	var v := BossCharge.compute_charge_velocity(
		Vector2.ZERO, Vector2(100, 100), 500.0)
	# 45° diagonal → vx = vy = 500 * sin(45°) ≈ 353.55
	assert_almost_eq(v.x, 500.0 * sqrt(2.0) * 0.5, 0.5)
	assert_almost_eq(v.y, 500.0 * sqrt(2.0) * 0.5, 0.5)


func test_compute_charge_velocity_zero_distance() -> void:
	var v := BossCharge.compute_charge_velocity(
		Vector2(50, 50), Vector2(50, 50), 500.0)
	assert_eq(v, Vector2.ZERO)


# ---------------------------------------------------------------------------
# triceratops_charge — Wiring
# ---------------------------------------------------------------------------

func test_triceratops_charge_loaded() -> void:
	assert_true(ContentLoader.has_item(&"boss", &"triceratops_charge"))


func test_triceratops_charge_fields() -> void:
	var def := ContentLoader.get_or_null(&"boss", &"triceratops_charge") as BossDef
	assert_not_null(def)
	assert_eq(def.max_health, 1000.0)
	assert_eq(def.reward_currency_amount, 75)
	assert_eq(def.phases.size(), 3)


func test_triceratops_mid_phase_has_charge_ability() -> void:
	var def := ContentLoader.get_or_null(&"boss", &"triceratops_charge") as BossDef
	var mid: BossPhase = def.phases[1]
	assert_eq(mid.abilities.size(), 1)
	var charge := mid.abilities[0] as BossCharge
	assert_not_null(charge)
	assert_almost_eq(charge.charge_speed, 500.0, 0.01)


func test_triceratops_rage_phase_has_faster_charge() -> void:
	var def := ContentLoader.get_or_null(&"boss", &"triceratops_charge") as BossDef
	var rage: BossPhase = def.phases[2]
	var charge := rage.abilities[0] as BossCharge
	assert_almost_eq(charge.charge_speed, 700.0, 0.01)
	assert_almost_eq(charge.cooldown, 5.0, 0.01)


# ---------------------------------------------------------------------------
# BossMob.start_charge / is_charging
# ---------------------------------------------------------------------------

func test_boss_mob_not_charging_by_default() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	assert_false(boss.is_charging())
	boss.queue_free()


func test_start_charge_sets_charging_state() -> void:
	# Mock-Player damit start_charge eine Direction findet
	var player := Node2D.new()
	player.global_position = Vector2(100, 0)
	player.add_to_group(&"player")
	add_child(player)

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	# Minimal-Setup: damit health/dealer existieren
	var def := BossDef.new()
	def.id = &"test_charge_boss"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.scene = BOSS_MOB_SCENE
	boss.setup(def, Vector2.ZERO)

	var charge := BossCharge.new()
	charge.id = &"test_charge"
	charge.charge_speed = 500.0
	charge.charge_duration = 0.5
	charge.damage = 30.0

	boss.start_charge(charge)
	assert_true(boss.is_charging())

	boss.queue_free()
	player.queue_free()


func test_charge_movement_consumes_remaining_time() -> void:
	var player := Node2D.new()
	player.global_position = Vector2(1000, 0)
	player.add_to_group(&"player")
	add_child(player)

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	var def := BossDef.new()
	def.id = &"test_charge_boss2"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.scene = BOSS_MOB_SCENE
	boss.setup(def, Vector2.ZERO)

	var charge := BossCharge.new()
	charge.charge_speed = 500.0
	charge.charge_duration = 0.5
	boss.start_charge(charge)
	assert_true(boss.is_charging())

	# Einen langen Tick simulieren — Charge sollte enden
	boss._move_toward_player(0.5)
	assert_false(boss.is_charging(),
		"Nach charge_duration soll is_charging false sein")

	boss.queue_free()
	player.queue_free()


# ---------------------------------------------------------------------------
# Wave-Rotation Tests
# ---------------------------------------------------------------------------

func test_wave_5_uses_tyrannosaurus() -> void:
	# wave_5_tyrannosaurus.tres → boss_id = tyrannosaurus_prime
	var def: WaveDef = WaveSpawner.get_wave_def_for(5)
	assert_not_null(def)
	assert_eq(def.boss_id, &"tyrannosaurus_prime")


func test_wave_10_uses_triceratops() -> void:
	# wave_10_triceratops.tres → boss_id = triceratops_charge (NEU ADR 0043)
	var def: WaveDef = WaveSpawner.get_wave_def_for(10)
	assert_not_null(def)
	assert_eq(def.boss_id, &"triceratops_charge")


func test_wave_15_uses_tyrannosaurus() -> void:
	var def: WaveDef = WaveSpawner.get_wave_def_for(15)
	assert_not_null(def)
	assert_eq(def.boss_id, &"tyrannosaurus_prime")


func test_wave_20_uses_triceratops() -> void:
	var def: WaveDef = WaveSpawner.get_wave_def_for(20)
	assert_not_null(def)
	assert_eq(def.boss_id, &"triceratops_charge")


# ---------------------------------------------------------------------------
# forest_clearing Map
# ---------------------------------------------------------------------------

func test_forest_clearing_loaded() -> void:
	assert_true(ContentLoader.has_item(&"map", &"forest_clearing"))


func test_forest_clearing_is_12x12() -> void:
	var m := ContentLoader.get_or_null(&"map", &"forest_clearing") as MapDef
	assert_eq(m.grid_size, Vector2i(12, 12))
	assert_eq(m.path_row, 6)
	assert_eq(m.path_col, 6)


func test_forest_clearing_has_camera_padding() -> void:
	var m := ContentLoader.get_or_null(&"map", &"forest_clearing") as MapDef
	assert_eq(m.camera_padding, Vector2(60, 40))
