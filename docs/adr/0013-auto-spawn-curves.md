# ADR 0013 – Auto-Spawn-Curves v1 (prozedural)

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven (teilweise), #7 testbar
- Voraussetzungen: ADR 0006 (WaveSpawner), ADR 0009 (Spawn-API), ADR 0011 (Group-Konvention)
- Wird vorausgesetzt von: WaveDef-Resource (eigenes ADR), Boss-Wellen

---

## 1. Kontext

WaveSpawner triggert heute Wave-Lifecycle-Signals, aber spawnt nicht
selbst. `_spawn_demo_enemies()` ist Test-Hook. Game-Erlebnis: 3 Raptoren
beim Start, danach Stille.

Anforderungen v1:

- **Auto-Spawn** während laufender Welle, gemäß Spawn-Rate
- **Welle-skalierend**: Welle 1 sanft, Welle 2 dichter, etc.
- **Spawn-Position** relativ zum Player (außerhalb Sichtkegel)
- **Headless-testbar**: `_tick_auto_spawn(delta)` als pure Methode
- **Daten-getrieben kommt später**: v1 ist prozedurale Curve im Code,
  v2 lädt `WaveDef`-Resources (eigenes ADR)

Bewusst NICHT in v1:

- WaveDef als ContentLoader-Type (eigenes ADR)
- Mix aus mehreren Enemy-Typen pro Welle
- Boss-Wellen-Mechanik (Boss-Spawn statt Schwarm)
- Burst-Spawn-Patterns (Wellen mit Cluster-Spawn)
- Visuelle Spawn-Animation / Spawn-Telegraphie

## 2. Optionen

### Option A — Prozedurale Curve im WaveSpawner-Code (empfohlen)

```gdscript
func _spawn_rate_for_wave(idx: int) -> float:
    return 0.5 + 0.3 * (idx - 1)  # 0.5/s, 0.8/s, 1.1/s, ...

func _enemy_id_for_wave(idx: int) -> StringName:
    return &"raptor_grunt"  # v1 nur ein Typ
```

**Pro**
- Trivial, keine neue Resource-Klasse
- Refactor zu Option B ohne API-Bruch
- Tuning passiert im Code, mit gut-Tests

**Contra**
- Modder können Spawn-Curves nicht ohne Code-Change ändern
- Nicht skalierbar zu komplexen Mix-Wellen

### Option B — WaveDef als Content-Resource

```
WaveDef extends ContentItem
├── spawn_table: Array[{ enemy_id, count, interval }]
├── duration: float
└── difficulty_multiplier: float
```

**Pro**
- Data-Driven (Prinzip 1) konsequent
- Modder können Welle-Mixes definieren

**Contra**
- Schema-Design braucht eigenes ADR
- Mehr Komplexität für v1, wo wir nur einen Enemy-Typ haben

### Option C — Burst-Spawn nach Timer

Pro Welle ein Burst (z.B. 20 Enemies auf einmal), dann ruhe.

**Pro**
- Klassisches Wave-Survival-Gefühl

**Contra**
- Survivor-likes-Standard ist kontinuierlicher Stream
- Performance-Spike bei Burst-Spawn

## 3. Empfehlung

**Option A** — prozedurale Curve im Code, `WaveDef` als Content-Type
für v2-ADR markiert.

**Begründung**
- Liefert sofortiges Spielerlebnis
- WaveDef-Migration ist klar — nur die `_spawn_rate_for_wave` /
  `_enemy_id_for_wave` werden später durch ContentLoader-Lookup ersetzt
- Modder bekommen die Möglichkeit später ohne Breaking Change

**Spawn-Curve-Konstanten**

```gdscript
const BASE_SPAWN_RATE: float = 0.5     # Spawns/s in Welle 1
const SPAWN_RATE_PER_WAVE: float = 0.3  # +pro Welle
const MAX_SPAWN_RATE: float = 5.0      # Cap (verhindert Performance-Tod)
const SPAWN_RADIUS_FROM_PLAYER: float = 400.0  # Pixel vom Player
```

**Spawn-Position-Strategie**

Zufälliger Punkt auf Kreis um den Player (Group-Lookup `&"player"`).
Wenn kein Player: Fallback auf `(0, 0)`. Alle Enemies spawnen
außerhalb des Sichtfelds, was Survivor-likes-Standard entspricht.

**Tick-Logik (im WaveSpawner._physics_process)**

```gdscript
func _physics_process(delta):
    if not _active:
        return
    _tick_auto_spawn(delta)

func _tick_auto_spawn(delta):
    _auto_spawn_timer = max(0.0, _auto_spawn_timer - delta)
    if _auto_spawn_timer <= 0.0:
        _do_auto_spawn()
        _auto_spawn_timer = _current_spawn_interval

func _do_auto_spawn():
    if _spawn_root == null:
        return
    var pos = _random_spawn_position()
    spawn_enemy_at(_enemy_id_for_wave(_current_wave), pos)
```

**Wave-Lifecycle-Hook**

Bei `_start_next_wave()`: `_current_spawn_interval = 1.0 / spawn_rate`.
Bei `_on_run_ended`: `_auto_spawn_timer = 0`, `_active = false`.

## 4. Konsequenzen

**Positiv**
- **Endloser Mini-Game-Loop**: F5 → Player läuft → Raptoren spawnen
  immer schneller → Spieler kämpft → bis Player stirbt (was aktuell
  noch keine sichtbare Konsequenz hat — Game-Over-ADR Backlog)
- Welle-Progression sichtbar: jede neue Welle bringt mehr Pressure

**Negativ**
- Spawn-Caps wichtig: ohne MAX_SPAWN_RATE würde das Spiel bei Welle 50
  unspielbar. v1 hat einen Cap, ist aber nicht UI-konfigurierbar.

**Risiken**
- **Risiko:** Wenn Player stirbt, läuft Auto-Spawn weiter — Container
  füllt sich endlos.
  → **Mitigation:** RunState.end() triggert `_active = false` →
  Auto-Spawn stoppt. Existierende Enemies bleiben aber. Cleanup ist
  Game-Over-Screen-ADR-Sache.
- **Risiko:** Spawn-Position ohne Player-Reference fällt auf (0,0) —
  wenn Player nicht bei (0,0) ist, spawnen Enemies an seltsamer Stelle.
  → **Akzeptiert:** in der Run-Scene ist Player am Anfang bei (0,0),
  und Player-Reference ist immer da, sobald RunScene._ready durch ist.

## 5. Betroffene Dateien & Systeme

Anzulegen / erweitern:
- `core/wave_spawner.gd`              +Auto-Spawn-Tick + Curve-Methoden
- `tests/unit/test_wave_spawner.gd`   +Auto-Spawn-Tests

Berührt später:
- ADR — WaveDef als Content-Resource (data-driven Curves)
- ADR — Boss-Wellen-Mechanik
- ADR — Spawn-Telegraphie / Animation

## 6. Folge-Entscheidungen (Backlog)

- ADR — WaveDef-Resource für Modder-Curves
- ADR — Mix-Wellen mit mehreren Enemy-Typen
- ADR — Boss-Spawn-Mechanik
- ADR — Game-Over-Screen + Run-Restart (cleanup von Auto-Spawn)
