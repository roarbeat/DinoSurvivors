extends Node
## Globaler ContentLoader — type-indizierte Registry aller .tres-Resources.
##
## Implementiert ADR 0003. Eager Discovery beim Boot, Type-Class-Validation,
## ID-Uniqueness-Check, Mod-Override-Handling.
##
## Public-API (für Game-Code und Mods):
##   get(type, id)         → ContentItem (panic bei unbekannt)
##   get_or_null(type, id) → ContentItem | null
##   get_all(type)         → Array[ContentItem]
##   has(type, id)         → bool
##   types()               → Array[StringName]
##   all_ids(type)         → Array[StringName]
##   reload()              → Dev-only, feuert content_loaded neu

# ---------------------------------------------------------------------------
# Type-Konfiguration
# ---------------------------------------------------------------------------
# Pro Type: Erwartete Klasse (für is-Check) und Verzeichnis-Name unter
# res://content/<dir>/. Erweiterbar — neue Typen einfach hier eintragen.
const TYPE_CONFIG: Dictionary = {
	&"mutation": {
		"dir": "mutations",
		"script_path": "res://core/content/mutation_def.gd",
	},
	&"enemy": {
		"dir": "enemies",
		"script_path": "res://core/content/enemy_def.gd",
	},
	&"boss": {
		"dir": "bosses",
		"script_path": "res://core/content/boss_def.gd",
	},
	&"dino": {
		"dir": "dinos",
		"script_path": "res://core/content/dino_def.gd",
	},
	&"wave": {
		"dir": "waves",
		"script_path": "res://core/content/wave_def.gd",
	},
	&"sound": {
		"dir": "sounds",
		"script_path": "res://core/content/sound_def.gd",
	},
}

const CORE_CONTENT_ROOT := "res://content/"
const MOD_CONTENT_ROOT := "user://mods/"

# Registry: Dictionary[type: StringName → Dictionary[id: StringName → ContentItem]]
var _registry: Dictionary = {}

# Liste der angewendeten Override-IDs — für Save-Manifest und UI.
var _overrides_applied: Array[StringName] = []


func _ready() -> void:
	_initialize_registry()
	discover_all()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Liefert das ContentItem zu (type, id) oder bricht laut ab.
## Game-Code, der mit fehlenden IDs robust umgehen muss, nutzt
## stattdessen `get_or_null()`.
func get_item(type: StringName, id: StringName) -> ContentItem:
	var item := get_or_null(type, id)
	assert(item != null,
		"ContentLoader: unbekannte ID '%s' in type '%s'" % [id, type])
	return item


## Wie get_item, aber liefert null statt zu panicen.
func get_or_null(type: StringName, id: StringName) -> ContentItem:
	if not _registry.has(type):
		return null
	return _registry[type].get(id, null)


## Liefert alle Items eines Types als Array. Reihenfolge ist
## Discovery-Order; nicht für Gameplay-Logik verlassen.
func get_all(type: StringName) -> Array:
	if not _registry.has(type):
		return []
	return _registry[type].values()


## Prüft, ob (type, id) registriert ist.
func has_item(type: StringName, id: StringName) -> bool:
	return _registry.has(type) and _registry[type].has(id)


## Liste aller bekannten Type-Keys.
func types() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _registry.keys():
		out.append(k)
	return out


