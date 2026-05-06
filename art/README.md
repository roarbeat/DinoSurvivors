# art/ — Asset-Drop-Pfade

> Vom `shader-fx-specialist` und Asset-Artists genutzt. Pro-Subfolder-
> README spezifiziert, was rein gehört. Style-Guide-Source-of-Truth ist
> [`docs/art/VISUAL-TARGET.md`](../docs/art/VISUAL-TARGET.md).

## Convention

- **Pixel-Art**, isometrisch, harte Kanten, keine Anti-Aliasing
- **Tile-Standard**: 64×32 Pixel pro Tile (2:1 iso)
- **Sprite-Pivot**: unten zentriert (Fuß-Punkt der Figur)
- **Filename-Convention**: `<id>_<state>.png` (z.B. `raptor_idle.png`,
  `raptor_walk.png`)
- **Animation-Strips**: horizontal aneinandergereiht, Frame-Größe in
  README pro Subfolder dokumentiert

## Subfolder

| Folder | Inhalt |
|--------|--------|
| `tiles/` | Iso-Tiles für die Welt (Grass, Dirt-Path, Edges) |
| `decor/` | Eigenständige Decoration-Sprites (Blumen, Crystals, Tufts) |
| `player/` | Spielbare Dino-Sprites + AnimatedSprite2D-Scenes |
| `enemies/` | Enemy-Variants als Scenes (raptor_grunt, pteranodon, ...) |
| `bosses/` | Boss-Sprites + Scenes |
| `pickups/` | Coin, Bernstein-Crystal, Health-Pack-Sprites |
| `ui/` | Pixel-Font, 9-Slice-Frames, HUD-Icons |
| `audio/` | .ogg-Streams für SFX (von SoundDef.stream referenziert) |

## Mod-Convention

Modder dürfen ihre Assets unter `user://mods/<mod_id>/art/<subfolder>/`
ablegen — gleiches Layout, gleiche Specs. SoundDef-/EnemyDef-/etc.
.tres-Files referenzieren die Resource-Paths direkt.

## Status v0.1.1

Alle Subfolder existieren als Folder mit README — keine echten Sprites
sind eingehängt. Das Spiel läuft mit programmatischen Placeholder-
Tiles (Polygon2D in `core/world/iso_world.gd`) und ColorRect-Mobs
(ADR 0024). Sobald echte Sprites landen, werden sie über
`EnemyDef.visual_scene` / `DinoDef.visual_scene` / `SoundDef.stream`
referenziert (ADR 0027 / ADR 0028).
