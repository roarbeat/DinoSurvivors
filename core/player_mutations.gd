extends Node
## Globaler PlayerMutations-Autoload (ADR 0015).
##
## Sammelt gepickte Mutationen während eines Runs. Aggregiert ihre Stats
## additiv, baut konkrete DamageModifier-Resourcen über die Bridge-Logik.
##
## Lifecycle:
##   - Subscribed `run_started` → reset
##   - Game-Code triggert pick/remove
##   - HUD/Player-Combat lauschen auf `mutations_changed`

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _picked: Array[StringName] = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_started.connect(_on_run_started)


func _on_run_started(_dino_id: StringName) -> void:
	reset()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Pickt eine Mutation. Rückgabe: true wenn akzeptiert, false bei
## unbekannter ID oder bereits gepickter Mutation.
func pick(mut_id: StringName) -> bool:
	if has(mut_id):
		return false
	if get_node_or_null("/root/ContentLoader") == null:
		return false
	if not ContentLoader.has_item(&"mutation", mut_id):
		push_warning("PlayerMutations.pick: unbekannte Mutation '%s'" % mut_id)
		return false
	_picked.append(mut_id)
	_emit_changed()
	return true


## Entfernt eine Mutation aus der Liste. Rückgabe: true wenn entfernt.
func remove(mut_id: StringName) -> bool:
	var idx := _picked.find(mut_id)
	if idx < 0:
		return false
	_picked.remove_at(idx)
	_emit_changed()
	return true


## Setzt die Liste zurück auf leer. Wird automatisch bei run_started
## gerufen — Game-Code muss das nicht selbst tun.
func reset() -> void:
	if _picked.is_empty():
		return
	_picked.clear()
	_emit_changed()


func has(mut_id: StringName) -> bool:
	return _picked.has(mut_id)


## Liefert eine Kopie der aktuellen Pick-Liste (in Pick-Reihenfolge).
func get_picked() -> Array[StringName]:
	return _picked.duplicate()


## Aggregiert alle gepickten Mutationen zu einem konsolidierten Modifier-Set.
## Mehrere damage_pct werden additiv gestackt → ein einziger MultiplierModifier.
##
## Schema:
##   {
##     "outgoing": Array[DamageModifier],
##     "incoming": Array[DamageModifier],
##     "unhandled": Dictionary[StringName, float]
##   }
func get_aggregated() -> Dictionary:
	# Schritt 1: Raw-Stats über alle Mutationen additiv aggregieren
	var raw: Dictionary = {}
	for mut_id in _picked:
		var mut: MutationDef = ContentLoader.get_or_null(&"mutation", mut_id) as MutationDef
		if mut == null or mut.stat_modifiers == null:
			continue
		for k in mut.stat_modifiers.keys():
			var key_name := StringName(k)
			var val := float(mut.stat_modifiers[k])
			raw[key_name] = float(raw.get(key_name, 0.0)) + val

	# Schritt 2: Aggregierte Stats in Modifier umsetzen
	return _build_modifiers_from_aggregated(raw)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _build_modifiers_from_aggregated(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"outgoing": [] as Array[DamageModifier],
		"incoming": [] as Array[DamageModifier],
		"unhandled": {} as Dictionary,
	}

	var damage_pct: float = float(raw.get(&"damage_pct", 0.0))
	var crit_chance: float = clamp(float(raw.get(&"crit_chance", 0.0)), 0.0, 1.0)
	var crit_damage_pct: float = float(raw.get(&"crit_damage_pct", 0.0))
	var armor_pct: float = clamp(float(raw.get(&"armor_pct", 0.0)), 0.0, 1.0)

	if damage_pct > 0.0:
		var m := MultiplierModifier.new()
		m.multiplier = 1.0 + damage_pct
		result["outgoing"].append(m)

	if crit_chance > 0.0:
		var c := CritModifier.new()
		c.chance = crit_chance
		c.multiplier = 2.0 + crit_damage_pct
		result["outgoing"].append(c)
	elif crit_damage_pct > 0.0:
		# Crit-Damage ohne Crit-Chance landet in unhandled
		result["unhandled"][&"crit_damage_pct"] = crit_damage_pct

	if armor_pct > 0.0:
		var a := ArmorModifier.new()
		a.reduction_pct = armor_pct
		result["incoming"].append(a)

	# Unbekannte Stats durchreichen (additiv aggregiert)
	var known := MutationModifierBridge.KNOWN_OUTGOING + MutationModifierBridge.KNOWN_INCOMING
	for k in raw.keys():
		var key_name := StringName(k)
		if known.has(key_name):
			continue
		result["unhandled"][key_name] = float(raw[k])

	return result


func _emit_changed() -> void:
	if get_node_or_null("/root/EventBus") != null:
		EventBus.mutations_changed.emit()