## Alle IDs eines Types.
func all_ids(type: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _registry.has(type):
		for k in _registry[type].keys():
			out.append(k)
	return out


## Liste der Mod-Overrides, die gerade aktiv sind. Format: &"type:id".
func overrides_applied() -> Array[StringName]:
	return _overrides_applied.duplicate()


## Dev-Only: kompletter Re-Scan. Feuert content_loaded am Ende.
func reload() -> void:
	_initialize_registry()
	discover_all()


# ---------------------------------------------------------------------------
# Discovery & Validation
# ---------------------------------------------------------------------------

func _initialize_registry() -> void:
	_registry.clear()
	_overrides_applied.clear()
	for type in TYPE_CONFIG.keys():
		_registry[type] = {}


## Scannt Core und Mod-Pfade, lädt alle .tres, indexiert sie.
## Idempotent: kann via reload() jederzeit erneut aufgerufen werden.
func discover_all() -> void:
	_initialize_registry()

	# 1. Core-Content
	for type in TYPE_CONFIG.keys():
		var dir_name: String = TYPE_CONFIG[type]["dir"]
		_scan_directory(CORE_CONTENT_ROOT + dir_name, type, &"")

	# 2. Mod-Content (in Mod-Load-Reihenfolge — derzeit alphabetisch,
	#    wird später vom Mod-Loader bestimmt, ADR 0005)
	if DirAccess.dir_exists_absolute(MOD_CONTENT_ROOT):
		var mods_dir := DirAccess.open(MOD_CONTENT_ROOT)
		if mods_dir != null:
			mods_dir.list_dir_begin()
			var mod_id := mods_dir.get_next()
			while mod_id != "":
				if mods_dir.current_is_dir() and not mod_id.begins_with("."):
					for type in TYPE_CONFIG.keys():
						var dir_name: String = TYPE_CONFIG[type]["dir"]
						var mod_path := MOD_CONTENT_ROOT + mod_id + "/content/" + dir_name
						_scan_directory(mod_path, type, StringName(mod_id))
				mod_id = mods_dir.get_next()
			mods_dir.list_dir_end()

	# 3. Notify
	var item_count := 0
	for type in _registry.keys():
		item_count += _registry[type].size()
	# EventBus-Signal — Boot-Notification für Game-Systeme.
	# Defensiv: in isolierten Test-Scenes ohne EventBus-Autoload skippen.
	if get_node_or_null("/root/EventBus") != null:
		EventBus.content_loaded.emit(_registry.size(), item_count)


## Scannt ein einzelnes Verzeichnis nach .tres-Files und registriert sie.
## `mod_id` ist &"" für Core, sonst die Mod-ID.
func _scan_directory(path: String, type: StringName, mod_id: StringName) -> void:
	if not DirAccess.dir_exists_absolute(path):
		# Mods sind optional, fehlende Mod-Verzeichnisse sind kein Fehler.
		# Auch fehlende Core-Verzeichnisse sind in frühen Phasen erlaubt.
		return
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ContentLoader: konnte '%s' nicht öffnen" % path)
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			_load_and_register(path + "/" + fname, type, mod_id)
		fname = dir.get_next()
	dir.list_dir_end()


## Lädt eine einzelne .tres-Datei und registriert sie.
func _load_and_register(file_path: String, type: StringName, mod_id: StringName) -> void:
	var res: Resource = load(file_path)
	if res == null:
		push_warning("ContentLoader: load('%s') fehlgeschlagen" % file_path)
		return

	if not (res is ContentItem):
		push_warning("ContentLoader: '%s' ist kein ContentItem" % file_path)
		return

	var item: ContentItem = res

	# Type-Match: Script-Pfad muss zum Type passen (oder davon erben).
	var expected_path: String = TYPE_CONFIG[type]["script_path"]
	if not _script_matches(item, expected_path):
		push_warning("ContentLoader: '%s' Script passt nicht zu type '%s' (erwartet %s)"
			% [file_path, type, expected_path])
		return

	# Validation
	var err := item.validate()
	if err != "":
		push_warning("ContentLoader: '%s' ungültig — %s" % [file_path, err])
		return

	# Source-Mod setzen
	item.source_mod_id = mod_id

	# ID-Konvention prüfen
	if not _is_valid_id(String(item.id)):
		push_warning("ContentLoader: '%s' hat ungültige ID '%s' (snake_case, max 40)"
			% [file_path, item.id])
		return

	# Reservierter Core-Präfix
	if mod_id != &"" and String(item.id).begins_with("core_"):
		push_warning("ContentLoader: Mod '%s' nutzt reservierten Präfix 'core_' in ID '%s'"
			% [mod_id, item.id])
		return

	# Kollision?
	var bucket: Dictionary = _registry[type]
	if bucket.has(item.id):
		var existing: ContentItem = bucket[item.id]
		if mod_id != &"" and item.override_existing:
			# Erlaubter Override
			bucket[item.id] = item
			_overrides_applied.append(StringName("%s:%s" % [type, item.id]))
			push_warning("ContentLoader: Mod '%s' überschreibt %s:%s (Core von '%s')"
				% [mod_id, type, item.id, existing.source_mod_id])
		else:
			push_warning("ContentLoader: ID-Kollision %s:%s (Quelle '%s' vs '%s'), zweiter Eintrag ignoriert"
				% [type, item.id, existing.source_mod_id, mod_id])
		return

	bucket[item.id] = item


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Prüft, ob eine Resource das erwartete Script (oder eine Subklasse davon)
## verwendet. Vergleich erfolgt über resource_path — robust gegen
## Refactorings im Klassen-Namen.
func _script_matches(res: Resource, expected_script_path: String) -> bool:
	var script: Script = res.get_script()
	while script != null:
		if script.resource_path == expected_script_path:
			return true
		script = script.get_base_script()
	return false


## Validiert eine ID gegen die Convention (snake_case, ASCII, max 40).
func _is_valid_id(id: String) -> bool:
	if id.length() == 0 or id.length() > 40:
		return false
	for i in id.length():
		var c := id[i]
		var is_lower := c >= "a" and c <= "z"
		var is_digit := c >= "0" and c <= "9"
		var is_underscore := c == "_"
		if not (is_lower or is_digit or is_underscore):
			return false
	return true
