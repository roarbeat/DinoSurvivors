# DinoRogue – Architektur

> Lebendiges Dokument. Wird vom `game-architect` (Konzept) und vom
> `godot-implementer` (Patterns nach Implementation) gepflegt.

## 7 Kern-Prinzipien

1. **Data-driven** – kein Game-Inhalt im Code. Alles als Resource (.tres).
2. **Event-Bus** als zentrales Nervensystem (siehe ADR 0001).
3. **Save-Versionierung** mit Migrations.
4. **Lokalisierung** ab Tag 1 – jeder User-facing String via `tr()`.
5. **Mod-freundliche** Struktur – stabile Public-API.
6. **Stable Content-IDs** – einmal vergeben, nie umbenannt.
7. Jedes System ist **alleine testbar**.

## Verzeichnis-Layout (Stand: 2026-05-06)

```
DinoSurvivors/
├── core/                       Engine-Glue: Bus, Loader, Save, Mods
│   ├── event_bus.gd            ADR 0001 — globaler Signal-Hub
│   ├── content_loader.gd       ADR 0003 — Type-indizierte Registry
│   ├── save_system.gd          ADR 0002 — JSON-Save mit Migrations
│   ├── mod_loader.gd           ADR 0005 — Mod-Manifest-Parser
│   ├── run_state.gd            ADR 0006 — State-Maschine
│   ├── wave_spawner.gd         ADR 0006 — Wave-Lifecycle
│   ├── player_mutations.gd     ADR 0015 — Aggregator-Autoload
│   ├── meta_progression.gd     ADR 0030 — Bernstein-Tracker (persistent)
│   ├── player/                 ADR 0008
│   │   ├── player_character.gd
│   │   └── player_character.tscn
│   ├── enemy/                  ADR 0009
│   │   ├── enemy_mob.gd
│   │   └── enemy_mob.tscn
│   ├── boss/                   ADR 0025
│   │   ├── boss_mob.gd
│   │   └── boss_mob.tscn
│   ├── audio/                  ADR 0028
│   │   └── sfx_bus.gd          SFX-Bridge auf EventBus
│   ├── art/                    ADR 0031
│   │   └── palette.gd          Single-Source-of-Truth-Color-Palette
│   ├── world/                  ADR 0031 + 0032
│   │   ├── iso_world.gd        Iso-Tile-Map-Skelett
│   │   ├── iso_world.tscn
│   │   ├── run_camera.gd       Player-Follow-Camera mit Smooth-Lerp
│   │   └── run_camera.tscn
│   ├── run_scene/              ADR 0016
│   │   ├── run.gd
│   │   └── run.tscn            (main_scene beim Boot)
│   ├── ui/                     ADR 0018
│   │   ├── health_bar.gd
│   │   └── health_bar.tscn
│   ├── combat/                 ADR 0007 + 0010 + 0014
│   │   ├── damage_info.gd      Damage-Payload-Resource
│   │   ├── damage_modifier.gd  Modifier-Base-Resource
│   │   ├── mutation_modifier_bridge.gd  ADR 0014 — Mut → Modifier-Set
│   │   └── modifiers/
│   │       ├── flat_bonus_modifier.gd
│   │       ├── multiplier_modifier.gd
│   │       ├── crit_modifier.gd
│   │       └── armor_modifier.gd
│   ├── components/             ADR 0007 — Node-anhängbare Komponenten
│   │   ├── health_component.gd
│   │   └── damage_dealer_component.gd
│   ├── save_migrations/        Migration-Pipeline (eine Datei pro Schritt)
│   │   ├── _migration.gd       Interface-Konvention
│   │   └── _runner.gd          sequenzieller Caller
│   └── content/                Resource-Schemas
│       ├── content_item.gd     Base-Klasse
│       ├── mutation_def.gd
│       ├── enemy_def.gd
│       ├── boss_def.gd
│       ├── dino_def.gd
│       ├── wave_def.gd         ADR 0026 — Wellen als Content-Resource
│       └── sound_def.gd        ADR 0028 — SFX als Content-Resource
├── content/                    .tres-Resources (Mutationen, Gegner, Bosse, Dinos, Wellen)
│   ├── mutations/
│   │   ├── triceratops_horns.tres
│   │   ├── spinosaur_sail.tres
│   │   └── ankylosaur_plates.tres
│   ├── enemies/
│   │   ├── raptor_grunt.tres
│   │   ├── pteranodon.tres
│   │   ├── raptor_alpha.tres
│   │   └── armored_carnotaurus.tres
│   ├── bosses/
│   │   └── tyrannosaurus_prime.tres
│   ├── dinos/
│   │   └── trex.tres
│   ├── waves/                  ADR 0026
│   │   ├── wave_default.tres   Curve-Default (is_default=true)
│   │   ├── wave_5_tyrannosaurus.tres   Override Welle 5
│   │   └── wave_10_tyrannosaurus.tres  Override Welle 10
│   └── sounds/                 ADR 0028
│       ├── sfx_enemy_died.tres
│       ├── sfx_boss_defeated.tres
│       ├── sfx_player_damaged.tres
│       ├── sfx_player_died.tres
│       ├── sfx_mutation_picked.tres
│       └── sfx_wave_started.tres
├── locale/                     po-Files (de.po, en.po)
├── BALANCE.csv                 Stats-Audit-Sheet
├── tests/
│   ├── unit/                   gut-Tests (headless lauffähig)
│   ├── scenes/                 manuelle Smoke-Test-Scenes
│   └── fixtures/
│       ├── save_v1.json        JSON-Reference-Saves für Migrations-Tests
│       └── mods/               Test-Mod-Fixtures (example_mod, broken_mod, …)
├── docs/
│   ├── ARCHITECTURE.md         ← dieses Dokument
│   └── adr/                    Architecture Decision Records
└── .claude/
    └── agents/                 Sub-Agent-Crew (Phase 0a)
```

## Pattern: EventBus

**Wann nutzen?**
Für *bedeutende* State-Changes, die mehr als einen Konsumenten haben:
HUD-Update, Save-Trigger, Telemetrie, Achievement-Check, Mod-Hooks.

**Wann NICHT nutzen?**
Für Hot-Path-Events (>100×/Sekunde): Damage-Ticks pro Frame, Position-
Updates, Animation-Frames. Solche Events laufen direkt zwischen
Komponenten (z.B. Combat-Component → Health-Component).

**Producer-Seite**

```gdscript
# Irgendwo im Game-Code:
EventBus.enemy_died.emit(enemy_id, global_position)
```

**Consumer-Seite (Method-Ref — bevorzugt)**

```gdscript
func _ready() -> void:
    EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy_id: StringName, pos: Vector2) -> void:
    ...
```

Bei Method-Refs übernimmt Godot das Disconnect beim `queue_free()`.

**Consumer-Seite (Lambda — nur in begründeten Fällen)**

```gdscript
var _cb: Callable

func _ready() -> void:
    _cb = func(id, pos): ...
    EventBus.enemy_died.connect(_cb)

func _exit_tree() -> void:
    EventBus.enemy_died.disconnect(_cb)
```

Lambdas werden nicht automatisch disconnected — IMMER selbst aufräumen.

**Naming-Convention**
`<noun>_<past-tense-verb>` → `enemy_died`, `wave_started`, `mutation_picked`.

**Mod-Sichtbarkeit**
Alle Signals in `event_bus.gd` zählen als Public-API. Renames sind
Breaking Changes — vor Änderung `mod-api-curator` konsultieren.

## Pattern: SaveSystem

Saves sind JSON-Files unter `user://saves/save.json`, schema-versioniert,
mit Migration-Pipeline (siehe ADR 0002).

**Regeln**

- Game-Code feuert NIE direkt `SaveSystem.save()` — immer:
  ```gdscript
  EventBus.save_requested.emit(&"wave_end")
  ```
- Felder werden via gepunktete Pfade gesetzt:
  ```gdscript
  SaveSystem.set_field("settings.master_volume", 0.6)
  ```
- Lesen über `SaveSystem.get_data()` (deep-copy, sicher gegen Mutation).
- Save-Refs (z.B. `bosses_defeated[]`) werden beim Load gegen ContentLoader
  validiert. Fehlende IDs werden geloggt, nicht zerstörerisch behandelt.

**Schema-Änderung — Procedure**

1. game-architect bestätigt die Änderung (oft via ADR)
2. save-migration-specialist erhöht `CURRENT_SCHEMA_VERSION` in
   `core/save_system.gd`
3. Migration-File `core/save_migrations/v<n>_to_v<n+1>.gd` anlegen
   (siehe `_migration.gd` für Konvention)
4. Test-Fixture `tests/fixtures/save_v<n>.json` und gut-Test ergänzen
5. `_default_save()` aktualisieren falls neue Default-Felder
6. CHANGELOG-Eintrag mit User-facing Beschreibung
7. mod-api-curator informieren — Save-Format ist Mod-Public-API

## Boot-Sequence

Reihenfolge der Autoloads in `project.godot` ist signifikant:

```
1. EventBus       ADR 0001 — globaler Signal-Hub
2. ContentLoader  ADR 0003 — feuert content_loaded
3. SaveSystem     ADR 0002 — bei Load validiert es Refs gegen ContentLoader
                              und subscribet save_requested am EventBus
4. ModLoader      ADR 0005 — scannt user://mods/, validiert mod.json,
                              ruft ContentLoader.reload(), feuert
                              mod_loaded / mod_failed
5. RunState       ADR 0006 — State-Maschine, hält aktiven Dino,
                              feuert run_started / run_ended
6. WaveSpawner    ADR 0006 — subscribed run_started/ended,
                              Wave-Timer + wave_started / wave_cleared
7. PlayerMutations ADR 0015 — Aggregator für gepickte Mutationen,
                              feuert mutations_changed bei Änderung
```

