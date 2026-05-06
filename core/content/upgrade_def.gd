class_name UpgradeDef
extends ContentItem
## Permanente Meta-Upgrade-Definition (ADR 0040).
##
## Im Meta-Shop kaufbar mit Bernstein. Wirkt auf Player-Stats analog
## zu Mutationen, aber persistent über Runs (gespeichert via
## MetaProgression).
##
## Schema-Konvention für stat_modifiers_per_level (analog
## MutationDef.stat_modifiers): `{ &"damage_pct": 0.05, ... }`
## MutationModifierBridge.build kann diese Dictionaries zu Modifier-
## Resourcen umwandeln.

## Maximales Level (1 = Single-Buy, 5 = 5-Stage-Upgrade).
@export var max_level: int = 1

## Cost-Curve: cost_per_level[level] = Bernstein-Kosten für Kauf
## von Level→Level+1. Wenn weniger Einträge als max_level, wird der
## letzte Eintrag wiederholt.
@export var cost_per_level: Array[int] = [50]

## Stat-Modifiers pro Level. value[level] = Modifier-Werte.
## Schema gleich wie MutationDef.stat_modifiers.
@export var stat_modifiers_per_level: Array[Dictionary] = [{}]

## Currency-Type. v1: nur "amber". Mehrere Currencies kommen mit
## eigenem ADR.
@export var cost_currency: StringName = &"amber"

## Optionaler i18n-Key für Tier-Beschreibung (z.B. "+15% Damage").
@export var tier_description_key: StringName = &""

## Kategorie für Shop-Filterung (ADR 0044). Default `&"stat"`. Andere
## Standard-Werte: `&"dino_unlock"` für Dino-Käufe.
## Modder können beliebige Kategorien einführen.
@export var category: StringName = &"stat"

## Nur relevant wenn category=&"dino_unlock". ID des freischaltbaren
## Dinos. Wird beim Kauf vom Player als unlocked markiert.
@export var unlock_dino_id: StringName = &""


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if max_level <= 0:
		return "max_level muss > 0 sein"
	if cost_per_level.is_empty():
		return "cost_per_level darf nicht leer sein"
	for c in cost_per_level:
		if int(c) < 0:
			return "cost_per_level darf keine negativen Werte enthalten"
	if String(cost_currency) == "":
		return "cost_currency muss gesetzt sein"
	return ""


## Liefert die Bernstein-Kosten für den nächsten Level-Up.
## current_level=0 → cost_per_level[0]
## current_level >= max_level → -1 (max erreicht)
func get_cost_for_level(current_level: int) -> int:
	if current_level >= max_level:
		return -1
	if cost_per_level.is_empty():
		return 0
	# Wenn weniger Einträge als max_level: letzten Eintrag wiederholen
	var idx: int = clamp(current_level, 0, cost_per_level.size() - 1)
	return int(cost_per_level[idx])


## Liefert das Stat-Modifier-Dictionary für ein bestimmtes Level (1-basiert).
## Level 1 → stat_modifiers_per_level[0]
## Wenn weniger Einträge: letzten Eintrag wiederholen.
## Level 0 → leeres Dictionary (kein Effekt).
func get_modifiers_for_level(level: int) -> Dictionary:
	if level <= 0 or stat_modifiers_per_level.is_empty():
		return {}
	var idx: int = clamp(level - 1, 0, stat_modifiers_per_level.size() - 1)
	return (stat_modifiers_per_level[idx] as Dictionary).duplicate()
