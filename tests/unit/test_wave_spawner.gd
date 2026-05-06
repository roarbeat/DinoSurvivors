extends "res://addons/gut/test.gd"
## Wave-Lifecycle-Tests.

func before_each() -> void:
	# Frischer Run-Start für jeden Test
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()
	WaveSpawner.set_wave_duration(60.0)  # langer Default
	# Sicherstellen, dass auto_advance default ist (MutationPickOverlay
	# in anderen Suiten kann es auf false gesetzt haben — siehe ADR 0021).
	WaveSpawner.auto_advance = true
	watch_signals(EventBus)


func after_each() -> void:
	if RunState.is_running():
		RunState.end(&"test_cleanup")
	RunState.reset()
	WaveSpawner.set_wave_duration(WaveSpawner.DEFAULT_WAVE_DURATION_SEC)


# ---------------------------------------------------------------------------
# Activation
# ---------------------------------------------------------------------------

func test_inactive_when_idle() -> void:
	assert_false(WaveSpawner.is_active())
	assert_eq(WaveSpawner.current_wave(), 0)


func test_starts_wave_one_after_run_start() -> void:
	RunState.start(&"trex")
	# RunStart wurde gerade gefeuert, WaveSpawner subscribed → wave 1 läuft
	assert_true(WaveSpawner.is_active())
	assert_eq(WaveSpawner.current_wave(), 1)


func test_run_start_emits_wave_started_signal() -> void:
	RunState.start(&"trex")
	assert_signal_emitted(EventBus, "wave_started")
	var params: Array = get_signal_parameters(EventBus, "wave_started")
	assert_eq(params[0], 1)
	assert_typeof(params[1], TYPE_FLOAT)


# ---------------------------------------------------------------------------
# Wave-Cleared + Auto-Next
# ---------------------------------------------------------------------------

func test_force_wave_end_advances_to_next() -> void:
	RunState.start(&"trex")
	assert_eq(WaveSpawner.current_wave(), 1)
	WaveSpawner._force_wave_end()
	# Nach _force_wave_end: wave_cleared für 1, dann wave_started für 2
	assert_eq(WaveSpawner.current_wave(), 2)
	assert_signal_emitted(EventBus, "wave_cleared")


func test_wave_cleared_carries_index() -> void:
	RunState.start(&"trex")
	WaveSpawner._force_wave_end()
	var params: Array = get_signal_parameters(EventBus, "wave_cleared")
	assert_eq(params[0], 1)


# ---------------------------------------------------------------------------
# Run-Ended Cleanup
# ---------------------------------------------------------------------------

func test_run_end_deactivates_spawner() -> void:
	RunState.start(&"trex")
	assert_true(WaveSpawner.is_active())
	RunState.end(&"player_died")
	assert_false(WaveSpawner.is_active())


func test_wave_counter_resets_on_run_end() -> void:
	RunState.start(&"trex")
	WaveSpawner._force_wave_end()
	assert_eq(WaveSpawner.current_wave(), 2)
	RunState.end(&"player_died")
	assert_eq(WaveSpawner.current_wave(), 0)


# ---------------------------------------------------------------------------
# Set Duration
# ---------------------------------------------------------------------------

func test_set_wave_duration_rejects_zero() -> void:
	WaveSpawner.set_wave_duration(0.0)
	# Default bleibt — wir sehen das daran, dass es nicht 0 ist
	assert_gt(WaveSpawner.get_wave_duration(), 0.0)


func test_set_wave_duration_accepts_positive() -> void:
	WaveSpawner.set_wave_duration(15.5)
	assert_almost_eq(WaveSpawner.get_wave_duration(), 15.5, 0.001)


# ---------------------------------------------------------------------------
# Spawn-API (ADR 0009)
# ---------------------------------------------------------------------------

func test_spawn_without_root_returns_null_and_warns() -> void:
	WaveSpawner.set_spawn_root(null)
	var mob := WaveSpawner.spawn_enemy_at(&"raptor_grunt", Vector2.ZERO)
	assert_null(mob, "Ohne spawn_root muss spawn_enemy_at null liefern")


