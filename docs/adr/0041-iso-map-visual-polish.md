# ADR 0041 – Iso-Map-Visual-Polish

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist + content-author (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0031 (IsoWorld), ADR 0036 (MapDef), ADR 0034 (Y-Sort)
- Wird vorausgesetzt von: ADR — TileSet-Authoring (echte Sprite-Tiles)

---

## 1. Kontext

Die `IsoWorld` aus ADR 0031 zeigt nur die Top-Diamonds der Tiles. Die
Mood-Reference (`docs/art/VISUAL-TARGET.md`) zeigt aber:

- **Erhabene Plattform** mit sichtbaren **Dirt-Side-Faces** (untere/
  rechte Reihe der Tiles offenbart die Erd-Schichten drunter)
- **Decorations**: Blumen-Cluster (rot/gelb/lila), Grass-Tufts, Crystal-
  Spikes
- **Charcoal-Background** außerhalb der Plattform (`#3a3d40`)

Heute fehlt das alles — Mobs laufen auf einem flachen Tile-Mesh ohne
3D-Tiefe, ohne visuelle Variation, mit dem Godot-Default-Background.

Anforderungen v1:

- **Dirt-Side-Polygon2D** an der unteren UND rechten Plattform-Kante
  (Sichtbarkeit folgt Iso-Konvention)
- **Programmatische Decorations** (Blumen + Crystals) als Polygon2D-
  Sprites, deterministisch verteilt auf Grass-Tiles (nicht auf
  Path-Tiles)
- **Background-ColorRect** auf BG_CHARCOAL als Run-Scene-Child
  (außerhalb IsoWorld, damit es die ganze Camera füllt)
- **Decoration-Density konfigurierbar** via @export
- **Backward-Kompat**: existierende IsoWorld-Tests bleiben grün
  (Decorations sind additiv unter `Tiles`-Sibling-Container)

Bewusst NICHT in v1:

- **Echte Sprite-Tiles** (kommt mit Asset-Drop-Pass)
- **Animated Decorations** (Float-Bobbing, Sway-Wind)
- **Decor-Layout aus MapDef** (Decorations werden zentral im IsoWorld
  generiert; per-Map-Override = eigenes ADR)
- **Z-Sort der Decorations** (wir nutzen y_sort_origin auf dem
  Container-Level)

## 2. Empfehlung

### Side-Faces

Pro Tile in der **unteren oder rechten Edge-Reihe** wird ein zusätz-
liches Polygon2D als "Dirt-Side" angelegt. Das Polygon hängt unter dem
Diamond und reicht in die Tiefe (~16-24 Pixel). Farbe: Gradient zwischen
DIRT_SIDE_TOP und DIRT_SIDE_BOTTOM via zwei Polygon-Shapes.

```
Tile-Diamond (Polygon2D, Pivot oben zentriert)
└── Dirt-Side (Polygon2D drunter, Trapez-Form, nur an Edge-Tiles sichtbar)
```

**Erkennung Edge-Tiles**:
- Untere Edge: `tile.x == grid_size.x - 1` ODER `tile.y == grid_size.y - 1`
  (Rand des Iso-Diamonds nach Süden, Süd-Osten oder Süd-Westen)
- Spezifisch fürs Iso: nur Tiles mit `tile.y == grid_size.y - 1` ODER
  `tile.x == grid_size.x - 1` zeigen Side-Face nach unten/rechts

In v1: einfach für jeden Tile in der **letzten Reihe** (y=ymax-1) und
**letzten Spalte** (x=xmax-1) eine Side-Face ergänzen.

### Decorations

```gdscript
# core/world/iso_world.gd
@export var decoration_density: float = 0.20  # Anteil grass-Tiles mit Decor

func _build_decorations() -> void:
    if decoration_density <= 0.0: return
    var rng := RandomNumberGenerator.new()
    rng.seed = grid_size.x * 73 + grid_size.y * 191  # deterministisch
    for y in grid_size.y:
        for x in grid_size.x:
            var tile := Vector2i(x, y)
            if is_path_tile(tile): continue
            if rng.randf() > decoration_density: continue
            var decor := _make_random_decor(rng, tile)
            decorations_root.add_child(decor)
```

Decor-Typen (in v1):
- **Blume rot** (FLOWER_RED)
- **Blume gelb** (FLOWER_YELLOW)
- **Blume lila** (FLOWER_LILA)
- **Crystal grün** (CRYSTAL_GREEN, etwas größer + 4-eckiges Polygon)

Jede Decor ist ein kleines Polygon2D (3-5 Pixel Durchmesser).

### Background-Color

`RunScene` bekommt einen `Background`-ColorRect als FIRST-Child
unter `WorldLayer` (z_index sehr negativ), der die ganze Viewport
mit `BG_CHARCOAL` füllt.

```gdscript
# Im run.tscn:
WorldLayer (Node2D, z_index=-10)
├── Background (ColorRect, full-rect, color = Palette.BG_CHARCOAL)
├── IsoWorld
```

ColorRect anchor 0,0 → 1,1 mit fixed offsets sodass es das ganze
Viewport füllt.

## 3. Konsequenzen

**Positiv**
- **Mood-Reference-Approximation**: Spiel sieht erstmals nach
  isometrischer Plattform aus — nicht mehr flacher Tile-Mesh
- **Asset-frei**: alles via Polygon2D, kein Sprite-Drop nötig
- **Deterministisch**: Decor-Layout ist stable über Sessions (Tests
  + visuelle Reproducibility)

**Negativ**
- **Keine Animations**: Blumen wedeln nicht, Crystals glitzern nicht.
  Akzeptabel v1, eigenes ADR für Animations.

**Risiken**
- **Risiko:** Y-Sort der Decorations kollidiert mit Mob-Y-Sort.
  → **Mitigation**: Decorations leben im IsoWorld unter `WorldLayer`
    (z_index=-10), Mobs leben unter `EnemyContainer/PlayerSlot`
    (z_index=0). Decorations sind also immer hinter den Mobs.

## 4. Betroffene Dateien

Berührt:
- `core/world/iso_world.gd` — `_build_sides`, `_build_decorations`,
  `decoration_density`, `_make_random_decor`
- `core/run_scene/run.tscn` — `Background`-ColorRect-Child
- `tests/unit/test_iso_world.gd` — Decoration-Tests, Side-Face-Tests
- `docs/ARCHITECTURE.md` — Visual-Polish-Block

## 5. Folge-Entscheidungen (Backlog)

- ADR — Decor-Animation (Bobbing, Sway)
- ADR — Decor-Layout aus MapDef (per-Map konfigurierbar)
- ADR — TileSet-Authoring mit echten Sprite-Tiles
- ADR — Side-Face-Variation (verschiedene Heights pro Map)
