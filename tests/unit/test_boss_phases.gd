extends "res://addons/gut/test.gd"
## Boss-Phasen-Tests (ADR 0029).

const BOSS_MOB_SCENE: PackedScene = preload("res://core/boss/boss_mob.tscn")


# ---------------------------------------------------------------------------
# BossPhase Schema-Defaults
# ---------------------------------------------------------------------------

func test_boss_phase_default_fields() -> void:
	var p := BossPhase.new()
	assert_almost_eq(p.hp_threshold, 1.0, 0.001)
	assert_almost_eq(p.speed_multiplier, 1.0, 0.001)
	assert_almost_eq(p.damage_multiplier, 1.0, 0.001)
	assert_eq(p.color_tint, Color.WHITE)
	assert_eq(String(p.label_key), "")


func test_boss_phase_validate_passes_for_default() -> void:
	var p := BossPhase.new()
	assert_eq(p.validate(), "")


func test_boss_phase_validate_rejects_threshold_above_one() -> void:
	var p := BossPhase.new()
	p.hp_threshold = 1.5
	assert_string_contains(p.validate(), "hp_threshold")


func test_boss_phase_validate_rejects_negative_threshold() -> void:
	var p := BossPhase.new()
	p.hp_threshold = -0.1
	assert_string_contains(p.validate(), "hp_threshold")


func test_boss_phase_validate_rejects_zero_speed_multiplier() -> void:
	var p := BossPhase.new()
	p.speed_multiplier = 0.0
	assert_string_contains(p.validate(), "speed_multiplier")


func test_boss_phase_validate_rejects_negative_damage_multiplier() -> void:
	var p := BossPhase.new()
	p.damage_multiplier = -0.5
	assert_string_contains(p.validate(), "damage_multiplier")


# ---------------------------------------------------------------------------
# BossDef-Validation: phases müssen sortiert sein
# ---------------------------------------------------------------------------

func _make_phase(threshold: float) -> BossPhase:
	var p := BossPhase.new()
	p.hp_threshold = threshold
	return p


func test_boss_def_validate_passes_for_sorted_phases() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_sorted"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.phases = [_make_phase(1.0), _make_phase(0.66), _make_phase(0.33)]
	assert_eq(def.validate(), "")


func test_boss_def_validate_rejects_unsorted_phases() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_unsorted"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	# 0.33 vor 0.66 → bricht absteigende Sortierung
	def.phases = [_make_phase(1.0), _make_phase(0.33), _make_phase(0.66)]
	assert_string_contains(def.validate(), "absteigend")


func test_boss_def_validate_rejects_invalid_phase() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_invalid"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	var bad_phase := BossPhase.new()
	bad_phase.hp_threshold = 2.0  # > 1.0 → invalid
	def.phases = [bad_phase]
	var err := def.validate()
	assert_string_contains(err, "phases[0]")
	assert_string_contains(err, "hp_threshold")


# ---------------------------------------------------------------------------
# BossMob: Phase-Resolver (Pure Function)
# ---------------------------------------------------------------------------

func _make_test_boss_def() -> BossDef:
	var def := BossDef.new()
	def.id = &"test_boss_phases"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.speed = 100.0
	def.damage = 10.0
	def.scene = BOSS_MOB_SCENE
	# 3 Phasen analog tyrannosaurus_prime
	var p1 := BossPhase.new()
	p1.hp_threshold = 1.0
	p1.speed_multiplier = 1.0
	p1.damage_multiplier = 1.0
	var p2 := BossPhase.new()
	p2.hp_threshold = 0.66
	p2.speed_multiplier = 1.2
	p2.damage_multiplier = 1.15
	var p3 := BossPhase.new()
	p3.hp_threshold = 0.33
	p3.speed_multiplier = 1.5
	p3.damage_multiplier = 1.4
	def.phases = [p1, p2, p3]
	return def


func test_resolve_phase_index_at_full_hp_is_zero() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	# Pure function — direkt aufrufbar
	assert_eq(boss._resolve_phase_index(1.0), 0)
	boss.queue_free()


func test_resolve_phase_index_at_67_percent_is_zero() -> void:
	# 0.67 ist > 0.66 → noch in Phase 0
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	assert_eq(boss._resolve_phase_index(0.67), 0)
	boss.queue_free()


