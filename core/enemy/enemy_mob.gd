class_name EnemyMob
extends Node2D
## Generischer Enemy-Mob (ADR 0009).
##
## Stationäre HP-Säcke in v1 — kein Movement, kein AI. Bewegung kommt
## mit eigenem Movement-ADR.
##
## enemy_id (Convention aus ADR 0007) ist Pflicht — HealthComponent's
## Death-Pfad liest dieses Property, um EventBus.enemy_died korrekt
## zu feuern.

# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

@onready var health: HealthComponent = $Health
@onready var dealer: DamageDealerComponent = $Dealer


# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Wird vom Spawner aus EnemyDef.id übertragen. HealthComponent's
## Death-Pfad liest dieses Property (Convention aus ADR 0007).
@export var enemy_id: StringName = &""


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _def: EnemyDef


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Group-Konvention (ADR 0011): PlayerCharacter findet Enemies darüber.
	add_to_group(&"enemy")

	# Same Pattern wie PlayerCharacter: für Tests, die EnemyMob direkt
	# instantiieren ohne Scene-Setup.
	if has_node("Health"):
		health = $Health
	else:
		health = HealthComponent.new()
		health.name = "Health"
		add_child(health)
	if has_node("Dealer"):
		dealer = $Dealer
	else:
		dealer = DamageDealerComponent.new()
		dealer.name = "Dealer"
		add_child(dealer)

	health.is_player = false

	# HP-Bar binden, sofern in der Scene angelegt (ADR 0018)
	if has_node("HealthBar"):
		var hpbar: HealthBar = $HealthBar
		hpbar.set_health(health)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Konfiguriert den Mob aus seiner EnemyDef. Setzt enemy_id, max_hp,
## position, default_source_id auf dem Dealer.
func setup(def: EnemyDef, pos: Vector2) -> void:
	if def == null:
		push_warning("EnemyMob.setup: def ist null")
		return
	_def = def
	enemy_id = def.id
	global_position = pos

	# Stats
	health.max_hp = def.max_health
	health.reset_to_full()

	# Dealer
	dealer.default_source_id = def.id

	# Visuals (ADR 0024) — Body-Color, -Size + HealthBar-Offset
	_apply_visuals(def)


func _apply_visuals(def: EnemyDef) -> void:
	# Visual-Provider (ADR 0027): wenn visual_scene gesetzt, instanzieren
	# und ColorRect verstecken. Sonst Color/Size-Modus (ADR 0024).
	if def.visual_scene != null:
		_spawn_visual_scene(def.visual_scene)
		var body_node := get_node_or_null("Body") as ColorRect
		if body_node != null:
			body_node.visible = false
		var bar := get_node_or_null("HealthBar") as Node2D
		if bar != null:
			bar.position = Vector2(0, -8.0) + def.visual_pivot_offset
		return

	# Fallback: ColorRect-Mode
	var body_node := get_node_or_null("Body") as ColorRect
	if body_node != null:
		body_node.visible = true
		body_node.color = def.body_color
		var half := def.body_size * 0.5
		body_node.offset_left = -half.x
		body_node.offset_top = -half.y
		body_node.offset_right = half.x
		body_node.offset_bottom = half.y

	var bar := get_node_or_null("HealthBar") as Node2D
	if bar != null:
		bar.position.y = -(def.body_size.y * 0.5) - 8.0


## Instanziert die Visual-Scene als Child unter dem Mob. Existierende
## Visual-Instanzen werden vorher entfernt (Idempotenz für Resetup).
func _spawn_visual_scene(scene: PackedScene) -> void:
	# Vorhandene Visual-Instanz aufräumen
	var existing := get_node_or_null("Visual")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var inst := scene.instantiate()
	if inst is Node:
		inst.name = "Visual"
		add_child(inst)


func get_def() -> EnemyDef:
	return _def


func get_health_component() -> HealthComponent:
	return health


func get_dealer_component() -> DamageDealerComponent:
	return dealer


# ---------------------------------------------------------------------------
# Movement (ADR 0017)
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _def == null:
		return
	if health == null or health.is_dead():
		return
	_move_toward_player(delta)


## Bewegt den Mob ein Stück Richtung nähestem Player. Pure Vector-Math —
## kein Physics, keine Avoidance.
func _move_toward_player(delta: float) -> void:
	var player := _find_nearest_player()
	if player == null:
		return
	var diff: Vector2 = player.global_position - global_position
	if diff.length_squared() <= 0.0:
		return
	var dir: Vector2 = diff.normalized()
	global_position += dir * get_speed() * delta


## Findet den nähesten Player über Group-Konvention (ADR 0011).
## null wenn keiner in der Group ist.
func _find_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	for node in get_tree().get_nodes_in_group(&"player"):
		if node == null or not (node is Node2D):
			continue
		if not is_instance_valid(node):
			continue
		var n: Node2D = node
		var d_sq: float = (n.global_position - global_position).length_squared()
		if d_sq < nearest_dist_sq:
			nearest = n
			nearest_dist_sq = d_sq
	return nearest


## Effektive Speed (aus EnemyDef.speed, später durch Modifier erweiterbar).
func get_speed() -> float:
	if _def == null:
		return 0.0
	return _def.speed