Wer einen neuen Autoload ergänzt, MUSS sich überlegen, wo in dieser Kette
er hingehört, und das hier dokumentieren.

## Pattern: Run-Lifecycle

Zwei eigenständige Autoloads — `RunState` (State-Maschine) und `WaveSpawner`
(Wave-Lifecycle) — koppeln sich ausschließlich über den EventBus. Siehe
ADR 0006.

**State-Maschine (RunState)**

```
            run_start_requested (vom UI/Game-Code)
        IDLE ─────────► start(dino_id) ─────────► RUNNING
                                                     │
                                                     │  end(reason)
                                                     ▼
                                                   ENDED
                                                     │
                                                     │  reset()
                                                     ▼
                                                    IDLE
```

**Producer (Game-Code)**

```gdscript
# Run starten — RunState validiert Dino gegen ContentLoader
RunState.start(&"trex")

# Run beenden — feuert run_ended, deaktiviert WaveSpawner
RunState.end(&"player_died")

# Zurück ins Hauptmenü — WaveSpawner-Counter zurück auf 0
RunState.reset()
```

**Consumer (Game-Systeme)**

```gdscript
# Auf Run-Start hören (HUD, Music-Manager, Telemetry, Mods, …)
EventBus.run_started.connect(func(dino_id):
    print("Run gestartet mit %s" % dino_id))

# Auf Run-Ende hören (Save-Trigger, End-Screen, Achievement-Check)
EventBus.run_ended.connect(func(reason, run_time):
    EventBus.save_requested.emit(&"run_ended"))
```

**WaveSpawner (Status-Quo)**

In v0.0.1 ist WaveSpawner ein **Logik-Skelett ohne tatsächliche Spawns** —
nur Timer + Wave-Counter + EventBus-Signals. Combat-System (separates ADR)
wird hier später echte Gegner spawnen.

```gdscript
WaveSpawner.set_wave_duration(20.0)  # Sekunden
WaveSpawner.is_active()              # true während RUNNING
WaveSpawner.current_wave()           # 0 wenn idle, ≥1 sonst
```

**Verbotene Pattern**
- Game-Code triggert WaveSpawner direkt (Spawn, Wave-Skip) — NIE.
  Alles über EventBus.run_started/ended.
- Mehrere Run-States parallel — nicht in v1 vorgesehen.
- Mid-Run-Save direkt am SaveSystem rufen — kommt in eigenem ADR (Backlog).

## Pattern: Combat-Pipeline (ADR 0007)

Component-basiert, mit klarer Hot-Path-Trennung. **Damage geht NICHT über
den EventBus** — nur **bedeutsame State-Changes** (Tod, signifikanter
Spieler-Schaden) werden gebus't.

**Komponenten**

```
PlayerCharacter (CharacterBody2D, kommt mit ADR 0008)
├── HealthComponent       max_hp, take_damage(info), heal(amount)
└── DamageDealerComponent deal_damage(target, info)

EnemyMob (Node2D + script mit `enemy_id: StringName`, kommt mit ADR 0009)
├── HealthComponent
└── DamageDealerComponent
```

**DamageInfo** (Resource)

```gdscript
DamageInfo.make(amount, source_id, damage_type, is_crit)
# damage_type ist offene StringName — Mods dürfen "fire", "poison", … einführen
```

**Hot-Path** (direkte Calls, nie Bus)

```gdscript
target_health.take_damage(damage_info)        # Direct
dealer.deal_damage(target_health, info)       # Direct, mit Modifier-Hook
```

**Bus** (nur bei bedeutsamen Events)

```gdscript
EventBus.player_damaged.emit(amount, source_id)   # HUD-HP-Bar, Damage-Indicator
EventBus.player_died.emit()                       # Run-Ende, Game-Over-Screen
EventBus.enemy_died.emit(enemy_id, position)      # XP-Drop, Telemetrie
```

**Lokale Component-Signals** (Mod- und Test-Hooks)

```gdscript
health.damage_taken.connect(my_handler)   # pro-Tick OK, lokal
health.healed.connect(...)
health.died.connect(...)
dealer.will_deal_damage.connect(...)      # Pre-Damage Hook
```

**Verbotene Pattern**

- Damage als globales EventBus-Signal (Hot-Path-Verstoß ADR 0001)
- Damage als Plain-Float (verliert source_id, damage_type → kein Mod-Hook)
- HP-Manipulation außerhalb HealthComponent (Death-Pfad bricht)

## Pattern: Modifier-Pipeline (ADR 0010)

DamageModifier-Resources transformieren `DamageInfo` deklarativ — bevor sie
beim HealthComponent ankommt (outgoing) oder bevor HP reduziert wird
(incoming).

**Stack-Setup**

```gdscript
# Outgoing (am DamageDealer): Crit, Boni, Damage-Multipliers
var bonus := FlatBonusModifier.new()
bonus.bonus_amount = 5.0
dealer.add_modifier(bonus)

var crit := CritModifier.new()
crit.chance = 0.15
crit.multiplier = 2.0
dealer.add_modifier(crit)

# Incoming (am HealthComponent): Armor, Damage-Resistance
var armor := ArmorModifier.new()
armor.reduction_pct = 0.30
hp.add_modifier(armor)
```

**Reihenfolge (priority — niedrig zuerst)**

| Range | Bedeutung | Beispiel-Klasse |
|-------|-----------|-----------------|
| 0..99 | Pre-Calc | (Custom Mod-Klassen) |
| 100..199 | Flat-Boni | FlatBonusModifier (150) |
| 200..299 | Multiplier | MultiplierModifier (250), CritModifier (250) |
| 300..399 | Defensive | ArmorModifier (300) |
| 400..499 | Post-Calc | (Damage-Cap, Min-Damage) |

**Pure-Function-Konvention**

```gdscript
func apply(info: DamageInfo) -> DamageInfo:
    return info.with_amount(info.amount + bonus_amount)  # ✓ Kopie
    # NIEMALS: info.amount += bonus_amount               # ✗ Mutation
```

`with_amount()` liefert eine neue Resource. Tests verifizieren das mit
Identity-Checks gegen die Eingabe.

**RNG-Determinismus**

CritModifier hat eine eigene `RandomNumberGenerator`-Instanz, die per
`set_rng(rng)` für Tests überschrieben werden kann. Edge-Cases
(chance=0, chance=1) sind ohnehin RNG-frei.

**Verbotene Pattern**

- Modifier mutiert die übergebene DamageInfo in-place
- Modifier ruft EventBus oder andere Singletons (Hot-Path-Verstoß)
- Modifier hat State-abhängiges Verhalten ohne RNG-Override-Hook

## Pattern: Mutation→Modifier-Bridge (ADR 0014)

`MutationDef.stat_modifiers` ist deklarativer Daten-Bag. Die Bridge
übersetzt diese Daten zur Laufzeit in konkrete `DamageModifier`-Resourcen,
die sich an Combat-Komponenten hängen lassen.

**Aufruf**

```gdscript
var mut := ContentLoader.get_or_null(&"mutation", &"triceratops_horns") as MutationDef
var result := MutationModifierBridge.build(mut)

# Outgoing-Stats an den DamageDealer
for m in result["outgoing"]:
    player_dealer.add_modifier(m)

# Incoming-Stats an die HealthComponent
for m in result["incoming"]:
    player_health.add_modifier(m)

# Unbekannte Stats → Player-Stat-System
for k in result["unhandled"]:
    player_stats.add(k, result["unhandled"][k])
```

**Bekannte stat_keys (v1)**

| stat_key | Mapping |
|----------|---------|
| `damage_pct` | MultiplierModifier (outgoing, multiplier=1+v) |
| `crit_chance` | CritModifier (outgoing, chance=v) |
| `crit_damage_pct` | bündelt mit crit_chance — multiplier=2+v |
| `armor_pct` | ArmorModifier (incoming, reduction_pct=v) |

Alle anderen stat_keys (`move_speed_pct`, `max_health_pct`,
`pickup_radius_pct`, `melee_range_pct` etc.) gelten als **Player-Stats**
und landen in `unhandled`.

**Pure-Function-Konvention**

`build()` darf weder MutationDef noch globalen State mutieren. Tests
verifizieren das mit Snapshot-Vergleich.

**Erweiterung**

Neue stat_keys werden im Bridge-Code ergänzt (KNOWN_OUTGOING /
KNOWN_INCOMING + Mapping-Branch). Mods, die eigene Modifier-Klassen
einführen wollen, hängen sie aktuell direkt am DamageDealer/HealthComponent
ein — Plugin-Hook-Variante kommt mit eigenem ADR (Backlog).

## Pattern: Player-Mutations-Aggregator (ADR 0015)

PlayerMutations sammelt **mehrere** gepickte Mutationen und aggregiert
ihre Stats additiv — vor dem Bridging zu Modifiern.

**Pick-Lifecycle**

```gdscript
PlayerMutations.pick(&"triceratops_horns")     # +15% damage
PlayerMutations.pick(&"spinosaur_sail")        # +10% crit, +50% crit-dmg
PlayerMutations.pick(&"ankylosaur_plates")     # +20% armor

# Aggregiert sich automatisch:
var agg := PlayerMutations.get_aggregated()
# agg["outgoing"] = [MultiplierModifier(1.15), CritModifier(0.10, 2.5)]
# agg["incoming"] = [ArmorModifier(0.20)]
# agg["unhandled"] = { "melee_range_pct": 0.10, "max_health_pct": 0.15 }
```

**Aggregations-Regeln (v1)**

| Stat | Regel | Cap |
|------|-------|-----|
| `damage_pct` | additiv | – |
| `crit_chance` | additiv | clamp 1.0 |
| `crit_damage_pct` | additiv | – |
| `armor_pct` | additiv | clamp 1.0 |
| Unbekannte | additiv pro Key | – |

