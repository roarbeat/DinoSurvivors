class_name HealthBar
extends Node2D
## Generische HP-Bar für Mobs in der Game-World (ADR 0018).
##
## Lokal an eine HealthComponent gebunden — kein EventBus-Aufruf.
## Pro Mob eine eigene Bar.
##
## Im Test: get_displayed_pct() liest die aktuelle Foreground-Width.

@export var bar_width: float = 30.0:
	set(value):
		bar_width = max(1.0, value)
		_apply_layout()

@export var bar_height: float = 4.0:
	set(value):
		bar_height = max(1.0, value)
		_apply_layout()

@export var fg_color: Color = Color(0.2, 0.85, 0.2):
	set(value):
		fg_color = value
		if fg != null:
			fg.color = value

## Wenn true: bei jedem damage_taken zusätzlich ein DamageNumber-VFX
## spawnen (ADR 0012). Default true.
@export var spawn_damage_numbers: bool = true


# Damage-Number-Scene als preload für Spawns
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://core/ui/damage_number.tscn")


@onready var bg: ColorRect = $Background
@onready var fg: ColorRect = $Foreground


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _health: HealthComponent


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive: Tests instantiieren ggf. ohne Scene-Children.
	if has_node("Background"):
		bg = $Background
	else:
		bg = ColorRect.new()
		bg.name = "Background"
		add_child(bg)
	if has_node("Foreground"):
		fg = $Foreground
	else:
		fg = ColorRect.new()
		fg.name = "Foreground"
		add_child(fg)
	_apply_layout()
	_update_visual()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Bindet die Bar an eine HealthComponent. Erneutes Setzen disconnectet
## den vorigen.
func set_health(hp: HealthComponent) -> void:
	if _health == hp:
		return
	# Disconnect alt
	if _health != null and is_instance_valid(_health):
		if _health.damage_taken.is_connected(_on_damage_taken):
			_health.damage_taken.disconnect(_on_damage_taken)
		if _health.healed.is_connected(_on_healed):
			_health.healed.disconnect(_on_healed)
		if _health.died.is_connected(_on_died):
			_health.died.disconnect(_on_died)

	_health = hp
	visible = true
	if _health == null:
		_update_visual()
		return

	_health.damage_taken.connect(_on_damage_taken)
	_health.healed.connect(_on_healed)
	_health.died.connect(_on_died)
	_update_visual()


## Aktueller HP-Anteil als 0..1. Nützlich für Tests.
func get_displayed_pct() -> float:
	if fg == null or bar_width <= 0.0:
		return 0.0
	return clamp(fg.size.x / bar_width, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_damage_taken(info: DamageInfo, _hp_after: float) -> void:
	_update_visual()
	if spawn_damage_numbers and info != null:
		_spawn_damage_number(info)


func _spawn_damage_number(info: DamageInfo) -> void:
	if get_tree() == null:
		return
	var dn: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	# Unter current_scene hängen, damit es nicht beim Mob-queue_free verschwindet.
	var parent: Node = get_tree().current_scene
	if parent == null:
		# Test-Setup: Fallback auf eigenen Parent
		parent = get_parent()
	if parent == null:
		dn.queue_free()
		return
	parent.add_child(dn)
	dn.show_damage(info.amount, info.is_crit, global_position)


func _on_healed(_amount: float, _hp_after: float) -> void:
	_update_visual()


func _on_died(_info: DamageInfo) -> void:
	visible = false


func _apply_layout() -> void:
	if bg != null:
		bg.size = Vector2(bar_width, bar_height)
		bg.position = Vector2(-bar_width * 0.5, 0)
		bg.color = Color(0.12, 0.12, 0.12)
	if fg != null:
		fg.position = Vector2(-bar_width * 0.5, 0)
		fg.color = fg_color


func _update_visual() -> void:
	if fg == null:
		return
	var pct: float = 1.0
	if _health != null and is_instance_valid(_health):
		pct = _health.get_hp_pct()
	fg.size = Vector2(bar_width * pct, bar_height)
