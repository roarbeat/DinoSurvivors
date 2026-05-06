class_name MutationDef
extends ContentItem
## Eine wählbare Mutation — modifiziert Spieler-Stats und/oder gibt Tags
## für Synergie-Berechnungen.

const VALID_RARITIES := [&"common", &"rare", &"epic", &"legendary"]

## Seltenheits-Tier — beeinflusst Drop-Wahrscheinlichkeit und UI-Farbe.
@export var rarity: StringName = &"common"

## Stat-Modifier als Dictionary[stat_key: StringName, amount: float].
## Beispiel: { &"damage_pct": 0.15, &"crit_chance": 0.05 }
## Stat-Keys sind in BALANCE.csv katalogisiert.
@export var stat_modifiers: Dictionary = {}

## Tags für Synergie-Suche. z.B. [&"horn", &"melee", &"crit_synergy"]
@export var tags: Array[StringName] = []

## Tooltip-Icon. Optional — wenn null, nutzt UI Fallback.
@export var icon: Texture2D


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if not VALID_RARITIES.has(rarity):
		return "rarity '%s' ist nicht in VALID_RARITIES" % rarity
	# stat_modifiers: keys auf StringName normalisieren — .tres-Files
	# können String oder StringName liefern, Registry-Lookup soll konsistent sein.
	var normalized: Dictionary = {}
	for k in stat_modifiers.keys():
		if not (k is StringName or k is String):
			return "stat_modifiers key '%s' ist kein String/StringName" % k
		var v = stat_modifiers[k]
		if not (v is float or v is int):
			return "stat_modifiers['%s'] ist kein Number" % k
		normalized[StringName(k)] = float(v)
	stat_modifiers = normalized
	return ""
