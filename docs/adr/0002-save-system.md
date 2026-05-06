# ADR 0002 – Save-System & Schema-Versionierung

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), save-migration-specialist (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #3 Save-Versionierung, #5 Mod-freundlich, #6 Stable IDs
- Voraussetzungen: ADR 0001 (EventBus), ADR 0003 (ContentLoader)

---

## 1. Kontext

Spieler-Saves müssen über die gesamte Lebensdauer von DinoRogue lesbar
bleiben — auch nach Schema-Änderungen, neuen Features, Mod-Inkompatibilitäten.
Die strikte Regel: **Spieler-Saves gehen nie verloren**, oder Spieler bekommen
mindestens eine klare, freundliche Fehlermeldung.

Anforderungen:
- **Versioniert** mit `schema_version` als erstes Feld — vor Migration lesbar
- **Migrations** als pure functions, additiv (alte Migrations werden NIE
  geändert oder gelöscht)
- **Atomic Writes** — Stromausfall während Save darf alten Save nicht zerstören
- **Backups** vor Migration: `save_backup_v<n>.json` neben `save.json`
- **Save-Refs validiert** gegen ContentLoader (ID existiert noch?) — fehlt
  ein Mod, läuft das Spiel mit Defaults statt zu crashen
- **Save-Trigger** ausschließlich über `EventBus.save_requested.emit(reason)`
  — Game-Code ruft NIE direkt `SaveSystem.save()`
- **Keine User-facing Strings** im SaveSystem — alle Nachrichten über tr()

## 2. Optionen

### Option A — JSON, manuelle Migration-Pipeline (empfohlen)

Save-Format ist UTF-8-JSON mit `schema_version` als erstes Feld.
Migrations leben als statische Klassen unter `core/save_migrations/v<n>_to_v<n+1>.gd`.
Beim Load wird sequenziell von der gefundenen Version bis CURRENT migriert.

**Pro**
- Lesbar für Save-Editing-Mods und Devs (Notepad-debuggable)
- JSON-Stabilität: Godot's JSON-Output ist deterministisch genug für Diffs
- Migrations als eigenständige Files: gut review-bar, isoliert testbar
- Keine Engine-spezifische Serialisierung — Saves überleben Godot-Updates
- Mod-Authoren können Save-Hooks ohne Reverse-Engineering bauen

**Contra**
- Größer als binär (für DinoRogue-Save-Größen praktisch egal — KB-Bereich)
- Floats verlieren ggf. minimale Präzision durch JSON — bei reinen Meta-Werten
  irrelevant

### Option B — Godot ConfigFile

`ConfigFile` ist Godot's eingebauter Key-Value-Persister.

**Pro**
- Null-Setup, eingebautes API
- Section-basierte Struktur ist Spieler-freundlich

**Contra**
- Schema-Versionierung muss von Hand obendrauf gebaut werden
- Verschachtelte Strukturen (Mutationen-Liste mit Tags etc.) sind unbequem
- Format ist Godot-spezifisch, schlechter portierbar
- Diffs sind weniger lesbar als JSON

### Option C — Binary mit FileAccess.store_var

Ressource speichern oder Variant-Stream.

**Pro**
- Kleinste Files, schnellste Reads
- Keine Float-Präzisions-Sorgen

**Contra**
- Black-Box für Save-Editing-Mods — Mod-Ökosystem verliert Hand
- Schema-Migration extrem teuer, weil Format selbst Engine-Version-abhängig
- Bei korruptem File: keine teilweise Wiederherstellung möglich

## 3. Empfehlung

**Option A — JSON mit manueller Migration-Pipeline.**

**Begründung**
- Mod-/Community-freundlich (Prinzip 5): Save-Editor-Mods, Save-Sharer,
  Save-Cheaters sind alle drei willkommen — alle drei brauchen lesbares Format
- Migration-Files sind kleine, klar versionierte Artefakte — der
  save-migration-specialist hat einen klaren Workflow
- ContentLoader-Cross-Validation ist trivial: alle ID-Felder im Save sind
  Strings, die direkt `ContentLoader.has_item(type, id)` durchlaufen können
- Disk-Größe ist für DinoRogue irrelevant — selbst große Saves bleiben < 1 MB

**Schema-Layout**

```jsonc
{
  "schema_version": 1,            // IMMER erstes Feld, Lese-Path liest nur diesen Header bei Validierung
  "meta": {
    "created_at": "2026-05-06T10:00:00Z",
    "last_played_at": "2026-05-06T10:30:00Z",
    "game_version": "0.0.1"
  },
  "meta_progression": {
    "currencies": { "amber": 0 },
    "unlocked_dinos": ["trex"],
    "research_progress": {}
  },
  "stats": {
    "total_runs": 0,
    "total_play_seconds": 0,
    "bosses_defeated": []
  },
  "settings": {
    "master_volume": 1.0, "music_volume": 0.8, "sfx_volume": 1.0,
    "language": "de"
  },
  "mod_overrides_used": []
}
```

Run-State (Mid-Run-Saves) ist NICHT Teil von v1 — kommt mit ADR Run-State,
sobald das Game-Flow steht.

**SaveSystem-Public-API**

```gdscript
SaveSystem.save(reason: StringName) -> bool      # atomic, feuert save_completed
SaveSystem.load() -> bool                        # feuert save_loaded(version)
SaveSystem.get_data() -> Dictionary              # readonly snapshot
SaveSystem.set_field(path: String, value)        # gepunktete Pfade ("settings.master_volume")
SaveSystem.has_save_file() -> bool
SaveSystem.delete_save() -> bool                 # Dev / Spieler-Reset
SaveSystem.export_path() -> String               # für Bug-Reports
```

**EventBus-Integration**
- SaveSystem subscribed `save_requested` → ruft intern `save(reason)`
- Bei Erfolg: emittet `save_completed`
- Bei Load: emittet `save_loaded(schema_version)` — wichtig: VOR Migration,
  damit Listener die Original-Version sehen

**Migration-Pipeline**

```
core/save_migrations/
├── _migration.gd              Interface: static func migrate(d: Dictionary) -> Dictionary
├── v1_to_v2.gd                (kommt mit erstem Schema-Bruch)
└── _runner.gd                 sequenzieller Caller, von SaveSystem genutzt
```

Regeln:
- Migrations sind **pure functions** — gleicher Input, gleicher Output, keine Side-Effects
- Alte Migrations werden **nie modifiziert oder gelöscht**, nur neue ergänzt
- Vor jeder Migration: Backup `save_backup_v<n>.json` schreiben

**Atomic-Write-Verfahren**
1. Schreibe nach `save.json.tmp`
2. `flush()` + close
3. `DirAccess.rename_absolute(tmp, save.json)` (auf POSIX atomic, auf Windows
   nicht garantiert atomic, aber gleichwertig „best-effort")

**Save-Ref-Validation beim Load**
- Nach Migration: walk durchs Dictionary, jedes ID-Feld via Convention
  (`*_id`, `unlocked_dinos[]`, `bosses_defeated[]`) gegen ContentLoader prüfen
- Fehlende IDs werden geloggt + in `mod_overrides_used` festgehalten,
  Spiel läuft weiter

## 4. Konsequenzen

**Positiv**
- Klar versionierte Saves überleben jedes Update
- save-migration-specialist hat einen einfachen, klar definierten Workflow
- Mod-Authoren können sicher Saves manipulieren / inspizieren
- ContentLoader-Validation entkoppelt Saves von genauer Mod-Konstellation

**Negativ**
- Migrations-Verzeichnis wächst monoton — bei v50 sind v1→v50 49 Dateien.
  Akzeptabel, da Reads schnell sind und Devs nur die letzte Migration anfassen.
- JSON-Schema-Drift muss diszipliniert dokumentiert werden
  (save-schema-history.md im Migration-Specialist-Memory)

**Risiken**
- **Risiko:** Migration enthält Side-Effect (z.B. file I/O), bricht Pure-Function-Garantie.
  → **Mitigation:** Code-Review-Checklist erweitert (siehe code-reviewer-Memory),
  Tests laden alte Fixtures und vergleichen Output deterministisch.
- **Risiko:** Atomic-Write-Rename auf Windows nicht atomic → bei Crash mid-rename
  liegt save.json kaputt vor.
  → **Mitigation:** Vor jedem Save existierende `save.json` nach
  `save_previous.json` kopieren — schlechtester Fall ist Verlust eines einzelnen
  Save-Slots, nicht eines Runs.
- **Risiko:** Save-Größe wächst durch Mod-Daten unkontrolliert.
  → **Mitigation:** SaveSystem loggt Größe bei jedem Save, Warnung > 5 MB.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/save_system.gd`                 Autoload, Public-API + Persistence
- `core/save_migrations/_migration.gd`  Interface-Doku (statische Klasse)
- `core/save_migrations/_runner.gd`     Sequenzieller Migrations-Aufrufer
- `tests/unit/test_save_system.gd`      gut-Tests
- `tests/fixtures/save_v1.json`         Reference-Save für Roundtrip-Tests
- `project.godot`                       SaveSystem als drittes Autoload
- `docs/adr/0002-save-system.md`        dieses Dokument
- `.claude/agents/memory/save-migration-specialist/save-schema-history.md`
                                        Schema-v1-Doku

Berührt später:
- jedes ADR, das persistente Daten ergänzt → neue Migration
- mod-api-curator: Save-Format ist Public-API für Save-Editing-Mods
- release-manager: Pre-Release-Checkliste verlangt Migration-Test

## 6. Folge-Entscheidungen (Backlog)

- ADR 0007 — Run-State-Persistierung (Mid-Run-Save)
- ADR 0004 — EventRecorder & Telemetrie (kann SaveSystem-Hook nutzen)
- ADR 0005 — Mod-Loader (interagiert mit `mod_overrides_used`-Feld)
