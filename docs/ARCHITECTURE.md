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
│   ├── player/                 ADR 0008
│   │   ├── player_character.gd
│   │   └── player_character.tscn
│   ├── enemy/                  ADR 0009
│   │   ├── enemy_mob.gd
│   │   └── enemy_mob.tscn
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
│       └── dino_def.gd
├── content/                    .tres-Resources (Mutationen, Gegner, Bosse, Dinos)
│   ├── mutations/
│   │   ├── triceratops_horns.tres
│   │   ├── spinosaur_sail.tres
│   │   └── ankylosaur_plates.tres
│   ├── enemies/
│   │   └── raptor_grunt.tres
│   └── dinos/
│       └── trex.tres
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
| 0013 | Auto-Spawn-Curves v1 (prozedural) | Accepted |
| 0017 | Enemy-Movement v1 (Direkt-Walk) | Accepted |
| 0018 | Visueller Stub + HP-Bar | Accepted |
| 0019 | Game-Over-Overlay + Run-Restart | Accepted |
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
