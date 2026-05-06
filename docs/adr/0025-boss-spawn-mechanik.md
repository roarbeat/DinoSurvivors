# ADR 0025 – Boss-Spawn-Mechanik

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0009 (EnemyMob), ADR 0023 (Boss-Resource-Stub), ADR 0024 (Visual-Diff)
- Wird vorausgesetzt von: Boss-Phasen-Schema (eigenes ADR), Boss-Intro-VFX

---

## 1. Kontext

`tyrannosaurus_prime.tres` ist seit ADR 0023 ein BossDef-Stub im Content-
Ordner. Der Boss spawnt aber nie — keine Mechanik, kein Death-Pfad, keine
Boss-Welle-Erkennung. Phase 3 fühlt sich unvollständig an, solange der
Boss nur in BALANCE.csv existiert.

Anforderungen v1:

- **Boss-Welle alle 5 Wellen** (Welle 5, 10, 15, …)
- **Spawn EINMAL** zu Beginn der Boss-Welle, normale Auto-Spawns laufen
  parallel weiter (kein Pause-Modus für Boss-only)
- **Eigene BossMob-Klasse**: gleiches Component-Pattern wie EnemyMob
  (Health + Dealer + Movement), aber Death feuert `boss_defeated` statt
  `enemy_died`
- **EventBus.boss_spawned + boss_defeated** — Signals existieren schon
  (ADR 0001 §3 Combat-Domäne)
- **Visual über BossDef.body_color/size** (analog ADR 0024 für Enemies)
- **Boss-Phasen sind Stub** — `phases: Array[Dictionary]` bleibt leer in v1

Bewusst NICHT in v1:

- Boss-Phasen-Logik (Dispatch auf hp_threshold)
- Boss-Intro-Card / Telegraphie-VFX
- Boss-spezifische Abilities (Rush, Slam, Stomp …)
- Music-Switch bei Boss-Spawn
- Boss-Currency-Reward-Pickup (Resource-Drop ist eigenes ADR)

## 2. Optionen

### Option A — Eigene BossMob-Klasse (empfohlen)

```
BossMob (Node2D)
├── Body (ColorRect)
├── Health (HealthComponent, is_player=false)
├── Dealer (DamageDealerComponent)
└── HealthBar
@export var boss_id: StringName
func setup(def: BossDef, pos: Vector2)
# Death feuert EventBus.boss_defeated(boss_id, run_time)
```

Code-Duplikation zu EnemyMob: ~50 Zeilen (Movement, Visual-Application).
Akzeptabel für klaren Boss-Lifecycle.

**Pro**
- Klarer Death-Pfad (`boss_defeated` statt `enemy_died`)
- Erweiterbar für Phasen-Schema (eigenes ADR)
- Konsistent mit Component-Pattern (ADR 0007)

**Contra**
- Code-Duplikation mit EnemyMob (~50 Zeilen Movement + Visuals)

### Option B — EnemyMob mit `is_boss`-Flag

Dieselbe Scene/Klasse, ein Flag entscheidet das Death-Signal.

**Pro**
- Keine Code-Duplikation
- Spawn-Logik einheitlich

**Contra**
- HealthComponent-Logik fragmentiert (3 Modi: player / enemy / boss)
- Zukünftige Boss-Mechaniken (Phasen, Abilities) müssten auch in
  EnemyMob, was die Klasse aufbläst
- Test-Setup pro Boss-Test muss is_boss explizit setzen

### Option C — MobBase-Refactor

EnemyMob und BossMob erben von einem gemeinsamen MobBase.

**Pro**
- DRY

**Contra**
- Refactor von EnemyMob in v1 ist überdimensioniert
- BossMob-Implementation ist v1, MobBase kann später kommen wenn echte
  Code-Duplikation schmerzhaft wird

## 3. Empfehlung

**Option A** — eigene BossMob-Klasse.

