extends "res://addons/gut/test.gd"
## GameOverOverlay-Tests (ADR 0019).

var _overlay: GameOverOverlay


func before_each() -> void:
	var packed := load("res://core/ui/game_over.tscn") as PackedScene
	_overlay = packed.instantiate() as GameOverOverlay
	add_child(_overlay)


func after_each() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


# ---------------------------------------------------------------------------
# Initial-State
# ---------------------------------------------------------------------------

func test_initial_visibility_false() -> void:
	assert_false(_overlay.is_shown(),
		"Overlay muss initial unsichtbar sein")


# ---------------------------------------------------------------------------
# show_run_ended / hide_overlay
# ---------------------------------------------------------------------------

func test_show_run_ended_makes_visible() -> void:
	_overlay.show_run_ended(&"player_died", 60.0, 2)
	assert_true(_overlay.is_shown())


func test_hide_overlay_makes_invisible() -> void:
	_overlay.show_run_ended(&"player_died", 60.0, 2)
	_overlay.hide_overlay()
	assert_false(_overlay.is_shown())


# ---------------------------------------------------------------------------
# Stats-Anzeige
# ---------------------------------------------------------------------------

func test_stats_label_shows_reason() -> void:
	_overlay.show_run_ended(&"boss_defeat", 125.0, 5)
	var label_text := _overlay.stats_label.text
	assert_string_contains(label_text, "boss_defeat",
		"Reason muss im Label stehen")


func test_stats_label_shows_time_minutes_seconds() -> void:
	_overlay.show_run_ended(&"player_died", 125.0, 5)
	var label_text := _overlay.stats_label.text
	# 125s = 2:05
	assert_string_contains(label_text, "2:05")


func test_stats_label_shows_wave() -> void:
	_overlay.show_run_ended(&"player_died", 60.0, 7)
	var label_text := _overlay.stats_label.text
	assert_string_contains(label_text, "7")
