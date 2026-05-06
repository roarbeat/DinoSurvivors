extends RefCounted
## Interface-Konvention für Save-Migrations.
##
## Jede Migration ist eine separate Datei `v<n>_to_v<n+1>.gd` und MUSS:
##   1. eine static func migrate(data: Dictionary) -> Dictionary haben
##   2. eine PURE FUNCTION sein — gleicher Input → gleicher Output, keine Side-Effects
##   3. eine const FROM_VERSION und TO_VERSION exportieren
##
## NIEMALS bestehende Migrations modifizieren oder löschen — nur neue ergänzen.
##
## Beispiel-Skelett:
##
##   extends RefCounted
##   const FROM_VERSION := 1
##   const TO_VERSION := 2
##
##   static func migrate(d: Dictionary) -> Dictionary:
##       # Beispiel: neues Feld hinzufügen mit Default
##       if not d.has("new_field"):
##           d["new_field"] = "default_value"
##       d["schema_version"] = TO_VERSION
##       return d
##
## Tests: jede Migration bekommt ein passendes Fixture-File unter
## tests/fixtures/save_v<n>.json plus einen gut-Test, der das Fixture lädt
## und das Output-Schema prüft.

# Diese Klasse ist reine Doku — wird nicht instantiiert.
