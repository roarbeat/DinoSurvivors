# ADR 0031 – Art-Pipeline + Iso-Map-Konventionen

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist + content-author + godot-implementer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0024 (Visual-Diff Color), ADR 0027 (Visual-Provider)
- Wird vorausgesetzt von: ADR — AnimatedSprite2D-State-Machine, ADR — TileSet-Authoring-Workflow

---

## 1. Kontext

Die Mood-Reference (`docs/art/VISUAL-TARGET.md`) zeigt eine **isometrische
Pixel-Art-Welt**: erhabene Tile-Plattform mit Grass-Tiles oben,
Dirt-Sides, Cross-Pfad, Decorations (Blumen, Crystals, Coins), kleiner
grüner Raptor in der Mitte.

Heute hat das Spiel:

- ColorRect-Mobs auf einem leeren Background (kein Tile-Gefühl)
- Kein World-Layout (Player läuft im leeren Raum)
- Color-Konstanten verstreut in EnemyDef/BossDef/HealthBar (`Color(0.82, 0.18, 0.18)` etc.)
- Keine Folder-Struktur für künftige Sprites/Audio

Anforderungen v1:

- **Folder-Struktur unter `art/`** so klar, dass Asset-Artists wissen,
  wohin welcher Sprite gehört
- **Pro-Folder README** mit Sprite-Specs (Größe, Frames, Pivot)
- **Single-Source-of-Truth-Palette** in `core/art/palette.gd`, sodass
  ColorRect-Mode und künftige Sprite-Tints aus derselben Quelle kommen
- **Iso-Map-Skelett** als Background — auch ohne echte Sprites soll der
  Spieler sehen, dass er auf einer Tile-Map läuft
- **Programmatische Placeholder-Tiles** (Polygon2D-Iso-Quads), die später
  durch echte Sprite-Tiles ersetzt werden — gleicher Layout-Code, nur
  Texture-Swap
- **Backward-Kompat**: existierende Tests laufen weiter durch (RunScene
  bekommt WorldLayer als Child, ohne Mob-Layout zu brechen)

Bewusst NICHT in v1:

- Echte Sprite-Imports (passiert in v0.1.x als Asset-Drop-Pass)
- TileSet-Authoring-Workflow (eigenes ADR — wenn echte Tiles landen)
- AnimatedSprite2D-State-Machine (Idle/Walk/Hit/Death) — eigenes ADR
- Camera-System (Camera2D-Folge des Players, Boundaries) — eigenes ADR
- Y-Sort-Layering (Mobs vor/hinter Decorations je nach Y) — eigenes ADR
- Dynamische Map-Generation (Procedural-Tile-Placement)

## 2. Iso-Konvention

**Tile-Standard**: 64×32 Pixel pro Tile (2:1 Verhältnis Breite:Höhe),
das ist der Godot-Iso-Default und matcht das Mood-Image.

**Welt-zu-Iso-Transformation** (pure function):

```gdscript
# Welt-Koords (x, y in Tiles) → Bildschirm-Koords (px, iso-projiziert)
func world_to_iso(tile: Vector2i, tile_size: Vector2i = Vector2i(64, 32)) -> Vector2:
    var px := (tile.x - tile.y) * (tile_size.x * 0.5)
    var py := (tile.x + tile.y) * (tile_size.y * 0.5)
    return Vector2(px, py)

func iso_to_world(screen: Vector2, tile_size: Vector2i = Vector2i(64, 32)) -> Vector2i:
    var x := screen.x / (tile_size.x * 0.5)
    var y := screen.y / (tile_size.y * 0.5)
    return Vector2i(int(round((x + y) * 0.5)), int(round((y - x) * 0.5)))
```

Pure functions — testbar ohne Frame-Dispatch.

**Tile-Wurzel-Pivot**: Mitte unten (visueller "Fuß-Punkt" des Tiles).
Sprites haben ihren Pivot gleichermaßen unten zentriert.

## 3. Folder-Struktur