**Run-Lifecycle**

`EventBus.run_started` triggert `PlayerMutations.reset()`. Game-Code muss
das nicht selbst tun. Mutationen sind run-internal — kein Persistieren
zwischen Runs (in v1).

**Listener-Hook**

```gdscript
EventBus.mutations_changed.connect(func():
    var agg := PlayerMutations.get_aggregated()
    # HUD aktualisieren, Modifier-Stacks am Player neu aufbauen, …)
```

`mutations_changed` feuert nach pick/remove und nach reset (sofern Liste
nicht schon leer war).

## Pattern: Player-Character (ADR 0008)

`PlayerCharacter` ist eine **generische** Spieler-Scene — der konkrete Dino
kommt als `DinoDef`-Resource via `set_dino()`. Stats werden datengetrieben
geladen, Mutationen wirken über den `mutations_changed`-Hook.

**Scene-Hierarchie**

```
PlayerCharacter (CharacterBody2D)
├── Health  (HealthComponent, is_player=true)
└── Dealer  (DamageDealerComponent, default_source_id="player")
```

**Initialisierung**

```gdscript
var player: PlayerCharacter = preload("res://core/player/player_character.tscn").instantiate()
add_child(player)
player.set_dino(ContentLoader.get_item(&"dino", &"trex"))
```

**Mutations-Application**

`PlayerCharacter` subscribed `EventBus.mutations_changed` und ruft bei
jeder Änderung `_apply_stats(PlayerMutations.get_aggregated())`:

| Aggregat-Teil | Wirkung |
|---------------|---------|
| `outgoing[]` | werden auf `dealer.outgoing_modifiers` gesetzt |
| `incoming[]` | werden auf `health.incoming_modifiers` gesetzt |
| `unhandled.max_health_pct` | erhöht `health.max_hp` (120 × 1.15 = 138) |
| `unhandled.move_speed_pct` | erhöht `_compute_velocity()` Output |

**Movement-Pattern**

```gdscript
# _physics_process
var input := Vector2(
    Input.get_axis("move_left", "move_right"),
    Input.get_axis("move_up", "move_down"))
velocity = _compute_velocity(input)
move_and_slide()

# _compute_velocity ist pure (testbar ohne Physics-Step)
func _compute_velocity(input_vec: Vector2) -> Vector2:
    if input_vec.length_squared() <= 0.0:
        return Vector2.ZERO
    return input_vec.normalized() * get_effective_speed()
```

**Verbotene Pattern**

- HP/Speed/Damage hardcoded im Player-Script — alles über DinoDef
- Eigene HP-Variable außer `health.get_hp()` — wir vertrauen der HealthComponent
- Mutations-Application ohne `mutations_changed`-Trigger — sonst
  inconsistent State

## Pattern: Enemy-Mob & Spawn-API (ADR 0009)

`EnemyMob` ist analog zu `PlayerCharacter` aufgebaut: Node2D-Wurzel mit
HealthComponent + DamageDealerComponent als Children, EnemyDef-getrieben.

**Scene-Hierarchie**

```
EnemyMob (Node2D)
├── Health  (HealthComponent, is_player=false)
└── Dealer  (DamageDealerComponent)
```

**Spawn-Workflow**

```gdscript
# Im Run-Setup (z.B. wenn Run-Scene fertig geladen ist):
WaveSpawner.set_spawn_root(get_tree().current_scene.get_node("EnemyContainer"))

# Spawn auslösen:
var mob := WaveSpawner.spawn_enemy_at(&"raptor_grunt", Vector2(400, 200))
# mob hat:
#   enemy_id = &"raptor_grunt"
#   global_position = (400, 200)
#   health.max_hp = 25 (aus EnemyDef)
#   dealer.default_source_id = &"raptor_grunt"
```

**Death-Pfad**

Wenn `mob.health.take_damage(...)` HP auf 0 reduziert:
1. lokales `died`-Signal feuert
2. HealthComponent liest `enemy_id` vom Owner-Node (Convention)
3. `EventBus.enemy_died.emit(enemy_id, mob.global_position)` feuert

**Bewusst NICHT in v1**
- Movement / AI: Enemies sind stationäre HP-Säcke (eigenes ADR)
- Auto-Spawn-Curves: WaveSpawner spawnt nicht selbst (Game-Code triggert)
- Despawn-Strategie (zu weit weg): kommt mit eigenem ADR

**Verbotene Pattern**
- Enemies ohne enemy_id-Property auf der Wurzel — Death-Signal funktioniert nicht
- Direktes Instantiieren von EnemyMob.tscn ohne setup() — Stats bleiben bei Defaults

## Pattern: Run-Scene-Glue (ADR 0016)

Die `Run`-Scene ist die `main_scene` beim Boot. Sie ist bewusst dünn —
ihr einziger Job: alle Autoloads zusammenführen und einen Run starten.

**Scene-Hierarchie**

```
Run (Node2D, root)
├── PlayerSlot (Node)        ← PlayerCharacter wird hier instantiiert
└── EnemyContainer (Node)    ← Spawn-Root für EnemyMobs
```

**_ready-Sequenz**

```
1. (defensive) RunState.end + reset, falls schon RUNNING
2. ContentLoader.get_or_null(&"dino", dino_id)
3. dino.character_scene.instantiate() → PlayerSlot.add_child
4. player.set_dino(dino)
5. WaveSpawner.set_spawn_root($EnemyContainer)
6. RunState.start(dino_id)
```

**Konfiguration**

```gdscript
@export var dino_id: StringName = &"trex"
@export var demo_enemy_id: StringName = &"raptor_grunt"
@export var demo_enemy_count: int = 3
```

`dino_id` ist Inspector-zugänglich — Char-Selection-UI wird das später
via Methoden-Call setzen.

**Testbarkeit**

Run-Scene lässt sich in Tests direkt instantiieren — alle Autoloads
laufen schon im Test-Setup. `_spawn_demo_enemies()` ist Test-Hook, der
3 Raptoren um den Player herum erzeugt.

**Nicht in v1**
- Auto-Spawn-Curves: WaveSpawner spawnt nicht von selbst (Backlog)
- HUD/UI: Visuelle Anzeigen kommen mit eigenem ADR
- Game-Over-Screen / Run-Restart: kommt mit Run-End-Flow-ADR
- Camera-Follow: eigenes ADR

## Pattern: Hit-Detection v1 (ADR 0011)

**Distanz-basiert** — kein Area2D, kein PhysicsServer. Pure Math, headless-
testbar, performant für 200+ Enemies.

**Group-Konvention**

| Group | Members | Wozu |
|-------|---------|------|
| `&"player"` | PlayerCharacter._ready | Enemies finden Player |
| `&"enemy"` | EnemyMob._ready | Player findet Enemies für Auto-Attack/Touch |

**Tick im PlayerCharacter._physics_process**

```gdscript
func _physics_process(delta):
    velocity = _compute_velocity(input)
    move_and_slide()
    _update_hit_detection(delta)

func _update_hit_detection(delta):
    # iframes runter zählen
    _invulnerable_for = max(0.0, _invulnerable_for - delta)

    # Auto-Attack-Tick alle 1/attack_rate Sekunden
    _attack_timer = max(0.0, _attack_timer - delta)
    if _attack_timer <= 0.0:
        _do_auto_attack()
        _attack_timer = 1.0 / _effective_attack_rate()

    # Touch-Damage (gestoppt während iframes)
    if _invulnerable_for <= 0.0:
        _check_touch_damage()
```

**Damage-Pfad**

| Quelle | Ziel | API |
|--------|------|-----|
| Player auto-attack | alle Enemies in attack_range | `dealer.deal_damage(enemy.health, info)` |
| Enemy touch | Player | `enemy.dealer.deal_damage(player.health, info)` |

→ Beide laufen durch DamageDealerComponent → Modifier-Pipeline (Crit,
Armor, Bonus) wirkt automatisch.

**Konstanten (v1)**

```gdscript
const TOUCH_HIT_RADIUS: float = 25.0     # Pixel
const IFRAMES_DURATION: float = 0.5      # Sekunden
const ATTACK_RANGE_FALLBACK: float = 80.0
```

**Spielfluss-Konsequenz**

Player läuft auf einen Enemy zu. Sobald Enemy in pickup_radius (Auto-
Attack-Range) ist, beginnt Player zu schlagen — automatisch im
attack_rate-Takt. Wird Player vom Enemy berührt, nimmt er Damage und
ist 0.5s unverwundbar. Touch-Damage trifft NUR den nähesten Enemy
(mehr-Enemy-Damage ist Boss-Mechanik, eigenes ADR).

**Mutations wirken automatisch**

```
Mutation: triceratops_horns (+15% damage)
→ MultiplierModifier(1.15) auf player.dealer
→ Auto-Attack mit 15 base × 1.15 = 17.25 Damage
→ Tested in test_auto_attack_respects_mutation_modifiers
```

## Pattern: Enemy-Movement v1 (ADR 0017)

**Direkt-Walk** Richtung nähestem Player. Pure Vector-Math, headless-
testbar, performant für 200+ Enemies.

```gdscript
# In EnemyMob._physics_process(delta):
if health.is_dead():
    return
var player := _find_nearest_player()
if player == null:
    return
var dir := (player.global_position - global_position).normalized()
global_position += dir * get_speed() * delta
```

**Speed**: aus `EnemyDef.speed` (raptor_grunt: 120 px/s).
**Player-Lookup**: über `&"player"`-Group (Konsistenz mit ADR 0011).

**Bewusst NICHT in v1**

- NavMesh / Pathfinding
- Schwarm-Avoidance
- AI-Modes (Patrol, Burst-Charge, Flee)
- Wand-Kollisionen (es gibt v1 keine Wände)

**Survivor-likes-Loop steht**

