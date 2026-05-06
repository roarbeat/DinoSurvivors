extends RefCounted
## Sequenzieller Migrations-Runner.
##
## Iteriert von `from_version` bis `to_version`, sucht für jeden Schritt
## eine Migration `v<n>_to_v<n+1>.gd` und ruft `migrate(data)` auf.
##
## Wenn eine erforderliche Migration fehlt: push_error und Daten bleiben
## unverändert — SaveSystem entscheidet, ob das Spiel trotzdem mit
## Default-State weitermacht.

const MIGRATION_DIR := "res://core/save_migrations/"


## Ruft alle Migrations sequenziell auf. Rückgabe: ggf. migrierte Daten.
static func migrate(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	if from_version >= to_version:
		return data

	var current := data
	for v in range(from_version, to_version):
		var script_path := "%sv%d_to_v%d.gd" % [MIGRATION_DIR, v, v + 1]
		if not ResourceLoader.exists(script_path):
			push_error("SaveSystem: Migration %d→%d fehlt (%s) — Save bleibt auf v%d"
				% [v, v + 1, script_path, v])
			return current
		var migration_script: GDScript = load(script_path)
		# Konvention: static func migrate(d) -> Dictionary
		var result = migration_script.migrate(current)
		if not (result is Dictionary):
			push_error("SaveSystem: Migration v%d→v%d gab kein Dictionary zurück"
				% [v, v + 1])
			return current
		current = result
		# Defensive: schema_version muss von der Migration gesetzt sein.
		if int(current.get("schema_version", -1)) != v + 1:
			push_warning("SaveSystem: Migration v%d→v%d hat schema_version nicht aktualisiert"
				% [v, v + 1])
			current["schema_version"] = v + 1
	return current
