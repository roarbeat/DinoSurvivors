# Public API Surface

> Vom `mod-api-curator` gepflegt. Vollständige Liste aller Modder-sichtbaren
> Schnittstellen. Stand 2026-05-06 (v0.0.1).

> **Regel:** Jede Änderung an einem Eintrag hier ist potenziell ein Breaking
> Change. Vor jedem Push:
> 1. Prüfen, ob die Änderung breaking ist
> 2. Wenn ja: in `breaking-changes-log.md` eintragen + CHANGELOG markieren
> 3. Wenn vermeidbar: vermeiden (additiv statt destructive)

---

## 1. EventBus-Signals (`core/event_bus.gd`)

Stabilität: Renames + Parameter-Änderungen sind Mod-Breaking.

### Combat
- `enemy_died(enemy_id: StringName, position: Vector2)`
- `player_damaged(amount: float, source_id: StringName)`
- `player_died()`

### Wave / Spawn
- `wave_started(wave_index: int, difficulty: float)`
- `wave_cleared(wave_index: int)`
- `boss_spawned(boss_id: StringName, position: Vector2)`
- `boss_defeated(boss_id: StringName, run_time: float)`
- `boss_phase_changed(boss_id: StringName, phase_index: int, label_key: StringName)` (ADR 0029)
- `boss_ability_used(boss_id: StringName, ability_id: StringName, position: Vector2)` (ADR 0038)
- `upgrade_purchased(upgrade_id: StringName, new_level: int)` (ADR 0040)

### Run-Lifecycle
- `run_started(dino_id: StringName)`
- `run_ended(reason: StringName, run_time: float)`

### Player-Mutationen (ADR 0015)
- `mutations_changed()`

### Mutation / Build
- `mutation_offered(choices: Array)`
- `mutation_picked(mutation_id: StringName)`

### Meta-Progression
- `xp_gained(amount: int)`
- `level_up(new_level: int)`
- `currency_changed(currency: StringName, new_value: int)`

### Save / Lifecycle
- `save_requested(reason: StringName)`
- `save_completed()`
- `save_loaded(schema_version: int)`

### Modding
- `mod_loaded(mod_id: StringName)`
- `mod_failed(mod_id: StringName, error: String)`

### Content / Boot
- `content_loaded(type_count: int, item_count: int)`

**Insgesamt: 24 Signals** — synchron mit `tests/unit/test_event_bus.gd::EXPECTED_SIGNALS`.

---

## 2. ContentLoader-API (`core/content_loader.gd`)

```gdscript
ContentLoader.get_item(type, id)        -> ContentItem        # panic bei unbekannt
ContentLoader.get_or_null(type, id)     -> ContentItem | null
ContentLoader.get_all(type)             -> Array[ContentItem]
ContentLoader.has_item(type, id)        -> bool
ContentLoader.types()                   -> Array[StringName]
ContentLoader.all_ids(type)             -> Array[StringName]
ContentLoader.overrides_applied()       -> Array[StringName]  # ["type:id", ...]
ContentLoader.reload()                  -> void               # Dev only
```

Pfad-Konventionen:
- Core: `res://content/<type>/<id>.tres`
- Mods: `user://mods/<mod_id>/content/<type>/<id>.tres`

---

## 3. Resource-Schemas (`core/content/`)

**ContentItem (Base):**
```
id                  : StringName     # snake_case, max 40, unique pro type
display_name_key    : StringName     # i18n-key
description_key     : StringName     # i18n-key
source_mod_id       : StringName     # vom Loader gesetzt
override_existing   : bool           # Mod-only
```

**MutationDef extends ContentItem:**
```
rarity              : StringName     # common | rare | epic | legendary
stat_modifiers      : Dictionary[StringName, float]
tags                : Array[StringName]
icon                : Texture2D      # optional
```

