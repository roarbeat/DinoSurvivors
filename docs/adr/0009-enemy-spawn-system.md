# ADR 0009 – Enemy-Mob-Pattern + Spawn-API

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #7 testbar
- Voraussetzungen: ADR 0006 (Run-Lifecycle), ADR 0007 (Combat), ADR 0008 (Player-Scene)
- Wird vorausgesetzt von: Hit-Detection (ADR 0011), Auto-Spawn-Curves

---

## 1. Kontext

WaveSpawner ist heute ein Lifecycle-Skelett ohne tatsächliche Spawns
(ADR 0006 §1). Player-Char existiert (ADR 0008). Was fehlt: eine
Enemy-Scene und eine API, mit der Spawner und Game-Code Enemies in
die laufende Run-Scene einsetzen können.

Anforderungen v1:

- **EnemyMob** als generische Enemy-Scene, analog zur PlayerCharacter —
  EnemyDef-getriebener Stats-Container, HealthComponent + DamageDealer
- **enemy_id**-Konvention: Owner-Node hat ein `enemy_id`-Property, damit
  HealthComponent's Death-Pfad das richtige Bus-Signal feuert
  (siehe ADR 0007)
- **Spawn-API auf WaveSpawner**: `spawn_enemy_at(enemy_id, position)`
  liefert den frischen EnemyMob zurück
- **spawn_root-Konvention**: WaveSpawner ist Autoload, hat keine eigene
  Scene-Position. Game-Code setzt `WaveSpawner.set_spawn_root(node)`
  beim Run-Start; ohne spawn_root = no-op + warning
- Bewusst KEINE **Movement-Logik** in v1 — Enemies sind stationäre
  HP-Säcke. Movement kommt mit eigenem ADR oder mit Hit-Detection-Patch.
- Bewusst KEIN **Auto-Spawn** in v1 — Spawn-Curves (welcher Enemy in
  welcher Welle) sind Phase-2

## 2. Optionen

### Option A — Generische EnemyMob-Scene + setup(def, pos) (empfohlen)

```
EnemyMob (Node2D)
├── Health (HealthComponent, is_player=false)
└── Dealer (DamageDealerComponent, default_source_id=enemy_id)
@export var enemy_id: StringName
func setup(def: EnemyDef, pos: Vector2) -> void
```

WaveSpawner.spawn_enemy_at:
1. Holt EnemyDef vom ContentLoader
2. Instantiiert def.scene (oder Default-EnemyMob.tscn)
3. Ruft setup(def, pos) → setzt enemy_id, max_hp, position
4. Hängt unter spawn_root
5. Liefert die Instance zurück

**Pro**
- Konsistent mit Player-Pattern (ADR 0008)
- Eine Scene für alle Enemies — Variation kommt über Stats/Tags/Visuals
- spawn_at ist trivial mockbar in Tests (spawn_root als TestNode)

**Contra**
- Per-Enemy Custom-Visuals brauchen entweder Override-Scenes oder ein
  Sprite-Field auf EnemyDef (Backlog)

### Option B — Pro Enemy eine eigene Scene

raptor_grunt.tscn, trex_boss.tscn …

**Pro**
- Maximale Visuelle Differenzierung

**Contra**
- Code-Duplikation
- skaliert schlecht bei 20+ Enemies
- Mod-Workflow schwerer (Modder müssen Scene-Convention lernen)

### Option C — Procedural Enemies ohne Scene

Code-erzeugte CharacterBody2D + Components ohne `.tscn`.

**Pro**
- Keine Scene-Files

**Contra**
- Editor-Inspektion fehlt
- Custom-Setups (Sprites, Particles) schwer
- Konsistenz mit Player-Pattern verletzt

## 3. Empfehlung

**Option A** — generisches `enemy_mob.tscn` + setup-API.

