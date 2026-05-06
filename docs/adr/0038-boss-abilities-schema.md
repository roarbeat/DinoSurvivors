# ADR 0038 – Boss-Abilities-Schema

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0007 (Combat), ADR 0025 (BossMob), ADR 0029 (Boss-Phasen)
- Wird vorausgesetzt von: ADR — Boss-Telegraph-VFX, ADR — Player-Reactive-Abilities

---

## 1. Kontext

ADR 0029 hat Boss-Phasen mit Speed/Damage-Multiplikatoren eingeführt.
Verhalten ist aber rein passiv — der Boss läuft schneller und macht
mehr Schaden, aber **macht nichts Eigenes**. Spieler sehen nichts
außer Color-Tinting + leicht aggressiveres Touch-Damage.

Anforderungen v1:

- **`BossAbility` als Resource-Base-Klasse** mit Cooldown + Trigger-Hook
- **Konkrete erste Ability**: `BossStomp` — periodischer AOE-Damage-
  Burst um den Boss
- **Per-Phase-Konfiguration**: jede Phase hat eigene Ability-Liste
  (Phase 0 keine, Phase 2 Stomp)
- **EventBus-Hook**: `boss_ability_used(boss_id, ability_id, position)`
  für UI/SFX/VFX
- **Pure-Function-Test-Hooks** für Cooldown-Math + AOE-Target-Selection
- **Backward-Kompat**: leere `phase.abilities` → Phase verhält sich
  wie ADR 0029 (nur Multiplikatoren)

Bewusst NICHT in v1:

- **Telegraph-VFX** (Vorwarnung vor Stomp — eigenes ADR)
- **Vielfalt**: nur Stomp in v1, Roar/Charge/Spawn-Adds folgen in
  eigenen ADRs nach demselben Pattern
- **Player-Reactive-Abilities** (Boss reagiert auf Player-Verhalten)
- **Conditional-Abilities** (nur wenn N Adds tot etc.) — eigenes ADR

## 2. Empfehlung

**BossAbility als Resource-Base mit virtual `tick` und `trigger` Hooks**.

```gdscript
# core/content/boss_ability.gd
class_name BossAbility extends Resource

@export var id: StringName = &""
@export var cooldown: float = 5.0          # Sekunden zwischen Triggers
@export var initial_delay: float = 1.0     # Sekunden bis erster Trigger nach Phase-Start

# Subclasses überschreiben das.
# Wird vom BossMob mit Boss-Reference + Spielzeit-delta gerufen.
func trigger(_boss: BossMob) -> void:
    pass
```

**BossStomp** als erste Subklasse:

```gdscript
# core/content/abilities/boss_stomp.gd
class_name BossStomp extends BossAbility

@export var radius: float = 120.0
@export var damage: float = 25.0

func trigger(boss: BossMob) -> void:
    if boss == null: return
    var hits := _find_players_in_radius(boss.global_position, radius)
    var info := DamageInfo.make(damage, &"boss_stomp")
    for player_health in hits:
        boss.get_dealer_component().deal_damage(player_health, info)
    # EventBus für UI/SFX
    if Engine.get_main_loop().has_node("/root/EventBus"):
        EventBus.boss_ability_used.emit(boss.boss_id, id, boss.global_position)

# Pure-Function-Helper (Test-Hook):
static func find_player_health_in_radius(
    center: Vector2, radius: float, players: Array
) -> Array:
    var out: Array = []
    var r2 := radius * radius
    for p in players:
        if not (p is Node2D): continue
        if (p.global_position - center).length_squared() <= r2:
            var hp := p.get_node_or_null("Health") as HealthComponent
            if hp != null:
                out.append(hp)
    return out
```

**BossPhase-Erweiterung**:

```gdscript
# core/content/boss_phase.gd
@export var abilities: Array[BossAbility] = []
```

**BossMob-Tick**:

```gdscript
# Pro Ability ein eigener Cooldown-Timer
var _ability_cooldowns: Dictionary = {}  # ability_id → seconds

func _process(delta):
    if health.is_dead(): return
    if _current_phase_idx < 0: return
    var phase := _def.phases[_current_phase_idx] as BossPhase
    for ability in phase.abilities:
        var key := ability.id
        var cd := float(_ability_cooldowns.get(key, ability.initial_delay))
        cd -= delta
        if cd <= 0.0:
            ability.trigger(self)
            cd = ability.cooldown
        _ability_cooldowns[key] = cd

func _on_phase_changed():
    # Cooldowns reset bei Phase-Wechsel — neue Phase hat oft neue Abilities
    _ability_cooldowns.clear()
```

**EventBus-Erweiterung**:

```gdscript
signal boss_ability_used(boss_id: StringName, ability_id: StringName, position: Vector2)
```

EventBus-Total: 22 → **23** Signals.

## 3. Konsequenzen

**Positiv**
- **Boss-Fight bekommt Drohpotential**: Spieler muss aktiv kiten
- **Modder können eigene Abilities** als Subklassen schreiben +
  per Mod-MapDef in Phasen einbauen
- **Pattern skaliert**: Stomp ist der Template, Roar/Charge/Spawn-Adds
  folgen demselben Schema

**Negativ**
- **Pro Ability eine Subklasse** — leichte Code-Duplizierung. Akzeptabel
  v1, später kann mit Strategy-Pattern refactored werden.
- **Cooldown-Reset bei Phase-Wechsel**: Stomp aus Phase 1 wird im
  ersten Tick von Phase 2 sofort wieder ausgelöst (initial_delay
  greift). Akzeptabel.

**Risiken**
- **Risiko:** Trigger-Loops via Damage-Cycle (Stomp triggert
  player_damaged, das wird zu Camera-Shake, Camera-Shake schreibt
  Save? — nein, das passiert nur bei run_ended).
  → Nicht real, aber überprüft.

- **Risiko:** Trigger-bei-toten-Bossen.
  → **Mitigation:** `_process` checkt `health.is_dead()` → return.

## 4. Betroffene Dateien

Anzulegen:
- `core/content/boss_ability.gd` (Base-Resource)
- `core/content/abilities/boss_stomp.gd`
- `tests/unit/test_boss_abilities.gd`

Berührt:
- `core/content/boss_phase.gd` — `+ abilities: Array[BossAbility]`
- `core/boss/boss_mob.gd` — Tick-Logic, `_ability_cooldowns`,
  Phase-Change-Reset
- `core/event_bus.gd` — `+ signal boss_ability_used(...)` (23 total)
- `tests/unit/test_event_bus.gd` — KNOWN_SIGNALS erweitert
- `content/bosses/tyrannosaurus_prime.tres` — Rage-Phase bekommt
  BossStomp Sub-Resource
- `agents/memory/mod-api-curator/public-api-surface.md`

## 5. Folge-Entscheidungen (Backlog)

- ADR — Telegraph-VFX (Vorwarn-Indikator vor Stomp/Charge)
- ADR — BossRoar (Buff für andere Enemies, Slow für Player)
- ADR — BossCharge (Boss rennt schnell auf Player zu)
- ADR — BossSpawnAdds (Boss ruft kleine Adds in Phase 2/3)
- ADR — Conditional-Abilities (nur wenn HP < X% oder N Adds tot)