**EnemyDef extends ContentItem:**
```
max_health          : float (>0)
speed               : float (≥0)
damage              : float
xp_reward           : int
scene               : PackedScene    # optional
body_color          : Color           # ADR 0024 — Visual-Differenzierung
body_size           : Vector2         # ADR 0024
visual_scene        : PackedScene    # optional, ADR 0027 — Sprite/Custom-Visual
visual_pivot_offset : Vector2         # ADR 0027 — HealthBar-Anchor-Korrektur
```

**BossDef extends ContentItem:**
```
max_health          : float (>0)
phases              : Array[Dictionary]    # Schema folgt
intro_text_key      : StringName
reward_currency_amount : int (≥0)
scene               : PackedScene          # ADR 0025 — BossMob-Scene
speed               : float                # ADR 0025 — Movement-Speed
damage              : float                # ADR 0025 — Touch-Damage
body_color          : Color                # ADR 0024
body_size           : Vector2              # ADR 0024
visual_scene        : PackedScene         # optional, ADR 0027
visual_pivot_offset : Vector2              # ADR 0027
```

**DinoDef extends ContentItem:**
```
max_health          : float (>0)
base_speed          : float (≥0)
base_damage         : float
base_attack_rate    : float (>0)
pickup_radius       : float (≥0)
character_scene     : PackedScene    # optional
visual_scene        : PackedScene    # optional, ADR 0027
visual_pivot_offset : Vector2         # ADR 0027
```

**WaveDef extends ContentItem (ADR 0026):**
```
is_default          : bool             # genau eine WaveDef trägt das Flag
target_wave_index   : int (≥0)         # 0 = Default-Modus; >0 = Override für genau diese Welle
base_spawn_rate     : float (≥0)       # Welle-1-Rate in Spawns/s (relevant wenn is_default=true)
spawn_rate_per_wave : float (≥0)       # +pro Welle
max_spawn_rate      : float (≥base)    # Cap
enemy_pool          : Array[StringName] # Default-Pool oder Override-Pool
boss_id             : StringName       # nur sinnvoll bei target_wave_index>0
duration_sec        : float (≥0)       # 0 = WaveSpawner.DEFAULT_WAVE_DURATION_SEC nutzen
```

Validate-Regeln:
- `is_default=true` und `target_wave_index>0` schließen sich gegenseitig aus
- weder `is_default` noch `target_wave_index>0` gesetzt → invalid
- `boss_id` darf nur auf Override-WaveDefs gesetzt sein

**SoundDef extends ContentItem (ADR 0028):**
```
stream              : AudioStream      # null = no-op (v1-Default)
volume_db           : float            # Volume-Offset, 0.0 = unverändert
pitch_random_range  : float (≥0, ≤1)   # ±-Range pro Playback (Variabilität)
```

Validate-Regeln:
- `pitch_random_range` darf nicht negativ sein und nicht > 1.0

**BossPhase Resource (ADR 0029) — Sub-Resource in BossDef.phases:**
```
hp_threshold        : float (0.0–1.0)   # absteigend sortiert in BossDef.phases
speed_multiplier    : float (>0)        # 1.0 = base
damage_multiplier   : float (≥0)        # 1.0 = base
color_tint          : Color             # multipliziert auf body.color / Visual.modulate
label_key           : StringName        # optionaler i18n-Key für Phase-Banner
```

Validate-Regeln:
- `hp_threshold` muss in [0.0, 1.0] sein
- `speed_multiplier` muss > 0 sein
- `damage_multiplier` darf nicht negativ sein
- `BossDef.phases` muss absteigend nach `hp_threshold` sortiert sein
  (sonst BossDef.validate() Fehler)

Phase-Resolver-Verhalten:
- Aktive Phase = letzte Phase mit `hp_threshold >= current_hp_pct`
- MONOTON: Index steigt nur, kein Rückfall bei Heal
- Bei Phase-Wechsel feuert `EventBus.boss_phase_changed`

**BossAbility Resource-Base (ADR 0038):**
```
id              : StringName
cooldown        : float (>0)         # Sekunden zwischen Triggers
initial_delay   : float (≥0)         # Sekunden bis erster Trigger nach Phase-Start

# Virtual:
func trigger(boss: Node) -> void
```

