# ADR 0034 – Y-Sort-Layering

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist + godot-implementer (konsultiert)
- Betrifft Prinzipien: #7 testbar
- Voraussetzungen: ADR 0008 (PlayerCharacter), ADR 0009 (EnemyMob), ADR 0025 (BossMob), ADR 0031 (IsoWorld)
- Wird vorausgesetzt von: ADR — Decoration-Spawn-System, ADR — TileSet-Authoring

---

## 1. Kontext

Heute werden Mobs (Player, Enemy, Boss) durch ihre Reihenfolge im
Scene-Tree gerendert. In einer 2D-Top-Down-Welt geht das, in einer
**isometrischen Welt** (ADR 0031) führt das zu Render-Bugs:

- Player steht "vor" einem Enemy, der weiter unten in der Welt ist
  (höherer Y-Wert) — sieht aus, als ob der Enemy hinter ihm wäre,
  obwohl er näher zur Kamera ist
- Wenn Decorations dazukommen (Bäume, Gebäude), wird der Look komplett
  kaputt — Player rennt vor einem Baum durch, obwohl er hinter ihm
  sein müsste

Anforderungen v1:

- **Container-basiertes Y-Sorting**: PlayerSlot + EnemyContainer
  setzen `y_sort_enabled = true` als Node2D
- **Mobs setzen ihren Pivot korrekt** auf den Fuß-Punkt (Y-Bottom),
  sodass die Y-Sort-Kanten zwischen Sprites richtig liegen
- **WorldLayer bleibt unter den Mobs** durch z_index=-10 (unverändert)
- **HUD/Overlays sind CanvasLayer** und betroffen davon nicht

Bewusst NICHT in v1:

- **Decorations werden in v1 nicht Y-sortiert** mit den Mobs (Decorations
  sind innerhalb von IsoWorld und werden via z_index=-10 unten
  gerendert). Wenn Decorations über die Tile-Höhe hinausragen
  (Bäume), folgt eigenes ADR.
- **Custom Y-Sort-Origin per Mob-Type**: in v1 nutzen wir den
  Default-Pivot (Mob-Position). Spätere ADRs können eigene
  Y-Sort-Origins pro Mob konfigurieren.
- **Y-Sort-Performance**: bei 1000+ Mobs könnte das Sorting teuer
  werden. v1 hat 50-200 Mobs, akzeptabel.

## 2. Empfehlung

**PlayerSlot + EnemyContainer als Node2D mit `y_sort_enabled = true`**.

```
Run (Node2D)
├── WorldLayer (z_index=-10)        # Tile-Map untergrund
├── PlayerSlot (Node2D, y_sort)
├── EnemyContainer (Node2D, y_sort) # Mobs werden nach Y sortiert
├── RunCamera
└── HUDLayer (CanvasLayer)          # immer oben, unbeeinflusst
```

**Wichtig**: heute sind PlayerSlot + EnemyContainer als plain `Node`
typed (kein Node2D). Wir ändern sie zu `Node2D`, damit der Y-Sort-
Mechanismus greift.

```
PlayerSlot (Node)         → PlayerSlot (Node2D, y_sort_enabled=true)
EnemyContainer (Node)     → EnemyContainer (Node2D, y_sort_enabled=true)
```

Die @onready-Refs in run.gd sind als `Node` typed — das passt weiterhin
zu Node2D (Polymorphie).

**Mob-Pivot-Konvention**

EnemyMob, PlayerCharacter, BossMob sind bereits `Node2D` (bzw.
`CharacterBody2D` für Player). Ihre `global_position` ist die Mitte
des Sprite-Bodies. Für Y-Sorting müssen wir die `y_sort_origin`
auf den **Fuß-Punkt** setzen — Godot 4 macht das automatisch wenn
das Mob ein Sprite mit `region_rect` hat, oder via expliziten
`y_sort_origin` Property.

In v1 ist der Pivot der Mob-Mitte (Body-Center). Das ist nicht
optimal — Mob A hinter Mob B mit gleichem Y-Wert kann zufällig
über Mob B rendern. Akzeptabel v1 — sobald echte Sprites landen
und der Pivot auf Foot-Point sitzt, wird das automatisch korrekt.

## 3. Konsequenzen

**Positiv**
- **Korrekte Iso-Tiefe**: weiter unten in der Welt = vor dem Spieler
- **Skaliert auf Decorations**: wenn später Bäume/Gebäude landen,
  müssen sie nur auch im EnemyContainer (oder einem weiteren Y-Sort-
  Container) leben
- **Null Performance-Cost** bei 50-200 Mobs (Godot's Y-Sort ist O(n log n))

**Negativ**
- **Pivot-Konvention noch nicht final**: bei ColorRect-Mobs sitzt der
  Pivot in der Mitte — das gibt minimal-falschen Y-Sort bei Mobs auf
  gleicher Y-Höhe. Bei echten Sprites mit Foot-Point-Pivot wird's korrekt.

**Risiken**
- **Risiko:** Tests, die `add_child` auf PlayerSlot/EnemyContainer
  machen, brechen wenn der Type von `Node` auf `Node2D` wechselt.
  → **Mitigation:** `Node2D` ist Subklasse von `Node`, alle
  `Node`-APIs funktionieren weiter. Die Tests sollten durchlaufen.

- **Risiko:** Z-Index-Conflict zwischen Y-sortierten Mobs und
  WorldLayer (z_index=-10).
  → **Mitigation:** Y-Sort wirkt nur INNERHALB des Containers.
  Mobs bleiben über WorldLayer durch global z_index Default 0 vs.
  WorldLayer z_index=-10.

## 4. Betroffene Dateien

Berührt:
- `core/run_scene/run.tscn` — PlayerSlot/EnemyContainer auf
  `Node2D` mit `y_sort_enabled = true`
- `tests/unit/test_run_scene.gd` — Y-Sort-Verifikation
- `docs/ARCHITECTURE.md` — Y-Sort-Block

## 5. Folge-Entscheidungen (Backlog)

- ADR — Custom Y-Sort-Origin per Mob-Type (Sprites mit Foot-Point-Pivot)
- ADR — Decoration-Layer mit Y-Sort (Bäume, Gebäude)
- ADR — Y-Sort-Performance bei 1000+ Mobs (Quadtree, Spatial-Hash)
