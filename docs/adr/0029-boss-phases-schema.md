# ADR 0029 – Boss-Phasen-Schema

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0023 (BossDef-Stub), ADR 0025 (BossMob), ADR 0027 (Visual-Provider)
- Wird vorausgesetzt von: ADR — Boss-Abilities (Stomp, Roar), ADR — Boss-Intro-Card-VFX

---

## 1. Kontext

`BossDef.phases: Array[Dictionary]` ist seit ADR 0023 ein Stub. In v1
hat der Boss keine Phasen-Logik — er läuft mit konstanter Speed/Damage
bis er stirbt. Das macht den Boss-Fight uninteressant, weil das
Verhalten nie wechselt.

Anforderungen v1:

- **Phasen als getypte Resource** (statt loose Dictionary), Validation
  beim Boot
- **HP-Threshold-basiert**: Boss wechselt Phase, wenn HP unter X% fällt
- **Multiplikatoren auf Speed/Damage** pro Phase (1.0 = Default,
  2.0 = doppelt so schnell/hart)
- **Color-Tint** pro Phase (auch im ColorRect-Mode, später Sprite-Modulate)
- **EventBus.boss_phase_changed**-Signal für UI/SFX/VFX-Hooks
- **Pure Function Phase-Lookup** (testbar ohne Frame-Dispatch)

Bewusst NICHT in v1:

- Boss-Abilities pro Phase (Stomp, Roar, Charge)
- Phase-spezifischer Spawn-Pool (Boss ruft Adds in Phase 2)
- Phase-Timer (manche Phasen dauern fest 30s, dann zwingender Wechsel)
- Phase-Transition-VFX (Hit-Stop, Color-Flash, Camera-Shake)
- Phase-spezifische Movement-Patterns

## 2. Optionen

### Option A — `BossPhase: Resource` (typed, empfohlen)

```gdscript
class_name BossPhase extends Resource

@export var hp_threshold: float = 1.0    # 1.0 = ab Spawn aktiv, 0.5 = ab 50% HP
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var color_tint: Color = Color.WHITE  # Modulate für Visual

func validate() -> String:
    if hp_threshold < 0.0 or hp_threshold > 1.0:
        return "hp_threshold muss zwischen 0.0 und 1.0 sein"
    ...
```

`BossDef.phases: Array[BossPhase]` (statt `Array[Dictionary]`).

**Pro**
- Type-Safe (Editor zeigt Felder, Validation early)
- Erweiterbar ohne Schema-Bruch (additive Felder)
- Konsistent mit Modifier/SoundDef/WaveDef-Pattern

**Contra**
- Mehr Boilerplate als loose Dictionary
- BossDef-Migration: bestehende `phases = []` bleibt valid (leeres Array
  = keine Phasen-Logik = altes Verhalten)

### Option B — Dictionary bleibt, Validate-Schema in BossDef

```gdscript
@export var phases: Array[Dictionary] = []
# Convention: { &"hp_threshold": 0.5, &"speed_mul": 1.5, ... }
```

**Pro**
- Schemaless, Mods können beliebige Felder anhängen

**Contra**
- Tipp-Fehler im Dictionary-Key fallen erst zur Laufzeit auf
- Editor zeigt nur „Dictionary" — kein Auto-Complete
- Inkonsistent mit dem getypten Resource-Pattern (MutationDef, EnemyDef …)

### Option C — Separate `boss_phases/`-Folder mit eigenen .tres-Files

`content/boss_phases/tyrannosaurus_prime_phase_1.tres` etc.

**Pro**
- Modder können einzelne Phasen überschreiben

**Contra**
- 1 Boss × 3 Phasen = 3 .tres-Files pro Boss
- Cross-Reference-Komplexität (BossDef.phase_ids: Array[StringName])
- Overengineered für v1

## 3. Empfehlung

**Option A** — `BossPhase: Resource` als Sub-Resource, embedded in
`BossDef.phases: Array[BossPhase]`.

**Begründung**
- Type-Safe + erweiterbar
- Sub-Resources sind in Godot der idiomatische Weg für „dieses Resource
  hat eine Liste verwandter Resources"
