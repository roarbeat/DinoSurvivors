# ADR 0003 – ContentLoader & Resource-Konventionen

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), Haupt-Agent
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-freundlich, #6 Stable IDs, #7 testbar
- Voraussetzungen: ADR 0001 (EventBus)
- Wird vorausgesetzt von: ADR 0002 (Save-System), zukünftiges ADR Mod-Loader

---

## 1. Kontext

DinoRogue ist datengetrieben — Mutationen, Gegner, Bosse, Wellen,
Forschungs-Nodes, Achievements existieren als Daten-Files (`.tres`),
nicht im Code. Wir brauchen eine zentrale Komponente, die diese Files
zur Laufzeit findet, lädt, validiert und game-systemen über IDs zur
Verfügung stellt.

Zusätzliche Anforderungen:

- **Mods** müssen eigenen Content beisteuern können, ohne den Core
  zu patchen (Prinzip #5). Mod-Files leben unter `user://mods/<mod_id>/content/...`.
- **IDs sind stabil** (Prinzip #6) — wenn `triceratops_horns` einmal
  vergeben wurde, bleibt sie das. Save-Files referenzieren IDs,
  Save-Migrations können fehlen.
- **Validierung beim Boot**: Doppel-IDs, fehlende i18n-Keys, ungültige
  Stat-Felder müssen früh und laut auffallen, nicht erst beim ersten
  Spawn in Welle 7.
- **Single Source of Truth**: weder Game-Systeme noch Mods dürfen direkt
  per `load("res://content/...")` zugreifen — alles über den Loader.

## 2. Optionen

### Option A — Eager Discovery, Type-Indexed Registry (empfohlen)

Beim Boot scannt der Loader feste Pfade per `DirAccess`:
- `res://content/<type>/*.tres` (Core)
- `user://mods/<mod_id>/content/<type>/*.tres` (Mods, in Mod-Load-Order)

Jede `.tres` wird geladen, ihre Klasse geprüft (`is MutationDef` etc.),
in einer Registry `Dictionary[type → Dictionary[id → ContentItem]]` abgelegt.
Bei ID-Kollision: Standardverhalten **warn + skip** (Mod überschreibt
nicht, Mod-Author muss explizit `override: true` im Resource setzen).

**Pro**
- Robust: vergessene Manifest-Einträge führen nicht zu fehlendem Content
- Validation-Pass beim Boot: alle IDs einmalig, alle i18n-Keys auflösbar
- Game-Code bekommt synchrones, allokationsarmes `get(type, id)`
- Save-Loader kann früh feststellen, ob Save-IDs (noch) existieren

**Contra**
- Boot-Zeit linear in Anzahl Content-Files
- Speichert alles im RAM, auch ungenutzten Content (ist bei .tres-Größen
  praktisch egal — Texturen werden erst on-demand geladen)

### Option B — Lazy Loading per ID

Loader macht keine Discovery. `ContentLoader.get(type, id)` resolved
zur Aufrufzeit über Pfad-Konvention (`res://content/<type>/<id>.tres`).

**Pro**
- Boot praktisch instant
- Memory-effizient

**Contra**
- Keine Boot-Validation: Tippfehler in IDs schlagen erst beim Use auf
- Mod-Override-Logik müsste auf jedem `get()` durchlaufen werden
- `get_all(type)` braucht trotzdem Discovery — hybride Komplexität

### Option C — Manifest-Driven

Core hat `content/manifest.json` mit allen registrierten IDs + Pfaden.
Mods liefern `content_manifest.json` in ihrer Mod-Wurzel.

**Pro**
- Schnellste Boot-Zeit
- Manifest = explizite Public-API, kuratiert

**Contra**
- Manifest-Pflicht ist Ergonomie-Bremse für content-author und Modder
- Manifest und tatsächliche Files können auseinanderdriften (vergessenes Eintragen)
- Skill-Floor für Modder steigt

## 3. Empfehlung

**Option A** mit klar definiertem Discovery-Vertrag.

**Begründung**
- Robustheit > Boot-Performance: 200 .tres-Files laden in Bruchteilen einer
  Sekunde; Save-Refs auf nicht-existente IDs sind viel schlimmer.
- Senkt Hürde für `content-author` und Modder maximal: „leg .tres in den
  richtigen Ordner, fertig" — kein Manifest-Buchhalter nötig.
- Boot-Validation-Pass gibt frühe, laute Fehlermeldungen (Prinzip Fail-Fast).
- Eager Registry harmoniert mit Save-Loader (kann beim Save-Load synchron
  prüfen, ob alle referenzierten IDs noch existieren — Migration-Hook).

**Verbindliche Konventionen**

```
res://content/
├── mutations/   <id>.tres       extends MutationDef
├── enemies/     <id>.tres       extends EnemyDef
├── bosses/      <id>.tres       extends BossDef
├── waves/       <id>.tres       extends WaveDef        (später)
└── research/    <id>.tres       extends ResearchNode   (später)

user://mods/<mod_id>/content/<type>/<id>.tres
```

**Resource-Hierarchie**

```
Resource
└── ContentItem (abstract)            # core/content/content_item.gd
    ├── id: StringName                # snake_case, stabil, unique pro type
    ├── display_name_key: StringName  # i18n-Key, NIE Klartext
    ├── description_key: StringName   # i18n-Key, NIE Klartext
    ├── source_mod_id: StringName     # &"" für Core, sonst Mod-ID (vom Loader gesetzt)
    └── override_existing: bool       # erlaubt Mod, Core-ID zu überschreiben

      ├── MutationDef
      │   ├── rarity: StringName       (&"common"|&"rare"|&"epic"|&"legendary")
      │   ├── stat_modifiers: Dictionary[StringName, float]
      │   ├── tags: Array[StringName]
      │   └── icon: Texture2D (nullable)
      │
      ├── EnemyDef
      │   ├── max_health: float
      │   ├── speed: float
      │   ├── damage: float
      │   ├── xp_reward: int
      │   └── scene: PackedScene (nullable bis Combat-System steht)
      │
      └── BossDef
          ├── max_health: float
          ├── phases: Array[Dictionary]
          ├── intro_text_key: StringName
          └── reward_currency_amount: int
```

**ID-Konventionen**
- snake_case, ASCII a–z, 0–9, _
- Maximal 40 Zeichen
- Reserviert: Präfix `core_` ist nur für Core-Content, Mods dürfen ihn
  nicht nutzen (verhindert Imitations-Mods)

**Override-Regel**
- Standard: Mod-Resource mit Core-ID → Boot-Warnung, Mod-Eintrag ignoriert
- `override_existing = true` im Mod-Resource: Mod ersetzt Core-Eintrag,
  Loader emittiert Warning + sammelt Override-Liste für Save-Manifest

**Loader-Public-API**

```gdscript
ContentLoader.get(type: StringName, id: StringName) -> ContentItem
ContentLoader.get_or_null(type: StringName, id: StringName) -> ContentItem
ContentLoader.get_all(type: StringName) -> Array[ContentItem]
ContentLoader.has(type: StringName, id: StringName) -> bool
ContentLoader.types() -> Array[StringName]
ContentLoader.all_ids(type: StringName) -> Array[StringName]
ContentLoader.reload()                            # nur Dev — feuert content_reloaded
```

`get()` panics bei unbekannter ID (laut, früh). Game-Code, der mit
fehlenden IDs umgehen muss (z.B. Save-Loader), nutzt `get_or_null()`.

**EventBus-Integration**
Neues Signal: `content_loaded(type_count: int, item_count: int)`.
Wird einmal beim Boot gefeuert, nachdem Discovery + Validation durch sind.

## 4. Konsequenzen

**Positiv**
- Saubere Trennung zwischen *was* (Daten) und *wie* (Code)
- Mods sind Erst-Klasse-Bürger — kein Sonderpfad für Mod-Content
- ID-basierte Save-Referenzen sind sicher (Loader validiert beim Boot)
- `content-author`-Agent hat ein klares Procedure: Datei in den richtigen
  Ordner legen, fertig

**Negativ**
- Pfad-Layout ist Public-API — Umbenennung des `content/`-Ordners ist
  Mod-Breaking (mod-api-curator pflegt das)
- ResourceLoader-Caching: bei Hot-Reload aufpassen, sonst sehen Devs alte
  Werte. `reload()`-Methode hilft.

**Risiken**
- **Risiko:** Dev legt .tres im falschen Ordner ab → wird unter
  falschem Type indexiert.
  → **Mitigation:** Loader macht `is`-Check beim Laden und verweigert
  Inhalte, deren Klasse nicht zum Ordner-Namen passt.
- **Risiko:** Mod überschreibt Core-Mutation, ändert Balance subtil,
  Spieler weiß nicht warum sein Build anders fühlt.
  → **Mitigation:** UI-Indikator „modded" für überschriebenen Content
  (später), Loader führt Override-Liste, Save-Manifest enthält
  `mod_overrides_used`.

## 5. Betroffene Dateien & Systeme

Anzulegen (durch godot-implementer):
- `core/content/content_item.gd`        Base Resource (abstract)
- `core/content/mutation_def.gd`        Mutation-Schema
- `core/content/enemy_def.gd`           Enemy-Schema
- `core/content/boss_def.gd`            Boss-Schema (Stub für Phase 0)
- `core/content_loader.gd`              Autoload, Discovery + Registry
- `project.godot`                       ContentLoader als Autoload
                                        (NACH EventBus, da `content_loaded` feuert)
- `core/event_bus.gd`                   neues Signal `content_loaded`
- `tests/unit/test_content_loader.gd`   gut-Tests
- `content/mutations/triceratops_horns.tres`  erste echte Mutation
                                        (durch content-author)
- `locale/de.po` + `locale/en.po`       i18n-Stubs (durch
                                        localization-coordinator)
- `docs/CONTENT.md`                     wie content-author neuen Content
                                        anlegt (Boilerplate-Procedure)
- `docs/MODDING.md`                     erster Stub: wie Mods Content
                                        beisteuern

Berührt später:
- ADR 0002 Save-System: validiert Save-Refs gegen ContentLoader
- ADR Mod-Loader: ruft ContentLoader.reload() nach Mod-Discovery
- jedes Game-System das auf Content zugreift (Spawner, Mutation-System, …)

## 6. Folge-Entscheidungen (Backlog)

- ADR 0002 — Save-System, jetzt mit konkreter Resource-Surface
- ADR 0005 — Mod-Loader: lädt mod.json, registriert Mod-IDs, triggert
  ContentLoader-Re-Discovery in Mod-Pfaden
- ADR 0006 — Hot-Reload-Workflow für Dev-Sessions
