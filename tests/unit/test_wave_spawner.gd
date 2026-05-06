extends "res://addons/gut/test.gd"
## Wave-Lifecycle-Tests.

func before_each() -> void:
	# Frischer Run-Start für jeden Test
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()
	WaveSpawner.set_wave_duration(60.0)  # langer Default
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
	# v1: nur raptor_grunt
	assert_eq(WaveSpawner._enemy_id_for_wave(1), &"raptor_grunt")
	assert_eq(WaveSpawner._enemy_id_for_wave(50), &"raptor_grunt")


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