```
Player ←──── Enemy walks toward
       ←──── Enemy walks toward
       ←──── Enemy walks toward
       
Player kreist und schlägt zu →
Enemies in pickup_radius bekommen Damage
Enemies in TOUCH_HIT_RADIUS fügen Damage zu (mit iframes)
Tote Enemies stehen still, Player schlägt vorbei
```

## Pattern: HealthBar (ADR 0018)

Wiederverwendbare `Node2D`-Komponente für Game-World-HP-Bars über Mobs.
Kein EventBus — lokale Bindung an *eine* HealthComponent.

```gdscript
# In Player- oder Enemy-Scene:
$HealthBar.set_health($Health)

# HealthBar reagiert automatisch auf:
#   damage_taken  → Bar schrumpft
#   healed        → Bar wächst
#   died          → Bar versteckt sich (visible=false)
```

**Visual-Spec v1**

| Mob | Body | HP-Bar |
|-----|------|--------|
| Player | gelber ColorRect 24×24 | 30×4, grün, y=-22 |
| Enemy | roter ColorRect 16×16 | 20×3, orange, y=-16 |

**Test-Hook**

```gdscript
hpbar.get_displayed_pct()  # 0..1, für Verifikation in Tests
```

**Bewusst NICHT in v1**

- Animationen / Lerp / Tween-Anim
- Sprites statt ColorRects (kommt mit Sprites-ADR)
- Sub-Bar-Mechaniken (Shield, Armor)
- Damage-Number-VFX (eigenes ADR 0012)

## Pattern: Auto-Spawn-Curves v1 (ADR 0013)

WaveSpawner spawnt selbst. Prozedural in v1 (data-driven WaveDef ist
Backlog), Welle-skalierende Spawn-Rate, Player-relative Spawn-Position.

**Spawn-Curve**

```
Welle 1: 0.5 spawns/s   (1 Raptor alle 2.0s)
Welle 2: 0.8 spawns/s   (1 Raptor alle 1.25s)
Welle 3: 1.1 spawns/s   (1 Raptor alle 0.91s)
...
Welle 16+: 5.0 spawns/s (cap, sonst Performance-Tod)
```

**Tick-Logik**

```gdscript
# Im WaveSpawner._physics_process(delta):
if not _active:
    return
_tick_auto_spawn(delta)

# In _tick_auto_spawn(delta):
_auto_spawn_timer = max(0.0, _auto_spawn_timer - delta)
if _auto_spawn_timer <= 0.0:
    _do_auto_spawn()
    _auto_spawn_timer = _current_spawn_interval
```

**Spawn-Position**

Zufälliger Punkt auf Kreis (`SPAWN_RADIUS_FROM_PLAYER = 400px`) um den
nähesten Player. Group-Lookup `&"player"`. Fallback bei keinem Player:
Origin (0,0).

**Lifecycle-Hooks**

| Event | Auto-Spawn-Verhalten |
|-------|---------------------|
| `EventBus.run_started` | _active=true, Welle 1 startet, Timer setzt |
| `_start_next_wave` | _current_spawn_interval = 1/rate |
| `EventBus.run_ended` | _active=false, Timer reset |

**Daten-getrieben kommt später**

WaveDef als Content-Resource ist Backlog (eigenes ADR). Dann lädt der
WaveSpawner pro Welle eine WaveDef mit spawn_table, mehreren Enemy-Typen,
Burst-Patterns. v1-API bleibt kompatibel.

## Pattern: Game-Over + Run-Restart (ADR 0019)

CanvasLayer-Overlay über der Run-Scene. Welt bleibt im Hintergrund
sichtbar. Restart per `restart`-Action (Enter / R).

**Lifecycle**

```gdscript
# RunScene listened auf run_ended:
EventBus.run_ended.connect(_on_run_ended)

func _on_run_ended(reason, run_time):
    $GameOverLayer.show_run_ended(reason, run_time, WaveSpawner.current_wave())

func _input(event):
    if event.is_action_pressed("restart") and RunState.is_ended():
        restart_run()

func restart_run():
    # Cleanup Enemies + Player
    for child in enemy_container.get_children():
        child.queue_free()
    if _player != null:
        _player.queue_free()
    # RunState reset, Overlay verstecken, neuer Run
    RunState.reset()
    $GameOverLayer.hide_overlay()
    _spawn_player_and_start()
```

**Input-Action**

`restart`: `Enter` (KEY_ENTER) + `R` (KEY_R).

**GameOverOverlay-API**

```gdscript
show_run_ended(reason: StringName, run_time: float, wave: int) -> void
hide_overlay() -> void
is_shown() -> bool
```

**Test-Hook**

`RunScene.restart_run()` ist headless-aufrufbar — kein Input-Mock nötig.

**Verbotene Pattern**
- change_scene_to_packed beim Tod (Welt-Hintergrund verschwindet)
- Auto-Restart ohne User-Confirm (Frustration)

## Pattern: HUD-Overlay (ADR 0020)

CanvasLayer-Overlay mit drei Anzeigen: Run-Timer, Wave-Counter,
Mutation-Liste. Lauscht auf EventBus + pollt RunState pro Frame.

**Scene-Layer-Konvention**

```
RunScene (Node2D, root)
├── PlayerSlot       (game-world)
├── EnemyContainer   (game-world)
├── HUDLayer         (CanvasLayer, layer=50)   ← In-Game-HUD
└── GameOverLayer    (CanvasLayer, layer=100)  ← darüber bei Tod
```

**HUD-Anzeigen**

| Element | Position | Quelle |
|---------|----------|--------|
| Wave-Label | oben links | EventBus.wave_started |
| Timer-Label | oben mitte | _process pollt RunState.get_run_time |
| Mutations-Label | oben rechts | EventBus.mutations_changed → PlayerMutations.get_picked |

**Format-Helper (testbar)**

```gdscript
HUDOverlay._format_time(125.0) → "2:05"
HUDOverlay._format_time(63.0)  → "1:03"
HUDOverlay._format_time(-5.0)  → "0:00"  # clamp
```

**Lifecycle**

- `EventBus.run_started` → HUD wird sichtbar, Timer = 0:00, Wave = 1
- `EventBus.run_ended` → HUD wird unsichtbar (GameOver darüber)
- `EventBus.wave_started(idx, diff)` → "Wave N
×1.X" wenn diff > 1
- `EventBus.mutations_changed` → Liste aus PlayerMutations.get_picked

**Bewusst NICHT in v1**

- HP-Anzeige im HUD (HealthBar über Mob reicht)
- Damage-Numbers (eigenes ADR)
- i18n der Labels (Dev-Strings v1)
- Pause-Menü-Integration
- Mutation-Tooltips bei Hover

## Pattern: Mutation-Pick-Phase (ADR 0021)

Nach jeder Welle pausiert das Spiel und der Spieler wählt eine von 3
zufälligen Mutationen. Implementiert via `auto_advance`-Flag auf
WaveSpawner + PickOverlay als CanvasLayer.

**Lifecycle**

```
WaveSpawner._on_wave_timeout
  → EventBus.wave_cleared.emit(idx)
  → if auto_advance: _start_next_wave  (Default-Pfad)
                else: warten auf request_next_wave
                      ↑
MutationPickOverlay._on_wave_cleared
  → show_pick_phase()
    → 3 zufällige nicht-gepickte Mutationen (oder weniger)
    → get_tree().paused = true
    → visible = true
  → Spieler klickt Button N
  → _on_pick(offered_ids[N])
    → PlayerMutations.pick(id)
    → hide_overlay()
      → get_tree().paused = false
      → WaveSpawner.request_next_wave()  ← startet nächste Welle
```

**WaveSpawner-Konvention**

```gdscript
@export var auto_advance: bool = true   # Default Backward-kompat
WaveSpawner.request_next_wave()         # Public, no-op wenn !active
```

MutationPickOverlay setzt im _ready: `WaveSpawner.auto_advance = false`.

**Edge-Cases**

| Verfügbare Mutationen | Verhalten |
|----------------------|-----------|
| 0 (alle gepickt) | Phase übersprungen, sofort request_next_wave |
| 1-2 | Entsprechende Buttons sichtbar, Rest hidden |
| 3+ | 3 zufällige, Rest hidden |

**Layer-Stack der RunScene**

```
Run (Node2D)
├── PlayerSlot, EnemyContainer  (game-world)
├── HUDLayer            layer=50   (sichtbar während Run)
├── MutationPickLayer   layer=80   (während Pick-Phase)
└── GameOverLayer       layer=100  (bei Tod)
```

**Bewusst NICHT in v1**

- Rarity-gewichtete Picks (eigenes ADR)
- Reroll gegen Currency
- Tooltips bei Hover
- Pause-aware Run-Timer (HUD-Timer läuft real-time während Pause)

## Pattern: Rarity-Weighted Picks (ADR 0022)

Pick-Phase wählt Mutationen gewichtet nach Rarity statt uniform-zufällig.

**Standard-Verteilung (Survivor-likes-Konvention)**

| Rarity | Gewicht | Erwartet pro Pick |
|--------|---------|-------------------|
| Common | 70 | ~70% |
| Rare | 25 | ~25% |
| Epic | 4.5 | ~4.5% |
| Legendary | 0.5 | ~0.5% |

Effektive Wahrscheinlichkeit pro Mutation hängt vom Pool ab:
mehrere Common erhöhen die Gesamt-Common-Chance, jedes einzelne wird
seltener.

**Implementation**

```gdscript
# In MutationPickOverlay:
const RARITY_WEIGHTS := { &"common": 70.0, &"rare": 25.0, ... }

func _weighted_pick_one(pool):
    var weight_sum := pool.map(weight).sum()
    var roll := _rng.randf() * weight_sum
    var cumulative := 0.0
    for m in pool:
        cumulative += weight(m.rarity)
        if roll <= cumulative:
            return m
```

