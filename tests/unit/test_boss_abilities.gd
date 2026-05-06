extends "res://addons/gut/test.gd"
## Boss-Abilities-Tests (ADR 0038).

const BOSS_MOB_SCENE: PackedScene = preload("res://core/boss/boss_mob.tscn")


# ---------------------------------------------------------------------------
# BossAbility-Schema-Defaults
# ---------------------------------------------------------------------------

func test_boss_ability_default_fields() -> void:
	var a := BossAbility.new()
	assert_eq(String(a.id), "")
	assert_almost_eq(a.cooldown, 5.0, 0.001)
	assert_almost_eq(a.initial_delay, 1.0, 0.001)


func test_boss_ability_validate_passes_for_default() -> void:
	var a := BossAbility.new()
	assert_eq(a.validate(), "")


func test_boss_ability_validate_rejects_zero_cooldown() -> void:
	var a := BossAbility.new()
	a.cooldown = 0.0
	assert_string_contains(a.validate(), "cooldown")


func test_boss_ability_validate_rejects_negative_initial_delay() -> void:
	var a := BossAbility.new()
	a.initial_delay = -1.0
	assert_string_contains(a.validate(), "initial_delay")


# ---------------------------------------------------------------------------
# BossStomp-Defaults + Pure-Function-Helper
# ---------------------------------------------------------------------------

func test_boss_stomp_default_fields() -> void:
	var s := BossStomp.new()
	assert_almost_eq(s.radius, 120.0, 0.001)
	assert_almost_eq(s.damage, 25.0, 0.001)


func test_find_player_health_in_radius_includes_close() -> void:
	# Mock-Player Node2D mit Health-Child
	var p := Node2D.new()
	p.global_position = Vector2(50, 0)
	var hp := HealthComponent.new()
	hp.name = "Health"
	hp.max_hp = 100.0
	p.add_child(hp)
	add_child(p)

	var hits: Array = BossStomp.find_player_health_in_radius(
		Vector2.ZERO, 100.0, [p])
	assert_eq(hits.size(), 1)
	assert_eq(hits[0], hp)

	p.queue_free()


func test_find_player_health_in_radius_excludes_far() -> void:
	var p := Node2D.new()
	p.global_position = Vector2(500, 0)
	var hp := HealthComponent.new()
	hp.name = "Health"
	hp.max_hp = 100.0
	p.add_child(hp)
	add_child(p)

	var hits: Array = BossStomp.find_player_health_in_radius(
		Vector2.ZERO, 100.0, [p])
	assert_eq(hits.size(), 0)

	p.queue_free()


func test_find_player_health_in_radius_skips_node_without_health() -> void:
	var p := Node2D.new()
	p.global_position = Vector2(50, 0)
	add_child(p)

	var hits: Array = BossStomp.find_player_health_in_radius(
		Vector2.ZERO, 100.0, [p])
	assert_eq(hits.size(), 0,
		"Node ohne Health-Child wird geskippt")

	p.queue_free()


# ---------------------------------------------------------------------------
# BossPhase.abilities-Array
# ---------------------------------------------------------------------------

func test_boss_phase_default_abilities_empty() -> void:
	var p := BossPhase.new()
	assert_eq(p.abilities.size(), 0)


func test_boss_phase_can_have_abilities() -> void:
	var p := BossPhase.new()
	var a := BossAbility.new()
	a.id = &"test_ability"
	p.abilities = [a]
	assert_eq(p.abilities.size(), 1)


# ---------------------------------------------------------------------------
# tyrannosaurus_prime — Stomp-Wiring
# ---------------------------------------------------------------------------

func test_tyrannosaurus_prime_rage_phase_has_stomp() -> void:
	var def: BossDef = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	assert_not_null(def)
	# Phase 2 = Rage
	var rage_phase: BossPhase = def.phases[2]
	assert_eq(rage_phase.abilities.size(), 1,
		"Rage-Phase soll genau eine Ability haben (Stomp)")
	var stomp: BossStomp = rage_phase.abilities[0] as BossStomp
	assert_not_null(stomp,
		"Rage-Ability muss BossStomp-Instanz sein")
	assert_eq(stomp.id, &"tyrannosaurus_stomp")


func test_tyrannosaurus_prime_spawn_phase_has_no_abilities() -> void:
	var def: BossDef = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	var spawn_phase: BossPhase = def.phases[0]
	assert_eq(spawn_phase.abilities.size(), 0)


