# art/player/

> Player-Dino-Sprites + AnimatedSprite2D-Scenes (ADR 0031).

## Spec

- **Frame-Größe**: 32×32 Pixel pro Animation-Frame
- **Pivot**: unten zentriert (Fuß-Punkt der Figur)
- **Animation-Strips**: horizontal aneinandergereiht (z.B. 4 Frames =
  128×32 PNG)
- **Filename**: `<dino_id>_<state>.png`

## Erwartete Files (pro Dino)

| File | Frames | Notes |
|------|--------|-------|
| `<id>_idle.png` | 4 | Atmen / Schwanz wedeln |
| `<id>_walk.png` | 6 | Walk-Loop |
| `<id>_hit.png` | 2 | Hit-React |
| `<id>_death.png` | 4 | Death-Pop |
| `<id>.tscn` | — | AnimatedSprite2D-Scene mit SpriteFrames-Resource |

## Integration

Die `<id>.tscn` wird in `content/dinos/<id>.tres` auf
`visual_scene` referenziert (ADR 0027 — Visual-Provider).

## Erste Charakter-Lieferung

`raptor.tscn` für `trex.tres` (oder ein eigener `velociraptor.tres`).
Sieht aus wie das Mood-Image: kleiner grüner Raptor, beidbeinig,
Schwanz hinten, leicht aggressive Pose.