**Without-Replacement**

3 Picks pro Phase liefern 3 unique IDs. Nach jedem Pick wird die ge-
wählte Mutation aus dem Pool entfernt → keine Duplikate.

**RNG-Determinismus**

`set_rng(rng)` für deterministische Tests (analog zu CritModifier
in ADR 0010).

**Bewusst NICHT in v1**

- Player-Stat-Modifier auf Pick-Chance (z.B. „+10% Rare-Chance")
- Reroll gegen Currency
- Pity-Timer
- Mod-Hook für RARITY_WEIGHTS (Modder schreiben aktuell Patch)

## Pattern: Damage-Number-VFX (ADR 0012)

Floating-Numbers über getroffenem Mob bei jedem Treffer. **Lokal an
HealthComponent gebunden** — kein EventBus-Aufruf (Hot-Path-Schutz).

**Spawn-Pfad**

```
HealthComponent.take_damage(info)
  → damage_taken-Signal (lokal)
  → HealthBar._on_damage_taken
    → _update_visual (Bar schrumpft)
    → _spawn_damage_number(info) wenn spawn_damage_numbers=true
       → DamageNumber.show_damage(amount, is_crit, global_pos)
       → unter current_scene gehängt (überlebt Mob-queue_free)
```

**Visual-Spec (Crit-Variation)**

| Element | Standard | Crit |
|---------|----------|------|
| Farbe | weiß | gelb (#FFD000) |
| Font-Größe | 14 | 20 |
| Tween: rise | 30px | 50px |
| Tween: fade | 0.7s | 0.9s |
| Format | "15", "1.5K" bei ≥1000 | gleich |

**Bewusst NICHT in v1**

- Damage-Type-Farben (fire = orange, etc.) — eigenes ADR
- Object-Pool für Performance — eigenes ADR
- Hit-Flash auf Mob-Body — eigenes ADR
- Crit-Bubble bei extrem hohen Crits — eigenes ADR

**Testbarkeit**

`DamageNumber._format_amount` ist static — direkt testbar.
`HealthBar.spawn_damage_numbers = false` für Tests, die Damage ohne
VFX-Side-Effects testen wollen.

## Pattern: Wave-Pool-Rotation (ADR 0023)

`WaveSpawner` wählt aus einem **Welle-spezifischen Pool** statt fixem
Enemy-Typ. Pool wächst monoton mit Welle-Index.

```
Welle  1-2:  [raptor_grunt]
Welle  3-5:  + raptor_alpha
Welle  6-10: + pteranodon
Welle 11+:   + armored_carnotaurus
```

```gdscript
func _pool_for_wave(idx: int) -> Array[StringName]:
    if idx <= 2: return [&"raptor_grunt"]
    if idx <= 5: return [&"raptor_grunt", &"raptor_alpha"]
    if idx <= 10: return [&"raptor_grunt", &"raptor_alpha", &"pteranodon"]
    return [&"raptor_grunt", &"raptor_alpha", &"pteranodon", &"armored_carnotaurus"]

func _enemy_id_for_wave(idx: int) -> StringName:
    var pool := _pool_for_wave(idx)
    return pool[randi() % pool.size()]
```

**Pool-Wahl ist v1 uniform** — Rarity-gewichtete Spawns sind eigenes ADR.
**WaveDef als Content-Resource** ersetzt diesen Code mit Daten-Lookup
in einem späteren ADR.

## Pattern: Boss-Resource (Stub)

`tyrannosaurus_prime.tres` (BossDef) ist im ContentLoader registriert,
hat aber **keine Spawn-Mechanik in v1**. Boss-Spawn (mit BossMob-Scene,
Telegraphie, eigenem Death-Pfad zu `boss_defeated`) ist eigenes ADR.

```gdscript
var boss := ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
# boss.max_health == 800, boss.reward_currency_amount == 50
# boss.phases == []  (Schema kommt später)
```

## Pattern: Visuelle Enemy-Differenzierung (ADR 0024)

EnemyDef hat zwei Visual-Felder (`body_color`, `body_size`), EnemyMob
appliziert sie beim setup() auf das Body-ColorRect. HP-Bar-Position
skaliert automatisch mit body_size.

```gdscript
# In EnemyDef:
@export var body_color: Color = Color(0.82, 0.18, 0.18)  # rot default
@export var body_size: Vector2 = Vector2(16, 16)         # default

# In EnemyMob.setup(def, pos):
_apply_visuals(def)   # appliziert color + size + HP-Bar-Offset
```

**Color-Konvention v1**

| Enemy | Color | Size | Bedeutung |
|-------|-------|------|-----------|
| raptor_grunt | rot `#D03030` | 16×16 | Standard |
| pteranodon | himmelblau `#5AB8E8` | 14×14 | Flieger, klein/fragil |
| raptor_alpha | dunkelrot `#A02020` | 22×22 | Mid-Tier, stärker |
| armored_carnotaurus | braungrau `#7A6850` | 28×28 | Tank-Erdton |
| boss_tyrannosaurus_prime | dunkelviolett (geplant) | 40×40 | Wenn Spawn-Mechanik kommt |

**Sprite-Pfad ist offen**

Wenn Sprites kommen (eigenes ADR), wird EnemyMob einen weiteren
Visual-Mode bekommen: `body_color/size` für ColorRect-Mode,
`texture/animation` für Sprite-Mode. EnemyDef bleibt das gleiche
Resource — neue Felder werden additiv hinzugefügt.

## Pattern: Boss-Spawn (ADR 0025)

`BossMob` ist eine eigene Klasse mit gleichem Component-Pattern wie EnemyMob,
aber eigenem Death-Pfad: feuert `boss_defeated` statt `enemy_died`.

**Boss-Welle**

```gdscript
const BOSS_WAVE_INTERVAL: int = 5

func _is_boss_wave(idx: int) -> bool:
    return idx > 0 and idx % BOSS_WAVE_INTERVAL == 0
```

Welle 5, 10, 15, … sind Boss-Wellen. Bei Wave-Start spawnt der Boss EINMAL
zusätzlich zu normalen Auto-Spawns.

**BossMob-Architektur**

```
BossMob (Node2D)
├── Body (ColorRect, Visual via BossDef.body_color/size)
├── Health (HealthComponent, is_boss=true → unterdrückt enemy_died)
├── Dealer (DamageDealerComponent)
└── HealthBar (große Boss-Bar)

Groups:
- "enemy"  → Player-Auto-Attack greift
- "boss"   → Marker für UI/Telemetrie
```

**Death-Pfad (sauber getrennt)**

```
HealthComponent.take_damage → HP=0 → _die()
  if is_player: EventBus.player_died
  if is_boss:   return (Owner feuert selbst)
  else:         EventBus.enemy_died

BossMob._on_died (lokales Signal von Health):
  EventBus.boss_defeated(boss_id, run_time)
```

**Visual-Convention**

| Boss | Color | Size | HP | Speed | DMG |
|------|-------|------|-----|-------|-----|
| tyrannosaurus_prime | dunkelviolett | 40×40 | 800 | 80 | 40 |

**Nicht in v1**

- Boss-Phasen (`phases: Array[Dictionary]` bleibt leer)
- Boss-Intro-Card-VFX
- Boss-spezifische Abilities (Stomp, Roar)
- Music-Switch bei Boss-Spawn

## Pattern: MapDef als Content-Resource (ADR 0036)

Map-Layouts sind data-driven über `MapDef`-Resources im
`content/maps/`-Folder.

**Schema**

```gdscript
class MapDef extends ContentItem:
    @export var grid_size: Vector2i = Vector2i(8, 8)
    @export var path_row: int = 4         # -1 = kein Pfad
    @export var path_col: int = 4
    @export var deterministic_colors: bool = true
    @export var biome_label_key: StringName = &""
```

**IsoWorld-Integration**

```gdscript
IsoWorld.set_map_def(def: MapDef)  # übernimmt Konfig + rebuilds Tiles
IsoWorld.get_map_def() -> MapDef
```

**RunScene-Integration**

```gdscript
@export var map_id: StringName = &"default"

func _ready():
    var map_def := ContentLoader.get_or_null(&"map", map_id) as MapDef
    if map_def != null:
        iso_world.set_map_def(map_def)
```

**Default-Map**

`content/maps/default.tres` repliziert die heutigen hardcoded-Werte
(8×8, Cross-Pfad bei (4,4), deterministic_colors=true) — Backward-
Kompatibilität gewahrt.

**Modder-Workflow**

```
user://mods/my_mod/content/maps/desert.tres   # eigene Map
                                              # mit override_existing=false
                                              # → neue Map-ID, im Map-Selection-UI später wählbar
```

## Pattern: Y-Sort-Layering (ADR 0034)

In einer isometrischen Welt (ADR 0031) müssen Mobs nach ihrer
Y-Position rendern: weiter unten in der Welt = vor näher zur Kamera
liegenden Mobs. Godot 4 macht das automatisch via
`y_sort_enabled = true` auf einem Node2D-Container.

**Container-Struktur**

```
Run (Node2D)
├── PlayerSlot (Node2D, y_sort_enabled=true)
├── EnemyContainer (Node2D, y_sort_enabled=true)
```

Alle Mobs unter EnemyContainer/PlayerSlot werden automatisch nach
ihrer `global_position.y` (bzw. `y_sort_origin`) sortiert.

**Pivot-Konvention**

Ideal: Mob-Pivot sitzt am Fuß-Punkt (Y-Bottom). Bei ColorRect-Mobs
(v1) ist der Pivot in der Mitte — Y-Sort funktioniert grundsätzlich,
aber kann bei Mobs auf gleicher Y-Höhe leichte Render-Reihenfolge-
Wackler erzeugen. Sobald echte Sprites mit Foot-Point-Pivot landen
(ADR 0027 Visual-Provider), wird's pixel-perfect.

**Z-Index ergänzt Y-Sort**

WorldLayer hat `z_index = -10` → bleibt immer unter den Mobs,
unabhängig von Y. CanvasLayer-Overlays (HUD, GameOver) sind
koord-system-unabhängig und unbeeinflusst.

## Pattern: RunCamera (ADR 0032)

`RunCamera` ist eine `Camera2D`-Subklasse, die einem Target-Node2D mit
Smooth-Lerp folgt. Pure-Function-Update-Hook (`compute_next_position`)
macht das System headless-testbar.

**Lerp-Formel (Frame-Rate-Independent)**

```gdscript
alpha = 1.0 - exp(-smoothing * delta)
new   = lerp(current, target, alpha)
```

Bei `smoothing = 0.0` → harter Snap. `5.0` ist Standard für
Survivor-likes-Feel.

**Pixel-Snap**

`pixel_snap = true` (Default) rundet die Camera-Position auf ganze
Pixel. Wichtig für Pixel-Art — ohne das passieren Sub-Pixel-Wackler
beim Sprite-Render.

**Public-API**

```gdscript
RunCamera.set_target(node: Node2D)               # Target wechseln
RunCamera.snap_to_target()                       # hard snap (kein lerp)
RunCamera.set_follow_smoothing(value: float)
RunCamera.set_bounds(min: Vector2, max: Vector2) # auto-enable_limits
```

Pure Function:
```gdscript
RunCamera.compute_next_position(current, target, smoothing, delta, pixel_snap_enabled) -> Vector2
```

**RunScene-Integration**

```
Run (Node2D)
├── WorldLayer (z_index=-10)
│   └── IsoWorld
├── PlayerSlot
├── EnemyContainer
├── RunCamera ← folgt Player nach _spawn_player_and_start
├── HUDLayer (CanvasLayer)
├── MutationPickLayer
└── GameOverLayer
```

`run_camera.set_target(_player)` + `attach_to_world(iso_world)` +
`snap_to_target()` direkt nach Player-Spawn → kein "fly-in" beim
Run-Start, Camera klemmt automatisch am Plattform-Rand.

**Auto-Bounds (ADR 0033)**

`RunCamera.attach_to_world(iso_world)` liest `IsoWorld.world_bounds()`
und ruft `set_bounds()` damit auf. So bleibt die Camera auch bei
großem Player-Abstand vom Center innerhalb der Plattform.

**Bounds-Padding (ADR 0037)**

```gdscript
RunCamera.attach_to_world(world, padding)        # padding @ attach
RunCamera.set_bounds_padding(p)                  # zur Laufzeit ändern
RunCamera.compute_padded_bounds(world_rect, padding) → Rect2  # static pure
```

Padding ERWEITERT die Bounds nach außen → Camera kann den Charcoal-
Background außerhalb der Plattform zeigen. Default `Vector2.ZERO` →
strikt am Plattform-Rand wie ADR 0033.

`MapDef.camera_padding` ist die data-driven Source-of-Truth — RunScene
liest das beim attach. Modder können pro Map eigenes Padding wählen.

**Custom-Shake-Profiles (ADR 0039)**

```gdscript
class ShakeProfile extends Resource:
    @export var trauma_amount: float = 0.3
    @export var decay_per_second: float = 0.0  # 0 = Camera-Default
    @export var max_offset: float = 0.0          # 0 = Camera-Default
```

```gdscript
RunCamera.add_trauma_from_profile(profile: ShakeProfile)
RunCamera.register_signal_profile(signal_name, profile)  # für Mods
RunCamera.register_ability_profile(ability_id, profile)  # boss_ability_used
```

Default-Profiles in `core/world/profiles/`:
- `profile_player_damaged.tres` (0.3 trauma)
- `profile_boss_defeated.tres`  (0.7 trauma)
- `profile_boss_stomp.tres`     (0.5 trauma)

`EventBus.boss_ability_used` löst pro Ability-ID ein Profile aus —
Default nur für `tyrannosaurus_stomp`. Modder können via
`register_ability_profile` eigene Mappings ergänzen.

Hardcoded `trauma_on_player_damaged`-Properties bleiben als Fallback —
wenn ein Signal kein Profile-Mapping hat, fällt RunCamera auf den
Standardwert zurück (Backward-Kompat ADR 0035).

**Camera-Shake (ADR 0035, Trauma-System)**

```gdscript
RunCamera.add_trauma(0.3)      # +Trauma von 0.0–1.0 (clampt)
RunCamera.set_trauma(0.5)      # direkt setzen
RunCamera.compute_shake_offset(trauma, max_offset, rng) → Vector2 (static)
RunCamera.compute_trauma_after_decay(trauma, decay_per_s, delta) → float (static)
```

EventBus-Hooks sind hardcoded:
- `player_damaged` → +0.3 Trauma
- `boss_defeated`  → +0.7 Trauma

Shake-Offset wirkt auf `Camera2D.offset` (additiv zur global_position),
sodass Follow-Lerp und Bounds-Clamping unverändert bleiben. Decay
ist Frame-Rate-Independent (1.5/s Standard).

**Zoom-Konvention**

Default `zoom = (2, 2)` für 1080p mit 540×270 logischen Pixeln.
Skaliert auf 4K auf 4×, etc. Modder können eigene Werte setzen.

**Nicht in v1**

- Camera-Shake (Trauma-Wert, exponentielles Decay)
- Mutation-Pick-Phase Zoom-In + Vignette
- Boss-Intro-Camera-Pan
- Camera-Bounds aus IsoWorld auto-berechnet
- Multi-Camera-Setup (Mini-Map, Boss-Cam)

## Pattern: Iso-World + Palette (ADR 0031)

`IsoWorld` ist ein Tile-Map-Skelett, das beim `_ready()` ein Grid von
Iso-Diamonds als `Polygon2D` baut. Sobald echte Sprite-Tiles landen,
wird `IsoWorld` auf `TileMapLayer + TileSet` umgebaut — gleicher Layout-
Code, andere Render-Quelle. **Public-API bleibt stabil.**

**Iso-Math (pure functions, statisch)**

```gdscript
IsoWorld.tile_to_iso(Vector2i(x, y), tile_size = (64, 32)) -> Vector2
IsoWorld.iso_to_tile(Vector2(px, py)) -> Vector2i
```

Konvention: `(0,0)` ist World-Origin. `(1,0)` → `(32, 16)` (rechts-unten).
`(0,1)` → `(-32, 16)` (links-unten). Roundtrip ist identity.

**Layout (RunScene)**

```
Run (Node2D)
├── WorldLayer (Node2D, z_index = -10)
│   └── IsoWorld (Polygon2D-Tiles)
├── PlayerSlot
├── EnemyContainer
├── HUDLayer (CanvasLayer, layer 50)
├── MutationPickLayer (CanvasLayer, layer 80)
└── GameOverLayer (CanvasLayer, layer 100)
```

WorldLayer hat negativen Z-Index → alle Mobs rendern darüber. CanvasLayer-
Overlays sind koord-system-unabhängig.

**Single-Source-of-Truth Palette**

`core/art/palette.gd` zentralisiert alle Color-Konstanten aus
[`docs/art/VISUAL-TARGET.md`](art/VISUAL-TARGET.md). EnemyDef/BossDef/
HUD/IsoWorld lesen ihre Default-Farben hier ab. Mod-Resourcen können
eigene Werte setzen — die Palette ist nur Fallback.

**Asset-Drop-Pfad**

```
art/
├── tiles/   (64×32 Iso-PNGs)
├── decor/   (Blumen, Crystals)
├── player/  (AnimatedSprite2D-Scenes)
├── enemies/ (pro Variante eine .tscn)
├── bosses/
├── pickups/
├── ui/      (Pixel-Font, 9-Slice)
└── audio/   (.ogg-Streams für SoundDef.stream)
```

Jeder Subfolder hat ein README mit Sprite-Spec (Größe, Frames, Pivot).
Sobald echte Sprites landen, werden sie in `*.tres`-Files via
`visual_scene` (ADR 0027) bzw. `stream` (ADR 0028) referenziert.

**Nicht in v1**

- TileSet-Authoring-Workflow (kommt mit echten Sprite-Tiles)
- Camera2D-Player-Follow + World-Boundaries
- Y-Sort-Layering (Mobs vor/hinter Decor je nach Y-Position)
- Procedural-Tile-Placement
- MapDef als Content-Resource (Map-Layouts data-driven definierbar)

## Pattern: Meta-Shop + UpgradeDef (ADR 0040)

`UpgradeDef` ist ein Content-Resource, das permanente Meta-Upgrades
definiert (Damage, HP, Speed, Pickup-Radius). Im Shop-Overlay kaufbar
mit Bernstein-Currency, persistent über Save-System.

**Schema**

```gdscript
class UpgradeDef extends ContentItem:
    @export var max_level: int = 1
    @export var cost_per_level: Array[int] = [50]
    @export var stat_modifiers_per_level: Array[Dictionary] = [{}]
    @export var cost_currency: StringName = &"amber"
```

`stat_modifiers_per_level` nutzt das gleiche Schema wie
`MutationDef.stat_modifiers` — `MutationModifierBridge.build()` wandelt
sie in Modifier-Resourcen um (gleiche Pipeline).

**MetaProgression-API**

```gdscript
MetaProgression.get_upgrade_level(id) -> int
MetaProgression.get_upgrade_cost(id) -> int   # Cost für nächsten Level
MetaProgression.can_afford_upgrade(id) -> bool
MetaProgression.purchase_upgrade(id) -> bool
MetaProgression.list_upgrade_levels() -> Dictionary
MetaProgression.get_aggregated_modifiers() -> Dictionary  # für Player-Stats
```

**EventBus**

```gdscript
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
```

**PlayerCharacter-Integration**

`PlayerCharacter.get_aggregated_or_empty()` mergt
`PlayerMutations.get_aggregated()` mit
`MetaProgression.get_aggregated_modifiers()`. Beide Quellen wirken
additiv auf den Player-Modifier-Stack.

`EventBus.upgrade_purchased` triggert `_apply_stats` neu — Player sieht
Upgrade sofort wirksam.

**Shop-Overlay**

`core/ui/shop_overlay.gd` (CanvasLayer auf layer=90, zwischen
MutationPickLayer und GameOverLayer). Listet alle Upgrades aus
ContentLoader, zeigt Cost + aktuelles Level + Buy-Button.

**Save-Schema (v1.2, additive)**

```json
"data": {
  "meta_progression": {"amber": 250},
  "upgrade_levels": {
    "stronger_jaws": 2,
    "faster_legs": 1
  }
}
```

Saves vor v0.2.0 ohne `upgrade_levels`-Slot werden korrekt geladen
(Default `{}`). **Keine Migration-File nötig.**

**Loop ist geschlossen**

```
Run → Bernstein verdienen → Run-Ende → SHOP →
Upgrade kaufen → Nächster Run mit permanentem Buff
```

**Nicht in v1**

- Multi-Tab-Shop (Stat / Dino / Cosmetic)
- Upgrade-Dependency-Tree
- Refund-Mechanik
- Multiple Currency-Typen
- Pause-Menü mit Shop-Zugang

## Pattern: Persistente Meta-Progression (ADR 0030)

`MetaProgression` ist ein Autoload-Tracker für Run-übergreifende
Currencies (in v1: Bernstein/`amber`). Bossen droppen
`reward_currency_amount` automatisch. Save/Load wird über das EventBus-
Save-Protokoll abgewickelt.

**EventBus-Driven**

```
EventBus.boss_defeated  → MetaProgression.add_currency(amber, def.reward)
EventBus.save_requested → MetaProgression schreibt seinen Slot in SaveSystem
EventBus.save_loaded    → MetaProgression liest seinen Slot aus SaveSystem
```

Game-Code feuert nie direkt `MetaProgression.add_currency()` — alles
geht durch den EventBus. Test-Code und Mods dürfen direkt aufrufen.

**Public-API**

```gdscript
MetaProgression.get_currency(id = &"amber")    -> int
MetaProgression.add_currency(id, amount)        -> int   # neuer Wert
MetaProgression.set_currency(id, value)         -> void
MetaProgression.list_currencies()               -> Dictionary
MetaProgression.reset()                          -> void  # Test-Hook
```

**Save-Schema (v1.1, additive)**

```json
{
  "schema_version": 1,
  "data": {
    "meta_progression": {
      "amber": 250
    }
  }
}
```

Saves vor v0.1.0 (ohne `meta_progression`-Slot) werden korrekt geladen
— MetaProgression startet mit Default-State (amber=0). Kein
Schema-Bruch, keine Migration-File.

**Run-Ende-Trigger**

`RunScene._on_run_ended` feuert `save_requested(&"run_end")`, sodass
Bernstein nach jedem Run automatisch persistiert wird (Player-Death,
Boss-Defeat, Quit). Atomic-Write durch SaveSystem.

**Nicht in v1**

- Meta-Shop-UI (Bernstein gegen permanente Upgrades)
- Multiple Currency-Typen (Schema unterstützt es, Game füllt nur amber)
- Currency-Pickups als World-Items (Coin-Sprites einsammeln)
- Currency-Drops von Enemies (nicht nur Bossen)

## Pattern: Boss-Abilities (ADR 0038)

Pro `BossPhase` kann ein Array von `BossAbility`-Resources hinterlegt
werden. BossMob tickt diese periodisch — jede Ability hat einen
eigenen Cooldown.

**BossAbility-Schema**

```gdscript
class BossAbility extends Resource:
    @export var id: StringName
    @export var cooldown: float = 5.0
    @export var initial_delay: float = 1.0

    func trigger(_boss: Node) -> void:
        pass  # virtual — Subclass überschreibt
```

**Erste konkrete Subklasse: BossStomp**

AOE-Damage in einem Radius um den Boss. Pure-Function-Helper
`find_player_health_in_radius(center, radius, players)` ist headless-
testbar.

**BossMob-Tick**

```gdscript
func _physics_process(delta):
    if health.is_dead(): return
    _move_toward_player(delta)
    _tick_abilities(delta)

func _tick_abilities(delta):
    var phase := _def.phases[_current_phase_idx]
    for ability in phase.abilities:
        var cd := _ability_cooldowns.get(ability.id, ability.initial_delay)
        cd -= delta
        if cd <= 0.0:
            ability.trigger(self)
            cd = ability.cooldown
        _ability_cooldowns[ability.id] = cd
```

**Phase-Wechsel-Reset**

Beim Phasen-Wechsel werden `_ability_cooldowns` gelöscht. Neue Phase
startet mit `initial_delay` pro Ability.

**EventBus**

```gdscript
signal boss_ability_used(boss_id, ability_id, position)
```

UI/SFX/VFX-Hooks subscriben hier (z.B. Telegraph-Anim am Stomp-Center,
SFX, Camera-Shake-Trigger).

**tyrannosaurus_prime — Stomp**

Rage-Phase (HP <= 33%) bekommt `tyrannosaurus_stomp`:
cooldown=4s, initial_delay=1.5s, radius=140px, damage=25.

**Nicht in v1**

- Telegraph-VFX (Vorwarn-Indikator)
- BossRoar/BossCharge/BossSpawnAdds
- Conditional-Abilities

## Pattern: Boss-Phasen (ADR 0029)

`BossDef.phases: Array[BossPhase]` definiert HP-Threshold-basierte
Verhaltens-Wechsel. Jede Phase hat Speed-/Damage-Multiplikatoren und
einen Color-Tint.

**Resource-Schema**

```gdscript
class BossPhase extends Resource:
    @export var hp_threshold: float = 1.0       # 0.0–1.0
    @export var speed_multiplier: float = 1.0
    @export var damage_multiplier: float = 1.0
    @export var color_tint: Color = Color.WHITE
    @export var label_key: StringName = &""     # i18n für Banner
```

**Resolver-Logik** (im BossMob)

```gdscript
# Phasen sortiert: 1.0 (Spawn) zuerst, 0.0 (Final) zuletzt.
# Aktive Phase = letzte Phase mit hp_threshold >= current_hp_pct.
# MONOTON: Index darf nur steigen, kein Rückfall bei Heal.
```

**Phase-Transition triggert EventBus**

```gdscript
EventBus.boss_phase_changed(boss_id, phase_index, label_key)
```

UI/SFX/VFX-Hooks:

- HUD zeigt Banner mit `tr(label_key)` ("T-PRIME: WAHNSINN!")
- SfxBus könnte `sfx_boss_phase_change` triggern (über add_signal_mapping)
- Camera-Shake bei Phase-Wechsel (eigenes ADR)

**tyrannosaurus_prime-Phasen**

| Phase | HP-Threshold | Speed × | Damage × | Tint |
|-------|--------------|---------|----------|------|
| 0 Spawn | 1.0 | 1.0 | 1.0 | weiß |
| 1 Mid | 0.66 | 1.2 | 1.15 | leicht rosa |
| 2 Rage | 0.33 | 1.5 | 1.4 | rot |

**Backward-Kompat**

`def.phases = []` → Boss verhält sich wie vor ADR 0029
(`get_current_phase_index() == -1`, Speed/Damage = base).

**Nicht in v1**

- Boss-Abilities pro Phase (Stomp, Roar)
- Phase-spezifischer Add-Spawn-Pool
- Phase-Timer (zwingender Wechsel nach 30s)
- Phase-Transition-VFX

## Pattern: SFX-Bus (ADR 0028)

`SfxBus` ist ein Autoload-Bridge zwischen EventBus-Signals und Audio-
Playback. Game-Code feuert nie selbst SFX — alles geht über bedeutsame
EventBus-Signale.

**Signal → Sound-Mapping**

```gdscript
const SIGNAL_TO_SOUND: Dictionary = {
    &"enemy_died":      &"sfx_enemy_died",
    &"boss_defeated":   &"sfx_boss_defeated",
    &"player_damaged":  &"sfx_player_damaged",
    &"player_died":     &"sfx_player_died",
    &"mutation_picked": &"sfx_mutation_picked",
    &"wave_started":    &"sfx_wave_started",
}
```

**Pool-Architektur**

Pool von 8 `AudioStreamPlayer`-Instanzen, Round-Robin-Allocation —
verhindert Audio-Cut-off bei vielen parallelen Treffern.

**SoundDef-Resource**

```gdscript
class SoundDef extends ContentItem:
    @export var stream: AudioStream            # null = no-op (v1-Default)
    @export var volume_db: float = 0.0
    @export var pitch_random_range: float = 0.0  # ±-Range pro Playback
```

**No-op-v1**

Alle 6 initialen SoundDefs haben `stream = null`. SfxBus skippt diese
als no-op. Sobald echte .ogg-Files landen, werden sie einfach im
.tres referenziert — kein Code-Touch.

**Mod-API**

```gdscript
SfxBus.add_signal_mapping(signal_name, sound_id)
SfxBus.set_muted(true)   # globale Stumm-Schaltung (Test-Hook)
SfxBus.play(sound_id)    # explizit triggern
```

**Nicht in v1**

- Music-Streaming (BG-Tracks, Loop-Punkte, Cross-fade)
- 3D-positionales Audio (`AudioStreamPlayer2D`)
- Audio-Bus-Mixer (Master/SFX/Music-Volume-Slider)
- SFX-Cooldown-Logik (vermeidet Audio-Spam bei Schwarm-Damage)
- Audio-Ducking

## Pattern: Visual-Provider (ADR 0027)

`EnemyDef`, `DinoDef` und `BossDef` haben einen optionalen Slot
`visual_scene: PackedScene`. Wenn gesetzt, instanziert der Mob die Scene
und versteckt den ColorRect-Body. Sonst bleibt der ColorRect-Mode aktiv
(ADR 0024).

**Migrations-Pfad zu Sprites**

```gdscript
# Default — kein Visual-Asset, ColorRect zeigt body_color/body_size
visual_scene = null

# Sprite einhängen
visual_scene = preload("res://art/raptor_grunt.tscn")
visual_pivot_offset = Vector2(0, -4)  # HealthBar etwas anheben
```

**Mob-Logik (gemeinsames Pattern)**

```gdscript
func _apply_visuals(def) -> void:
    if def.visual_scene != null:
        _spawn_visual_scene(def.visual_scene)
        body.visible = false
    else:
        body.visible = true
        body.color = def.body_color
        body.size = def.body_size
```

**Modder-Surface**

Modder können eine PackedScene-Reference im .tres-File setzen — kein
Code nötig. Die Sprite-Scene muss eine Node2D-Wurzel haben, deren Pivot
auf (0, 0) zentriert ist. HealthBar-Anchor ist über `visual_pivot_offset`
korrigierbar.

**Nicht in v1**

- AnimatedSprite2D-State-Machine (Idle/Walk/Hit/Death-Dispatch)
- Sprite-Tinting für Variants (Modulate-Property)
- Hit-Flash-Shader bei damage_taken
- Z-Index-Layering pro Mob-Typ

## Pattern: WaveDef-Resolver (ADR 0026)

`WaveDef` ist eine Content-Resource, die Wellen-Composition data-driven
beschreibt. Der WaveSpawner liest WaveDefs über den ContentLoader und
fällt bei Bedarf auf hardcoded Konstanten zurück.

**Zwei Resource-Modi**

```gdscript
# Modus 1: Curve-Default (genau eine WaveDef trägt das Flag)
is_default = true
base_spawn_rate = 0.5         # Welle-1-Rate
spawn_rate_per_wave = 0.3     # +pro Welle
max_spawn_rate = 5.0          # Cap
enemy_pool = [...]            # Default-Pool für alle Wellen ohne Override

# Modus 2: Wave-Override (target_wave_index > 0)
target_wave_index = 5
enemy_pool = [&"raptor_grunt", &"raptor_alpha", &"pteranodon"]
boss_id = &"tyrannosaurus_prime"
duration_sec = 0.0            # 0 = Default-Dauer nutzen
```

**Resolver im WaveSpawner**

```gdscript
get_wave_def_for(idx) → Override-Match → Default → null
get_active_wave_def() → für current_wave()

# Pro Lookup (Spawn-Rate, Pool, Boss-ID): zuerst Override-WaveDef,
# dann Default-WaveDef, dann Konstanten-Fallback
```

**Backward-Kompatibilität**

Alle Konstanten (`BASE_SPAWN_RATE`, `BOSS_WAVE_INTERVAL`, …) bleiben im
Code als Fallback. Ohne `wave_default.tres` verhält sich der Spawner
exakt wie vor ADR 0026. Tests, die nur Konstanten kannten, laufen
weiter durch.

**Modder-Workflow**

Modder können `content/waves/wave_<id>.tres` ergänzen, um eine bestimmte
Welle zu überschreiben — z.B. „Welle 7 ist immer ein Pteranodon-Schwarm".
Override eines Core-Files via `override_existing = true` auf der Mod-
Resource (analog Mutation/Enemy-Override).

**Nicht in v1**

- Pacing-Modes (Rest-Welle, Slow-Welle, Elite-Welle)
- Pro-Spawn-Gewichte (heute uniform `randi() % pool.size()`)
- Wave-spezifische Difficulty-Multiplier
- Wave-Trigger-Conditions (z.B. „spawne nur wenn Mutation X gepickt")

## Pattern: Lokalisierung ab Tag 1

Jeder User-facing String läuft durch `tr("category.id.field")`. Keine
deutschen oder englischen Literale im Code. Translation-Keys werden
vom `localization-coordinator` in `locale/de.po` und `locale/en.po`
gepflegt.

Dev-Logs (`print()`, `push_error()`) sind ausgenommen — die sind nicht
User-facing.


## Pattern: ContentLoader

Alle Game-Inhalte (Mutationen, Gegner, Bosse, …) leben als `.tres`-Resources
unter `res://content/<type>/` (Core) und `user://mods/<mod_id>/content/<type>/`
(Mods). Game-Code greift NIE direkt mit `load("res://content/...")` zu —
immer über den Loader.

**Pfad-Layout**

```
content/
├── mutations/   <id>.tres   extends MutationDef
├── enemies/     <id>.tres   extends EnemyDef
└── bosses/      <id>.tres   extends BossDef
```

**Producer-Seite (content-author)**

`.tres` in den passenden Ordner legen, Script ist die jeweilige
Resource-Klasse (`MutationDef`, `EnemyDef`, …). Der Loader scannt
beim Boot, prüft ID-Convention, ruft `validate()` auf der Resource
auf, indexiert in `Dictionary[type][id]`.

**Consumer-Seite (Game-Code)**

```gdscript
# Panic bei unbekannt — für Code wo IDs IMMER existieren müssen
var mut: MutationDef = ContentLoader.get_item(&"mutation", &"triceratops_horns")

# Robust für Save-Loader oder Mod-Diff-Logik
var mut := ContentLoader.get_or_null(&"mutation", id)
if mut == null:
    # Save referenziert nicht-existente ID → Migration nötig
    ...

# Listing für UI / Debug
for m in ContentLoader.get_all(&"mutation"):
    ...
```

**Mod-Override-Regel**

Standard: Mod-Resource mit Core-ID → Boot-Warnung, Mod-Eintrag verworfen.
Mod muss `override_existing = true` setzen, um zu überschreiben — Loader
emittiert Warning + sammelt in `overrides_applied()`.

**Verbotene Pattern**

- `load("res://content/...")` direkt im Game-Code
- ID-Renames (Save-Refs brechen, Mod-Saves auch — siehe Prinzip 6)
- Hardcoded Stat-Werte im Code (immer aus ContentItem lesen)

## Aktive ADRs

| Nr   | Titel | Status |
|------|-------|--------|
| 0001 | Globaler EventBus | Accepted |
| 0002 | Save-System & Schema-Versionierung | Accepted |
| 0003 | ContentLoader & Resource-Konventionen | Accepted |
| 0005 | Mod-Loader & mod.json-Schema | Accepted |
| 0006 | Run-Lifecycle, Wave-Spawner & Dino-Resources | Accepted |
| 0007 | Combat-Pipeline (Component-Pattern, Damage-Flow) | Accepted |
| 0008 | Player-Character-Scene + Movement | Accepted |
| 0009 | Enemy-Mob-Pattern + Spawn-API | Accepted |
| 0016 | Run-Scene-Glue | Accepted |
| 0010 | Modifier-Pipeline (Crit, Bonus, Multiplier, Armor) | Accepted |
| 0011 | Hit-Detection v1 (distanz-basiert) | Accepted |
| 0012 | Damage-Number-VFX | Accepted |
| 0013 | Auto-Spawn-Curves v1 (prozedural) | Accepted |
| 0017 | Enemy-Movement v1 (Direkt-Walk) | Accepted |
| 0018 | Visueller Stub + HP-Bar | Accepted |
| 0019 | Game-Over-Overlay + Run-Restart | Accepted |
| 0020 | HUD (Run-Timer, Wave-Counter, Mutation-Liste) | Accepted |
| 0021 | Mutation-Pick-Phase nach jeder Welle | Accepted |
| 0022 | Rarity-gewichtete Mutation-Picks | Accepted |
| 0023 | Enemy-Variants + Boss-Resource (Stub) | Accepted |
| 0024 | Visuelle Enemy-Differenzierung | Accepted |
| 0025 | Boss-Spawn-Mechanik | Accepted |
| 0014 | Mutation→Modifier-Bridge | Accepted |
| 0015 | Player-Mutation-System (Aggregator) | Accepted |
| 0004 | EventRecorder & Telemetrie-Format | Backlog |
| 0005 | Mod-Loader Boot-Reihenfolge | Backlog |

## Test-Strategie

**GUT 9.4.0** ist im Repo eingecheckt unter `addons/gut/` — keine separate
Installation für Devs. Tests laufen headless via `tools/run_tests.sh`
(POSIX) oder `tools/run_tests.ps1` (Windows). CI läuft auf jedem Push
und PR (`.github/workflows/test.yml`).

**Aktueller Stand:**
- 3 Test-Scripts, 29 Tests, 80 Asserts, alle grün
- Laufzeit < 100ms

**Kategorien:**
- **Unit-Tests** in `tests/unit/` — pro System (event_bus, content_loader,
  save_system). Nutzen `watch_signals(EventBus)` + `assert_signal_emitted`
  statt lambda-Capture-Tricks (GDScript-Lambdas sind keine echten Closures).
- **Smoke-Scenes** in `tests/scenes/` — manuelle visuelle Verifikation,
  z.B. `test_event_bus.tscn` mit Button pro Signal.
- **Fixtures** in `tests/fixtures/` — Reference-JSON-Saves für
  Roundtrip- und Migration-Tests.

**Verbindlich:**
- Save-Migrations bekommen IMMER Test-Saves als JSON-Fixtures.
- Pro neuem System: eigene Test-Datei in `tests/unit/`.
- Pre-Merge: `./tools/run_tests.sh` muss grün sein.
- Test-Engineer-Agent (`.claude/agents/test-engineer.md`) ist verantwortlich.

## Build & Release

Wird durch `release-manager`-Agent koordiniert. Build-Script und
Steam-Upload sind noch nicht eingerichtet (Backlog).