**BossStomp extends BossAbility (ADR 0038):**
```
radius   : float = 120.0
damage   : float = 25.0

# Pure function (Test-Hook):
static find_player_health_in_radius(center, radius, players) -> Array[HealthComponent]
```

`BossPhase.abilities: Array[BossAbility]` — leer = keine aktiven
Abilities (nur Speed/Damage-Multiplikatoren wirken).

BossMob-Tick: pro Ability eigener Cooldown-Timer in
`_ability_cooldowns: Dictionary`. Reset bei Phase-Wechsel.

**UpgradeDef extends ContentItem (ADR 0040):**
```
max_level                   : int (>0)              # Single-Buy oder N-Stage
cost_per_level              : Array[int]            # Bernstein-Kosten pro Level-Up
stat_modifiers_per_level    : Array[Dictionary]     # Schema wie MutationDef.stat_modifiers
cost_currency               : StringName            # default &"amber"
tier_description_key        : StringName            # optional i18n-Key

func get_cost_for_level(current_level: int) -> int  # -1 wenn max erreicht
func get_modifiers_for_level(level: int) -> Dictionary
```

MetaProgression-API für Upgrades:
```gdscript
MetaProgression.get_upgrade_level(id) -> int
MetaProgression.get_upgrade_cost(id) -> int
MetaProgression.can_afford_upgrade(id) -> bool
MetaProgression.purchase_upgrade(id) -> bool   # subtrahiert Currency, +1 Level
MetaProgression.list_upgrade_levels() -> Dictionary
MetaProgression.get_aggregated_modifiers() -> Dictionary  # Modifier-Stack für PlayerCharacter
```

PlayerCharacter mergt `PlayerMutations.get_aggregated()` mit
`MetaProgression.get_aggregated_modifiers()` additiv beim _apply_stats.
EventBus.upgrade_purchased triggert Re-Apply.

**MapDef extends ContentItem (ADR 0036):**
```
grid_size           : Vector2i        # default (8, 8)
path_row            : int             # -1 = kein horizontaler Pfad
path_col            : int             # -1 = kein vertikaler Pfad
deterministic_colors: bool            # true = stable Tile-Color-Variation
biome_label_key     : StringName      # optionaler i18n-Key für Map-Banner
camera_padding      : Vector2         # ADR 0037 — Bounds-Padding für RunCamera
```

Validate-Regeln:
- `grid_size` darf nicht negative Komponenten haben

Modder können MapDefs unter `user://mods/<mod>/content/maps/<id>.tres`
ablegen — ContentLoader registriert sie analog zu Mutation/Enemy/Wave.

---

## 3.5. SfxBus-API (`core/audio/sfx_bus.gd`, ADR 0028)

```gdscript
# Konstanten
const POOL_SIZE: int = 8
const SIGNAL_TO_SOUND: Dictionary  # signal_name → sound_id (6 Default-Mappings)

# Public-API
SfxBus.play(sound_id: StringName) -> bool   # liefert false bei no-op (mute/unknown/null-stream)
SfxBus.set_muted(muted: bool) -> void
SfxBus.is_muted() -> bool
SfxBus.pool_size() -> int
SfxBus.get_signal_mapping(signal_name: StringName) -> StringName
SfxBus.add_signal_mapping(signal_name: StringName, sound_id: StringName) -> void
```

Default-Subscriptions (intern, nicht überschreibbar in v1):
- `EventBus.enemy_died`      → `sfx_enemy_died`
- `EventBus.boss_defeated`   → `sfx_boss_defeated`
- `EventBus.player_damaged`  → `sfx_player_damaged`
- `EventBus.player_died`     → `sfx_player_died`
- `EventBus.mutation_picked` → `sfx_mutation_picked`
- `EventBus.wave_started`    → `sfx_wave_started`

