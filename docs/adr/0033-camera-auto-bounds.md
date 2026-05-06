# ADR 0033 – Camera-Auto-Bounds aus IsoWorld

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0031 (IsoWorld), ADR 0032 (RunCamera)
- Wird vorausgesetzt von: ADR — MapDef als Content-Resource

---

## 1. Kontext

ADR 0032 hat `RunCamera.set_bounds(min, max)` als manuelle API
eingeführt. In der Praxis kennt aber niemand die Bounds besser als
die `IsoWorld` selbst — sie weiß, wie groß ihr Tile-Grid ist und wo
der Plattform-Rand liegt.

Heute setzt RunScene **gar keine Bounds**, also kann die Camera dem
Player auch über die Map-Grenze hinaus folgen. Das macht den Spielern
visuell klar, dass das Spielfeld endet — das wollen wir aber nicht.

Anforderungen v1:

- **`IsoWorld.world_bounds() -> Rect2`** — liefert das Bounding-Rect
  des kompletten Iso-Grids in Welt-Koordinaten
- **`RunCamera.attach_to_world(iso_world: IsoWorld)`** — Helper, der
  `set_bounds()` aus dem World-Rect aufruft und die Verbindung als
  "lebendig" hält (re-evaluation wenn Grid sich ändert ist nicht in v1)
- **RunScene-Wiring**: nach `_ready` wird die Camera ans IsoWorld gebunden
- **Pure Function**: `world_bounds()` ist deterministisch berechenbar
  ohne Frame-Dispatch

Bewusst NICHT in v1:

- Live-Tracking bei dynamischer Grid-Size-Änderung (Camera passt sich
  automatisch an)
- Bounds-Padding (Camera darf den Rand zeigen, ein paar Pixel Headroom)
- Multiple-IsoWorlds (Sub-Maps, Procedural-Tile-Streaming)
- Bounds aus MapDef-Resource (kommt mit ADR 0036 — MapDef)

## 2. Empfehlung

**Pure-Function-API auf IsoWorld + Convenience-Helper auf RunCamera**.

```gdscript
# IsoWorld
func world_bounds() -> Rect2:
    if grid_size.x <= 0 or grid_size.y <= 0:
        return Rect2()
    var hw: float = TILE_SIZE.x * 0.5
    var hh: float = TILE_SIZE.y * 0.5
    var min_x: float = -float(grid_size.y - 1) * hw - hw
    var max_x: float =  float(grid_size.x - 1) * hw + hw
    var min_y: float = -hh
    var max_y: float =  float(grid_size.x + grid_size.y - 1) * hh + hh
    return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

# RunCamera
func attach_to_world(world: IsoWorld) -> void:
    if world == null:
        return
    var b := world.world_bounds()
    if b.size == Vector2.ZERO:
        return
    set_bounds(b.position, b.position + b.size)
```

Bounds-Berechnung-Logik:

- **min_x**: linkester Tile-Rand. Linkester Tile ist (0, grid.y-1) →
  `tile_to_iso((0, grid.y-1)).x = -(grid.y-1) * tw/2`. Plus Tile-Halbbreite
  (Diamond geht bis -tw/2 nach links).
- **max_x**: analog (grid.x-1, 0) → `(grid.x-1) * tw/2 + tw/2`.
- **min_y**: oberster Tile (0,0) hat `iso.y = 0`. Diamond geht bis `-th/2`
  nach oben.
- **max_y**: unterster Tile (grid.x-1, grid.y-1) → `iso.y = (grid.x+grid.y-2) * th/2`.
  Plus `th/2` für Diamond-Tiefe nach unten.

Pure Function — testbar gegen bekannte Werte für 8×8, 1×1, 0×0.

## 3. Konsequenzen

**Positiv**
- **Camera klemmt am Plattform-Rand**: visuell klar, wo das Spielfeld
  aufhört
- **Auto-Wiring**: RunScene muss keine Bounds-Konfiguration kennen
- **Modder-tauglich**: Custom-IsoWorld-Subklasse kann eigene `world_bounds()`
  überschreiben (z.B. für nicht-rechteckige Maps)

**Negativ**
- **Statisch**: bei dynamischer Grid-Size-Änderung muss
  `attach_to_world` neu gerufen werden. Akzeptabel — v1 hat kein
  dynamisches Resize.

**Risiken**
- **Risiko:** Camera-Viewport ist größer als die Plattform → Camera
  klemmt aber zeigt schwarzen Rand außerhalb.
  → **Mitigation:** Akzeptabel v1 — schwarzer Rand ist ehrlicher als
  über-die-Map-laufen. Bounds-Padding kommt mit eigenem ADR.

## 4. Betroffene Dateien

Berührt:
- `core/world/iso_world.gd` — `+ world_bounds() -> Rect2`
- `core/world/run_camera.gd` — `+ attach_to_world(world: IsoWorld)`
- `core/run_scene/run.gd` — `_ready` ruft
  `run_camera.attach_to_world($WorldLayer/IsoWorld)`
- `tests/unit/test_iso_world.gd` — `+ world_bounds`-Tests
- `tests/unit/test_run_camera.gd` — `+ attach_to_world`-Test

## 5. Folge-Entscheidungen (Backlog)

- ADR — Bounds-Padding (Camera darf den Rand mit Margin zeigen)
- ADR — Multi-IsoWorld + Procedural-Streaming
- ADR — Dynamisches Map-Resize (Welle 20+: Map wird kleiner)
