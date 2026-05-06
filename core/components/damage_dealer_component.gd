class_name DamageDealerComponent
extends Node
## DamageDealer (ADR 0007 + ADR 0010) — Hook-Punkt für Modifier-Pipeline.
##
## In v1 (ADR 0007) reichte der Dealer DamageInfo unverändert weiter.
## ADR 0010 ergänzt die Modifier-Pipeline: outgoing_modifiers werden
## in priority-Reihenfolge auf das DamageInfo angewandt, bevor das Target
## `take_damage()` sieht.
##
## Modifier sind PURE FUNCTIONS — sie liefern eine NEUE DamageInfo,
## die alte bleibt unverändert. Test-Konvention.

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Optional — wenn gesetzt, wird er als source_id eingetragen, falls
## das DamageInfo selbst keinen source_id hatte.
@export var default_source_id: StringName = &""

## Outgoing Modifier-Stack. Wird vor dem take_damage()-Call sequenziell
## angewandt, sortiert nach priority (niedrig zuerst).
## Modifikation der Liste invalidiert den internen Sort-Cache.
@export var outgoing_modifiers: Array[DamageModifier] = []:
	set(value):
		outgoing_modifiers = value
		_sort_dirty = true


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

var _sort_dirty: bool = true
var _sorted_cache: Array[DamageModifier] = []


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Lokales Hook für Mod-Effekte und Telemetrie. Wird VOR dem
## take_damage-Call gefeuert, NACH dem Modifier-Stack-Apply.
signal will_deal_damage(target: HealthComponent, info: DamageInfo)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Standard-Damage-Path. Hot-Path-tauglich (direkter Call, kein Bus).
func deal_damage(target: HealthComponent, info: DamageInfo) -> void:
	if target == null or info == null:
		return
	if target.is_dead():
		return

	# source_id-Default einsetzen falls leer
	var effective: DamageInfo = info
	if String(effective.source_id) == "" and String(default_source_id) != "":
		effective = info.with_amount(info.amount)
		effective.source_id = default_source_id

	# Outgoing-Modifier-Pipeline durchlaufen
	effective = _apply_modifiers(effective)

	will_deal_damage.emit(target, effective)
	target.take_damage(effective)


## Fügt einen Modifier hinzu und markiert die Liste als dirty
## (nächster deal_damage sortiert neu).
func add_modifier(mod: DamageModifier) -> void:
	if mod == null:
		return
	outgoing_modifiers.append(mod)
	_sort_dirty = true


## Entfernt einen Modifier (per Reference-Match).
func remove_modifier(mod: DamageModifier) -> bool:
	var idx := outgoing_modifiers.find(mod)
	if idx < 0:
		return false
	outgoing_modifiers.remove_at(idx)
	_sort_dirty = true
	return true


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _apply_modifiers(info: DamageInfo) -> DamageInfo:
	if outgoing_modifiers.is_empty():
		return info
	if _sort_dirty:
		_sorted_cache = outgoing_modifiers.duplicate()
		_sorted_cache.sort_custom(func(a: DamageModifier, b: DamageModifier):
			return a.priority < b.priority)
		_sort_dirty = false
	var current := info
	for mod in _sorted_cache:
		if mod == null:
			continue
		current = mod.apply(current)
	return current