**Begründung**
- Konsistent mit ADR 0008
- Eine Datei pro Verhaltens-Variante (v1 reicht eine — mehr werden
  durch Tags und Stats unterschieden, nicht durch Scene-Struktur)
- spawn_root-Konvention erlaubt headless-Tests via Test-Node

**WaveSpawner Public-API (Erweiterung)**

```gdscript
WaveSpawner.set_spawn_root(node: Node) -> void
WaveSpawner.get_spawn_root() -> Node
WaveSpawner.spawn_enemy_at(enemy_id: StringName, position: Vector2) -> EnemyMob
   # null bei: kein spawn_root, unbekannte ID, fehlende def.scene
```

**EnemyMob Public-API**

```gdscript
class_name EnemyMob extends Node2D

@export var enemy_id: StringName     # vom Spawner gesetzt
@onready var health: HealthComponent = $Health
@onready var dealer: DamageDealerComponent = $Dealer

func setup(def: EnemyDef, pos: Vector2) -> void
func get_def() -> EnemyDef
func get_health_component() -> HealthComponent
func get_dealer_component() -> DamageDealerComponent
```

**Death-Pfad (ADR 0007 §3)**

HealthComponent emittet `EventBus.enemy_died(enemy_id, position)` beim
Tod, sofern der Owner-Node ein `enemy_id`-Property hat. EnemyMob
erfüllt das per Convention.

**Beim Spawn**

1. Default-Position wird auf `pos` gesetzt (`global_position = pos`)
2. enemy_id wird vom Spawner aus dem `EnemyDef.id` übertragen
3. HealthComponent.max_hp = `def.max_health`
4. HealthComponent.reset_to_full()
5. DamageDealer.default_source_id = enemy_id

## 4. Konsequenzen

**Positiv**
- Erstmals **vollständiger Kreis**: ContentLoader → Spawn → Combat → Death-Signal
- WaveSpawner ist nicht mehr nur Skelett — hat echte Spawn-API
- Tests können Mini-Combat-Szenarien aufbauen (Player + 1 Enemy + ein Schlag)

**Negativ**
- spawn_root-Konvention ist nicht Compiler-erzwungen. Wenn Game-Code
  vergisst, ihn zu setzen, sind Spawns lautlos no-op (Mitigation: warning).
- v1 Enemies bewegen sich nicht — sie sind Trainings-Pflöcke. Kein
  Spielerlebnis ohne Movement-ADR.

**Risiken**
- **Risiko:** EnemyDef.scene ist null (initial — wir setzen es jetzt erst).
  → **Mitigation:** Spawner fällt auf default `enemy_mob.tscn` zurück,
  loggt warning. Ein neuer EnemyDef OHNE scene ist trotzdem spawnbar.
- **Risiko:** Mehrfache Spawns von gleicher ID erzeugen separate Nodes,
  enemy_died feuert mehrmals — das ist gewollt (Schwarm-Mechanik).
  Falls das in Tests stört: enemy_died-Counter prüfen.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/enemy/enemy_mob.gd`            EnemyMob-Script
- `core/enemy/enemy_mob.tscn`          EnemyMob-Scene mit Komponenten
- `core/wave_spawner.gd`               +set_spawn_root, +spawn_enemy_at
- `content/enemies/raptor_grunt.tres`  +scene-Reference
- `tests/unit/test_enemy_mob.gd`       gut-Tests
- `tests/unit/test_wave_spawner.gd`    +Spawn-Tests

Berührt später:
- ADR 0011 Hit-Detection: Area2D auf EnemyMob, Collision-Layer
- ADR — Enemy-Movement (AI-Stub, Bewegung Richtung Player)
- ADR — Spawn-Curves (welcher Enemy in welcher Welle wie oft)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Enemy-Movement / AI-Pattern
- ADR — Spawn-Position-Strategie (außerhalb Sichtkegel, Spawn-Layer)
- ADR — Despawn-Strategie (zu weit weg → cleanup)
