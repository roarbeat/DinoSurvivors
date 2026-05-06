# art/pickups/

> Pickup-Sprites: Coins, Bernstein-Crystals, evtl. Health-Packs.

## Spec

- **Frame-Größe**: 8×8 bis 12×12 Pixel
- **Float-Animation**: 1-2 Pixel auf/ab pro 60 Frames (subtile Idle)
- **Pivot**: unten zentriert

## Erwartete Files

| File | Inhalt |
|------|--------|
| `coin.tscn` | Gold-Münze (4-Frame Spin) |
| `amber_crystal.tscn` | Bernstein-Currency-Pickup (für ADR 0030 — Meta-Progression) |

## World-Item-Spawn

Currency-Pickups als World-Items kommen mit eigenem ADR (heute zahlt
Boss-Defeat direkt in MetaProgression aus, kein Pickup-Schritt).