func test_resolve_phase_index_at_66_percent_is_one() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	assert_eq(boss._resolve_phase_index(0.66), 1)
	boss.queue_free()


func test_resolve_phase_index_at_33_percent_is_two() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	assert_eq(boss._resolve_phase_index(0.33), 2)
	boss.queue_free()


func test_resolve_phase_index_at_zero_hp_is_two() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	assert_eq(boss._resolve_phase_index(0.0), 2)
	boss.queue_free()


# ---------------------------------------------------------------------------
# BossMob: Speed/Damage-Multiplier
# ---------------------------------------------------------------------------

func test_get_speed_at_spawn_uses_phase_zero() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	# Phase 0 hat speed_mul=1.0
	assert_almost_eq(boss.get_speed(), 100.0, 0.01)
	boss.queue_free()


func test_get_speed_after_damage_to_phase_two() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	# Damage auf 30% HP → Phase 2 (rage)
	boss.health.take_damage(DamageInfo.make(70.0, &"test"))
	assert_eq(boss.get_current_phase_index(), 2)
	# Phase 2 hat speed_mul=1.5 → effektive Speed = 100 * 1.5 = 150
	assert_almost_eq(boss.get_speed(), 150.0, 0.01)
	boss.queue_free()


func test_get_damage_after_damage_to_phase_two() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	boss.health.take_damage(DamageInfo.make(70.0, &"test"))
	# Phase 2 hat damage_mul=1.4 → effektiver Damage = 10 * 1.4 = 14
	assert_almost_eq(boss.get_damage(), 14.0, 0.01)
	boss.queue_free()


# ---------------------------------------------------------------------------
# BossMob: Phase-Transition emittiert boss_phase_changed
# ---------------------------------------------------------------------------

func test_phase_change_emits_signal() -> void:
	watch_signals(EventBus)
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	# Damage auf 50% HP → Phase 1 (mid)
	boss.health.take_damage(DamageInfo.make(50.0, &"test"))
	assert_signal_emitted(EventBus, "boss_phase_changed")
	var params: Array = get_signal_parameters(EventBus, "boss_phase_changed")
	assert_eq(params[0], &"test_boss_phases")
	assert_eq(params[1], 1)
	boss.queue_free()


func test_phase_does_not_revert_on_heal() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def(), Vector2.ZERO)
	# Damage auf 30% → Phase 2
	boss.health.take_damage(DamageInfo.make(70.0, &"test"))
	assert_eq(boss.get_current_phase_index(), 2)
	# Heal zurück auf 90% — Phase soll NICHT auf 0 zurückspringen
	boss.health.heal(60.0)
	assert_eq(boss.get_current_phase_index(), 2,
		"Phase soll monoton fallend bleiben (kein Rückwärts bei Heal)")
	boss.queue_free()


# ---------------------------------------------------------------------------
# BossMob ohne Phasen (Backward-Kompat)
# ---------------------------------------------------------------------------

func test_boss_without_phases_returns_negative_one() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_no_phases"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.speed = 80.0
	def.damage = 30.0
	def.scene = BOSS_MOB_SCENE
	def.phases = []  # leeres Array

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(def, Vector2.ZERO)
	assert_eq(boss.get_current_phase_index(), -1,
		"Ohne phases: Index bleibt -1 (Backward-Kompat)")
	# Ohne Phase: get_speed/damage liefert def.speed/damage direkt
	assert_almost_eq(boss.get_speed(), 80.0, 0.01)
	assert_almost_eq(boss.get_damage(), 30.0, 0.01)
	boss.queue_free()


# ---------------------------------------------------------------------------
# Backward-Kompat: Loaded tyrannosaurus_prime hat Phasen
# ---------------------------------------------------------------------------

func test_tyrannosaurus_prime_loaded_with_three_phases() -> void:
	var def: BossDef = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	assert_not_null(def)
	assert_eq(def.phases.size(), 3,
		"tyrannosaurus_prime soll genau 3 Phasen haben (Spawn/Mid/Rage)")
	assert_almost_eq(def.phases[0].hp_threshold, 1.0, 0.001)
	assert_almost_eq(def.phases[1].hp_threshold, 0.66, 0.001)
	assert_almost_eq(def.phases[2].hp_threshold, 0.33, 0.001)


func test_tyrannosaurus_prime_phases_are_validated() -> void:
	var def: BossDef = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	assert_eq(def.validate(), "")
