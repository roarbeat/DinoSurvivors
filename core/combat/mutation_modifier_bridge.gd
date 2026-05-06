class_name MutationModifierBridge
extends RefCounted
## Brückt MutationDef.stat_modifiers auf konkrete DamageModifier-Resourcen
## (ADR 0014).
##
## REGELN:
##   - build() ist eine PURE FUNCTION (kein State, keine Side-Effects)
##   - eine Mutation → eine Liste Modifier; Aggregation ist Player-System-Sache
##   - unbekannte stat_keys landen in `unhandled`, nicht im Crash

# ---------------------------------------------------------------------------
# Mapping-Konvention (Public-API)
# ---------------------------------------------------------------------------

## Outgoing-Stats (am DamageDealer einhängen).
const KNOWN_OUTGOING: Array[StringName] = [
	&"damage_pct",
	&"crit_chance",
	&"crit_damage_pct",
]

## Incoming-Stats (am HealthComponent einhängen).
const KNOWN_INCOMING: Array[StringName] = [
	&"armor_pct",
]


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Erzeugt aus einer MutationDef konkrete Modifier-Resourcen.
##
## Rückgabe-Schema:
##   {
##     "outgoing": Array[DamageModifier],     # für DamageDealer.add_modifier
##     "incoming": Array[DamageModifier],     # für HealthComponent.add_modifier
##     "unhandled": Dictionary[StringName, float]  # Player-Stat-System bekommt sie
##   }
static func build(mut: MutationDef) -> Dictionary:
	var result: Dictionary = {
		"outgoing": [] as Array[DamageModifier],
		"incoming": [] as Array[DamageModifier],
		"unhandled": {} as Dictionary,
	}
	if mut == null:
		return result
	if mut.stat_modifiers == null or mut.stat_modifiers.is_empty():
		return result

	var stats: Dictionary = mut.stat_modifiers

	# Heraus mit den Werten — Defaults 0.0 für nicht-vorhandene Keys.
	var damage_pct: float = float(stats.get(&"damage_pct", 0.0))
	var crit_chance: float = float(stats.get(&"crit_chance", 0.0))
	var crit_damage_pct: float = float(stats.get(&"crit_damage_pct", 0.0))
	var armor_pct: float = float(stats.get(&"armor_pct", 0.0))

	# damage_pct → MultiplierModifier (additive Konvention: 0.15 = +15%)
	if damage_pct > 0.0:
		var m := MultiplierModifier.new()
		m.multiplier = 1.0 + damage_pct
		result["outgoing"].append(m)

	# crit_chance + crit_damage_pct → CritModifier (gebündelt)
	if crit_chance > 0.0:
		var c := CritModifier.new()
		c.chance = crit_chance
		c.multiplier = 2.0 + crit_damage_pct
		result["outgoing"].append(c)
	elif crit_damage_pct > 0.0:
		# Crit-Damage ohne Crit-Chance ist sinnlos — als unhandled markieren.
		# (Player-System aggregiert evtl. später mit anderer Mutation.)
		result["unhandled"][&"crit_damage_pct"] = crit_damage_pct

	# armor_pct → ArmorModifier (incoming)
	if armor_pct > 0.0:
		var a := ArmorModifier.new()
		a.reduction_pct = armor_pct
		result["incoming"].append(a)

	# Restliche stat_keys → unhandled (Player-Stat-System interpretiert sie)
	for k in stats.keys():
		var key_name := StringName(k)
		if KNOWN_OUTGOING.has(key_name) or KNOWN_INCOMING.has(key_name):
			continue
		result["unhandled"][key_name] = float(stats[k])

	return result