Mods können via `add_signal_mapping(signal_name, sound_id)` zusätzliche
Mappings für eigene Signals registrieren.

---

## 3.7. Palette + IsoWorld (`core/art/palette.gd`, `core/world/iso_world.gd`, ADR 0031)

```gdscript
# Palette — Single-Source-of-Truth-Color-Konstanten
class_name Palette extends RefCounted

# Stable Color-Konstanten (16 total): BG_CHARCOAL, GRASS_LIGHT/MID/DARK,
# GRASS_EDGE, DIRT_PATH, DIRT_SIDE_TOP/BOTTOM, PLAYER_BODY/ACCENT,
# COIN_GOLD/HIGHLIGHT, CRYSTAL_GREEN, FLOWER_RED/YELLOW/LILA

static func random_grass(rng: RandomNumberGenerator = null) -> Color
```

```gdscript
# IsoWorld — Tile-Map-Skelett, public-API stabil über v1+
class_name IsoWorld extends Node2D

const TILE_SIZE: Vector2i = Vector2i(64, 32)

# Pure-Function-API (testbar ohne Instanz)
static func tile_to_iso(tile: Vector2i, tile_size = TILE_SIZE) -> Vector2
static func iso_to_tile(screen: Vector2, tile_size = TILE_SIZE) -> Vector2i

# Instance-API
@export var grid_size: Vector2i = Vector2i(8, 8)
@export var path_row: int = 4
@export var path_col: int = 4

func world_size() -> Vector2
func world_bounds() -> Rect2  # ADR 0033 — Plattform-Bounding-Rect
func is_path_tile(tile: Vector2i) -> bool
```

Mods können IsoWorld via Scene-Override unter
`user://mods/<mod>/core/world/iso_world.tscn` ersetzen — die Public-
API muss aber stabil bleiben (sonst breaks RunScene).

```gdscript
# RunCamera (ADR 0032) — Camera2D mit Player-Follow + Smooth-Lerp
class_name RunCamera extends Camera2D

@export var target: Node2D
@export var follow_smoothing: float = 5.0
@export var pixel_snap: bool = true
@export var enable_limits: bool = false
@export var bound_min: Vector2
@export var bound_max: Vector2

func set_target(t: Node2D) -> void
func snap_to_target() -> void
func set_follow_smoothing(value: float) -> void
func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void
func attach_to_world(world: IsoWorld, padding = Vector2(-1,-1)) -> void  # ADR 0033/0037
func set_bounds_padding(p: Vector2) -> void  # ADR 0037 — re-apply on cached bounds
@export var bounds_padding: Vector2 = Vector2.ZERO  # ADR 0037

# Pure Function (Test-Hook)
static func compute_padded_bounds(world_rect: Rect2, padding: Vector2) -> Rect2

# Camera-Shake (ADR 0035)
func add_trauma(amount: float) -> void
func set_trauma(value: float) -> void
@export var max_shake_offset: float = 8.0
@export var trauma_decay_per_second: float = 1.5
@export var trauma_on_player_damaged: float = 0.3
@export var trauma_on_boss_defeated: float = 0.7
@export var shake_muted: bool = false
var trauma: float  # 0.0 – 1.0, public-read

# Pure Functions (Test-Hooks)
static func compute_shake_offset(trauma, max_offset, rng) -> Vector2
static func compute_trauma_after_decay(trauma, decay_per_s, delta) -> float

# Custom-Shake-Profiles (ADR 0039)
const PROFILE_PLAYER_DAMAGED: ShakeProfile
const PROFILE_BOSS_DEFEATED:  ShakeProfile
const PROFILE_BOSS_STOMP:     ShakeProfile

func add_trauma_from_profile(profile: ShakeProfile) -> void
func register_signal_profile(signal_name: StringName, profile: ShakeProfile) -> void
func register_ability_profile(ability_id: StringName, profile: ShakeProfile) -> void
func get_signal_profile(signal_name: StringName) -> ShakeProfile
func get_ability_profile(ability_id: StringName) -> ShakeProfile

# ShakeProfile Resource (ADR 0039)
class ShakeProfile extends Resource:
    @export var trauma_amount: float = 0.3
    @export var decay_per_second: float = 0.0  # 0 = Camera-Default
    @export var max_offset: float = 0.0          # 0 = Camera-Default

# Pure Function (Test-Hook)
static func compute_next_position(
    current: Vector2, target_pos: Vector2,
    smoothing: float, delta: float, pixel_snap_enabled: bool = true
) -> Vector2
```