```
art/
├── README.md                         # High-Level-Konventionen (siehe VISUAL-TARGET.md)
├── tiles/
│   ├── README.md                     # 64×32 px, oben zentriert
│   ├── grass_light.png               (TBD — von Asset-Artist)
│   ├── grass_mid.png
│   ├── grass_dark.png
│   ├── dirt_path_h.png
│   ├── dirt_path_v.png
│   ├── dirt_path_cross.png
│   └── grass_edge_n/e/s/w.png
├── decor/
│   ├── README.md                     # eigenständige Sprites, nicht Tiles
│   ├── flower_red.png
│   ├── flower_yellow.png
│   ├── flower_lila.png
│   ├── grass_tuft.png
│   └── crystal_green.png
├── player/
│   ├── README.md                     # AnimatedSprite2D-Konvention
│   ├── raptor_idle.png               (4-frame strip, 32×32 pro Frame)
│   ├── raptor_walk.png               (6-frame)
│   ├── raptor_hit.png                (2-frame)
│   ├── raptor_death.png              (4-frame)
│   └── raptor.tscn                   AnimatedSprite2D-Scene mit SpriteFrames
├── enemies/
│   ├── README.md
│   ├── raptor_grunt.tscn             (jede Enemy-Variante als eigene Scene)
│   ├── pteranodon.tscn
│   ├── raptor_alpha.tscn
│   └── armored_carnotaurus.tscn
├── bosses/
│   ├── README.md
│   └── tyrannosaurus_prime.tscn
├── pickups/
│   ├── README.md
│   ├── coin.tscn                     (4-frame Spin)
│   └── amber_crystal.tscn            (Bernstein-Currency-Pickup)
├── ui/
│   ├── README.md                     # 9-Slice-Frames, Pixel-Font
│   ├── frame_default.png
│   └── pixel_font.tres               (Bitmap-Font-Resource)
└── audio/                            (eigene Subfolder pro Familie)
    ├── README.md
    ├── enemy_death.ogg
    ├── boss_defeated.ogg
    └── ...
```

Convention: Modder dürfen ihre Assets unter
`user://mods/<mod_id>/art/<subfolder>/` ablegen — gleiches Layout,
gleiche Specs.

## 4. Palette als Single-Source-of-Truth

```gdscript
# core/art/palette.gd
class_name Palette
extends RefCounted

const BG_CHARCOAL: Color = Color("#3a3d40")
const GRASS_LIGHT: Color = Color("#7ec850")
const GRASS_MID: Color   = Color("#5fa83a")
const GRASS_DARK: Color  = Color("#3e8528")
const GRASS_EDGE: Color  = Color("#2c5e1c")
const DIRT_PATH: Color   = Color("#a87455")
const DIRT_SIDE_TOP: Color = Color("#8a5a3a")
const DIRT_SIDE_BOTTOM: Color = Color("#5e3e28")
const PLAYER_BODY: Color = Color("#5fa83a")
const PLAYER_ACCENT: Color = Color("#2c5e1c")
const COIN_GOLD: Color = Color("#d6a64f")
const COIN_HIGHLIGHT: Color = Color("#f0c878")
const FLOWER_RED: Color = Color("#c84e44")
const FLOWER_YELLOW: Color = Color("#e8c84a")
const FLOWER_LILA: Color = Color("#a86ed4")
const CRYSTAL_GREEN: Color = Color("#3acf6e")
```

EnemyDef/BossDef/HUD nutzen diese Konstanten als Default-Farben (statt
hardcoded `Color(0.82, 0.18, 0.18)`). Mods können eigene Palettes
mitbringen, indem sie ihre .tres-Resourcen mit eigenen Farben
konfigurieren — die Palette ist nur der Default.

## 5. Iso-World-Skelett

`core/world/iso_world.gd` baut beim `_ready()` ein Grid von 8×8
Iso-Tiles via `Polygon2D`. Tile-Farbe rotiert über Grass-Light/Mid/Dark
für visuelle Variation. Cross-Pfad in Dirt-Color über die Mitte. Plus
Dirt-Side-Faces an den Tile-Rändern (untere Reihe + rechte Reihe sichtbar).

Wenn echte Sprite-Tiles landen, wird `IsoWorld` von Polygon2D auf
`TileMapLayer + TileSet` umgebaut — gleiches Layout, andere Render-
Quelle. Public-API (`tile_to_iso`, `iso_to_tile`, `world_size`) bleibt
stabil.

