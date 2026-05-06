class_name GameOverOverlay
extends CanvasLayer
## Game-Over-Overlay (ADR 0019).
##
## Wird von RunScene auf EventBus.run_ended angezeigt. Zeigt Run-Stats
## und einen Restart-Hint. Initial unsichtbar.

@onready var panel: Control = $Panel
@onready var stats_label: Label = $Panel/StatsLabel


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive: auch wenn die Scene-Children fehlen, kein Crash
	if not has_node("Panel"):
		var p := Control.new()
		p.name = "Panel"
		add_child(p)
		panel = p
	if not has_node("Panel/StatsLabel"):
		var l := Label.new()
		l.name = "StatsLabel"
		panel.add_child(l)
		stats_label = l
	visible = false


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Zeigt das Overlay mit Run-Stats. Wird von RunScene auf run_ended gerufen.
func show_run_ended(reason: StringName, run_time: float, wave: int) -> void:
	stats_label.text = _format_stats(reason, run_time, wave)
	visible = true


## Versteckt das Overlay (z.B. beim Restart).
func hide_overlay() -> void:
	visible = false


func is_shown() -> bool:
	return visible


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _format_stats(reason: StringName, run_time: float, wave: int) -> String:
	var minutes: int = int(run_time) / 60
	var seconds: int = int(run_time) % 60
	# Dev-Strings — i18n-Keys kommen mit lore-writer + UI-ADR
	return "GAME OVER\n\nReason: %s\nTime: %d:%02d\nWave reached: %d\n\n[Enter] Restart" % [
		reason, minutes, seconds, wave
	]
