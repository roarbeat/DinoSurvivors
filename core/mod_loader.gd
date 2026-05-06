extends Node
## Globaler ModLoader-Autoload.
##
## Implementiert ADR 0005. Scannt user://mods/, parsed mod.json-Manifeste,
## validiert sie und übergibt die aktive Mod-Liste an ContentLoader.
##
## Lifecycle (Boot):
##   1. _ready() ruft discover()
##   2. Pro Verzeichnis: mod.json laden + validieren
##   3. ContentLoader.discover_mods(active_ids) anstoßen
##   4. EventBus.mod_loaded / mod_failed pro Mod feuern
##
## Public-API:
##   discover()         -> int           Anzahl aktiv geladener Mods
##   list_active()      -> Array[StringName]
##   get_manifest(id)   -> Dictionary    readonly Kopie
##   is_loaded(id)      -> bool
##   failed_mods()      -> Array[Dictionary]  [{id, error}]

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

const MOD_ROOT := "user://mods/"
const FIXTURE_MOD_ROOT := "res://tests/fixtures/mods/"  # nur für Tests
const MOD_JSON := "mod.json"

const REQUIRED_MANIFEST_FIELDS: Array[String] = [
	"schema_version", "id", "name", "version",
	"game_version_min",
]

const MANIFEST_SCHEMA_VERSION := 1
const RESERVED_ID_PREFIX := "core_"


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

# Map[mod_id: StringName -> manifest: Dictionary]
var _active: Dictionary = {}
# Liste der mod_ids in Lade-Reihenfolge (alphabetisch in v1, später topologisch)
var _load_order: Array[StringName] = []
# Liste fehlgeschlagener Mods: [{id: StringName, error: String}]
var _failed: Array[Dictionary] = []
# Custom-Roots für Tests — kann von test-engineer gesetzt werden
var _scan_roots: Array[String] = [MOD_ROOT]


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# In Tests werden wir _scan_roots explizit setzen und discover() manuell
	# anstoßen — daher bei Boot nur discover() wenn user-Pfad existiert.
	if DirAccess.dir_exists_absolute(MOD_ROOT):
		discover()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Komplett-Re-Scan. Vorherigen State verwerfen, alles neu laden.
## Rückgabe: Anzahl erfolgreich geladener Mods.
func discover() -> int:
	_active.clear()
	_load_order.clear()
	_failed.clear()

	var candidates: Array = []
	for root in _scan_roots:
		if not DirAccess.dir_exists_absolute(root):
			continue
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if dir.current_is_dir() and not name.begins_with("."):
				candidates.append({
					"id_hint": name,
					"path": root.path_join(name),
				})
			name = dir.get_next()
		dir.list_dir_end()

	# Alphabetisch nach id_hint sortieren — deterministische Reihenfolge.
	candidates.sort_custom(func(a, b): return a["id_hint"] < b["id_hint"])

	# Phase 1: Manifeste parsen und validieren
	var parsed: Array = []
	for c in candidates:
		var mod_path: String = c["path"]
		var manifest_path := mod_path.path_join(MOD_JSON)
		var result := _parse_manifest(manifest_path)
		if result["ok"]:
			parsed.append({ "manifest": result["manifest"], "path": mod_path })
		else:
			_failed.append({
				"id": StringName(c["id_hint"]),
				"error": result["error"],
			})
			_emit_failed(StringName(c["id_hint"]), result["error"])

	# Phase 2: ID-Kollisionen erkennen
	var id_to_mods: Dictionary = {}
	for p in parsed:
		var id := StringName(p["manifest"]["id"])
		if not id_to_mods.has(id):
			id_to_mods[id] = []
		id_to_mods[id].append(p)
	var collided: Dictionary = {}
	for id in id_to_mods.keys():
		if id_to_mods[id].size() > 1:
			collided[id] = true

	# Phase 3: Erfolgreiche Mods registrieren, kollidierte abweisen
	for p in parsed:
		var manifest: Dictionary = p["manifest"]
		var id := StringName(manifest["id"])
		if collided.has(id):
			_failed.append({
				"id": id,
				"error": "id_collision: %d mods reklamieren id '%s'" % [id_to_mods[id].size(), id],
			})
			_emit_failed(id, "id_collision")
			continue
		# Reservierter Präfix
		if String(id).begins_with(RESERVED_ID_PREFIX):
			_failed.append({
				"id": id,
				"error": "reserved_prefix: '%s' ist Core-only" % RESERVED_ID_PREFIX,
			})
			_emit_failed(id, "reserved_prefix")
			continue
		# (Compat-Range, Dependencies — Backlog ADR 0009)
		_active[id] = manifest.duplicate(true)
		_load_order.append(id)
		_emit_loaded(id)

	# Phase 4: ContentLoader-Bridge — re-scan mit Mod-Pfaden
	if get_node_or_null("/root/ContentLoader") != null:
		# Wir nutzen ContentLoader's bestehende discover_all() — er scannt
		# user://mods/ ohnehin. Damit Tests aber Fixture-Mods reinziehen,
		# rufen wir hier reload() auf, damit der Loader frische Sicht hat.
		ContentLoader.reload()

	return _active.size()


func list_active() -> Array[StringName]:
	return _load_order.duplicate()


func get_manifest(id: StringName) -> Dictionary:
	if not _active.has(id):
		return {}
	return _active[id].duplicate(true)


func is_loaded(id: StringName) -> bool:
	return _active.has(id)


func failed_mods() -> Array[Dictionary]:
	return _failed.duplicate(true)


# ---------------------------------------------------------------------------
# Test-Hooks (nicht Public-API, von test-engineer aus aufgerufen)
# ---------------------------------------------------------------------------

## Setzt die Scan-Wurzeln. Tests setzen das auf Fixture-Pfade.
func _set_scan_roots(roots: Array[String]) -> void:
	_scan_roots = roots


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _parse_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "missing_mod_json" }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return { "ok": false, "error": "open_failed" }
	var raw := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return { "ok": false, "error": "invalid_json" }

	# Pflichtfelder prüfen
	for field in REQUIRED_MANIFEST_FIELDS:
		if not parsed.has(field):
			return { "ok": false, "error": "missing_field:" + field }

	# Schema-Version-Check
	if int(parsed["schema_version"]) != MANIFEST_SCHEMA_VERSION:
		return {
			"ok": false,
			"error": "manifest_schema_mismatch: expected %d got %s"
				% [MANIFEST_SCHEMA_VERSION, parsed["schema_version"]],
		}

	# id-Format
	var id: String = String(parsed["id"])
	if not _is_valid_mod_id(id):
		return { "ok": false, "error": "invalid_id_format: '%s'" % id }

	return { "ok": true, "manifest": parsed }


func _is_valid_mod_id(id: String) -> bool:
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


func _emit_loaded(id: StringName) -> void:
	if get_node_or_null("/root/EventBus") != null:
		EventBus.mod_loaded.emit(id)


func _emit_failed(id: StringName, error: String) -> void:
	if get_node_or_null("/root/EventBus") != null:
		EventBus.mod_failed.emit(id, error)