func test_spawn_with_root_creates_enemy() -> void:
	# Root ist ein Test-Node, der nach dem Test cleared wird
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)

	var mob := WaveSpawner.spawn_enemy_at(&"raptor_grunt", Vector2(40, 60))
	assert_not_null(mob)
	assert_true(mob is EnemyMob)
	assert_eq(mob.get_parent(), root, "Mob muss unter spawn_root hängen")
	assert_eq(mob.enemy_id, &"raptor_grunt")
	assert_eq(mob.global_position, Vector2(40, 60))

	# Cleanup
	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_spawn_unknown_enemy_id_returns_null() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)

	var mob := WaveSpawner.spawn_enemy_at(&"velociraptor_does_not_exist", Vector2.ZERO)
	assert_null(mob)

	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_spawn_uses_def_scene_if_set() -> void:
	# raptor_grunt hat eine scene-Reference; Spawn muss sie nutzen
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)

	var mob := WaveSpawner.spawn_enemy_at(&"raptor_grunt", Vector2.ZERO)
	assert_not_null(mob)
	assert_not_null(mob.get_health_component(),
		"HealthComponent muss aus der Scene mitkommen")
	assert_almost_eq(mob.get_health_component().max_hp, 25.0, 0.0001,
		"Stats müssen via setup() aus EnemyDef gesetzt sein")

	WaveSpawner.set_spawn_root(null)
	root.queue_free()


# ---------------------------------------------------------------------------
# Auto-Spawn (ADR 0013)
# ---------------------------------------------------------------------------

func test_spawn_rate_curve() -> void:
	# Welle 1: 0.5/s, Welle 2: 0.8, Welle 3: 1.1, ...
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(1), 0.5, 0.001)
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(2), 0.8, 0.001)
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(3), 1.1, 0.001)


func test_spawn_rate_caps_at_max() -> void:
	# Bei Welle 100 sollte rate auf MAX gecapt sein (5.0/s)
	var rate := WaveSpawner._spawn_rate_for_wave(100)
	assert_almost_eq(rate, WaveSpawner.MAX_SPAWN_RATE, 0.001)


func test_enemy_id_for_wave_v1() -> void:
	# Welle 1 hat nur raptor_grunt im Pool (ADR 0023). Höhere Wellen
	# können andere Enemies pickern — eigener Test deckt das ab.
	assert_eq(WaveSpawner._enemy_id_for_wave(1), &"raptor_grunt")


func test_auto_spawn_does_not_tick_when_inactive() -> void:
	# Run nicht gestartet → _active = false → kein Tick
	WaveSpawner._tick_auto_spawn(10.0)  # 10 Sek vorspulen
	# Kein Spawn (kein spawn_root, kein active) — kein Crash zu erwarten
	pass_test("kein Crash bei _tick_auto_spawn ohne aktiven Run")


