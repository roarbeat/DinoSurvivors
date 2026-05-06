class_name BossMob
extends Node2D
## Generischer Boss-Mob (ADR 0025).
##
## Analog zu EnemyMob, aber mit eigenem Death-Pfad: feuert
## EventBus.boss_defeated statt enemy_died.

# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

@onready var health: HealthComponent = $Health
@onready var dealer: DamageDealerComponent = $Dealer


# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Wird vom Spawner aus BossDef.id übertragen.
@export var boss_id: StringName = &""


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _def: BossDef
var _spawn_time_msec: int = 0
## Aktueller Phase-Index aus _def.phases. -1 = noch keine Phase aktiviert
## (z.B. _def.phases ist leer oder Boss noch nicht setup).
var _current_phase_idx: int = -1


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive Stubs (Tests ohne Scene-Children)
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
	health.is_boss = true

	# Group-Konvention (ADR 0011): Player findet Boss als "enemy"
	# (Auto-Attack soll greifen) — aber Death feuert boss_defeated.
	add_to_group(&"enemy")
	add_to_group(&"boss")

	# HP-Bar binden
	if has_node("HealthBar"):
		var hpbar: HealthBar = $HealthBar
		hpbar.set_health(health)

	# Death-Hook (lokal, nicht Bus): wir wollen unser eigenes Bus-Signal
	health.died.connect(_on_died)

	# Phasen-Hooks (ADR 0029): bei jedem HP-Change die Phase neu auswerten
	health.damage_taken.connect(_on_health_changed)
	health.healed.connect(_on_health_changed)

	_spawn_time_msec = Time.get_ticks_msec()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

func setup(def: BossDef, pos: Vector2) -> void:
	if def == null:
		push_warning("BossMob.setup: def ist null")
		return
	_def = def
	boss_id = def.id
	global_position = pos

	# Stats
	health.max_hp = def.max_health
	health.reset_to_full()

	# Dealer
	dealer.default_source_id = def.id

	# Visuals (analog ADR 0024)
	_apply_visuals(def)

	# Phasen-Setup (ADR 0029): initiale Phase auswerten + applizieren
	_current_phase_idx = -1
	_evaluate_phase()


func get_def() -> BossDef:
	return _def


func get_health_component() -> HealthComponent:
	return health


func get_dealer_component() -> DamageDealerComponent:
	return dealer


func get_speed() -> float:
	if _def == null:
		return 0.0
	var base := _def.speed
	if _current_phase_idx >= 0 and _current_phase_idx < _def.phases.size():
		base *= _def.phases[_current_phase_idx].speed_multiplier
	return base


## Effektiver Damage-Output (BossDef.damage * aktive Phase). Boss-Touch
## benutzt diesen Wert statt def.damage direkt.
func get_damage() -> float:
	if _def == null:
		return 0.0
	var base := _def.damage
	if _current_phase_idx >= 0 and _current_phase_idx < _def.phases.size():
		base *= _def.phases[_current_phase_idx].damage_multiplier
	return base


## Aktueller Phase-Index (0-basiert). -1 wenn keine Phase aktiv (z.B. Boss
## ohne phases-Definition).
func get_current_phase_index() -> int:
	return _current_phase_idx


# ---------------------------------------------------------------------------
# Movement (analog ADR 0017)
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _def == null:
		return
	if health == null or health.is_dead():
		return
	_move_toward_player(delta)


func _move_toward_player(delta: float) -> void:
	var player := _find_nearest_player()
	if player == null:
		return
	var diff: Vector2 = player.global_position - global_position
	if diff.length_squared() <= 0.0:
		return
	var dir: Vector2 = diff.normalized()
	global_position += dir * get_speed() * delta


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


# ---------------------------------------------------------------------------
# Death-Pfad (boss_defeated statt enemy_died)
# ---------------------------------------------------------------------------

