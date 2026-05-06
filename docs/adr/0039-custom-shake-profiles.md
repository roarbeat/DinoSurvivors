# ADR 0039 – Custom-Shake-Profiles

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #5 Mod-friendly
- Voraussetzungen: ADR 0035 (Camera-Shake), ADR 0038 (Boss-Abilities)

---

## 1. Kontext

ADR 0035 hat Camera-Shake als hardcoded Trauma-Werte pro EventBus-
Signal (player_damaged → 0.3, boss_defeated → 0.7). Das skaliert nicht:

- Ein Stomp soll mehr Shake auslösen als ein normaler Treffer
- Modder können keine eigenen Shake-Werte für eigene Signals registrieren
- Boss-Phase-Wechsel sollte vielleicht eigenen Shake haben

Anforderungen v1:

- **`ShakeProfile`-Resource** mit Trauma + Decay + MaxOffset
- **RunCamera.register_signal_profile(signal_name, profile)** für
  Mod-Erweiterung
- **Default-Profiles** als Konstanten exposed (PROFILE_PLAYER_DAMAGED,
  PROFILE_BOSS_DEFEATED, PROFILE_BOSS_STOMP)
- **Backward-Kompat**: hardcoded `trauma_on_player_damaged`-Properties
  bleiben als Fallback erhalten

Bewusst NICHT in v1:

- ShakeProfile als ContentLoader-Type (overengineered, nutzt Resource direkt)
- Frequency-/Direction-Konfigurierung pro Profile (kommt mit
  Rotation-Shake-ADR)
- Shake-Layering (mehrere parallele Shakes mit unterschiedlichen Decays)

## 2. Empfehlung

```gdscript
# core/world/shake_profile.gd
class_name ShakeProfile extends Resource

@export var trauma_amount: float = 0.3
@export var decay_per_second: float = 1.5  # 0 = nutze Camera-Default
@export var max_offset: float = 8.0          # 0 = nutze Camera-Default
```

```gdscript
# RunCamera-Erweiterung
const PROFILE_PLAYER_DAMAGED := preload("res://core/world/profiles/profile_player_damaged.tres")
const PROFILE_BOSS_DEFEATED  := preload("res://core/world/profiles/profile_boss_defeated.tres")
const PROFILE_BOSS_STOMP     := preload("res://core/world/profiles/profile_boss_stomp.tres")

var _signal_profiles: Dictionary = {}  # signal_name → ShakeProfile

func _ready():
    # Default-Mappings
    _signal_profiles[&"player_damaged"] = PROFILE_PLAYER_DAMAGED
    _signal_profiles[&"boss_defeated"]  = PROFILE_BOSS_DEFEATED
    # Boss-Ability ist eine eigene Subscription weil signal-name-Param
    EventBus.boss_ability_used.connect(_on_boss_ability_used)

func add_trauma_from_profile(profile: ShakeProfile) -> void:
    if profile == null or shake_muted: return
    trauma = clampf(trauma + profile.trauma_amount, 0.0, 1.0)
    # Optional: Decay/MaxOffset überschreiben (v1: nur Trauma additiv)
    # Eigentlich brauchen wir das pro-Schake — kommt mit Layering-ADR.

func register_signal_profile(signal_name: StringName, profile: ShakeProfile) -> void:
    _signal_profiles[signal_name] = profile
```

**Fallback-Verhalten**

Wenn ein Signal kein Profile-Mapping hat, fallback auf hardcoded
`trauma_on_player_damaged` etc. — Backward-Kompat.

**Boss-Ability-Hook**

`EventBus.boss_ability_used` löst Camera-Shake aus. Default-Mapping:
nur für `tyrannosaurus_stomp` ein Profile. Andere Abilities (zukünftig)
können Modder via `register_signal_profile` mit eigenen Profiles
registrieren.

## 3. Konsequenzen

**Positiv**
- **Pro-Event-Konfigurierbarkeit**: Stomp 0.5 Trauma, normaler Hit 0.3
- **Modder-tauglich**: Custom-Signals + Custom-Profiles
- **Resource-basiert**: Designer können ShakeProfile-.tres editieren

**Negativ**
- **Single-Trauma-Pool**: alle Profiles addieren in dieselben
  `trauma`-Variable. Komplexere Shake-Layering kommt mit eigenem ADR.

## 4. Betroffene Dateien

Anzulegen:
- `core/world/shake_profile.gd`
- `core/world/profiles/profile_player_damaged.tres`
- `core/world/profiles/profile_boss_defeated.tres`
- `core/world/profiles/profile_boss_stomp.tres`

Berührt:
- `core/world/run_camera.gd` — `add_trauma_from_profile`,
  `register_signal_profile`, `boss_ability_used`-Subscription
- `tests/unit/test_run_camera.gd` — Profile-Tests

## 5. Folge-Entscheidungen (Backlog)

- ADR — Shake-Layering (mehrere parallele Shakes)
- ADR — Direction-Specific Shake (Stomp = vertikal, Roar = horizontal)
- ADR — Frequency-Variation pro Profile
