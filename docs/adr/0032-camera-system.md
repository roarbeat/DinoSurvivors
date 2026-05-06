# ADR 0032 – Camera-System (Player-Follow + Bounds)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0008 (PlayerCharacter), ADR 0016 (RunScene), ADR 0031 (IsoWorld)
- Wird vorausgesetzt von: ADR — Camera-Shake bei Boss-Defeat, ADR — Mutation-Pick-Phase-Zoom-In

---

## 1. Kontext

Heute hat das Spiel keine Kamera. Sobald der Player läuft, fällt er
aus dem Sichtfeld. Mit der neuen Iso-Map (ADR 0031) ist das auch
visuell offensichtlich — der Player rennt von der Plattform.

Anforderungen v1:

- **Camera2D folgt dem Player** mit Smooth-Lerp (kein hartes Snap)
- **Pixel-Art-Crispness** — Camera-Position rastet auf ganze Pixel
- **Optionale World-Bounds** — Camera darf den Plattform-Rand nicht
  zeigen (Zoom-/Pan-Limit anschalten via @export)
- **Make-Current automatisch** beim Spawn — kein doppelter
  `make_current()`-Call nötig
- **Test-tauglich**: Camera-Position kann ohne Frame-Dispatch geprüft
  werden (Pure-Function-Update statt _process-only)

Bewusst NICHT in v1:

- **Camera-Shake** bei Damage-Take / Boss-Defeat (eigenes ADR)
- **Zoom-In bei Mutation-Pick-Phase** (eigenes ADR)
- **Multi-Camera-Setup** (Mini-Map, Boss-Cam) — eigenes ADR
- **Camera-Pan-Animations** für Cinematic-Boss-Intro
- **Mouse-Edge-Pan** (Strategy-Game-Stil)

## 2. Optionen

### Option A — Camera als RunScene-Child mit set_target (empfohlen)

```gdscript
class_name RunCamera extends Camera2D

@export var target: Node2D
@export var follow_smoothing: float = 5.0  # Lerp-Geschwindigkeit
@export var pixel_snap: bool = true
@export var enable_limits: bool = false  # erst aktivieren wenn Map-Bounds bekannt

func set_target(t: Node2D) -> void
func _process(delta) -> void:  # smooth lerp zur target.global_position
```

**Pro**
- Lokale Verantwortung in RunScene (Camera-Lifetime = Run-Lifetime)
- Per-Run konfigurierbar (Boss-Phase könnte später `follow_smoothing`
  ändern für Action-Camera-Feel)
- Kein Autoload-Bloat

**Contra**
- Camera muss bei jeder neuen RunScene neu instanziert werden — kein
  Problem, RunScene-Restart erstellt sie ohnehin neu

### Option B — Camera als Player-Child

Camera2D direkt unter PlayerCharacter im .tscn.

**Pro**
- Keine zusätzliche set_target-Logik

**Contra**
- Camera kann nicht ohne Player existieren (z.B. Game-Over-Screen
  zeigt noch tote Mobs auf der Map — Camera braucht eigenen Owner)
- Camera-Shake/Zoom-Effekte müssten den Player schütteln
- Boss-Cam-Pan beim Boss-Spawn unmöglich, weil Camera am Player klebt

### Option C — Camera als Autoload

```gdscript
# core/run_camera.gd extends Camera2D
extends Camera2D
```

**Pro**
- Singleton, immer verfügbar

**Contra**
- Camera2D als Autoload ist in Godot ungewöhnlich — Camera2D braucht
  Viewport-Kontext und sollte zur Scene gehören
- Persistiert zwischen Scenes (Menu → Run-Scene), was Confusion verursacht

## 3. Empfehlung

**Option A** — Camera als RunScene-Child mit `set_target`.

**Begründung**
- Lokale Verantwortung, klare Lifetime-Semantik
- Einfach um Boss-Cam-Effekte zu erweitern (set_target temporär auf
  Boss, dann zurück auf Player)
- Test-tauglich: Camera-Tests nutzen direkt RunCamera-Instanzen
- Kein Autoload-Mehraufwand

### RunCamera-API