```gdscript
class_name IsoWorld
extends Node2D

const TILE_SIZE: Vector2i = Vector2i(64, 32)

@export var grid_size: Vector2i = Vector2i(8, 8)
@export var path_row: int = 4    # horizontal-Pfad
@export var path_col: int = 4    # vertikal-Pfad

func tile_to_iso(tile: Vector2i) -> Vector2  # pure
func iso_to_tile(screen: Vector2) -> Vector2i  # pure
func world_size() -> Vector2  # px-Bounds des kompletten Iso-Grids
```

## 6. RunScene-Integration

```gdscript
# core/run_scene/run.tscn — neuer Child:
WorldLayer (Node2D, Z-Index = -10)
└── IsoWorld
PlayerSlot (Node2D, Z-Index = 0)
EnemyContainer (Node2D, Z-Index = 0)
HUDLayer
GameOverLayer
MutationPickLayer
```

WorldLayer hat negativen Z-Index, sodass alle Mobs darüber rendern.
Y-Sort-Layering (Mobs vor/hinter Decorations) ist eigenes ADR — v1
nutzt einfaches Z-Index-Stacking.

**Background-Color**: ProjectSettings.rendering/environment/defaults/
default_clear_color = `Palette.BG_CHARCOAL`. Wird in RunScene nicht
gesetzt — bleibt Engine-Default-Setting (Modder können das überschreiben).

## 7. Konsequenzen

**Positiv**
- **Asset-Artist hat klare Drop-Locations**: jedes Sprite-File hat
  exakt einen Pfad, jedes README sagt was reingehört
- **Palette zentralisiert**: Color-Tweaks an EINER Stelle, alle Mobs
  übernehmen automatisch
- **Iso-Welt sichtbar in v0.1.1**: Spieler sieht sofort eine Plattform,
  auch ohne echte Sprite-Tiles (Polygon2D-Placeholder)
- **Modder können art-Override**: gleiche Folder-Struktur unter
  `user://mods/<mod>/art/`

**Negativ**
- **Polygon2D-Placeholder ist nicht hübsch**: bunte Quads ohne Texture.
  Akzeptabel für v0.1.1 — bei v0.1.x landen echte Sprites.
- **Tile-Layout hardcoded** (8×8 Grid, Cross-Pfad bei Mitte): später
  via WaveDef/MapDef konfigurierbar (eigenes ADR).

**Risiken**
- **Risiko:** Iso-Math ist falsch implementiert, Tiles sehen schief aus.
  → **Mitigation:** Pure-Function-Tests für `tile_to_iso` /
  `iso_to_tile` gegen bekannte Werte (z.B. (0,0) → (0,0), (1,0) →
  (32, 16), (0,1) → (-32, 16)).

- **Risiko:** Z-Index-Conflict mit HUD/GameOver-Overlays.
  → **Mitigation:** WorldLayer auf -10, Mobs auf 0, HUD/Overlay sind
  CanvasLayer (eigenes Coord-System) — kein Conflict.

## 8. Betroffene Dateien

Anzulegen:
- `core/art/palette.gd`
- `core/world/iso_world.gd`
- `core/world/iso_world.tscn`
- `art/README.md`
- `art/{tiles,decor,player,enemies,bosses,pickups,ui,audio}/README.md`
- `tests/unit/test_palette.gd`
- `tests/unit/test_iso_world.gd`

Berührt:
- `core/run_scene/run.tscn` — `+ WorldLayer/IsoWorld` als Child
- `core/run_scene/run.gd` — keine Code-Änderung (additiv im .tscn)
- `agents/memory/mod-api-curator/public-api-surface.md` — Palette + IsoWorld-Section
- `docs/ARCHITECTURE.md` — neuer Pattern-Block „Iso-World"
- `docs/CONTENT.md` — Asset-Drop-Section
- `agents/memory/godot-implementer/file-purpose-index.md`

## 9. Folge-Entscheidungen (Backlog)

- ADR — TileSet-Authoring-Workflow (wenn echte Tile-Sprites landen)
- ADR — AnimatedSprite2D-State-Machine (Idle/Walk/Hit/Death-Dispatch)
- ADR — Camera-System (Camera2D-Player-Follow, World-Boundaries)
- ADR — Y-Sort-Layering (Mobs vor/hinter Decorations je nach Y)
- ADR — MapDef als Content-Resource (Modder können Maps definieren)
- ADR — Procedural-Tile-Placement (Floor-Variation, Decor-Streuung)