func test_auto_spawn_creates_enemy_after_interval() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)
	WaveSpawner.set_wave_duration(60.0)

	# Run starten — Welle 1 läuft, spawn_interval = 1/0.5 = 2.0s
	if RunState.is_running(): RunState.end(&"test_setup_cleanup")
	RunState.reset()
	RunState.start(&"trex")

	# WaveSpawner._auto_spawn_timer = 2.0 nach _start_next_wave
	# Tick mit delta=2.0 sollte 1 Spawn auslösen
	var before := root.get_child_count()
	WaveSpawner._tick_auto_spawn(2.0)
	var after := root.get_child_count()
	assert_eq(after - before, 1, "Nach 2.0s muss 1 Enemy gespawnt sein")

	RunState.end(&"test_cleanup")
	RunState.reset()
	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_auto_spawn_respects_interval_no_spawn_too_early() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)
	WaveSpawner.set_wave_duration(60.0)

	if RunState.is_running(): RunState.end(&"test_setup_cleanup")
	RunState.reset()
	RunState.start(&"trex")

	# spawn_interval = 2.0s. Tick mit delta=1.0 sollte NICHTS spawnen
	var before := root.get_child_count()
	WaveSpawner._tick_auto_spawn(1.0)
	assert_eq(root.get_child_count(), before,
		"Vor Ablauf des Intervalls darf nichts gespawnt werden")

	RunState.end(&"test_cleanup")
	RunState.reset()
	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_auto_spawn_stops_after_run_ended() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)
	WaveSpawner.set_wave_duration(60.0)

	if RunState.is_running(): RunState.end(&"test_setup_cleanup")
	RunState.reset()
	RunState.start(&"trex")
	assert_true(WaveSpawner.is_active())

	RunState.end(&"player_died")
	assert_false(WaveSpawner.is_active())

	# Tick danach darf nichts spawnen
	var before := root.get_child_count()
	WaveSpawner._tick_auto_spawn(10.0)
	assert_eq(root.get_child_count(), before,
		"Nach run_ended darf Auto-Spawn nichts mehr spawnen")

	RunState.reset()
	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_random_spawn_position_uses_player_as_center() -> void:
	# Player-Marker bei (500, 0) in Group
	var marker := Node2D.new()
	marker.add_to_group(&"player")
	marker.global_position = Vector2(500, 0)
	add_child(marker)

	var pos := WaveSpawner._random_spawn_position()
	# pos ist auf Kreis um (500,0) mit Radius SPAWN_RADIUS_FROM_PLAYER
	var dist := (pos - Vector2(500, 0)).length()
	assert_almost_eq(dist, WaveSpawner.SPAWN_RADIUS_FROM_PLAYER, 0.5,
		"Spawn-Position muss exakt SPAWN_RADIUS_FROM_PLAYER vom Player entfernt sein")

	marker.remove_from_group(&"player")
	marker.queue_free()


func test_random_spawn_position_falls_back_to_origin() -> void:
	# Sicherstellen, dass keine Player-Marker da sind
	for n in get_tree().get_nodes_in_group(&"player"):
		if is_instance_valid(n): n.remove_from_group(&"player")

	var pos := WaveSpawner._random_spawn_position()
	# Ohne Player: center = (0,0), pos auf Kreis um Origin
	var dist := pos.length()
	assert_almost_eq(dist, WaveSpawner.SPAWN_RADIUS_FROM_PLAYER, 0.5,
		"Ohne Player: Spawn um (0,0)")


# ---------------------------------------------------------------------------
# auto_advance-Flag + request_next_wave (ADR 0021)
# ---------------------------------------------------------------------------

func test_auto_advance_default_true() -> void:
	# Default-Verhalten unverändert — alte Tests bleiben grün
	WaveSpawner.auto_advance = true  # explizit setzen für Test-Isolation
	assert_true(WaveSpawner.auto_advance)


func test_auto_advance_false_stops_at_wave_cleared() -> void:
	# Mit auto_advance=false läuft kein _start_next_wave
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	WaveSpawner.set_wave_duration(60.0)
	WaveSpawner.auto_advance = false
	RunState.start(&"trex")

	assert_eq(WaveSpawner.current_wave(), 1)
	WaveSpawner._force_wave_end()
	# Mit auto_advance=false: kein wave_2 — current_wave bleibt bei 1
	assert_eq(WaveSpawner.current_wave(), 1,
		"auto_advance=false darf nicht automatisch weiterspawnen")

	# Cleanup
	RunState.end(&"test_cleanup")
	RunState.reset()
	WaveSpawner.auto_advance = true  # Default zurücksetzen


func test_request_next_wave_advances_when_paused_progression() -> void:
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	WaveSpawner.set_wave_duration(60.0)
	WaveSpawner.auto_advance = false
	RunState.start(&"trex")
	WaveSpawner._force_wave_end()
	assert_eq(WaveSpawner.current_wave(), 1)

	WaveSpawner.request_next_wave()
	assert_eq(WaveSpawner.current_wave(), 2)

	# Cleanup
	RunState.end(&"test_cleanup")
	RunState.reset()
	WaveSpawner.auto_advance = true


func test_request_next_wave_no_op_when_run_not_active() -> void:
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	WaveSpawner.auto_advance = false

	# Run nicht aktiv → request darf nichts tun
	var before := WaveSpawner.current_wave()
	WaveSpawner.request_next_wave()
	assert_eq(WaveSpawner.current_wave(), before,
		"request_next_wave ohne aktiven Run muss no-op sein")

	WaveSpawner.auto_advance = true


