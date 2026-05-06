# ADR 0016 – Run-Scene als Glue zwischen Logik und Sicht

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0006 (Run-Lifecycle), ADR 0008 (Player-Scene), ADR 0009 (Enemy-Spawn)
- Wird vorausgesetzt von: Hit-Detection (ADR 0011), HUD/UI

---

## 1. Kontext

Die ganze logische Welt ist fertig (Autoloads + Player + Enemy + Mutations).
Was fehlt: eine **Glue-Scene**, die alles zusammenführt — Player wird
instantiiert, EnemyContainer als spawn_root gesetzt, RunState gestartet.

Anforderungen v1:

- **Eine Run-Scene** als `main_scene` beim Boot
- **Container-Konvention**: `PlayerSlot` und `EnemyContainer` als
  vorbereitete Nodes in der Scene-Hierarchie
- **Deklaratives Verhalten**: Alle Mechanik delegiert an Autoloads
  (RunState, WaveSpawner, PlayerMutations) — Run-Scene-Skript ist
  bewusst dünn
- **Demo-Spawn**: 3 Stub-Enemies beim Start, damit visuell sichtbar
  wird, dass die Pipeline läuft (kommt mit Auto-Spawn-Curves weg)
- **`@export var dino_id`**: konfigurierbar pro Scene-Instanz
  (für Tests + spätere Char-Selection)

Bewusst NICHT in v1:

- Auto-Spawn-Curves (eigenes ADR)
- HUD/UI (eigenes ADR)
- Game-Over-Screen, Run-Restart-Logik
- Camera-Follow (eigenes ADR)

## 2. Optionen

### Option A — Eine Run-Scene, dünnes Skript (empfohlen)

```
Run (Node2D, root, script)
├── PlayerSlot (Node)
│   └── (PlayerCharacter wird hier instantiiert)
└── EnemyContainer (Node)
    └── (EnemyMob-Instanzen werden hier gespawnt)
```

Run-Skript hat:
- @export `dino_id: StringName = &"trex"`
- _ready: instanziiert Player aus dino.character_scene, hängt unter
  PlayerSlot, ruft RunState.start, WaveSpawner.set_spawn_root(EnemyContainer)
- Public-API: `_spawn_demo_enemies()` als Test-Hook
- Listener auf `run_ended` für späteren Game-Over-Screen

**Pro**
- Klar, deklarativ, Test-friendly
- Kein Game-Logik im Scene-Skript — alles delegiert
- @export dino_id ist UI-zugänglich (für Char-Selection später)

**Contra**
- Zwei Container-Nodes mehr in der Scene-Hierarchie
- @export dino_id ist Inspector-only — Char-Selection via UI braucht
  später eigenen Hook (set_dino_id-Methode)

### Option B — Run-Logik in einer Klasse, manuell instanziieren

Run-Scene ist nur Visuals; ein `RunController`-Script läuft als
Autoload und managt das Setup.

**Pro**
- Run-Scene ist pure Hierarchy

**Contra**
- Zu viele Autoloads (jetzt 8), Boot-Order-Komplexität
- Test-Setup wird komplizierter

### Option C — Player und Enemies direkt in der Scene-Hierarchie

Pre-platzierter Player + Enemies im Scene-Editor.

**Pro**
- Editor-WYSIWYG

**Contra**
- Player wird nicht aus DinoDef.character_scene instantiiert →
  ID-basierte Char-Selection bricht
- Enemies pre-platziert ist konfigurations-getrieben, nicht
  daten-getrieben (Wave-Spawn-Logik passt nicht)

## 3. Empfehlung

**Option A** — Run-Scene mit dünnem Glue-Skript.

**Begründung**
- Konsistent mit ADR 0006 (RunState ist Autoload, Run-Scene triggert nur)
- Skalliert zur Char-Selection-UI ohne API-Bruch
- Headless-testbar via direkter Scene-Instanziierung

**Public-API (Run-Skript)**

```gdscript
class_name RunScene extends Node2D

@export var dino_id: StringName = &"trex"

func get_player() -> PlayerCharacter
func get_enemy_container() -> Node

# Test-Hook
func _spawn_demo_enemies() -> void
```

**Lifecycle**

```
_ready:
  1. resolve dino_id → DinoDef via ContentLoader.get_item
  2. var player := def.character_scene.instantiate()
  3. PlayerSlot.add_child(player); player.set_dino(def)
  4. WaveSpawner.set_spawn_root($EnemyContainer)
  5. RunState.start(dino_id)
  # Auto-Spawn-Curves kommen mit eigenem ADR. v1 ist Run-Scene
  # die meiste Zeit „leere Bühne" — Demo-Spawn ist Test-Hook.

_on_run_ended (signal):
  # v1: nichts. Game-Over-Screen kommt mit UI-ADR.
```

## 4. Konsequenzen

**Positiv**
- **Erstmals startbar im Editor** — F5 lädt run.tscn, Player erscheint,
  Demo-Enemies können getriggert werden
- Scene-Tree ist klar lesbar (PlayerSlot + EnemyContainer)
- Tests können das ganze Glue-Setup in 5 Zeilen verifizieren

**Negativ**
- Run-Scene-Skript ist Game-Setup-Glue, nicht Game-Logik. Wer
  „PlayerSlot enthält den aktuellen Player" als Convention nicht
  kennt, sucht zu lange.
  → Mitigation: get_player() / get_enemy_container() als API.

**Risiken**
- **Risiko:** dino_id falsch → ContentLoader.get_item panicked.
  → **Mitigation:** Fallback auf get_or_null + Log + Default-Trex.
- **Risiko:** Run-Scene wird mehrfach instantiiert (Hot-Reload, Quick-Restart)
  → mehrfaches RunState.start.
  → **Mitigation:** Run-Skript ruft RunState.reset() vor start, wenn
  schon RUNNING.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/run_scene/run.gd`              Glue-Skript
- `core/run_scene/run.tscn`            Scene mit PlayerSlot + EnemyContainer
- `project.godot`                      `run/main_scene = res://core/run_scene/run.tscn`
- `tests/unit/test_run_scene.gd`       gut-Tests

Berührt später:
- ADR 0011 Hit-Detection: Run-Scene bekommt Player-vs-Enemy-Layer
- ADR — HUD/UI: HP-Bar, Wave-Counter, Mutation-Picks
- ADR — Auto-Spawn-Curves: WaveSpawner spawnt selbst nach Welle-Tabelle

## 6. Folge-Entscheidungen (Backlog)

- ADR — Camera-Follow auf den Player
- ADR — Char-Selection-UI (vor Run-Start)
- ADR — Game-Over-Screen + Run-Restart
