# ADR 0036 – MapDef als Content-Resource

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), content-author + godot-implementer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #6 Stable Content-IDs, #7 testbar
- Voraussetzungen: ADR 0003 (ContentLoader), ADR 0031 (IsoWorld)
- Wird vorausgesetzt von: ADR — Procedural-Map-Generation, ADR — Multi-Biome-Support

---

## 1. Kontext

`IsoWorld` hat seit ADR 0031 hardcoded Konfiguration:
`grid_size = (8, 8)`, `path_row = 4`, `path_col = 4`. Das ist
funktional, aber:

- **Designer können Map-Größe nicht ohne Code-Änderung anpassen**
- **Modder können keine eigenen Maps definieren** — der Modding-Pakt
  deckt Mutation/Enemy/Boss/Dino/Wave/Sound ab, aber nicht Maps
- **Mehrere Levels/Biome später**: Wenn das Spiel 5 Maps haben soll
  (Wald, Wüste, Sumpf, Eis, Vulkan), wäre 5× Code-Branching unhaltbar

Anforderungen v1:

- Neuer Content-Type `map` parallel zu `mutation`/`enemy`/`boss`/`dino`/
  `wave`/`sound`
- **MapDef-Schema** deckt: grid_size, path_row, path_col, deterministic_colors
- **IsoWorld liest aus MapDef** über `set_map_def(def)`
- **Default-Map** als `content/maps/default.tres` mit den heutigen
  hardcoded-Werten (Backward-Kompat — ohne MapDef bleibt das Verhalten
  wie vorher)
- **Backward-Kompat**: ohne MapDef-Resource fällt IsoWorld auf seine
  hardcoded @export-Defaults zurück

Bewusst NICHT in v1:

- **Procedural-Tile-Layouts** (Random-Tile-Variation per Map)
- **Biome-spezifische Color-Palettes** (Wald grün, Wüste sandbraun)
- **Multi-Path-Pattern** (Y-förmig, Spirale, custom-Mask)
- **Spawn-Points pro Map** (Player-Start, Enemy-Spawn-Areas)
- **Map-Layer/Decoration-Layout** (Bäume an bestimmten Tile-Positionen)
- **Map-Selection-UI** (in v1: hardcoded `default`-Map beim Boot)

## 2. Empfehlung

```gdscript
class_name MapDef extends ContentItem

## Grid-Größe in Tiles.
@export var grid_size: Vector2i = Vector2i(8, 8)

## Cross-Pfad: horizontale Pfad-Reihe. -1 = kein Pfad.
@export var path_row: int = 4

## Cross-Pfad: vertikale Pfad-Spalte. -1 = kein Pfad.
@export var path_col: int = 4

## Deterministische Tile-Color-Variation (Hash-basiert).
@export var deterministic_colors: bool = true

## Optionaler i18n-Key für Map-Banner ("Wald-Lichtung").
@export var biome_label_key: StringName = &""


func validate() -> String:
    var base := super.validate()
    if base != "":
        return base
    if grid_size.x < 0 or grid_size.y < 0:
        return "grid_size darf nicht negativ sein"
    return ""
```

### IsoWorld-Erweiterung

```gdscript
# core/world/iso_world.gd

func set_map_def(def: MapDef) -> void:
    if def == null:
        return
    grid_size = def.grid_size
    path_row = def.path_row
    path_col = def.path_col
    deterministic_colors = def.deterministic_colors
    _build_tiles()  # rebuild mit neuer Konfig

func get_map_def() -> MapDef:
    return _map_def
```

### RunScene-Integration

```gdscript
# core/run_scene/run.gd
@export var map_id: StringName = &"default"

func _ready():
    # ... existing logic ...
    if iso_world != null:
        var map_def := ContentLoader.get_or_null(&"map", map_id) as MapDef
        if map_def != null:
            iso_world.set_map_def(map_def)
```

### ContentLoader-Eintrag

```gdscript
&"map": {
    "dir": "maps",
    "script_path": "res://core/content/map_def.gd",
},
```

### Initial-Content

`content/maps/default.tres` repliziert die heutigen Werte 1:1
(8×8 Grid, Cross-Pfad bei (4,4), deterministic_colors=true). Migration
ist mechanisch — beim ersten Boot wird die Map geladen, das Verhalten
bleibt identisch.

## 3. Konsequenzen

**Positiv**
- **Designer ändern Map-Layout ohne Code-Touch**: grid_size in der
  .tres editieren → Re-Import → neue Welt
- **Modder bekommen `map` als Mod-Override-Surface** — analog zu
  `wave`/`enemy`/`boss`
- **Foundation für Multi-Biome**: später `forest`, `desert`, `swamp`-
  Maps mit eigenem Look

**Negativ**
- **3 zusätzliche Code-Pfade in IsoWorld** (set_map_def + Resolver
  für Path-Logik). Akzeptabel.

**Risiken**
- **Risiko:** MapDef.grid_size != IsoWorld._build_tiles() vorhandener
  Tiles → Memory-Leak bei Map-Wechsel.
  → **Mitigation:** `set_map_def` ruft `_build_tiles()` auf, das
  alte Tiles via `queue_free` entfernt (idempotent).

- **Risiko:** Modder definiert Map mit grid_size=(1000, 1000) → 1M Tiles
  → Crash.
  → **Mitigation v1**: kein Hard-Limit. Wenn Mod-Konflikte landen, ADR
  für Map-Limits.

## 4. Betroffene Dateien

Anzulegen:
- `core/content/map_def.gd`
- `content/maps/default.tres`
- `tests/unit/test_map_def.gd`

Berührt:
- `core/content_loader.gd` — TYPE_CONFIG +`map`
- `core/world/iso_world.gd` — `+ set_map_def`, `+ get_map_def`
- `core/run_scene/run.gd` — `+ @export var map_id`, lädt MapDef
- `tests/unit/test_iso_world.gd` — set_map_def-Tests
- `tests/unit/test_content_loader.gd` — map-Type-Check
- `BALANCE.csv` — `map`-Eintrag
- `locale/{de,en}.po` — `map.default.*`-Keys
- `docs/CONTENT.md` — `map`-Type-Beschreibung
- `agents/memory/mod-api-curator/public-api-surface.md`

## 5. Folge-Entscheidungen (Backlog)

- ADR — Multi-Biome (Wald/Wüste/Sumpf/Eis/Vulkan mit eigenen Palettes)
- ADR — Procedural-Map-Generation (Per-Run-Random-Layout)
- ADR — Map-Selection-UI (Run-Start: Player wählt aus N Maps)
- ADR — Spawn-Points pro Map (Player-Start, Enemy-Spawn-Areas)
- ADR — Map-Decoration-Layout (Bäume/Felsen an bestimmten Tile-Positionen)