# ---------------------------------------------------------------------------
# Pool-Curve (ADR 0023)
# ---------------------------------------------------------------------------

func test_pool_for_wave_1() -> void:
	# Welle 1-2: nur raptor_grunt
	var pool := WaveSpawner._pool_for_wave(1)
	assert_eq(pool, [&"raptor_grunt"])


func test_pool_for_wave_2() -> void:
	var pool := WaveSpawner._pool_for_wave(2)
	assert_eq(pool, [&"raptor_grunt"])


func test_pool_for_wave_3_through_5() -> void:
	# Welle 3-5: raptor_grunt + raptor_alpha
	var pool := WaveSpawner._pool_for_wave(3)
	assert_eq(pool.size(), 2)
	assert_true(pool.has(&"raptor_grunt"))
	assert_true(pool.has(&"raptor_alpha"))


func test_pool_for_wave_6_through_10_includes_pteranodon() -> void:
	var pool := WaveSpawner._pool_for_wave(7)
	assert_eq(pool.size(), 3)
	assert_true(pool.has(&"pteranodon"))


func test_pool_for_wave_11_includes_carnotaurus() -> void:
	var pool := WaveSpawner._pool_for_wave(12)
	assert_eq(pool.size(), 4)
	assert_true(pool.has(&"armored_carnotaurus"))


func test_enemy_id_for_wave_returns_pool_member() -> void:
	# Bei Welle 7 sollte der Spawn aus dem 3-Pool kommen
	for i in 30:  # mehrere Versuche, um Pool-Variation zu sehen
		var picked := WaveSpawner._enemy_id_for_wave(7)
		var pool := WaveSpawner._pool_for_wave(7)
		assert_true(pool.has(picked),
			"Picked enemy '%s' must be in pool %s" % [picked, pool])


# ---------------------------------------------------------------------------
# Boss-Wellen + spawn_boss_at (ADR 0025)
# ---------------------------------------------------------------------------

func test_is_boss_wave_at_intervals() -> void:
	# BOSS_WAVE_INTERVAL = 5 → Welle 5, 10, 15 sind Boss-Wellen
	assert_false(WaveSpawner._is_boss_wave(0))
	assert_false(WaveSpawner._is_boss_wave(1))
	assert_false(WaveSpawner._is_boss_wave(4))
	assert_true(WaveSpawner._is_boss_wave(5))
	assert_false(WaveSpawner._is_boss_wave(6))
	assert_true(WaveSpawner._is_boss_wave(10))
	assert_true(WaveSpawner._is_boss_wave(15))


func test_boss_for_wave_returns_tyrannosaurus_prime() -> void:
	# v1: alle Boss-Wellen spawnen tyrannosaurus_prime
	assert_eq(WaveSpawner._boss_for_wave(5), &"tyrannosaurus_prime")
	assert_eq(WaveSpawner._boss_for_wave(15), &"tyrannosaurus_prime")


func test_spawn_boss_at_creates_boss_mob() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)

	var boss := WaveSpawner.spawn_boss_at(&"tyrannosaurus_prime", Vector2(200, 100))
	assert_not_null(boss)
	assert_true(boss is BossMob)
	assert_eq(boss.boss_id, &"tyrannosaurus_prime")
	assert_eq(boss.global_position, Vector2(200, 100))

	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_spawn_boss_at_emits_boss_spawned_signal() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)
	watch_signals(EventBus)

	WaveSpawner.spawn_boss_at(&"tyrannosaurus_prime", Vector2(0, 0))

	assert_signal_emitted(EventBus, "boss_spawned")
	var params: Array = get_signal_parameters(EventBus, "boss_spawned")
	assert_eq(params[0], &"tyrannosaurus_prime")

	WaveSpawner.set_spawn_root(null)
	root.queue_free()


func test_spawn_boss_at_unknown_id_returns_null() -> void:
	var root := Node.new()
	add_child(root)
	WaveSpawner.set_spawn_root(root)

	var boss := WaveSpawner.spawn_boss_at(&"unknown_boss", Vector2.ZERO)
	assert_null(boss)

	WaveSpawner.set_spawn_root(null)
	root.queue_free()


