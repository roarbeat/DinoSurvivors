extends Node
## Persistente Meta-Progression-Tracker (ADR 0030).
##
## Globaler Bernstein-Counter (und potenzielle weitere Currencies).
## Lauscht auf EventBus.boss_defeated und addiert
## BossDef.reward_currency_amount automatisch zu Bernstein.
##
## Save/Load: SaveSystem speichert das Currency-Dict im
## save.data["meta_progression"]-Slot. Beim save_loaded liest
## MetaProgression sich raus.
##
## Public-API:
##   get_currency(id)              -> int
##   add_currency(id, amount)      -> int (neuer Wert)
##   set_currency(id, value)       -> void
##   list_currencies()             -> Dictionary[StringName, int]
##   reset()                       -> void  # Test-Hook + New-Game-Reset

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

## Default-Currency-ID. Bossen droppen Bernstein. Andere Currencies können
## per Mods ergänzt werden.
const DEFAULT_CURRENCY: StringName = &"amber"

## Save-Slot im SaveSystem (save.data[SAVE_KEY] = Dictionary).
const SAVE_KEY: String = "meta_progression"

## Save-Slot für Upgrade-Levels (ADR 0040).
const UPGRADE_LEVELS_KEY: String = "upgrade_levels"


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Currency-Dict: StringName → int. Default-Currencies werden initial
## mit 0 angelegt; weitere Keys werden by-need ergänzt.
var _currencies: Dictionary = { DEFAULT_CURRENCY: 0 }

## Upgrade-Levels (ADR 0040). upgrade_id → int (0 = nicht gekauft).
var _upgrade_levels: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensiv: in isolierten Test-Scenes ohne EventBus-Autoload skippen.
	if get_node_or_null("/root/EventBus") != null:
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.save_loaded.connect(_on_save_loaded)
		EventBus.save_requested.connect(_on_save_requested)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Liefert den aktuellen Wert einer Currency. 0 wenn unbekannt.
func get_currency(id: StringName = DEFAULT_CURRENCY) -> int:
	return int(_currencies.get(id, 0))


## Erhöht eine Currency um amount. Negative amounts sind erlaubt
## (= subtract). Lower-cap bei 0 (keine negativen Werte).
## Feuert EventBus.currency_changed nur wenn der Wert sich ändert.
## Liefert den neuen Wert zurück.
func add_currency(id: StringName, amount: int) -> int:
	var current: int = int(_currencies.get(id, 0))
	var new_value: int = max(0, current + amount)
	if new_value == current:
		return current
	_currencies[id] = new_value
	if get_node_or_null("/root/EventBus") != null:
		EventBus.currency_changed.emit(id, new_value)
	return new_value


## Setzt eine Currency direkt. Für Save-Load und Cheats.
## Feuert EventBus.currency_changed nur wenn der Wert sich ändert.
func set_currency(id: StringName, value: int) -> void:
	var clamped: int = max(0, value)
	var current: int = int(_currencies.get(id, 0))
	if clamped == current:
		return
	_currencies[id] = clamped
	if get_node_or_null("/root/EventBus") != null:
		EventBus.currency_changed.emit(id, clamped)


## Liefert eine Kopie des Currency-Dicts. Mutationen am Rückgabe-Wert
## wirken NICHT auf den internen State.
func list_currencies() -> Dictionary:
	return _currencies.duplicate()


## Setzt alle Currencies auf Default-State zurück. Test-Hook und
## New-Game-Reset. Feuert KEINE Signals (Bulk-Reset).
func reset() -> void:
	_currencies = { DEFAULT_CURRENCY: 0 }
	_upgrade_levels = {}


# ---------------------------------------------------------------------------
# Upgrade-API (ADR 0040)
# ---------------------------------------------------------------------------

## Liefert das aktuelle Level eines Upgrades. 0 = nicht gekauft.
func get_upgrade_level(id: StringName) -> int:
	return int(_upgrade_levels.get(id, 0))


## Liefert die Bernstein-Kosten für den NÄCHSTEN Level-Up.
## -1 wenn Upgrade unbekannt oder bereits auf max_level.
func get_upgrade_cost(id: StringName) -> int:
	if get_node_or_null("/root/ContentLoader") == null:
		return -1
	var def: UpgradeDef = ContentLoader.get_or_null(&"upgrade", id) as UpgradeDef
	if def == null:
		return -1
	return def.get_cost_for_level(get_upgrade_level(id))


## Prüft ob Player das Upgrade kaufen kann (Currency reicht und
## max_level nicht erreicht).
func can_afford_upgrade(id: StringName) -> bool:
	var cost: int = get_upgrade_cost(id)
	if cost < 0:
		return false
	if get_node_or_null("/root/ContentLoader") == null:
		return false
	var def: UpgradeDef = ContentLoader.get_or_null(&"upgrade", id) as UpgradeDef
	if def == null:
		return false
	return get_currency(def.cost_currency) >= cost


