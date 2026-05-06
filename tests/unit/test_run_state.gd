extends "res://addons/gut/test.gd"
## State-Maschinen-Tests für RunState.

func before_each() -> void:
	RunState.reset()
	watch_signals(EventBus)


func after_each() -> void:
	# Räumt RUNNING auf, sonst leakt der Active-State in andere Tests
	# (z.B. test_wave_spawner, dessen Spawner über EventBus.run_started subscribed)
	if RunState.is_running():
		RunState.end(&"test_cleanup")
	RunState.reset()


# ---------------------------------------------------------------------------
# State-Übergänge
# ---------------------------------------------------------------------------

func test_initial_state_is_idle() -> void:
	assert_true(RunState.is_idle())
	assert_false(RunState.is_running())
	assert_false(RunState.is_ended())


func test_start_with_known_dino_succeeds() -> void:
	var ok := RunState.start(&"trex")
	assert_true(ok)
	assert_true(RunState.is_running())
	assert_false(RunState.is_idle())


func test_start_with_unknown_dino_fails() -> void:
	var ok := RunState.start(&"velociraptor_does_not_exist")
	assert_false(ok)
	assert_true(RunState.is_idle(), "State darf bei Failure nicht wechseln")


func test_start_during_running_is_noop() -> void:
	RunState.start(&"trex")
	var second := RunState.start(&"trex")
	assert_false(second, "zweiter start aus RUNNING muss false zurückgeben")


func test_end_transitions_running_to_ended() -> void:
	RunState.start(&"trex")
	RunState.end(&"player_died")
	assert_true(RunState.is_ended())
	assert_false(RunState.is_running())
	assert_eq(RunState.get_last_end_reason(), &"player_died")


func test_end_from_idle_is_noop() -> void:
	RunState.end(&"whatever")
	assert_true(RunState.is_idle(),
		"end() aus IDLE darf keinen State-Wechsel auslösen")


func test_reset_returns_to_idle_from_ended() -> void:
	RunState.start(&"trex")
	RunState.end(&"quit")
	RunState.reset()
	assert_true(RunState.is_idle())
	assert_eq(RunState.get_active_dino(), null)


# ---------------------------------------------------------------------------
# EventBus-Integration
# ---------------------------------------------------------------------------

func test_run_started_signal_carries_dino_id() -> void:
	RunState.start(&"trex")
	assert_signal_emitted_with_parameters(EventBus, "run_started", [&"trex"])


func test_run_ended_signal_carries_reason_and_time() -> void:
	RunState.start(&"trex")
	RunState.end(&"player_died")
	assert_signal_emitted(EventBus, "run_ended")
	var params: Array = get_signal_parameters(EventBus, "run_ended")
	assert_eq(params[0], &"player_died")
	assert_typeof(params[1], TYPE_FLOAT)
	# Run-Time ist > 0 (sollte zumindest einige ms gewesen sein)
	assert_gte(params[1], 0.0)


# ---------------------------------------------------------------------------
# Active-Dino
# ---------------------------------------------------------------------------

func test_active_dino_is_null_when_idle() -> void:
	assert_eq(RunState.get_active_dino(), null)


func test_active_dino_set_after_start() -> void:
	RunState.start(&"trex")
	var d := RunState.get_active_dino()
	assert_not_null(d)
	assert_eq(d.id, &"trex")