```gdscript
class_name RunCamera extends Camera2D

## Target, dem die Camera folgen soll. null = bleibt stehen.
@export var target: Node2D

## Lerp-Geschwindigkeit. 0 = harter Snap, 5.0 = smooth Survivor-likes-
## Standard. Setzen via Inspector ODER set_follow_smoothing() zur Laufzeit.
@export var follow_smoothing: float = 5.0

## Pixel-Snap: Camera-Position rundet auf ganze Pixel (Pixel-Art).
@export var pixel_snap: bool = true

## World-Bounds aktivieren? Camera2D.limit_left etc. werden gesetzt.
@export var enable_limits: bool = false

## Bounds-Konfiguration (nur wirksam wenn enable_limits=true).
@export var bound_min: Vector2 = Vector2(-1000, -1000)
@export var bound_max: Vector2 = Vector2(1000, 1000)

# Public-API
func set_target(t: Node2D) -> void
func set_follow_smoothing(v: float) -> void
func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void

# Test-Hook (Pure Function)
static func compute_next_position(
    current: Vector2,
    target_pos: Vector2,
    smoothing: float,
    delta: float,
    pixel_snap: bool = true
) -> Vector2
```

### compute_next_position — Pure Test-Hook

```gdscript
# Smooth lerp mit Standard-Frame-Rate-Independence-Formel:
# alpha = 1 - exp(-smoothing * delta)
# new = lerp(current, target, alpha)
# Pixel-Snap: round() jeder Component
static func compute_next_position(...) -> Vector2:
    if smoothing <= 0.0:
        var p := target_pos
        if pixel_snap: return Vector2(round(p.x), round(p.y))
        return p
    var alpha := 1.0 - exp(-smoothing * delta)
    var p := current.lerp(target_pos, alpha)
    if pixel_snap: return Vector2(round(p.x), round(p.y))
    return p
```

Pure function → Test ohne Frame-Dispatch:

```gdscript
func test_camera_follow_zero_smoothing_snaps_to_target():
    var p := RunCamera.compute_next_position(Vector2(0,0), Vector2(100,50), 0.0, 0.016)
    assert_eq(p, Vector2(100, 50))
```

### Pixel-Art-Konvention

Camera2D.zoom = `Vector2(2, 2)` als Default — passt zu 1080p mit
540×270 logischen "Pixeln" (Survivor-likes-Standard für Klarheit).
Konfigurierbar via @export.

### RunScene-Integration

```gdscript
# core/run_scene/run.tscn — neuer Top-Level-Child:
RunCamera (Camera2D, mit Script run_camera.gd)
```

Im Code: nach `_spawn_player_and_start()` wird
`run_camera.set_target(_player)` aufgerufen. Bei Player-Death bleibt
die Camera am Tod-Spot stehen (target wird nicht null gesetzt — der
Player-Node ist noch in der Scene, nur is_dead).

Beim `restart_run()` wird die alte Camera reused (`set_target`-Reset),
nicht neu erstellt.

## 4. Konsequenzen

**Positiv**
- **Player bleibt im Bild**: Spielfeld fühlt sich navigiert an
- **Smooth-Feel**: Lerp gibt der Bewegung Trägheit (nicht hartes Snap-
  Tracking)
- **Asset-frei spielbar**: ColorRect-Mobs auf IsoWorld + Camera-Follow
  → erstmals echtes Survivor-Feel
- **Erweiterbar**: Camera-Shake/Boss-Cam folgen demselben Pattern

**Negativ**
- **Pixel-Snap kann ruckeln**: bei langsamen Player-Bewegungen
  springt die Camera zwischen Pixeln. Akzeptabel — typisch für
  Pixel-Art. Wer's flüssig mag, setzt `pixel_snap = false`.

**Risiken**
- **Risiko:** Camera folgt einem freed Player-Node → Crash
  (`is_instance_valid` fehlt).
  → **Mitigation:** `_process` checkt
    `target != null and is_instance_valid(target)` und skippt sonst.

- **Risiko:** Bounds-Config falsch (min > max), Camera "klemmt".
  → **Mitigation:** `set_bounds()` validiert und korrigiert (swap min/max
    wenn nötig).

## 5. Betroffene Dateien

Anzulegen:
- `core/world/run_camera.gd`
- `core/world/run_camera.tscn`
- `tests/unit/test_run_camera.gd`

Berührt:
- `core/run_scene/run.tscn` — `+ RunCamera` als Child
- `core/run_scene/run.gd` — `_spawn_player_and_start` hängt Camera an
- `agents/memory/mod-api-curator/public-api-surface.md` — RunCamera-Section
- `docs/ARCHITECTURE.md` — neuer Pattern-Block „RunCamera"
- `agents/memory/godot-implementer/file-purpose-index.md`

## 6. Folge-Entscheidungen (Backlog)

- ADR — Camera-Shake (Trauma-Wert, exponentielles Decay)
- ADR — Mutation-Pick-Phase Zoom-In (sanftes Zoomen + Vignette)
- ADR — Boss-Intro-Camera-Pan (Cinematic, Player friert kurz ein)
- ADR — Camera-Bounds aus IsoWorld auto-berechnet (statt @export)
- ADR — Multi-Camera (Mini-Map, Boss-Cam, Picture-in-Picture)