---

## 3.6. MetaProgression-API (`core/meta_progression.gd`, ADR 0030)

```gdscript
const DEFAULT_CURRENCY: StringName = &"amber"
const SAVE_KEY: String = "meta_progression"

# Public-API
MetaProgression.get_currency(id: StringName = DEFAULT_CURRENCY) -> int
MetaProgression.add_currency(id: StringName, amount: int) -> int   # neuer Wert
MetaProgression.set_currency(id: StringName, value: int) -> void
MetaProgression.list_currencies() -> Dictionary  # {id: int}
MetaProgression.reset() -> void   # Test-Hook + New-Game-Reset
```

EventBus-Hooks (intern):
- `EventBus.boss_defeated` → addiert `BossDef.reward_currency_amount` zu `amber`
- `EventBus.save_requested` → schreibt Snapshot in `SaveSystem.set_field("meta_progression", ...)`
- `EventBus.save_loaded` → liest Snapshot aus `SaveSystem.get_data().meta_progression`

Currency-Eigenschaften:
- Lower-Cap bei 0 (keine negativen Werte)
- `add_currency(_, 0)` ist no-op (kein Signal)
- Beliebige Currency-IDs erlaubt (Mods können eigene anlegen)

EventBus.currency_changed feuert nur wenn der Wert sich ändert.

---

## 4. Combat-Komponenten (`core/components/`)

**HealthComponent (Node):**
```
@export max_hp: float
@export is_player: bool
take_damage(info: DamageInfo) -> void
heal(amount: float) -> void
get_hp() -> float
get_hp_pct() -> float
is_dead() -> bool
reset_to_full() -> void

signals (lokal):
  damage_taken(info: DamageInfo, hp_after: float)
  healed(amount: float, hp_after: float)
  died(info: DamageInfo)
```

**DamageDealerComponent (Node):**
```
@export default_source_id: StringName
deal_damage(target: HealthComponent, info: DamageInfo) -> void

signals (lokal):
  will_deal_damage(target: HealthComponent, info: DamageInfo)
```

**DamageModifier (Resource, Subklassen-Hub für Mod-Effekte):**
```
@export priority: int            # 0..499, niedrig zuerst (siehe ADR 0010)
apply(info: DamageInfo) -> DamageInfo  # Pure Function, NIE in-place mutieren
```

**Konkrete Modifier-Subklassen (v1):**
- `FlatBonusModifier`: bonus_amount (priority 150)
- `MultiplierModifier`: multiplier (priority 250)
- `CritModifier`: chance, multiplier, set_rng() (priority 250)
- `ArmorModifier`: reduction_pct, respektiert info.pierce_armor (priority 300)

Mods dürfen eigene Subklassen einführen — `apply()` overriden, eigenen
priority setzen.

**MutationModifierBridge (Static, ADR 0014):**
```
const KNOWN_OUTGOING := [&"damage_pct", &"crit_chance", &"crit_damage_pct"]
const KNOWN_INCOMING := [&"armor_pct"]

static build(mut: MutationDef) -> Dictionary
   # returns { "outgoing": [...], "incoming": [...], "unhandled": {...} }
```

KNOWN_OUTGOING/KNOWN_INCOMING-Listen sind Public-API. Erweiterung um
einen neuen stat_key ist additiv (keine Breaking Change). Entfernen
einer ID daraus IST breaking — vorher deprecaten.