## Kauft ein Upgrade. Liefert true bei Erfolg, false wenn:
##   - Upgrade unbekannt
##   - Currency nicht ausreichend
##   - max_level bereits erreicht
##
## Bei Erfolg: Currency wird subtrahiert, Level erhöht,
## EventBus.upgrade_purchased gefeuert. SaveSystem-Persistenz erfolgt
## beim nächsten save_requested.
func purchase_upgrade(id: StringName) -> bool:
	if get_node_or_null("/root/ContentLoader") == null:
		return false
	var def: UpgradeDef = ContentLoader.get_or_null(&"upgrade", id) as UpgradeDef
	if def == null:
		return false
	var current_level: int = get_upgrade_level(id)
	if current_level >= def.max_level:
		return false
	var cost: int = def.get_cost_for_level(current_level)
	if cost < 0:
		return false
	if get_currency(def.cost_currency) < cost:
		return false

	# Currency abziehen
	add_currency(def.cost_currency, -cost)
	# Level erhöhen
	var new_level: int = current_level + 1
	_upgrade_levels[id] = new_level

	# EventBus für UI/PlayerCharacter
	if get_node_or_null("/root/EventBus") != null:
		EventBus.upgrade_purchased.emit(id, new_level)
	return true


## Liefert alle Upgrade-Level als Dict-Kopie (id → level).
func list_upgrade_levels() -> Dictionary:
	return _upgrade_levels.duplicate()


## Prüft ob ein Dino spielbar ist (ADR 0044). Default-Dinos ohne
## `unlock_upgrade_id` sind always-unlocked.
func is_dino_unlocked(dino_id: StringName) -> bool:
	if get_node_or_null("/root/ContentLoader") == null:
		return false
	var def: DinoDef = ContentLoader.get_or_null(&"dino", dino_id) as DinoDef
	if def == null:
		return false
	if String(def.unlock_upgrade_id) == "":
		return true  # always-unlocked
	return get_upgrade_level(def.unlock_upgrade_id) >= 1


## Aggregiert alle gekauften Upgrades zu einem Modifier-Schema-Dict
## (gleiche Struktur wie PlayerMutations.get_aggregated):
##   { "outgoing": [], "incoming": [], "unhandled": {stat_key: value} }
##
## PlayerCharacter nutzt das additiv zu PlayerMutations.get_aggregated.
func get_aggregated_modifiers() -> Dictionary:
	var result: Dictionary = {
		"outgoing": [],
		"incoming": [],
		"unhandled": {},
	}
	if get_node_or_null("/root/ContentLoader") == null:
		return result
	for upgrade_id in _upgrade_levels.keys():
		var level: int = int(_upgrade_levels[upgrade_id])
		if level <= 0:
			continue
		var def: UpgradeDef = ContentLoader.get_or_null(&"upgrade", upgrade_id) as UpgradeDef
		if def == null:
			continue
		# Stat-Modifier-Dict für dieses Level holen
		var mods: Dictionary = def.get_modifiers_for_level(level)
		# Über MutationModifierBridge in Modifier-Resourcen umwandeln
		# (gleiche Pipeline wie Mutationen — Schema-Konsistenz!)
		var mut_stub := MutationDef.new()
		mut_stub.id = upgrade_id
		mut_stub.stat_modifiers = mods
		var built: Dictionary = MutationModifierBridge.build(mut_stub)
		for m in built["outgoing"]:
			result["outgoing"].append(m)
		for m in built["incoming"]:
			result["incoming"].append(m)
		for k in built["unhandled"]:
			result["unhandled"][k] = float(result["unhandled"].get(k, 0.0)) + float(built["unhandled"][k])
	return result


# ---------------------------------------------------------------------------
# EventBus-Handler
# ---------------------------------------------------------------------------

func _on_boss_defeated(boss_id: StringName, _run_time: float) -> void:
	if get_node_or_null("/root/ContentLoader") == null:
		return
	var def: BossDef = ContentLoader.get_or_null(&"boss", boss_id) as BossDef
	if def == null:
		return
	if def.reward_currency_amount > 0:
		add_currency(DEFAULT_CURRENCY, def.reward_currency_amount)


func _on_save_loaded(_version: int) -> void:
	if get_node_or_null("/root/SaveSystem") == null:
		return
	var data: Dictionary = SaveSystem.get_data()
	var meta = data.get(SAVE_KEY, null)
	if meta != null and meta is Dictionary:
		# Reset und neu befüllen — sonst bleiben Currencies aus dem letzten
		# Run-State stehen, falls Player ein anderes Save lädt.
		_currencies = { DEFAULT_CURRENCY: 0 }
		for key in (meta as Dictionary).keys():
			_currencies[StringName(key)] = int((meta as Dictionary)[key])

	# Upgrade-Levels (ADR 0040) — additive, fehlend ist kein Fehler
	var ul = data.get(UPGRADE_LEVELS_KEY, null)
	if ul != null and ul is Dictionary:
		_upgrade_levels = {}
		for key in (ul as Dictionary).keys():
			_upgrade_levels[StringName(key)] = int((ul as Dictionary)[key])
	else:
		_upgrade_levels = {}


func _on_save_requested(_reason: StringName) -> void:
	# Bei jedem Save-Request schreiben wir unseren Currency-Snapshot
	# + Upgrade-Snapshot in den SaveSystem-Slot.
	if get_node_or_null("/root/SaveSystem") == null:
		return
	# Currency: StringName-Keys → String-Keys für JSON
	var serializable: Dictionary = {}
	for key in _currencies.keys():
		serializable[String(key)] = int(_currencies[key])
	SaveSystem.set_field(SAVE_KEY, serializable)

	# Upgrade-Levels (ADR 0040)
	var ul_serializable: Dictionary = {}
	for key in _upgrade_levels.keys():
		ul_serializable[String(key)] = int(_upgrade_levels[key])
	SaveSystem.set_field(UPGRADE_LEVELS_KEY, ul_serializable)
