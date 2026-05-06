# art/tiles/

> Iso-Tile-Sprites für die Welt-Map (ADR 0031).

## Spec

- **Größe**: 64×32 Pixel (2:1 Iso-Standard)
- **Pivot**: oben zentriert (Tile-Diamond mittig in den 64×32-Frame)
- **Format**: PNG mit transparenten Pixeln außerhalb der Diamond-Form
- **Farb-Range**: aus `core/art/palette.gd` (GRASS_LIGHT/MID/DARK,
  DIRT_PATH, GRASS_EDGE, DIRT_SIDE_TOP/BOTTOM)

## Erwartete Files

| File | Inhalt |
|------|--------|
| `grass_light.png` | Helle Grass-Variante (heller als Default-Mid) |
| `grass_mid.png` | Mittel-Grass (Default für die meisten Tiles) |
| `grass_dark.png` | Dunkler Grass (für Schatten/Tiefen-Variation) |
| `dirt_path_h.png` | Horizontaler Pfad (Ost-West) |
| `dirt_path_v.png` | Vertikaler Pfad (Nord-Süd) |
| `dirt_path_cross.png` | Kreuzung |
| `grass_edge_n.png` | Edge-Variante mit Dirt-Side an der Nord-Kante |
| `grass_edge_e.png` | Ost-Edge |
| `grass_edge_s.png` | Süd-Edge |
| `grass_edge_w.png` | West-Edge |

## Authoring-Hinweis

Aseprite-Template oder Pyxel-Edit-Datei mit dem korrekten 64×32-Iso-
Diamond-Outline ergänzt der Asset-Artist beim ersten echten Drop.