**PlayerMutations (Autoload, ADR 0015):**
```
pick(mut_id: StringName) -> bool       # false bei unbekannt oder doppelt
remove(mut_id: StringName) -> bool
reset() -> void                        # auto bei run_started
has(mut_id: StringName) -> bool
get_picked() -> Array[StringName]      # Pick-Reihenfolge
get_aggregated() -> Dictionary
   # additiv über alle gepickten Mutationen aggregiert
   # crit_chance + armor_pct werden auf 1.0 geclampt
```

Mods, die Mutations-Picks tracken: an `EventBus.mutations_changed`
lauschen, dann `PlayerMutations.get_picked()` / `get_aggregated()` lesen.

**DamageDealerComponent — erweitert (ADR 0010):**
```
@export outgoing_modifiers: Array[DamageModifier]
add_modifier(mod: DamageModifier) -> void
remove_modifier(mod: DamageModifier) -> bool
```

**HealthComponent — erweitert (ADR 0010):**
```
@export incoming_modifiers: Array[DamageModifier]
add_modifier(mod: DamageModifier) -> void
remove_modifier(mod: DamageModifier) -> bool
```

**DamageInfo (Resource):**
```
amount        : float (≥0)
damage_type   : StringName  # offen — Mods dürfen eigene Typen einführen
source_id     : StringName  # mutation_id, enemy_id, …
is_crit       : bool
pierce_armor  : bool

static make(amount, source_id, damage_type, is_crit) -> DamageInfo
validate() -> String
with_amount(new_amount) -> DamageInfo
```

Mods, die Hit-Reaktionen schreiben: an `health.damage_taken` lauschen
(lokal, hot-path-OK) oder `EventBus.player_damaged` (global, low-frequency).

`validate()`-Hook auf jeder Klasse — leerer Return = OK, sonst Fehlertext.

---

## 5. mod.json Schema (v1)

Pflicht: `schema_version`, `id`, `name`, `version`, `game_version_min`.
Optional: `author`, `description`, `dependencies`, `content_types`,
`game_version_max`, `homepage`, `license`.

ID-Format wie ContentItem-IDs: snake_case, max 40, ASCII.

---

## 6. SaveSystem-Format (v1)

Save-File ist JSON, Pfad `user://saves/save.json`.
Format-Doku in `agents/memory/save-migration-specialist/save-schema-history.md`.

Mod-Authoren, die Save-Editing-Tools bauen:
- `schema_version` IMMER erstes Feld
- `mod_overrides_used` listet aktive Mod-Overrides
- ID-Felder in `bosses_defeated[]`, `unlocked_dinos[]` etc. werden beim Load
  gegen ContentLoader validiert

---

## 7. Pfad-Konventionen (Mod-Layout)

```
user://mods/<mod_id>/
├── mod.json
└── content/
    ├── mutations/   <id>.tres   extends MutationDef
    ├── enemies/     <id>.tres   extends EnemyDef
    └── bosses/      <id>.tres   extends BossDef
```

Pfad-Layout-Änderung = Mod-Breaking (jeder existierende Mod muss umziehen).

---

## API-Surface Diff-Verfahren (für mod-api-curator)

Vor jedem CHANGELOG-Eintrag, der core/event_bus.gd, core/content_loader.gd,
core/content/*.gd, core/save_system.gd oder core/mod_loader.gd berührt:

```bash
# Vergleich der Signal-Liste zwischen zwei Tags
git diff v<old> v<new> -- core/event_bus.gd | grep '^[-+]signal'

# ContentLoader-Public-API
git diff v<old> v<new> -- core/content_loader.gd | grep -E '^[-+]func [a-z]'

# mod.json-Pflichtfelder
git diff v<old> v<new> -- core/mod_loader.gd | grep -A3 'REQUIRED_MANIFEST_FIELDS'
```

Jede Subtraktion (`-`) ist eine Breaking Change. Jede Addition ist additiv
und nur dann breaking, wenn sie ein Pflichtfeld hinzufügt.