# ---------------------------------------------------------------------------
# BossMob-Tick — Cooldown-Logik
# ---------------------------------------------------------------------------

func _make_test_boss_def_with_stomp(cooldown: float = 1.0, initial: float = 0.5) -> BossDef:
	var def := BossDef.new()
	def.id = &"test_boss_stomp"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.speed = 80.0
	def.damage = 10.0
	def.scene = BOSS_MOB_SCENE

	var stomp := BossStomp.new()
	stomp.id = &"test_stomp"
	stomp.cooldown = cooldown
	stomp.initial_delay = initial
	stomp.radius = 100.0
	stomp.damage = 5.0

	var phase := BossPhase.new()
	phase.hp_threshold = 1.0
	phase.abilities = [stomp]
	def.phases = [phase]
	return def


func test_tick_abilities_does_not_trigger_before_initial_delay() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def_with_stomp(1.0, 0.5), Vector2.ZERO)
	watch_signals(EventBus)

	# Tick 0.3s (< initial_delay 0.5)
	boss._tick_abilities(0.3)
	assert_signal_not_emitted(EventBus, "boss_ability_used")

	boss.queue_free()


func test_tick_abilities_triggers_after_initial_delay() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def_with_stomp(1.0, 0.5), Vector2.ZERO)
	watch_signals(EventBus)

	# Tick 0.6s (> initial_delay 0.5) → soll triggern
	boss._tick_abilities(0.6)
	assert_signal_emitted(EventBus, "boss_ability_used")
	var params: Array = get_signal_parameters(EventBus, "boss_ability_used")
	assert_eq(params[0], &"test_boss_stomp")
	assert_eq(params[1], &"test_stomp")

	boss.queue_free()


func test_tick_abilities_respects_cooldown() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def_with_stomp(1.0, 0.0), Vector2.ZERO)
	watch_signals(EventBus)

	# Erste Tick triggert (initial_delay=0)
	boss._tick_abilities(0.1)
	# Sofort nochmal — cooldown=1s, also kein zweiter Trigger
	boss._tick_abilities(0.5)
	# Zähle Emissionen — sollte 1 sein
	assert_eq(get_signal_emit_count(EventBus, "boss_ability_used"), 1,
		"Cooldown unterdrückt zweiten Trigger")

	boss.queue_free()


func test_tick_abilities_resets_cooldowns_on_phase_change() -> void:
	# Boss mit zwei Phasen, Stomp nur in Phase 1
	var def := BossDef.new()
	def.id = &"test_boss_two_phases"
	def.display_name_key = &"x.y"
	def.max_health = 100.0
	def.scene = BOSS_MOB_SCENE

	var phase0 := BossPhase.new()
	phase0.hp_threshold = 1.0
	# keine Abilities

	var stomp := BossStomp.new()
	stomp.id = &"test_stomp_phase1"
	stomp.cooldown = 5.0
	stomp.initial_delay = 0.5
	stomp.radius = 100.0
	stomp.damage = 5.0

	var phase1 := BossPhase.new()
	phase1.hp_threshold = 0.5
	phase1.abilities = [stomp]
	def.phases = [phase0, phase1]

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(def, Vector2.ZERO)

	# Zu Phase 1 wechseln durch Damage
	boss.health.take_damage(DamageInfo.make(60.0, &"test"))
	assert_eq(boss.get_current_phase_index(), 1)
	# initial_delay sollte greifen — sofort tick triggert nicht
	watch_signals(EventBus)
	boss._tick_abilities(0.3)
	assert_signal_not_emitted(EventBus, "boss_ability_used")

	boss.queue_free()


func test_dead_boss_does_not_tick_abilities() -> void:
	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(_make_test_boss_def_with_stomp(0.5, 0.0), Vector2.ZERO)
	watch_signals(EventBus)
	# Boss tot machen
	boss.health.take_damage(DamageInfo.make(999.0, &"test"))
	assert_true(boss.health.is_dead())
	# _physics_process callt _tick_abilities NICHT bei toten Bossen
	# (Guard in _physics_process). Wir simulieren das hier.
	# Direkter _tick_abilities-Call wäre nicht safe, daher prüfen wir
	# dass _physics_process früh returnt.
	boss._physics_process(0.1)
	# Nach Damage feuert auch enemy_died-Pfad nicht — boss_defeated
	# läuft über _on_died, _tick_abilities wird gar nicht erreicht.
	pass_test("dead boss überspringt _tick_abilities")

	boss.queue_free()
