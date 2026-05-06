# ADR 0006 – Run-Lifecycle, Wave-Spawner & Dino-Resources

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #7 alleine testbar
- Voraussetzungen: ADR 0001 (EventBus), ADR 0003 (ContentLoader), ADR 0002 (Save)
- Wird vorausgesetzt von: Combat-System (späteres ADR), UI/HUD-System

---

## 1. Kontext

Phase 0 hat das architektonische Skelett geliefert (Bus, Loader, Save, Mods).
Was fehlt: **ein Run hat noch nie stattgefunden**. Es gibt keinen Player-Char,
keine Wellen, keinen State der zwischen „im Menü" und „in einem Run" unterscheidet.

Bevor Combat oder UI gebaut werden kann, brauchen wir einen sauberen
Run-Lifecycle. Ziel dieses ADRs ist:

- **Run-State** als zentrale Quelle der Wahrheit (was läuft gerade, mit welchem Dino, welche Welle)
- **Wave-Lifecycle** als Zeit-getriebene Sequenz (Welle startet → Welle dauert N Sek. → Welle abgeschlossen → nächste)
- **Player-Charakter als Daten-Resource** (DinoDef), nicht im Code hardcoded
- **EventBus-Integration**: alle Lifecycle-Übergänge feuern Signals
- Bewusst **kein Combat** in diesem ADR — bleibt Logik-Skelett, das später
  von Combat-System ausgefüllt wird

## 2. Optionen

### Option A — Zwei Autoloads (RunState + WaveSpawner), Daten-getrieben (empfohlen)

`RunState` ist eine reine State-Maschine mit Run-Metadaten, kein Logik-Owner.
`WaveSpawner` ist ein eigenständiger Autoload, der den Wave-Timer hält und
EventBus-Signals feuert. Player-Char ist eine `DinoDef`-Resource (.tres),
die `RunState` referenziert.

