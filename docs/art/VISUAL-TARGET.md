# Visual Target — DinoRogue Art-Direction

> **North-Star für die Sprite-/Tile-/UI-Arbeit.** Vom User am 2026-05-06
> via Mood-Reference-Image vorgegeben. Diese Doku beschreibt die
> Ziel-Ästhetik in Worten — die echte Reference-Image liegt unter
> `docs/art/reference/visual-target.png` (vom User dort hinkopiert).

## Stil

- **Pixel-Art**, nicht hand-painted, nicht 3D-rendered
- **Isometrische Projektion** (Tile-basiert, 2:1 Verhältnis Höhe:Breite
  pro Tile in der Standard-Iso-Konvention)
- **Begrenzte Farbpalette** pro Asset — kein Anti-Aliasing
  (harte Pixelkanten), aber subtile Color-Variation für Tile-Texturen
- **Saturierte, klare Farben** — kein Foto-Realismus, kein Hyper-Stilisiert
- **Charcoal-Grey-Hintergrund** außerhalb der Spielfläche
  (~ #3a3d40, NICHT pure black)

## Spielfeld (Map)

- **Tile-Map mit erhabener Plattform**: Grass-Tiles oben, Erde/Dirt-Sides
  zeigen die Plattform-Tiefe (~3-4 Pixel-Reihen Erd-Layer sichtbar)
- **Grass-Tiles** in 2-3 Grünschattierungen für subtile Texture-Variation
  (heller-dunkler-mittlerer Grünton, randomisiert pro Tile)
- **Path/Road-System** als Dirt-Brown-Tiles, kreuzförmig durch die
  Map verlaufend (Cross-Pattern: vertikaler + horizontaler Dirt-Streifen)
- **Tile-Größe Referenz**: Map ist ca. 8×8 Tiles im Mood-Image,
  finales Spielfeld kann größer sein
- **Side-Faces der Plattform** in 2 Brauntönen (hell oben, dunkel unten)
  mit grünen Gras-Edge-Pixeln am Top-Rim

## Decorations (Map-Dressing)

- **Blumen** in kleinen 1-2-Pixel-Clustern (rot+gelb, gelb+gelb, lila+gelb)
- **Crystal/Emerald-Spikes** als grüne, leicht transparente Spitzen-Sprites
  (für Pickup-Hint oder Loot-Drop)
- **Flowers/Grass-Tufts** subtil verteilt — nicht zu dicht, sonst wirkt
  die Map unruhig

## Pickups

- **Coins** als gold-glänzende, achteckige Münzen mit subtle Highlight
  oben links (~6-8 Pixel Durchmesser)
- **Gem/Crystal** als länglicher hexagonaler Edelstein (gold im Mood-Image,
  könnte für Bernstein-Currency in unserem Spiel benutzt werden)
- Pickups schweben leicht über dem Boden (1-2 Pixel-Float-Animation)

## Player-Dino (Start-Dino)

- **Velociraptor-ähnlich**: schmal, beidbeinig, langer Schwanz
- **Grün** mit dunkleren Akzenten am Rücken/Kopf
- **Leicht aggressive Pose** (vorgebeugt, Arme nach vorne)
- **Sprite-Größe**: ca. 24-32 Pixel hoch in finaler Auflösung
  (im Mood-Image kleiner — Spielfigur darf auf ~1-1.5 Tile-Höhe wirken)
- **Animation-Bedarf**: Idle (atmen), Walk-Loop (4-6 Frames),
  Attack/Hit-React, Death-Pop

## UI-Direction (impliziert)

- **Movement-Indicator**: 4- oder 8-Richtungs-Arrows um den aktiven
  Dino, schwarz, dezent (Mood-Image zeigt 8 Richtungen)
- **Ähnliche Sprite-Sprache** für HUD-Elemente: Pixel-Font, kleine Frames,
  keine glossy Effekte
- **Damage-Numbers** weiterhin pixelig (nicht smooth-Tween) — passt zum Stil

## Color-Palette (vorläufig, basierend auf Mood-Image)

| Element | Farbton | Hex (geschätzt) |
|---------|---------|-----------------|
| Background | Charcoal | `#3a3d40` |
| Grass light | Hellgrün | `#7ec850` |
| Grass mid | Mittelgrün | `#5fa83a` |
| Grass dark | Dunkelgrün | `#3e8528` |
| Grass edge (tile-rim) | Dunkelgrün | `#2c5e1c` |
| Dirt path | Hellbraun | `#a87455` |
| Dirt side (top) | Mittelbraun | `#8a5a3a` |
| Dirt side (bottom) | Dunkelbraun | `#5e3e28` |
| Player-Dino body | Grün | `#5fa83a` (matcht Grass für Camo-Vibe) |
| Player-Dino accent | Dunkelgrün | `#2c5e1c` |
| Coin gold | Goldgelb | `#d6a64f` |
| Coin highlight | Hellgelb | `#f0c878` |
| Flower red | Korallenrot | `#c84e44` |
| Flower yellow | Sonnengelb | `#e8c84a` |
| Flower lila | Pastell-Lila | `#a86ed4` |
| Crystal green | Smaragdgrün | `#3acf6e` |

## Asset-Liste — Phase v0.0.10+

Wenn echte Sprite-Arbeit beginnt:

### Tile-Set
- `art/tiles/grass_light.png` (32×32 für non-iso, oder 64×32 iso)
- `art/tiles/grass_mid.png`
- `art/tiles/grass_dark.png`
- `art/tiles/dirt_path_h.png` (horizontaler Pfad)
- `art/tiles/dirt_path_v.png` (vertikaler Pfad)
- `art/tiles/dirt_path_cross.png` (Kreuzung)
- `art/tiles/grass_edge_n/e/s/w.png` (4 Edge-Varianten)

### Decorations (eigenständige Sprites, nicht Tiles)
- `art/decor/flower_red.png`
- `art/decor/flower_yellow.png`
- `art/decor/flower_lila.png`
- `art/decor/grass_tuft.png`
- `art/decor/crystal_green.png`

### Player-Dino (animated)
- `art/player/raptor_idle.png` (4-frame strip, 32×32 pro Frame)
- `art/player/raptor_walk.png` (6-frame strip)
- `art/player/raptor_hit.png` (2-frame React)
- `art/player/raptor_death.png` (4-frame Death-Pop)

→ AnimatedSprite2D-Scene `art/player/raptor.tscn` mit den Frames als
SpriteFrames-Resource. Diese Scene wird in `content/dinos/trex.tres`
auf `visual_scene` referenziert (ADR 0027 — Visual-Provider).

### Enemies (analog Pattern)
- `art/enemies/raptor_grunt.tscn` (kleinerer/anders gefärbter Raptor)
- `art/enemies/pteranodon.tscn` (Flieger, andere Silhouette)
- `art/enemies/raptor_alpha.tscn` (größer, dunkler)
- `art/enemies/armored_carnotaurus.tscn` (Tank-Silhouette)

### Boss
- `art/bosses/tyrannosaurus_prime.tscn` (deutlich größer, ~64×64,
  4-frame Idle, 6-frame Walk, eigenes Hit-React, Death-Pop)

### Pickups
- `art/pickups/coin.tscn` (4-frame Spin-Animation)
- `art/pickups/amber_crystal.tscn` (Bernstein für Meta-Currency,
  ADR 0030)

### UI
- Pixel-Font (z.B. m5x7 oder PixelOperator) für HUD/Damage-Numbers
- 9-Slice-Frames für MutationPickOverlay, GameOver-Overlay, HUD-Boxes

## Mod-Author-Hinweis

Modder können eigene Sprites einhängen, ohne sich an diese Style-Guide
halten zu müssen — aber Core-Content soll konsistent bleiben.
Style-Brüche zwischen Core und Mods sind akzeptabel (verschiedene
Universen können verschiedene Looks haben). Siehe ADR 0027 für die
data-driven `visual_scene`-Slot-Mechanik.

## Status

- **Phase v0.0.9** ist abgeschlossen — alle visuellen Elemente sind als
  ColorRect-Stub-Mode implementiert. Die Visual-Provider-Pipeline
  (ADR 0027) ist scharf, sobald ein .tres-File `visual_scene` referenziert,
  schaltet der Mob automatisch um.
- **Asset-Drop-Pass** kann jederzeit beginnen — kein Code-Touch nötig,
  nur Resource-Wiring.
- **Phase v0.1.0** wickelt das Spiel-Skelett (Persistenz, Boss-Phasen,
  Vertical-Slice-Polish) ab, ohne auf Assets zu warten.
