# ADR 0042 – Raptor-Composite-Visual

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist + content-author (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0027 (Visual-Provider), ADR 0031 (Palette)
- Wird vorausgesetzt von: ADR — AnimatedSprite2D-Migration

---

## 1. Kontext

`DinoDef.visual_scene` ist seit ADR 0027 ein Slot für eine eigene Sprite/
Composite-Scene. Bisher leer → Player rendert als gelber 24×24-ColorRect.

Die Mood-Reference zeigt einen **grünen Velociraptor**: schmal,
beidbeinig, langer Schwanz, leicht aggressive Pose.

Anforderungen v1:

- **Polygon2D-Composite-Scene** als Annäherung an die Raptor-Silhouette
  (kein echtes Sprite, aber besser als Quadrat)
- **Default `visual_scene`** für `trex.tres` referenziert die Composite
- **Backward-Kompat**: ColorRect-Mode bleibt Fallback wenn
  `visual_scene = null`
- **Modder können eigenes Composite** bauen (PackedScene-Reference im .tres)

Bewusst NICHT in v1:

- **AnimatedSprite2D mit echten Frames** (kommt mit Asset-Drop)
- **Walk/Hit/Death-Animations** (eigenes ADR — AnimatedSprite2D-State-
  Machine)
- **Direction-Flip** (Player schaut links/rechts) — eigenes ADR
- **Sprite-Tinting** für Phasen — eigenes ADR

## 2. Empfehlung

`art/player/raptor_composite.tscn` als Polygon2D-Composite:

```
Raptor (Node2D)  ← Pivot bei (0, 0) = Fuß-Punkt
├── Tail (Polygon2D)        long thin curve, dark green
├── Body (Polygon2D)         oval, mid green
├── Head (Polygon2D)         small ellipse, mid green
├── BackLegFront (Polygon2D) dark green
├── BackLegBack (Polygon2D)  dark green (slightly offset)
└── EyeMarker (Polygon2D)    tiny black/white dot
```

Polygone werden mit `Palette.PLAYER_BODY` (mid green) und
`Palette.PLAYER_ACCENT` (dark green) gefärbt. Die Konturen sind grob
silhouettiert — keine pixel-genaue Sprite-Ablösung, aber die Raptor-
Silhouette ist erkennbar.

`trex.tres`:

```
visual_scene = preload("res://art/player/raptor_composite.tscn")
visual_pivot_offset = Vector2(0, -4)  # HealthBar etwas anheben
```

## 3. Konsequenzen

**Positiv**
- **Raptor erkennbar** statt gelbes Quadrat — Mood-Reference deutlich näher
- **Asset-frei** — Polygon2D, kein PNG-Import nötig
- **Modder-Pattern**: zeigt wie ein Visual-Composite aussieht

**Negativ**
- **Statisch**: keine Animations, kein Flip, kein Hit-Reaction
- **Stilbruch zu Enemies** (die bleiben ColorRect-Mobs in v1) —
  akzeptabel, beim Asset-Drop wird alles auf echte Sprites migriert

**Risiken**
- **Risiko:** Visual-Provider-Tests nutzen `visual_stub.tscn` als
  Fixture. Wenn `trex.tres` jetzt eine `visual_scene` hat, könnten
  Tests durcheinander kommen die ein leeres `visual_scene` erwarten.
  → **Mitigation:** Tests checken explizit gegen die NEUE Default-
  visual_scene-Reference (die jetzt eben nicht mehr null ist).

## 4. Betroffene Dateien

Anzulegen:
- `art/player/raptor_composite.tscn`

Berührt:
- `content/dinos/trex.tres` — `visual_scene` auf Composite-Scene
- `tests/unit/test_visual_provider.gd` — Default-trex-Test anpassen
  (visual_scene ist jetzt nicht mehr null)
- `art/player/README.md` — Composite-Section ergänzen

## 5. Folge-Entscheidungen (Backlog)

- ADR — AnimatedSprite2D-State-Machine
- ADR — Direction-Flip bei Player-Movement
- ADR — Custom-Composites für Enemies + Boss
- ADR — Asset-Migration-Pass (PNG-Sprites einbauen)