**Pro**
- Klare SRP-Trennung: RunState ↔ WaveSpawner ↔ Combat (späterer Autoload)
- Beide alleine testbar (Prinzip #7)
- DinoDef als Resource bedeutet: neue Dinos sind reine Content-Adds
- WaveSpawner kann später für Combat-System Spawns triggern, ohne dass
  RunState davon erfährt

**Contra**
- Zwei Autoloads mehr — Boot-Order-Disziplin erforderlich

### Option B — Ein "GameDirector"-Autoload mit allem drin

State + Spawner + Combat-Glue in einer Klasse.

**Pro**
- Weniger Autoloads
- Cross-cutting Logik einfacher

**Contra**
- Verletzt SRP von Anfang an
- Schlecht testbar (Mock vom Combat-Teil hindert State-Tests)
- Wachsende God-Class

### Option C — Scene-basierter Run, kein Autoload

Run-Logik lebt in der Run-Scene, die beim Run-Start instanziiert wird.

**Pro**
- Lifecycle ist an Scene-Lifecycle gekoppelt — automatisches Cleanup

**Contra**
- HUD/UI bräuchte Scene-Tree-Lookups (`get_tree().get_first_node_in_group()`)
- Save-System kann nicht ohne weiteres Run-Daten lesen
- Mod-Hooks haben keinen stabilen Zugriffspunkt

## 3. Empfehlung

**Option A** — zwei Autoloads, `DinoDef` als Resource.

**Begründung**
- Saubere SRP, alleine testbar
- Konsistent mit ADR 0001 (EventBus als Nervensystem) und ADR 0003 (Daten in Resources)
- WaveSpawner kann für Tests trivial gemockt werden via `set_wave_duration()`
- HUD/UI/Mods haben einen stabilen Zugriffspunkt

**RunState — Zustände**

```
       run_start_requested
   IDLE ─────────────────────► RUNNING
                                 │
                                 │  player_died
                                 │  ODER manueller Quit
                                 ▼
                                ENDED
                                 │
                                 │  reset()
                                 ▼
                                IDLE
```

Genau drei Zustände in v1: `IDLE`, `RUNNING`, `ENDED`. Boss-Fight-Phase
ist KEINE eigener Zustand — Boss läuft innerhalb von RUNNING als spezielle
Welle (BossDef hat `is_boss_wave: true` o.ä., das WaveSpawner respektiert).

**RunState — Public-API**

```gdscript
RunState.start(dino_id: StringName) -> bool      # IDLE → RUNNING
RunState.end(reason: StringName) -> void         # RUNNING → ENDED
RunState.reset() -> void                         # ENDED → IDLE
RunState.is_running() -> bool
RunState.is_idle() -> bool
RunState.get_active_dino() -> DinoDef            # null wenn idle
RunState.get_run_time() -> float                 # Sekunden seit Start
RunState.get_current_wave() -> int               # vom WaveSpawner gefüllt
```

**WaveSpawner — Verantwortung**

In v1: rein zeitgesteuert, **kein tatsächliches Spawnen**. Hält einen Timer,
der nach einer wave_duration `wave_cleared` feuert und (sofern Run noch läuft)
sofort die nächste Welle mit höherem Index startet.

```gdscript
WaveSpawner.set_wave_duration(seconds: float) -> void  # Default 30
WaveSpawner.is_active() -> bool
WaveSpawner.current_wave() -> int
```

WaveSpawner subscribed `run_started` / `run_ended` automatisch und steuert
seinen Timer entsprechend. Game-Code triggert WaveSpawner NICHT direkt.

**Neue EventBus-Signals**

- `run_started(dino_id: StringName)`
- `run_ended(reason: StringName, run_time: float)`

`reason` ist eine StringName wie `&"player_died"`, `&"player_quit"`,
`&"boss_defeated_final"`. Argumente werden bei jeder neuen RunEnd-Reason
ergänzt, nicht ersetzt (additiv).

**DinoDef — Resource-Schema**

```gdscript
class_name DinoDef extends ContentItem

@export var max_health: float
@export var base_speed: float
@export var base_damage: float
@export var base_attack_rate: float    # Attacks pro Sekunde
@export var pickup_radius: float
@export var character_scene: PackedScene  # PlayerController-Scene, später
```

`character_scene` bleibt in v1 nullable — Combat-System fügt das später.

**Boot-Order**

```
1. EventBus
2. ContentLoader
3. SaveSystem
4. ModLoader
5. RunState         ← neu, MUSS nach ContentLoader (referenziert DinoDef)
6. WaveSpawner      ← neu, subscribed run_started/run_ended am EventBus
```

## 4. Konsequenzen

**Positiv**
- Erstmals feuert der EventBus in einer echten Spiel-Pipeline
- Tests können einen kompletten Run simulieren in unter einer Sekunde
- HUD-/UI-Implementation hat klare Zugriffspunkte (RunState.get_run_time(), …)
- Neue Dinos = neue `.tres`-Files, kein Code-Change

**Negativ**
- WaveSpawner ist v1 ein "fakespawner" ohne tatsächliche Gegner. Risiko:
  Pattern erstarrt, bevor echte Spawns kommen. Mitigation: ADR explizit
  „Skelett, kein Combat" — Combat-ADR wird WaveSpawner ergänzen,
  nicht ersetzen.
- Save-System weiß noch nichts von Run-State — Mid-Run-Save ist NICHT in v1
  implementiert. Persistente Daten (Boss-Defeat, XP-Gewinn) werden über
  `save_requested` am Run-Ende geflusht.

**Risiken**
- **Risiko:** Ein zweites Subscriben von WaveSpawner auf `run_started` würde
  doppelt-feuern.
  → **Mitigation:** Subscribe in `_ready()`, kein zweiter Pfad.
- **Risiko:** Run-Time-Berechnung via `Time.get_ticks_msec()` ist Game-pause-blind.
  → **Mitigation:** RunState pflegt `_run_started_at_msec`, pausiert das aktiv
  bei zukünftigem Pause-System (Backlog).

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/content/dino_def.gd`              DinoDef-Resource-Klasse
- `core/run_state.gd`                     Autoload, State-Maschine
- `core/wave_spawner.gd`                  Autoload, Wave-Timer
- `content/dinos/trex.tres`               Erste DinoDef
- `core/event_bus.gd`                     +2 Signals (run_started, run_ended)
- `core/content_loader.gd`                TYPE_CONFIG erweitern: dino
- `project.godot`                         RunState + WaveSpawner Autoload
- `tests/unit/test_run_state.gd`          gut-Tests
- `tests/unit/test_wave_spawner.gd`       gut-Tests
- `tests/unit/test_dino_def.gd`           Resource-Validation-Test
- `locale/de.po`, `locale/en.po`          dino.trex.* keys
- `docs/ARCHITECTURE.md`                  Run-Pattern dokumentieren
- `BALANCE.csv`                           Trex-Eintrag

## 6. Folge-Entscheidungen (Backlog)

- ADR 0007 — Combat-System (Damage-Component, Health-Component, Hit-Detection)
- ADR 0008 — UI/HUD-System (Wave-Anzeige, HP-Bar, Run-Timer)
- ADR 0012 — Pause-System & Run-Time-Korrekturen
- ADR 0013 — Mid-Run-Save (separater Save-Slot, anderer Schema-Block)