- Migration ist mechanisch: `phases = []` bleibt valid
- Modder können in ihrer .tres-File eigene Phasen-Listen einsetzen

### BossPhase-Schema

```gdscript
class_name BossPhase extends Resource

## HP-Schwellwert (0.0–1.0). Phase ist aktiv, sobald current_hp/max_hp <=
## hp_threshold. Phasen werden in Reihenfolge des höchsten Threshold
## ausgewertet (1.0 = Spawn-Phase, 0.0 = Final-Phase).
@export var hp_threshold: float = 1.0

## Speed-Multiplikator. 1.0 = BossDef.speed unverändert.
@export var speed_multiplier: float = 1.0

## Damage-Multiplikator. 1.0 = BossDef.damage unverändert.
@export var damage_multiplier: float = 1.0

## Color-Tint für visuelle Phase-Marker. Im ColorRect-Mode wird
## body_color * color_tint multipliziert. Im Sprite-Mode (ADR 0027)
## wird `Visual.modulate` gesetzt.
@export var color_tint: Color = Color.WHITE

## Optionaler i18n-Key für Phase-Banner ("RAGE MODE!").
@export var label_key: StringName = &""

func validate() -> String:
    if hp_threshold < 0.0 or hp_threshold > 1.0:
        return "hp_threshold muss in [0.0, 1.0] sein"
    if speed_multiplier <= 0.0:
        return "speed_multiplier muss > 0 sein"
    if damage_multiplier < 0.0:
        return "damage_multiplier darf nicht negativ sein"
    return ""
```

### BossMob-Phase-Dispatch

```gdscript
# Aktuelle Phase als Index in def.phases (oder -1 wenn keine Phase aktiv)
var _current_phase_idx: int = -1

func _ready():
    health.damage_taken.connect(_on_health_changed)
    health.healed.connect(_on_health_changed)

func _on_health_changed(_info) -> void:
    _evaluate_phase()

func _evaluate_phase() -> void:
    if _def == null or _def.phases.is_empty():
        return
    var hp_pct: float = health.get_hp() / max(0.001, health.max_hp)
    # Phase mit höchstem hp_threshold der noch <= hp_pct ist
    var new_idx: int = _resolve_phase_index(hp_pct)
    if new_idx != _current_phase_idx:
        _current_phase_idx = new_idx
        _apply_phase(new_idx)
        if get_node_or_null("/root/EventBus") != null:
            var phase: BossPhase = _def.phases[new_idx]
            EventBus.boss_phase_changed.emit(boss_id, new_idx, phase.label_key)

func _resolve_phase_index(hp_pct: float) -> int:
    # phases sind in absteigender hp_threshold-Reihenfolge zu konfigurieren:
    # Phase 0: hp_threshold=1.0 (Spawn)
    # Phase 1: hp_threshold=0.66 (mid)
    # Phase 2: hp_threshold=0.33 (rage)
    # Wir suchen die letzte Phase, deren threshold >= hp_pct ist.
    var best_idx: int = -1
    for i in _def.phases.size():
        var p: BossPhase = _def.phases[i]
        if hp_pct <= p.hp_threshold:
            best_idx = i
    return best_idx

func _apply_phase(idx: int) -> void:
    if idx < 0 or idx >= _def.phases.size():
        return
    var p: BossPhase = _def.phases[idx]
    # Visual-Tint
    var body := get_node_or_null("Body") as ColorRect
    if body != null and body.visible:
        body.color = _def.body_color * p.color_tint
    var visual := get_node_or_null("Visual") as CanvasItem
    if visual != null:
        visual.modulate = p.color_tint

func get_speed() -> float:
    if _def == null:
        return 0.0
    var base := _def.speed
    if _current_phase_idx >= 0:
        base *= _def.phases[_current_phase_idx].speed_multiplier
    return base
```

### EventBus-Erweiterung

Neues Signal: `boss_phase_changed(boss_id: StringName, phase_index: int, label_key: StringName)`.

