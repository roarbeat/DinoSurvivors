# ADR 0037 – Camera-Bounds-Padding

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0032 (RunCamera), ADR 0033 (Auto-Bounds), ADR 0036 (MapDef)
- Wird vorausgesetzt von: ADR — Mutation-Pick-Phase Zoom-In

---

## 1. Kontext

ADR 0033 (`attach_to_world`) setzt die Camera-Bounds **exakt** auf das
Plattform-Rect aus `IsoWorld.world_bounds()`. Bei der visuellen Mood-
Reference (`docs/art/VISUAL-TARGET.md`) ist die Plattform aber von
**Charcoal-Background umgeben** — die Camera sollte den dunklen
Hintergrund am Rand zeigen können, statt strikt am Plattform-Rand zu
clampen.

Anforderungen v1:

- **`bounds_padding: Vector2`** auf RunCamera (Default `Vector2.ZERO`).
  Padding ERWEITERT die Bounds nach außen → Camera kann Breathing-Room
  außerhalb der Plattform zeigen.
- **`MapDef.camera_padding: Vector2`** als data-driven Slot.
  RunScene hängt Camera über `attach_to_world(world, padding)` an.
- **Backward-Kompat**: ohne Padding bleibt Verhalten wie ADR 0033.
- **Pure-Function-Helper** für Padding-Math testbar.

Bewusst NICHT in v1:

- **Per-Edge-Padding** (left/right/top/bottom unterschiedlich) — wenn
  nötig, ADR-Erweiterung mit Vector4
- **Negative Padding** (Bounds einwärts schrumpfen) — kommt mit
  Camera-Center-Lock-ADR
- **Dynamic Padding** während Run (Boss-Phase ändert Padding)

## 2. Empfehlung

```gdscript
# RunCamera-Erweiterung
@export var bounds_padding: Vector2 = Vector2.ZERO

func set_bounds_padding(p: Vector2) -> void:
    bounds_padding = p
    # Re-evaluate Bounds wenn enable_limits gerade an ist
    if enable_limits and _last_world_bounds.size != Vector2.ZERO:
        _apply_bounds_with_padding(_last_world_bounds, p)

func attach_to_world(world: IsoWorld, padding: Vector2 = Vector2.ZERO) -> void:
    if world == null: return
    var b: Rect2 = world.world_bounds()
    if b.size == Vector2.ZERO: return
    if padding != Vector2.ZERO:
        bounds_padding = padding
    _last_world_bounds = b
    _apply_bounds_with_padding(b, bounds_padding)

func _apply_bounds_with_padding(world_rect: Rect2, padding: Vector2) -> void:
    var min_pos := world_rect.position - padding
    var max_pos := world_rect.position + world_rect.size + padding
    set_bounds(min_pos, max_pos)
```

```gdscript
# MapDef-Erweiterung
@export var camera_padding: Vector2 = Vector2.ZERO
```

```gdscript
# RunScene-Wiring
if iso_world != null and run_camera != null:
    var pad := Vector2.ZERO
    if iso_world.get_map_def() != null:
        pad = iso_world.get_map_def().camera_padding
    run_camera.attach_to_world(iso_world, pad)
```

### Pure-Function-Helper

```gdscript
static func compute_padded_bounds(
    world_rect: Rect2, padding: Vector2
) -> Rect2:
    var pos := world_rect.position - padding
    var size := world_rect.size + padding * 2.0
    return Rect2(pos, size)
```

Test-Hook: testbar gegen bekannte Inputs.

## 3. Konsequenzen

**Positiv**
- **Visueller Breathing-Room** am Map-Rand — Camera zeigt charcoal-
  Background außerhalb der Plattform
- **Modder-tauglich**: Custom-Maps können eigenes Padding pro Map
  konfigurieren
- **Backward-Kompat**: Default `Vector2.ZERO` → ADR 0033-Verhalten
  unverändert

**Negativ**
- **Akkumulationsfalle**: `set_bounds_padding(p1)` + `set_bounds_padding(p2)`
  überschreibt p1 (kein additives Stacking). Akzeptabel — ist die
  intuitive Semantik.

**Risiken**
- **Risiko:** Großes Padding + kleine Map → Camera kann "ins Nichts"
  laufen, alle Mobs außer Sicht.
  → **Mitigation:** Akzeptiert v1. Modder wählen Padding bewusst.
  Zukünftige ADR könnte Padding gegen Camera-Viewport clamp'n.

## 4. Betroffene Dateien

Berührt:
- `core/world/run_camera.gd` — `+ bounds_padding`, `+ set_bounds_padding`,
  `attach_to_world(world, padding)`-Overload, `_apply_bounds_with_padding`,
  `compute_padded_bounds` (static pure)
- `core/content/map_def.gd` — `+ camera_padding: Vector2`
- `core/run_scene/run.gd` — passes MapDef.camera_padding bei attach
- `tests/unit/test_run_camera.gd` — Padding-Tests
- `tests/unit/test_map_def.gd` — camera_padding-Default-Test

## 5. Folge-Entscheidungen (Backlog)

- ADR — Per-Edge-Padding (Vector4: left/top/right/bottom)
- ADR — Negative-Padding / Camera-Center-Lock (für sehr kleine Maps)
- ADR — Dynamic-Padding während Run (Boss-Phase ändert Padding)
- ADR — Auto-Padding aus Camera-Viewport-Größe
