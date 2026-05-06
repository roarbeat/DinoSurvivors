# ADR 0005 – Mod-Loader & mod.json-Schema

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), mod-api-curator (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-freundlich, #6 Stable IDs
- Voraussetzungen: ADR 0001 (EventBus), ADR 0003 (ContentLoader), ADR 0002 (SaveSystem)

---

## 1. Kontext

ContentLoader scannt bereits `user://mods/<mod_id>/content/<type>/` (ADR 0003).
Was fehlt: ein expliziter Mod-Lifecycle, Mod-Identitäts-Manifest (`mod.json`),
Boot-Order, Aktivieren/Deaktivieren, Failure-Strategie und ein klares Vertrag
zwischen Mod-Author und Engine.

Anforderungen:
- **Manifest (`mod.json`)** in jedem Mod-Wurzelverzeichnis: Name, Version,
  Autor, Spielversion-Compat-Bereich, Liste enthaltener Content-Types
- **ID-Discovery** vor ContentLoader-Discovery — der Loader muss wissen,
  welche Mods existieren, bevor er deren Content scannt
- **Failure-Isolation** — ein kaputter Mod darf andere Mods und Core nicht
  brechen; failure wird via `EventBus.mod_failed` gemeldet
- **Stable Boot-Order** — Mods werden alphabetisch nach ID geladen, sofern
  nicht durch `dependencies` im Manifest neu sortiert
- **Public-API-Surface** ist die Vereinigung aus EventBus-Signals,
  ContentLoader-Methoden, Resource-Schemas und mod.json-Schema

## 2. Optionen

### Option A — Eigener Autoload, vor ContentLoader (empfohlen)

`ModLoader` läuft als Autoload zwischen EventBus und ContentLoader. Bei Boot:
1. Scannt `user://mods/`, findet Verzeichnisse mit `mod.json`
2. Parsed Manifeste, validiert Schema, prüft Compat-Range
3. Sortiert Mods topologisch nach `dependencies`
4. Aktive Mod-IDs werden ContentLoader übergeben (statt blindem Scan
   aller Verzeichnisse)
5. Pro Mod: `EventBus.mod_loaded.emit(mod_id)` oder `mod_failed`

ContentLoader scannt nur Mods, die ModLoader als „aktiv" markiert hat.

**Pro**
- Klare Verantwortungs-Trennung: ModLoader kennt Mods, ContentLoader Content
- Failure ist isoliert pro Mod, nicht pro Datei
- `dependencies` im Manifest ergibt deterministische Override-Reihenfolge
- Manifest ist kuratierte Public-API — Modder müssen sich bewusst zu ihrem
  Mod committen

**Contra**
- Eine zusätzliche Boot-Stufe = mehr beweg- liche Teile
- ContentLoader.discover_all() braucht eine `mod_ids: Array[StringName]`-
  Variante zusätzlich zur Standalone-Variante (für Tests)

### Option B — ContentLoader scannt selbst Manifeste

Kein eigener ModLoader. ContentLoader liest `mod.json` direkt während
seines Discovery-Passes, behält Mod-Liste intern.

**Pro**
- Weniger Autoloads, weniger Boot-Komplexität

**Contra**
- ContentLoader bekommt zwei Verantwortungen — Mod-Lifecycle UND Content-Resolution
- Failure-Reporting wird komplizierter (per-Mod-Fehler vs. per-Datei-Fehler)
- Mod-Reihenfolge / Dependencies passen nicht zur Type-Indexierung
- Tests werden schwerer: Content-Tests müssten auch Mod-Manifeste aufsetzen

### Option C — Manifestlose Mods, alphabetisches Laden

Status quo aus ADR 0003 reicht: Mod-Verzeichnisse werden gescannt, kein Manifest,
keine Versionierung.

**Pro**
- Minimaler Aufwand für Mod-Author („einfach Files reinwerfen")

**Contra**
- Keine Compat-Versionierung → Spiel-Update bricht alle Mods leise
- Keine Author-Information → Mod-Listing-UI ohne Daten
- Keine Dependencies-Auflösung → Mod-Reihenfolge unstabil
- Modder verlieren Kontrolle über ihren Override-Vorrang

## 3. Empfehlung

**Option A — eigener ModLoader-Autoload, mod.json verbindlich.**

**Begründung**
- Saubere Verantwortungs-Trennung (Prinzip Single Responsibility)
- Compat-Range im Manifest ist der einzige verlässliche Weg, Mod-Bruch
  bei Spiel-Updates abzufangen
- `dependencies` ist der erwartete Modding-Standard (Workshop, Nexus etc.)
- ContentLoader bleibt fokussiert auf „lade alle .tres und indexiere"

**mod.json-Schema (v1)**

```jsonc
{
  "schema_version": 1,                         // mod.json schema, NICHT Game-Save-Schema
  "id": "example_mod",                         // snake_case, einzigartig, NIE umbenennen
  "name": "Example Mod",                       // anzeigbar, beliebige Sprache
  "version": "1.0.0",                          // SemVer
  "author": "Robin",
  "description": "Beispiel-Mod der Doku.",
  "game_version_min": "0.0.1",                 // SemVer-Range Untergrenze (inklusive)
  "game_version_max": "0.99.0",                // optional, exklusive Obergrenze
  "dependencies": [                            // optional
    { "id": "another_mod", "version_min": "1.0.0" }
  ],
  "content_types": ["mutation"],               // welche Types der Mod beisteuert
  "homepage": "https://example.com",           // optional
  "license": "MIT"                             // optional
}
```

**Boot-Sequenz**

```
1. EventBus           ADR 0001
2. ContentLoader      ADR 0003 — scannt Core (res://content/)
3. ModLoader          ADR 0005 — scannt user://mods/, validiert Manifeste
                                  ↓
                                  → ContentLoader.discover_mods(active_ids)
                                  → für jeden ok-Mod: EventBus.mod_loaded
                                  → für jeden Fehler:  EventBus.mod_failed
4. SaveSystem         ADR 0002 — mod_overrides_used wird gegen
                                  ContentLoader.overrides_applied() validiert
```

**Public-API**

```gdscript
ModLoader.discover() -> int                   # Anzahl aktiver Mods, feuert Signals
ModLoader.list_active() -> Array[StringName]  # IDs in Lade-Reihenfolge
ModLoader.get_manifest(id) -> Dictionary      # readonly Kopie
ModLoader.is_loaded(id) -> bool
ModLoader.failed_mods() -> Array[Dictionary]  # [{id, error}]
```

**Failure-Modi**

| Fehler | Verhalten |
|--------|-----------|
| `mod.json` nicht parsbar | mod_failed, Mod komplett ignoriert |
| Pflichtfeld fehlt | mod_failed mit Feldname, ignoriert |
| `id` Kollision mit anderem Mod | beide → mod_failed (Modder müssen das auflösen) |
| `id` reserviert (`core_*`) | mod_failed, ignoriert |
| `game_version` außerhalb Compat | mod_failed mit „incompatible", ignoriert |
| `dependency` fehlt oder zu alt | mod_failed mit „missing_dependency" |
| Cycle in `dependencies` | mod_failed für alle Mods im Cycle |

## 4. Konsequenzen

**Positiv**
- Mod-API-Surface ist nun **vollständig** und versioniert: EventBus +
  ContentLoader + Resource-Schemas + mod.json
- Pre-Release-Checkliste „Mod-API-Kompatibilität" hat einen konkreten
  Anker: Diff der Public-API-Surface zwischen Versionen
- Mod-Workshop-Listings haben strukturierte Daten (name, version, author)

**Negativ**
- Manifest-Pflicht ist Friction für Hobby-Modder. Mitigation: Tooling/
  Template via `docs/MODDING.md`, später vielleicht Editor-Plugin.
- Dependency-Auflösung ist klassische Topo-Sort-Komplexität — Initial-
  Implementation lässt das aus (alphabetisches Laden) und ergänzt es
  bei Bedarf.

**Risiken**
- **Risiko:** Topo-Sort-Bug → Cycle nicht erkannt → Endlos-Schleife.
  → **Mitigation:** Initial-Variante macht alphabetisches Laden,
  Dependencies-Validation ohne Topo-Sort. Cycle-Detection kommt mit
  Implementation der Dependencies, mit explizitem Test.
- **Risiko:** Mod-Override-Stapel ist unvorhersagbar wenn 3+ Mods
  dieselbe ID überschreiben.
  → **Mitigation:** Last-Wins-Regel + Override-Liste sichtbar in
  ContentLoader.overrides_applied(). Save-Manifest hält Stand fest.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/mod_loader.gd`               Autoload, Manifest-Parser, Discovery
- `core/content_loader.gd`           neue Methode `discover_mods(ids)`
- `tests/unit/test_mod_loader.gd`    gut-Tests
- `tests/fixtures/mods/example_mod/` Test-Mod mit mod.json + Override-Mutation
- `docs/MODDING.md`                  Mod-Author-Anleitung
- `project.godot`                    ModLoader als 4. Autoload
- `.claude/agents/memory/mod-api-curator/public-api-surface.md`
                                     vollständige API-Doku

## 6. Folge-Entscheidungen (Backlog)

- ADR 0009 — Dependency-Topo-Sort + Cycle-Detection
- ADR 0010 — Mod-UI (Liste, Aktivieren/Deaktivieren, Reihenfolge ändern)
- ADR 0011 — Workshop-Integration (Steam) — wenn der Game-Loop steht
