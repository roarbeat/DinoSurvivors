extends Node
## Globaler SaveSystem-Autoload.
##
## Implementiert ADR 0002. JSON-basiert, schema-versioniert, atomic-write,
## Migrations-Pipeline.
##
## Trigger ausschließlich über EventBus.save_requested(reason). Game-Code
## ruft NIE save() direkt — der Pfad geht immer über den Bus.
##
## Public-API:
##   save(reason)         atomic write, feuert save_completed
##   load_save()          liest, migriert, validiert; feuert save_loaded
##   has_save_file()      bool
##   get_data()           readonly Dictionary-Snapshot
##   set_field(path, val) gepunktete Pfade ("settings.master_volume")
##   delete_save()        Dev/Reset
##   export_path()        für Bug-Reports

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

const CURRENT_SCHEMA_VERSION := 1
const SAVE_PATH := "user://saves/save.json"
const SAVE_TMP_PATH := "user://saves/save.json.tmp"
const SAVE_PREVIOUS_PATH := "user://saves/save_previous.json"
const SAVE_DIR := "user://saves/"

# Migration-Runner — wird lazily geladen, da migrations evtl. nicht existieren
const MIGRATION_RUNNER := preload("res://core/save_migrations/_runner.gd")


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _data: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_save_dir()
	# Save-Trigger-Hook am EventBus.
	# Method-Ref → kein manuelles disconnect nötig.
	if get_node_or_null("/root/EventBus") != null:
		EventBus.save_requested.connect(_on_save_requested)
	# Default-State falls noch kein Save existiert.
	_data = _default_save()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Schreibt _data atomic auf Disk. Ruft Game-Code NIEMALS direkt —
## immer via EventBus.save_requested.emit(reason).
func save(reason: StringName = &"manual") -> bool:
	_data["meta"]["last_played_at"] = Time.get_datetime_string_from_system(true)
	_data["meta"]["last_save_reason"] = String(reason)
	_data["schema_version"] = CURRENT_SCHEMA_VERSION

	# Vorherigen Save als previous wegkopieren (Windows-Resilience).
	if FileAccess.file_exists(SAVE_PATH):
		var prev := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var content := prev.get_as_text()
		prev.close()
		var prev_out := FileAccess.open(SAVE_PREVIOUS_PATH, FileAccess.WRITE)
		if prev_out != null:
			prev_out.store_string(content)
			prev_out.close()

	# Atomic-Write: tmp → rename.
	var json_str := JSON.stringify(_data, "\t")
	var fout := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if fout == null:
		push_error("SaveSystem: konnte tmp-File nicht öffnen: %s"
			% FileAccess.get_open_error())
		return false
	fout.store_string(json_str)
	fout.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_error("SaveSystem: konnte Save-Dir nicht öffnen")
		return false
	var rename_err := dir.rename(SAVE_TMP_PATH.get_file(), SAVE_PATH.get_file())
	if rename_err != OK:
		push_error("SaveSystem: rename schlug fehl, err=%d" % rename_err)
		return false

	# Größen-Check (Risiko-Mitigation aus ADR 0002)
	var size := FileAccess.get_file_as_bytes(SAVE_PATH).size()
	if size > 5 * 1024 * 1024:
		push_warning("SaveSystem: Save-Größe %d Bytes > 5 MB — investigieren" % size)

	if get_node_or_null("/root/EventBus") != null:
		EventBus.save_completed.emit()
	return true


## Lädt + migriert + validiert. Bei Fehler: _data bleibt unverändert,
## Rückgabe false.
func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		# Kein Save vorhanden → Default-State, kein Fehler.
		_data = _default_save()
		return false

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveSystem: load_save FileAccess.open fail")
		return false
	var raw := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_error("SaveSystem: Save-File ist kein JSON-Object")
		return false

	var loaded: Dictionary = parsed
	var found_version: int = int(loaded.get("schema_version", 0))

	# Migration-Pipeline
	if found_version < CURRENT_SCHEMA_VERSION:
		_backup_before_migration(found_version)
		loaded = MIGRATION_RUNNER.migrate(loaded, found_version, CURRENT_SCHEMA_VERSION)

	# Save-Ref-Validation gegen ContentLoader
	_validate_content_refs(loaded)

	# _data MUSS gesetzt sein, bevor save_loaded feuert — Listener
	# (z.B. MetaProgression) lesen via get_data() ihre Slots aus.
	# `found_version` ist die ORIGINAL-Version (vor Migration), wie im
	# Signal-Doc dokumentiert.
	_data = loaded

	if get_node_or_null("/root/EventBus") != null:
		EventBus.save_loaded.emit(found_version)
	return true


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Liefert eine flache Kopie. Mutationen am Returnwert beeinflussen den
## State NICHT — für Mutations bitte set_field() nutzen.
func get_data() -> Dictionary:
	return _data.duplicate(true)


## Setzt einen Wert per gepunktetem Pfad, z.B. "settings.master_volume".
## Erzeugt fehlende Zwischendictionaries.
func set_field(path: String, value: Variant) -> void:
	var parts := path.split(".")
	var cursor: Dictionary = _data
	for i in parts.size() - 1:
		var key := parts[i]
		if not cursor.has(key) or not (cursor[key] is Dictionary):
			cursor[key] = {}
		cursor = cursor[key]
	cursor[parts[-1]] = value


func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	var err := dir.remove(SAVE_PATH.get_file())
	if err == OK:
		_data = _default_save()
	return err == OK


func export_path() -> String:
	# absoluter Pfad für Bug-Reports — User-friendly Hinweis im UI später.
	return ProjectSettings.globalize_path(SAVE_PATH)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_save_requested(reason: StringName) -> void:
	save(reason)


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _default_save() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"meta": {
			"created_at": Time.get_datetime_string_from_system(true),
			"last_played_at": Time.get_datetime_string_from_system(true),
			"game_version": ProjectSettings.get_setting("application/config/version", "0.0.1"),
		},
		"meta_progression": {
			"currencies": { "amber": 0 },
			"unlocked_dinos": ["trex"],
			"research_progress": {},
		},
		"stats": {
			"total_runs": 0,
			"total_play_seconds": 0,
			"bosses_defeated": [],
		},
		"settings": {
			"master_volume": 1.0,
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"language": "de",
		},
		"mod_overrides_used": [],
	}


func _backup_before_migration(version: int) -> void:
	var backup_path := "%ssave_backup_v%d.json" % [SAVE_DIR, version]
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	var dst := FileAccess.open(backup_path, FileAccess.WRITE)
	if dst != null:
		dst.store_string(content)
		dst.close()


## Walk durch _data und prüfe alle Felder, die nach ID-Konvention aussehen,
## gegen ContentLoader. Fehlende IDs landen in mod_overrides_used als Hinweis.
func _validate_content_refs(d: Dictionary) -> void:
	if get_node_or_null("/root/ContentLoader") == null:
		return
	# unlocked_dinos sind Player-Char-IDs — eigener Type, später ergänzt.
	# bosses_defeated sind Boss-IDs.
	var bosses_defeated: Array = d.get("stats", {}).get("bosses_defeated", [])
	for boss_id in bosses_defeated:
		if not ContentLoader.has_item(&"boss", StringName(boss_id)):
			push_warning("SaveSystem: bekannter Boss '%s' fehlt im ContentLoader (Mod entfernt?)"
				% boss_id)
