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


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Currency-Dict: StringName → int. Default-Currencies werden initial
## mit 0 angelegt; weitere Keys werden by-need ergänzt.
var _currencies: Dictionary = { DEFAULT_CURRENCY: 0 }


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
	if meta == null or not (meta is Dictionary):
		return
	# Reset und neu befüllen — sonst bleiben Currencies aus dem letzten
	# Run-State stehen, falls Player ein anderes Save lädt.
	_currencies = { DEFAULT_CURRENCY: 0 }
	for key in (meta as Dictionary).keys():
		_currencies[StringName(key)] = int((meta as Dictionary)[key])


func _on_save_requested(_reason: StringName) -> void:
	# Bei jedem Save-Request schreiben wir unseren Currency-Snapshot
	# in den SaveSystem-Slot. SaveSystem speichert dann die ganze
	# data-Dictionary auf Disk.
	if get_node_or_null("/root/SaveSystem") == null:
		return
	# StringName-Keys → String-Keys für JSON-Serialisierung
	var serializable: Dictionary = {}
	for key in _currencies.keys():
		serializable[String(key)] = int(_currencies[key])
	SaveSystem.set_field(SAVE_KEY, serializable)
