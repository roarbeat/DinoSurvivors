# Content-Pipeline

> Wie der `content-author` (Agent oder Mensch) neuen Content anlegt.
> Spec-Quelle: ADR 0003.

## Vorgehen pro neuer Mutation/Gegner/Boss

1. **ID wählen**
   - snake_case, ASCII a–z + 0–9 + _, max 40 Zeichen
   - In `agents/memory/content-author/content-id-registry.md` prüfen,
     ob die ID schon existiert
   - Naming-Conventions in `agents/memory/content-author/naming-conventions.md`

2. **`.tres`-File anlegen**
   - Pfad: `res://content/<type>/<id>.tres`
   - Script: passende Resource-Klasse aus `res://core/content/`
   - Alle i18n-Keys folgen `<type>.<id>.<field>`
   - `source_mod_id = &""` für Core, `override_existing = false`
   - Templates in `agents/memory/content-author/content-templates.md`

3. **Translation-Keys ergänzen**
   - In `locale/de.po` UND `locale/en.po`
   - lore-writer-Agent triggern, falls Tooltip-Text noch nicht vorhanden
   - Konsistenz mit `agents/memory/localization-coordinator/translation-glossary.md`

4. **BALANCE.csv-Eintrag**
   - Eine Zeile pro Item mit den wichtigsten Stats
   - Notes-Spalte: Begründung der Wahl, Synergie-Hinweise

5. **Manuelle Verifikation**
   - Godot-Editor öffnen, Resource lädt ohne Error
   - Smoke-Run: `tests/scenes/test_event_bus.tscn` zeigt `content_loaded`
     mit gestiegenem item_count

6. **Memory aktualisieren**
   - ID in `content-id-registry.md` eintragen
   - Wenn neue Stat-Keys: in `naming-conventions.md` ergänzen

## Was NICHT der content-author tut

- `.gd`-Code schreiben (das ist `godot-implementer`)
- Bestehende IDs umbenennen (Prinzip 6 — niemals)
- Neue Stat-Felder erfinden ohne Rücksprache mit `game-architect`
  (das ist eine Schema-Änderung, kein Content-Add)

## Mod-Author-Variante

Mods folgen demselben Schema, nur unter `user://mods/<mod_id>/content/<type>/`.
Override eines Core-Items: `override_existing = true` im Resource setzen.
Loader emittiert Warning + listet in `ContentLoader.overrides_applied()`.
