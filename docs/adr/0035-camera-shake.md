# ADR 0035 – Camera-Shake (Trauma-System)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist + godot-implementer (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0001 (EventBus), ADR 0032 (RunCamera)
- Wird vorausgesetzt von: ADR — Mutation-Pick-Phase Zoom-In, ADR — Boss-Intro-Camera-Pan

---

## 1. Kontext

Game-Feel ist ohne Camera-Shake nicht komplett. Wenn Spieler getroffen
wird oder ein Boss stirbt, soll die Kamera kurz erschüttern — das
verstärkt den Impact ohne die Spiel-Mechanik zu ändern.

Anforderungen v1:

- **Trauma-Wert** (0.0 – 1.0) als interner Camera-State
- **Exponentielles Decay** (jedes Frame: trauma *= decay_factor)
- **Shake-Offset = trauma² × max_offset × noise** (Goodwin-Pattern,
  Squared für sanften Anstieg, Quadratic für hohe Werte)
- **EventBus-Driven**: `player_damaged` und `boss_defeated` triggern
  `add_trauma()` automatisch
- **Frame-Rate-Independent**: Decay pro Sekunde, nicht pro Frame
- **Pure Function** für Trauma-Decay testbar ohne Frame-Dispatch

Bewusst NICHT in v1:

- **Trauma-Quellen pro Damage-Amount skaliert** (heutigen player_damaged
  liefert immer 0.3 Trauma — eigenes ADR für Damage-proportional)
- **Rotation-Shake** (Camera kippt minimal — eigenes ADR)
- **Zoom-Shake** (Zoom flackert leicht — eigenes ADR)
- **Cooldown** (mehrere Treffer in 100ms summieren sich addibtiv —
  Risk-of-Overshoot akzeptiert in v1)
- **Custom-Shake-Profiles** pro Event-Type (Boss-Death-Shake anders
  als Player-Hit-Shake — eigenes ADR)

## 2. Empfehlung

**Trauma-System à la Squirrel Eiserloh ("Math for Game Programmers:
Juicing Your Cameras With Math")**.

```gdscript
# RunCamera-Erweiterung
@export var max_shake_offset: float = 8.0   # Pixel
@export var trauma_decay_per_second: float = 1.5
@export var trauma_on_player_damaged: float = 0.3
@export var trauma_on_boss_defeated: float = 0.7

var _trauma: float = 0.0  # 0.0 – 1.0

func add_trauma(amount: float) -> void:
    _trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta) -> void:
    # ... existing follow-logic ...
    # Trauma-Decay
    if _trauma > 0.0:
        _trauma = max(0.0, _trauma - trauma_decay_per_second * delta)
    # Shake-Offset
    offset = _compute_shake_offset(_trauma, max_shake_offset, _shake_rng)

# Pure Function (Test-Hook)
static func compute_shake_offset(
    trauma: float, max_offset: float, rng: RandomNumberGenerator
) -> Vector2:
    var t2 := trauma * trauma
    var dx := (rng.randf() * 2.0 - 1.0) * max_offset * t2
    var dy := (rng.randf() * 2.0 - 1.0) * max_offset * t2
    return Vector2(dx, dy)
```

**Decay-Formel**

Linear pro Zeit, nicht pro Frame:
```
trauma_new = max(0, trauma - decay_per_second * delta)
```

Bei `decay_per_second = 1.5` und Trauma=1.0 dauert es ~0.67s bis 0.
Konfigurierbar per @export.

**Shake-Offset auf `Camera2D.offset`**

`Camera2D.offset` ist eine Sub-Pixel-Verschiebung, die NICHT die
`global_position` ändert. Smooth-Lerp + Bounds-Clamping wirken
weiterhin auf `global_position`, der Shake addiert sich oben drauf.

**EventBus-Subscriptions** (im RunCamera._ready)

```gdscript
EventBus.player_damaged.connect(_on_player_damaged)
EventBus.boss_defeated.connect(_on_boss_defeated)

func _on_player_damaged(_amount, _source_id):
    add_trauma(trauma_on_player_damaged)

func _on_boss_defeated(_boss_id, _run_time):
    add_trauma(trauma_on_boss_defeated)
```

## 3. Konsequenzen

**Positiv**
- **Game-Feel-Boost**: Treffer fühlen sich wuchtig an, Boss-Kill
  bekommt das verdiente Tremor-Finale
- **Modder-tauglich**: Custom-Trauma-Quellen via `cam.add_trauma(0.5)`
- **Frame-Rate-Independent**: Decay pro Sekunde

**Negativ**
- **Akkumulations-Risiko**: 5 Treffer in 200ms → trauma=1.5 → clamp
  auf 1.0. Akzeptabel, aber Spieler kann Camera nicht durch viele
  kleine Hits zerschütteln (richtig so).

**Risiken**
- **Risiko:** Shake-Offset zerstört Pixel-Snap-Crispness.
  → **Mitigation:** Shake-Offset ist getrennt von `global_position`
  und wird absichtlich NICHT pixel-snapped (sonst wirkt das
  Wackeln zu hart bei kleinen Trauma-Werten).

- **Risiko:** Tests, die `EventBus.player_damaged.emit()` während
  des Test-Setups feuern, lösen Camera-Shake aus → unerwartete
  Camera-Position.
  → **Mitigation:** RunCamera hat `set_muted(true)` analog SfxBus —
  Tests können das nutzen.

## 4. Betroffene Dateien

Berührt:
- `core/world/run_camera.gd` — Trauma-State, EventBus-Hooks,
  shake-offset-Update
- `tests/unit/test_run_camera.gd` — Trauma-Decay-Tests, Shake-Offset-Tests

## 5. Folge-Entscheidungen (Backlog)

- ADR — Damage-proportional Trauma (kleiner Hit = wenig Shake, kritischer
  Hit = viel)
- ADR — Rotation-Shake (Camera kippt minimal)
- ADR — Custom-Shake-Profiles pro Event-Type
- ADR — Cooldown gegen Akkumulation
