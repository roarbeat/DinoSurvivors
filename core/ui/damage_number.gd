class_name DamageNumber
extends Node2D
## Floating-Damage-Number-VFX (ADR 0012).
##
## Wird beim Treffer kurz über dem Mob angezeigt, fliegt nach oben,
## fade-out, freed sich selbst.

@onready var label: Label = $Label

# Visual-Spec aus ADR 0012
const NORMAL_COLOR: Color = Color(1, 1, 1)
const CRIT_COLOR: Color = Color(1, 0.82, 0)
const NORMAL_FONT_SIZE: int = 14
const CRIT_FONT_SIZE: int = 20
const NORMAL_RISE: float = 30.0
const CRIT_RISE: float = 50.0
const NORMAL_FADE: float = 0.7
const CRIT_FADE: float = 0.9
const SPAWN_OFFSET: Vector2 = Vector2(0, -15)


# ---------------------------------------------------------------------------
# State (für Tests)
# ---------------------------------------------------------------------------

var _amount: float = 0.0
var _is_crit: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive Stub für Tests, die die Scene-Children nicht haben
	if not has_node("Label"):
		var l := Label.new()
		l.name = "Label"
		add_child(l)
		label = l


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Zeigt die Damage-Number an. world_pos ist die Position des Mobs.
## Self-frees nach Animation.
func show_damage(amount: float, is_crit: bool, world_pos: Vector2) -> void:
	_amount = amount
	_is_crit = is_crit
	global_position = world_pos + SPAWN_OFFSET

	label.text = _format_amount(amount)
	if is_crit:
		label.add_theme_color_override("font_color", CRIT_COLOR)
		label.add_theme_font_size_override("font_size", CRIT_FONT_SIZE)
	else:
		label.add_theme_color_override("font_color", NORMAL_COLOR)
		label.add_theme_font_size_override("font_size", NORMAL_FONT_SIZE)

	_animate()


func get_amount() -> float:
	return _amount


func is_crit() -> bool:
	return _is_crit


# ---------------------------------------------------------------------------
# Format-Helper (testbar, static)
# ---------------------------------------------------------------------------

static func _format_amount(amount: float) -> String:
	# v1: einfache Integer-Anzeige bei Standard-Damage,
	# kompakt bei sehr großen Werten
	var rounded: int = int(round(amount))
	if rounded < 1000:
		return str(rounded)
	# 1.5K-Format
	return "%.1fK" % (rounded / 1000.0)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _animate() -> void:
	var rise: float = CRIT_RISE if _is_crit else NORMAL_RISE
	var fade_dur: float = CRIT_FADE if _is_crit else NORMAL_FADE

	var target_y: float = global_position.y - rise
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "global_position:y", target_y, fade_dur)
	tween.tween_property(label, "modulate:a", 0.0, fade_dur).set_delay(0.2)
	# Nach Tween-Ende self-free
	tween.chain().tween_callback(queue_free)