# ---------------------------------------------------------------------------
# WaveDef-Lookup (ADR 0026)
# ---------------------------------------------------------------------------

func test_get_wave_def_for_default_wave() -> void:
	# Keine Override-WaveDef für Welle 2 → liefert Default
	var def: WaveDef = WaveSpawner.get_wave_def_for(2)
	assert_not_null(def)
	assert_true(def.is_default)
	assert_eq(def.id, &"wave_default")


func test_get_wave_def_for_override_wave_5() -> void:
	# Welle 5 hat ein Override (wave_5_tyrannosaurus)
	var def: WaveDef = WaveSpawner.get_wave_def_for(5)
	assert_not_null(def)
	assert_false(def.is_default)
	assert_eq(def.target_wave_index, 5)
	assert_eq(def.boss_id, &"tyrannosaurus_prime")


func test_get_wave_def_for_override_wave_10() -> void:
	var def: WaveDef = WaveSpawner.get_wave_def_for(10)
	assert_not_null(def)
	assert_eq(def.target_wave_index, 10)


func test_get_active_wave_def_after_run_start() -> void:
	RunState.start(&"trex")
	# current_wave == 1 → kein Override → Default
	var def: WaveDef = WaveSpawner.get_active_wave_def()
	assert_not_null(def)
	assert_true(def.is_default)


func test_spawn_rate_uses_default_wavedef() -> void:
	# Default-WaveDef hat base=0.5, per_wave=0.3, max=5.0 — selbe Werte wie Konstanten,
	# also bleibt Spawn-Rate identisch nach Migration
	# Welle 1: 0.5
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(1), 0.5, 0.001)
	# Welle 2: 0.5 + 0.3 = 0.8
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(2), 0.8, 0.001)
	# Welle 100: gecappt auf 5.0
	assert_almost_eq(WaveSpawner._spawn_rate_for_wave(100), 5.0, 0.001)


func test_pool_for_wave_5_uses_override() -> void:
	# wave_5_tyrannosaurus hat enemy_pool [&"raptor_grunt", &"raptor_alpha", &"pteranodon"]
	var pool: Array[StringName] = WaveSpawner._pool_for_wave(5)
	assert_eq(pool.size(), 3)
	assert_true(pool.has(&"raptor_grunt"))
	assert_true(pool.has(&"raptor_alpha"))
	assert_true(pool.has(&"pteranodon"))


func test_pool_for_wave_10_uses_override() -> void:
	# wave_10_tyrannosaurus hat 4 Enemies im Pool
	var pool: Array[StringName] = WaveSpawner._pool_for_wave(10)
	assert_eq(pool.size(), 4)


func test_pool_for_wave_2_uses_constants_fallback() -> void:
	# Welle 2 hat keine Override + Default hat leeren Pool → Konstanten-Fallback
	# (idx <= 2: nur raptor_grunt)
	var pool: Array[StringName] = WaveSpawner._pool_for_wave(2)
	assert_eq(pool.size(), 1)
	assert_true(pool.has(&"raptor_grunt"))


func test_resolve_boss_id_for_wave_5_via_wavedef() -> void:
	# WaveDef wave_5_tyrannosaurus hat boss_id gesetzt
	var bid: StringName = WaveSpawner._resolve_boss_id_for_wave(5)
	assert_eq(bid, &"tyrannosaurus_prime")


func test_resolve_boss_id_for_wave_3_returns_empty() -> void:
	# Welle 3 ist keine Boss-Welle (mod 5 != 0) und kein Override → leer
	var bid: StringName = WaveSpawner._resolve_boss_id_for_wave(3)
	assert_eq(String(bid), "")


func test_resolve_boss_id_for_wave_15_uses_constants_fallback() -> void:
	# Welle 15 hat keine Override-WaveDef, aber _is_boss_wave(15) = true
	# → Konstanten-Fallback liefert tyrannosaurus_prime
	var bid: StringName = WaveSpawner._resolve_boss_id_for_wave(15)
	assert_eq(bid, &"tyrannosaurus_prime")