func _on_died(_info: DamageInfo) -> void:
	# HealthComponent feuert beim Tod auch enemy_died via Bus
	# (weil wir in der "enemy"-Group sind und der Owner-Node ein
	# enemy_id-Property hat? Nein — BossMob hat boss_id, nicht enemy_id.
	# HealthComponent's _die-Pfad liest "enemy_id" — der wird hier leer sein.
	# Also feuert er enemy_died mit leerer ID. Das ist akzeptabel — die
	# Death-Bedeutung steckt in boss_defeated.
	if get_node_or_null("/root/EventBus") == null:
		return
	var run_time: float = (Time.get_ticks_msec() - _spawn_time_msec) / 1000.0
	EventBus.boss_defeated.emit(boss_id, run_time)


# ---------------------------------------------------------------------------
# Visuals (analog ADR 0024)
# ---------------------------------------------------------------------------

func _apply_visuals(def: BossDef) -> void:
	# Visual-Provider (ADR 0027): wenn visual_scene gesetzt, instanzieren
	# und ColorRect verstecken. Sonst Color/Size-Modus (ADR 0024).
	if def.visual_scene != null:
		_spawn_visual_scene(def.visual_scene)
		var body_node := get_node_or_null("Body") as ColorRect
		if body_node != null:
			body_node.visible = false
		var bar := get_node_or_null("HealthBar") as Node2D
		if bar != null:
			bar.position = Vector2(0, -10.0) + def.visual_pivot_offset
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
		bar.position.y = -(def.body_size.y * 0.5) - 10.0


## Instanziert die Visual-Scene als Child unter dem Boss. Existierende
## Visual-Instanzen werden vorher entfernt.
func _spawn_visual_scene(scene: PackedScene) -> void:
	var existing := get_node_or_null("Visual")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var inst := scene.instantiate()
	if inst is Node:
		inst.name = "Visual"
		add_child(inst)


# ---------------------------------------------------------------------------
# Phasen-Dispatch (ADR 0029)
# ---------------------------------------------------------------------------

func _on_health_changed(_info: DamageInfo) -> void:
	_evaluate_phase()


## Wertet die aktuelle Phase basierend auf dem HP-Verhältnis aus.
## Monoton: einmal eine niedrigere Phase erreicht, kehrt der Boss bei
## Heal NICHT in eine höhere zurück.
func _evaluate_phase() -> void:
	if _def == null or _def.phases.is_empty():
		return
	if health == null or health.max_hp <= 0.0:
		return
	var hp_pct: float = health.get_hp() / health.max_hp
	var new_idx := _resolve_phase_index(hp_pct)
	# Monoton fallend: Index darf nur steigen (= „weiter unten" in der
	# Phasen-Liste), nicht wieder zurück nach oben.
	if new_idx <= _current_phase_idx:
		return
	_current_phase_idx = new_idx
	_apply_phase(new_idx)
	if get_node_or_null("/root/EventBus") != null:
		var phase: BossPhase = _def.phases[new_idx]
		EventBus.boss_phase_changed.emit(boss_id, new_idx, phase.label_key)


## Liefert den Index der aktiven Phase für `hp_pct` (0.0–1.0).
## Phasen sind absteigend sortiert (1.0 zuerst). Wir suchen die LETZTE
## Phase, deren `hp_threshold >= hp_pct` ist.
##
## Pure Function — testbar ohne Frame-Dispatch.
func _resolve_phase_index(hp_pct: float) -> int:
	if _def == null or _def.phases.is_empty():
		return -1
	var best_idx: int = -1
	for i in _def.phases.size():
		var p: BossPhase = _def.phases[i]
		if hp_pct <= p.hp_threshold:
			best_idx = i
	return best_idx


## Wendet die Visual-Konsequenzen der Phase an (Color-Tint).
## Speed/Damage-Multiplikatoren wirken lazy via get_speed()/get_damage().
func _apply_phase(idx: int) -> void:
	if _def == null or idx < 0 or idx >= _def.phases.size():
		return
	var p: BossPhase = _def.phases[idx]
	# ColorRect-Mode: body.color = def.body_color * tint
	var body := get_node_or_null("Body") as ColorRect
	if body != null and body.visible:
		body.color = _def.body_color * p.color_tint
	# Sprite-Mode (ADR 0027): Visual.modulate
	var visual := get_node_or_null("Visual") as CanvasItem
	if visual != null:
		visual.modulate = p.color_tint
