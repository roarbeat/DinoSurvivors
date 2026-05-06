extends "res://addons/gut/test.gd"
## HUD-Tests (ADR 0020).
##
## Format-Helper sind static — direkt testbar.
## Lifecycle-Tests laden die Scene und triggern EventBus-Signals.

# ---------------------------------------------------------------------------
# Format-Helper
# ---------------------------------------------------------------------------

func test_format_time_zero() -> void:
	assert_eq(HUDOverlay._format_time(0.0), "0:00")


func test_format_time_seconds_only() -> void:
	assert_eq(HUDOverlay._format_time(7.5), "0:07")


func test_format_time_minutes_seconds() -> void:
	assert_eq(HUDOverlay._format_time(125.0), "2:05")


func test_format_time_zero_pads_seconds() -> void:
	assert_eq(HUDOverlay._format_time(63.0), "1:03",
		"Sekunden müssen zweistellig gepaddet sein")


func test_format_time_clamps_negative() -> void:
	assert_eq(HUDOverlay._format_time(-5.0), "0:00",
		"Negative Sekunden → 0:00")


# ---------------------------------------------------------------------------
# update_wave / update_mutations
# ---------------------------------------------------------------------------

var _hud: HUDOverlay


func before_each() -> void:
	var packed := load("res://core/ui/hud.tscn") as PackedScene
	_hud = packed.instantiate() as HUDOverlay
	add_child(_hud)


func after_each() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func test_update_wave_sets_label() -> void:
	_hud.update_wave(3, 1.0)
	assert_eq(_hud.wave_label.text, "Wave 3")


func test_update_wave_with_difficulty_appends_multiplier() -> void:
	_hud.update_wave(5, 1.4)
	assert_string_contains(_hud.wave_label.text, "Wave 5")
	assert_string_contains(_hud.wave_label.text, "1.4")


func test_update_mutations_empty_shows_placeholder() -> void:
	_hud.update_mutations([])
	assert_string_contains(_hud.mutations_label.text, "no mutations")


func test_update_mutations_shows_ids() -> void:
	_hud.update_mutations([&"triceratops_horns", &"spinosaur_sail"])
	assert_string_contains(_hud.mutations_label.text, "triceratops_horns")
	assert_string_contains(_hud.mutations_label.text, "spinosaur_sail")


# ---------------------------------------------------------------------------
# Visibility
# ---------------------------------------------------------------------------

func test_initial_invisible() -> void:
	assert_false(_hud.visible, "HUD muss initial unsichtbar sein")


func test_set_run_active_toggles_visibility() -> void:
	_hud.set_run_active(true)
	assert_true(_hud.visible)
	_hud.set_run_active(false)
	assert_false(_hud.visible)


# ---------------------------------------------------------------------------
# EventBus-Integration
# ---------------------------------------------------------------------------

func test_run_started_makes_hud_visible() -> void:
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	# HUD ist initial unsichtbar
	assert_false(_hud.visible)
	# run_started feuern
	EventBus.run_started.emit(&"trex")
	assert_true(_hud.visible)
	assert_eq(_hud.timer_label.text, "0:00")
	# Cleanup — wir haben nicht via RunState.start gestartet, also keine
	# Cleanup-Risiken
	EventBus.run_ended.emit(&"test_cleanup", 0.0)


func test_run_ended_hides_hud() -> void:
	EventBus.run_started.emit(&"trex")
	assert_true(_hud.visible)
	EventBus.run_ended.emit(&"player_died", 5.0)
	assert_false(_hud.visible)


func test_wave_started_updates_label() -> void:
	EventBus.run_started.emit(&"trex")
	EventBus.wave_started.emit(7, 1.5)
	assert_string_contains(_hud.wave_label.text, "Wave 7")
	EventBus.run_ended.emit(&"test_cleanup", 0.0)


func test_mutations_changed_pulls_from_player_mutations() -> void:
	# Player-Mutations setzen, mutations_changed feuert dabei automatisch
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	PlayerMutations.reset()

	EventBus.run_started.emit(&"trex")
	# Direkt mutations_changed simulieren (statt Pick, damit Player-State
	# nicht durch Validation in den Weg kommt)
	PlayerMutations.pick(&"triceratops_horns")
	# mutations_changed wird automatisch gefeuert
	assert_string_contains(_hud.mutations_label.text, "triceratops_horns")
	PlayerMutations.reset()
	EventBus.run_ended.emit(&"test_cleanup", 0.0)
