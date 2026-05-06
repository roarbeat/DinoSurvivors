# ADR 0019 – Game-Over-Overlay + Run-Restart

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #7 testbar
- Voraussetzungen: ADR 0006 (RunState), ADR 0008 (Player), ADR 0016 (RunScene), ADR 0011 (Hit-Detection)
- Wird vorausgesetzt von: HUD (eigenes ADR), Stats-Tracking pro Run

---

## 1. Kontext

Wenn Player stirbt, läuft das Spiel ohne sichtbare Konsequenz weiter:
RunState wechselt zu ENDED (auf Bus), Player-HP bleibt 0, Auto-Spawn
stoppt. Aber der Spieler sieht nichts und kann nicht neu starten.

Anforderungen v1:

- **Overlay** statt neue Scene — Welt bleibt im Hintergrund sichtbar
- **Run-Stats** anzeigen: Reason (warum tot?), Run-Zeit, Welle-erreicht
- **Run-Restart** via Tastendruck (`restart`-Action: Enter / R)
- **Cleanup**: alte Enemies + Player aus Scene entfernen
- **Headless-testbar**: Restart-Flow ohne Input-Tastendruck triggerbar

Bewusst NICHT in v1:

- Game-Over-Animationen / Fades
- Score-Tracking, High-Score-Persistierung (kommt mit Save-Format-Erweiterung)
- Mutation-Pick-Phase nach Tod (Auto-Restart in v1)
- Pause-Menü vor Tod
- Multiple End-Screens (Sieg vs. Niederlage — alles ist „Game-Over")

## 2. Optionen

### Option A — CanvasLayer-Overlay in der RunScene (empfohlen)

```
Run (Node2D, root)
├── PlayerSlot
├── EnemyContainer
└── GameOverLayer  (CanvasLayer, initial visible=false)
    └── GameOverPanel (Control)
        ├── BG (ColorRect dark overlay)
        └── Label "GAME OVER\n\n{stats}\n\n[Enter] Restart"
```

Restart-Logic in der RunScene:
1. EnemyContainer.queue_free children
2. Player aus PlayerSlot freigeben
3. RunState.reset
4. _spawn_player + RunState.start (wie initial)

**Pro**
- Welt bleibt sichtbar (atmosphärisch besser als Black-Screen)
- Run-Reset im selben Scene-Tree — kein change_scene_to_packed
- Tests können restart_run() direkt aufrufen ohne Input-Simulation

**Contra**
- Memory-Footprint: tote Enemies bleiben kurz in der Scene bis cleanup
  (akzeptabel)

### Option B — Eigene Game-Over-Scene via change_scene_to_packed

Welt wird komplett gewechselt.

**Pro**
- Saubere Trennung

**Contra**
- Welt-Hintergrund verschwindet (weniger atmosphärisch)
- change_scene-Cycles brauchen Persistenz für Run-Stats
- Tests werden komplizierter (Scene-Wechsel)

### Option C — Auto-Restart nach Delay

Player tot → 3 Sek warten → automatisch neuer Run.

**Pro**
- Kein UI nötig

**Contra**
- Spieler hat keine Wahl — Frustration
- Keine Anzeige der Run-Stats

## 3. Empfehlung

**Option A** — CanvasLayer-Overlay in der RunScene.

**Begründung**
- Konsistent mit Run-Scene-Pattern (ADR 0016): Glue-Logic in einer Scene
- Tests rufen `restart_run()` direkt auf — kein Input-Mock nötig
- Atmosphärisch: Spieler sieht „seine" tote Welt während Game-Over

**GameOver-Scene-API**

```gdscript
class_name GameOverOverlay extends CanvasLayer

func show_run_ended(reason: StringName, run_time: float, wave: int) -> void
func hide_overlay() -> void
func is_shown() -> bool
```

**RunScene-Erweiterung**

```gdscript
func _ready():
    # bestehender Code +
    EventBus.run_ended.connect(_on_run_ended)

func _on_run_ended(reason: StringName, run_time: float):
    var overlay: GameOverOverlay = $GameOverLayer
    overlay.show_run_ended(reason, run_time, WaveSpawner.current_wave())

func _input(event):
    if event.is_action_pressed("restart") and RunState.is_ended():
        restart_run()

func restart_run():
    # Cleanup
    for child in enemy_container.get_children():
        child.queue_free()
    if _player != null and is_instance_valid(_player):
        _player.queue_free()
        _player = null
    RunState.reset()
    $GameOverLayer.hide_overlay()
    # Neu starten
    _spawn_player_and_start()
```

**Input-Action**

`restart` mit Default-Bindings: KEY_ENTER (4194309) + KEY_R (82).

## 4. Konsequenzen

**Positiv**
- **Loop ist geschlossen**: Tod → Game-Over → Enter → neuer Run
- Welle-Reset auf 1, neuer trex, leere PlayerMutations (RunState.reset
  triggert PlayerMutations.reset über run_started)

**Negativ**
- Tote Enemies bleiben kurz visuell sichtbar bis queue_free durchläuft
  (1 Frame). Akzeptabel.

**Risiken**
- **Risiko:** Restart-Loop kann State-Reste hinterlassen (z.B.
  HealthBar-Connections an freigegebene HP-Components).
  → **Mitigation:** queue_free disconnectet Method-Refs automatisch.
  HealthBar's set_health(null) sollte für Sicherheit ergänzt werden,
  aber v1 nutzt Method-Refs durchgängig.
- **Risiko:** Spieler drückt restart wenn RunState IDLE oder RUNNING ist
  (z.B. Tasten-Spam).
  → **Mitigation:** Guard `RunState.is_ended()` im _input.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/ui/game_over.gd` + `.tscn`     GameOver-Overlay
- `tests/unit/test_game_over.gd`       Overlay-Tests
- `tests/unit/test_run_scene.gd`       +restart_run-Tests

Berührt:
- `core/run_scene/run.gd` + `.tscn`    +GameOverLayer-Child + restart_run
- `project.godot`                      +input action `restart`

## 6. Folge-Entscheidungen (Backlog)

- ADR — Score- und Stats-Persistierung über Saves
- ADR — Pause-Menü
- ADR — Mutation-Pick-Phase nach Welle (nicht erst nach Tod)
- ADR — Animations / Fades für Game-Over-Transition