EventBus-Total: 21 → 22 Signals. Diff-Eintrag in
`agents/memory/mod-api-curator/breaking-changes-log.md` (additive — kein
Break, aber Public-API-Erweiterung).

### Initial-Content (tyrannosaurus_prime)

```
phases = [
  BossPhase { hp_threshold = 1.0,  speed_mul = 1.0, dmg_mul = 1.0, tint = WHITE,         label = "" },
  BossPhase { hp_threshold = 0.66, speed_mul = 1.2, dmg_mul = 1.15, tint = (1,0.85,0.85), label = "boss.t_prime.phase_2" },
  BossPhase { hp_threshold = 0.33, speed_mul = 1.5, dmg_mul = 1.4,  tint = (1,0.6,0.6),   label = "boss.t_prime.phase_rage" },
]
```

→ Spielgefühl: bei 33% HP wird der Boss deutlich aggressiver
(50% schneller, 40% mehr Damage), Body wird rötlicher.

## 4. Konsequenzen

**Positiv**
- **Boss-Fight bekommt Spannungsbogen**: erste 33% rage-Mode ist
  dramatisch und triggert Spieler zum Push
- **Modder können eigene Phasen designen** — additive Resource
- **Phase-Transition-Hook** (`boss_phase_changed`) öffnet die Tür für
  VFX/SFX-Polish (Color-Flash, Camera-Shake, dedicated SFX)

**Negativ**
- **Damage-Multiplier wirkt erst beim NÄCHSTEN Touch** — Player kann
  beim Phasen-Wechsel nicht überrascht werden vom alten Damage-Wert.
  Akzeptabel.
- **Speed-Update** ist Lazy (durch `get_speed()` jeden Frame). Kein
  Re-Targeting, kein Hard-Reset.

**Risiken**
- **Risiko:** Heal über die Threshold zurück sollte NICHT die Phase
  zurücksetzen (sonst kann Boss endlos im Mid-Mode bleiben).
  → **Mitigation:** Phase-Index ist monoton fallend — `_evaluate_phase`
  überspringt höhere Thresholds wenn `_current_phase_idx` schon weiter ist.
  → Eigentlich braucht man keine Mitigation, weil heal beim Boss in v1
  nicht passiert. Aber als Convention dokumentieren.

- **Risiko:** Phasen-Konfig ist falsch sortiert (z.B. 0.33 vor 1.0 in der
  Liste).
  → **Mitigation:** BossDef.validate() prüft Sortierung (descending
  hp_threshold), gibt sonst Warning.

## 5. Betroffene Dateien

Anzulegen:
- `core/content/boss_phase.gd` — Resource-Schema
- `tests/unit/test_boss_phases.gd` — Phase-Lookup, Multiplier-Application,
  Phase-Transition-Signal

Berührt:
- `core/content/boss_def.gd` — `phases: Array[Dictionary]` →
  `phases: Array[BossPhase]`. Validate-Sortierung.
- `core/boss/boss_mob.gd` — Phase-Dispatch im `_on_health_changed`
  oder `_evaluate_phase`-Hook, `get_speed()` Phase-aware,
  `get_damage()` Phase-aware.
- `core/event_bus.gd` — `+ signal boss_phase_changed(...)` (22 total)
- `tests/unit/test_event_bus.gd` — KNOWN_SIGNALS-Liste erweitert
- `agents/memory/mod-api-curator/public-api-surface.md` — BossPhase-Schema,
  EventBus-Doc-Total
- `content/bosses/tyrannosaurus_prime.tres` — 3 BossPhase-SubResources
- `locale/{de,en}.po` — `boss.t_prime.phase_2/rage`-Keys

## 6. Folge-Entscheidungen (Backlog)

- ADR — Boss-Abilities (Stomp, Roar, Charge) pro Phase
- ADR — Phase-spezifischer Add-Spawn-Pool (Boss ruft Adds in Phase 2)
- ADR — Phase-Timer (manche Phasen dauern fest 30s)
- ADR — Phase-Transition-VFX (Hit-Stop, Color-Flash, Camera-Shake)
- ADR — Phase-spezifische Movement-Patterns
