class_name HealthComponent
extends Node
## HP-Container für Player und Enemies (ADR 0007).
##
## Hängt als Child unter Player- und Enemy-Scenes.
## Hot-Path: take_damage() ist direkter Methoden-Aufruf, KEIN EventBus-Signal.
##
## Lokale Signals (Mod-/Test-Hooks):
##   damage_taken(info: DamageInfo, hp_after: float)
##   healed(amount: float, hp_after: float)
##   died(info: DamageInfo)
##
## Globale Bus-Signals (nur bei bedeutsamen State-Changes):
##   - is_player=true:  EventBus.player_damaged + player_died
##   - is_player=false: EventBus.enemy_died (mit owner-property `enemy_id`)

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

@export var max_hp: float = 100.0:
	set(value):
		max_hp = max(1.0, value)
		_current_hp = min(_current_hp, max_hp)

## true → emittet EventBus.player_damaged / player_died.
## false → emittet EventBus.enemy_died (mit owner.enemy_id).
@export var is_player: bool = false

## true → unterdrückt enemy_died (Owner feuert boss_defeated selbst).
## Wird von BossMob gesetzt (ADR 0025).
@export var is_boss: bool = false

## Incoming Modifier-Stack (ADR 0010). Wird auf eingehende DamageInfo
## angewandt, bevor HP reduziert wird. Sortiert nach priority (niedrig zuerst).
@export var incoming_modifiers: Array[DamageModifier] = []:
	set(value):
		incoming_modifiers = value
		_inc_sort_dirty = true


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

var _inc_sort_dirty: bool = true
var _inc_sorted_cache: Array[DamageModifier] = []


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal damage_taken(info: DamageInfo, hp_after: float)
signal healed(amount: float, hp_after: float)
signal died(info: DamageInfo)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _current_hp: float


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_current_hp = max_hp


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Reduziert HP gemäß DamageInfo. Hot-Path — direkter Call, kein Bus.
func take_damage(info: DamageInfo) -> void:
	if is_dead():
		return
	if info == null or info.amount <= 0.0:
		return

	# Incoming-Modifier-Pipeline (Armor etc.) — kann amount auf 0 reduzieren
	var effective := _apply_incoming(info)
	if effective.amount <= 0.0:
		# Damage komplett blockiert → kein State-Change
		return

	_current_hp = max(0.0, _current_hp - effective.amount)
	damage_taken.emit(effective, _current_hp)

	# Bedeutsame Bus-Notification (nicht hot-path-batch-empfindlich)
	if is_player and get_node_or_null("/root/EventBus") != null:
		EventBus.player_damaged.emit(effective.amount, effective.source_id)

	if _current_hp <= 0.0:
		_die(effective)


func heal(amount: float) -> void:
	if is_dead():
		return  # tote Nodes heilen nicht
	if amount <= 0.0:
		return
	_current_hp = min(max_hp, _current_hp + amount)
	healed.emit(amount, _current_hp)


func get_hp() -> float:
	return _current_hp


func get_hp_pct() -> float:
	if max_hp <= 0.0:
		return 0.0
	return _current_hp / max_hp


func is_dead() -> bool:
	return _current_hp <= 0.0


## Setzt HP direkt — z.B. beim Spawn eines Enemies mit voller HP, oder
## für Test-Setup. Game-Code sollte stattdessen take_damage / heal nutzen.
func reset_to_full() -> void:
	_current_hp = max_hp


## Fügt einen Incoming-Modifier hinzu (ADR 0010).
func add_modifier(mod: DamageModifier) -> void:
	if mod == null:
		return
	incoming_modifiers.append(mod)
	_inc_sort_dirty = true


## Entfernt einen Incoming-Modifier per Reference-Match.
func remove_modifier(mod: DamageModifier) -> bool:
	var idx := incoming_modifiers.find(mod)
	if idx < 0:
		return false
	incoming_modifiers.remove_at(idx)
	_inc_sort_dirty = true
	return true


func _apply_incoming(info: DamageInfo) -> DamageInfo:
	if incoming_modifiers.is_empty():
		return info
	if _inc_sort_dirty:
		_inc_sorted_cache = incoming_modifiers.duplicate()
		_inc_sorted_cache.sort_custom(func(a: DamageModifier, b: DamageModifier):
			return a.priority < b.priority)
		_inc_sort_dirty = false
	var current := info
	for mod in _inc_sorted_cache:
		if mod == null:
			continue
		current = mod.apply(current)
	return current


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _die(info: DamageInfo) -> void:
	died.emit(info)
	if get_node_or_null("/root/EventBus") == null:
		return

	if is_player:
		EventBus.player_died.emit()
		# Run wird vom RunState beendet — aber wir feuern keinen direkten
		# RunState.end() Call, das ist Game-Code-Sache (z.B. ein
		# PlayerDeathHandler-Autoload, oder ein Listener im Game-Director).
		return

	if is_boss:
		# BossMob feuert boss_defeated selbst — wir feuern hier KEIN enemy_died.
		return

	# Nicht-Player, nicht-Boss: enemy_id von Owner-Node ablesen.
	var owner_node := get_parent()
	if owner_node == null:
		return
	var enemy_id: StringName = &""
	if "enemy_id" in owner_node:
		enemy_id = owner_node.enemy_id
	# Position ist Convention: Owner ist eine Node2D oder Node3D.
	var pos := Vector2.ZERO
	if owner_node is Node2D:
		pos = (owner_node as Node2D).global_position
	EventBus.enemy_died.emit(enemy_id, pos)
