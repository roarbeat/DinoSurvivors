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

**Insgesamt: 21 Signals** — synchron mit `tests/unit/test_event_bus.gd::EXPECTED_SIGNALS`.

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
```

**BossDef extends ContentItem (Stub):**
```
max_health          : float (>0)
phases              : Array[Dictionary]    # Schema folgt
intro_text_key      : StringName
reward_currency_amount : int (≥0)
```

**DinoDef extends ContentItem:**
```
max_health          : float (>0)
base_speed          : float (≥0)
base_damage         : float
base_attack_rate    : float (>0)
pickup_radius       : float (≥0)
character_scene     : PackedScene  # optional
```

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