**Begründung**
- Klarer Boss-Lifecycle (boss_defeated-Signal)
- Erweiterbar für Phasen ohne EnemyMob-Bloat
- Code-Duplikation ist begrenzt (~50 Zeilen, copy-paste-ähnlich)
- Refactor zu MobBase ist offen wenn Bedarf entsteht

**BossMob-API**

```gdscript
class_name BossMob extends Node2D

@export var boss_id: StringName

func setup(def: BossDef, pos: Vector2) -> void
func get_def() -> BossDef
func get_health_component() -> HealthComponent
func get_dealer_component() -> DamageDealerComponent
func get_speed() -> float
```

Wichtig: BossMob ist in der `&"enemy"`-Group, sodass Player-Auto-Attack
ihn trifft (ADR 0011 §3). Aber sein Death-Pfad feuert `boss_defeated`,
nicht `enemy_died`.

**WaveSpawner-Erweiterung**

```gdscript
const BOSS_WAVE_INTERVAL: int = 5

func _is_boss_wave(idx: int) -> bool:
    return idx > 0 and idx % BOSS_WAVE_INTERVAL == 0

func _boss_for_wave(idx: int) -> StringName:
    # v1: ein Boss für alle Boss-Wellen
    return &"tyrannosaurus_prime"

func spawn_boss_at(boss_id: StringName, position: Vector2) -> BossMob

# In _start_next_wave: nach EventBus.wave_started:
if _is_boss_wave(_current_wave) and _spawn_root != null:
    var pos := _random_spawn_position()
    var boss := spawn_boss_at(_boss_for_wave(_current_wave), pos)
```

**Boss-Speed-Konvention**

Boss läuft langsamer als normale Enemies (statt `def.speed` direkt) —
Spieler hat Chance, ihn zu kiten. v1 nutzt einen Konstanten-Faktor:

```gdscript
const BOSS_SPEED_BASE: float = 80.0   # explicit, nicht aus def
```

Alternative wäre `BossDef.speed` — aber BossDef hat das Field nicht
(BossDef extends ContentItem, nicht EnemyDef). Wir ergänzen `speed` und
`damage` als BossDef-Felder analog zu EnemyDef.

## 4. Konsequenzen

**Positiv**
- **Boss spawnt sichtbar**: alle 5 Wellen erscheint der Tyrannosaurus
- Death-Pfad eindeutig (`boss_defeated`)
- Phasen-Schema kann auf BossMob aufsetzen (eigenes ADR)

**Negativ**
- ~50 Zeilen Code-Duplikation. Akzeptiert v1.
- Bei multiplen gleichzeitigen Bossen würden mehrere `boss_defeated`-
  Signals feuern. Nicht in v1 erwartet.

**Risiken**
- **Risiko:** Boss + Auto-Spawn-Welle gleichzeitig → Spieler überfordert.
  → **Akzeptiert v1**: Welle 5 spawnt 0.5/s + 1 Boss. Macht Boss-Welle
  zu echtem Schwierigkeits-Spike. Boss-Pause-Mode ist Folge-Backlog.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/boss/boss_mob.gd` + `.tscn`
- `tests/unit/test_boss_mob.gd`

Berührt:
- `core/content/boss_def.gd` (+speed, +damage, +body_color, +body_size)
- `content/bosses/tyrannosaurus_prime.tres` (alle neuen Felder + scene)
- `core/wave_spawner.gd` (+_is_boss_wave, +_boss_for_wave, +spawn_boss_at,
  +_start_next_wave-Hook)
- `tests/unit/test_wave_spawner.gd` (+Boss-Wave-Tests)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Boss-Phasen-Schema (Dispatch auf hp_threshold)
- ADR — Boss-Intro-Card-VFX (Comic-Style „BOSS! TYRANNOSAURUS PRIME!")
- ADR — Boss-spezifische Abilities (Stomp, Roar)
- ADR — Music-Switch bei Boss-Spawn
