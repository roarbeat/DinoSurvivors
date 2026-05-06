# ADR 0017 – Enemy-Movement v1 (Direkt-Walk)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #2 EventBus (nicht), #7 testbar
- Voraussetzungen: ADR 0009 (EnemyMob), ADR 0011 (Hit-Detection-Group-Konvention)
- Wird vorausgesetzt von: AI-Modes (späteres ADR), Boss-Phasen-Movement

---

## 1. Kontext

Hit-Detection (ADR 0011) ist da, aber Enemies stehen still. Das Mini-Spiel
funktioniert nur, wenn der Player sich freiwillig in den Touch-Radius
begibt. Klassische Survivor-likes-Mechanik fehlt: **Enemies laufen auf
Player zu**.

Anforderungen v1:

- **Direkt-Walk**: Enemy bewegt sich pro Frame Richtung nähestem Player
- **Speed kommt aus EnemyDef.speed** (raptor_grunt: 120 px/s)
- **Group-basiert**: Enemy findet Player über `&"player"`-Group
  (Konsistenz mit ADR 0011)
- **Headless-testbar**: pure Vector-Math, keine Physics-Engine
- **Tot bedeutet still**: Enemy bewegt sich nicht mehr, sobald HP=0

Bewusst NICHT in v1:

- NavMesh / Pathfinding (Direkt-Walk reicht für Survivor-likes)
- Avoidance zwischen Enemies (Schwarm-Überlappung ist OK)
- AI-Modes wie Patrouille, Flucht, Burst-Charge (eigene ADRs)
- Movement-Animation / Sprite-Flip (kommt mit Animations-ADR)

## 2. Optionen

### Option A — Direkt-Walk in Node2D._physics_process (empfohlen)

```gdscript
# In EnemyMob._physics_process(delta):
var player := _find_nearest_player()
if player != null:
    var dir := (player.global_position - global_position).normalized()
    global_position += dir * _def.speed * delta
```

**Pro**
- Trivial, headless-testbar
- Kein Physics-Setup
- Konsistent mit ADR 0011 (Player macht Distanz-Math, Enemy auch)

**Contra**
- Enemies können sich überlappen (kein Avoidance)
- Wände / Hindernisse werden ignoriert (es gibt v1 keine — Backlog)

### Option B — CharacterBody2D mit move_and_slide

EnemyMob extends CharacterBody2D, nutzt Physics-Engine.

**Pro**
- Engine-Kollisionen (Wand-Slide, Body-Push)
- Konsistent mit Player

**Contra**
- Tests brauchen Physics-Frame-Steps
- Mehr Boilerplate für nichts (v1 hat keine Walls)
- Refactor-Pfad zu Option A wäre Re-Cast

### Option C — Steering-Behaviors

Boids-artiges Schwarm-Verhalten mit Cohesion, Separation, Alignment.

**Pro**
- Visuell schön

**Contra**
- Premature für v1
- Mehrere Tuning-Parameter, die wir noch nicht balancieren können

## 3. Empfehlung

**Option A** — Direkt-Walk, pure Vector-Math.

**Begründung**
- Performance trivial: 200 Enemies × 1 Vector-Sub + 1 Lookup pro Frame
- Headless-Tests bleiben deterministisch
- Steering / NavMesh / Wände kommen mit eigenen ADRs, ohne diese
  Implementation zu brechen

**EnemyMob-API-Erweiterung**

```gdscript
EnemyMob._physics_process(delta) -> void
EnemyMob._move_toward_player(delta) -> void   # pure, testbar
EnemyMob._find_nearest_player() -> Node2D     # null wenn keiner da
EnemyMob.get_speed() -> float                 # aus EnemyDef.speed
```

**Lifecycle-Regel**

- Tot (`health.is_dead()`) → kein Movement
- Kein Player in Group → kein Movement
- Player am gleichen Ort (Distanz=0) → kein Movement (Vector2.ZERO normalized)

## 4. Konsequenzen

**Positiv**
- **Spiel ist tatsächlich spielbar**: Player läuft weg, Enemies folgen,
  Player kreist und schlägt zu — Survivor-likes-Loop funktioniert
- Enemies können effektiv mit Player interagieren — Touch-Damage greift,
  ohne dass Player sich freiwillig opfern muss

**Negativ**
- Schwarm überlappt sich auf einem Punkt (kein Avoidance) — sieht
  visuell weniger schön aus. Akzeptiert für v1.

**Risiken**
- **Risiko:** Enemies blockieren Player nicht (kein Body-Collision).
  → **Akzeptiert:** Player kann jederzeit durch Schwarm laufen, dafür
  bekommt er Touch-Damage. Survivor-likes-Standard.
- **Risiko:** Mit 1000+ Enemies könnte der Group-Lookup pro Enemy teuer
  werden (jeder Enemy macht get_nodes_in_group("player") pro Frame).
  → **Mitigation:** Cache der Player-Reference im Enemy beim _ready,
  ggf. update bei `mutations_changed`. Optimierung kommt mit
  Performance-Bench-ADR.

## 5. Betroffene Dateien & Systeme

Anzulegen / erweitern:
- `core/enemy/enemy_mob.gd`              +Movement-Methoden
- `tests/unit/test_enemy_mob.gd`         +Movement-Tests

Berührt später:
- ADR — AI-Modes (Patrol, Burst-Charge, Boss-Phases)
- ADR — Avoidance / Schwarm-Verhalten
- ADR — NavMesh wenn Wände/Hindernisse kommen

## 6. Folge-Entscheidungen (Backlog)

- ADR — AI-Modes pro EnemyDef (Patrol, Charger, Sniper)
- ADR — Schwarm-Avoidance für visuelle Schönheit
- ADR — Boss-Movement-Patterns (Telegraphie, Burst, Pause)
