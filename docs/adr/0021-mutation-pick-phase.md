# ADR 0021 – Mutation-Pick-Phase nach jeder Welle

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), game-designer + lore-writer (konsultiert)
- Betrifft Prinzipien: #2 EventBus, #4 i18n, #7 testbar
- Voraussetzungen: ADR 0006 (WaveSpawner), ADR 0015 (PlayerMutations), ADR 0014 (Bridge), ADR 0016 (RunScene)
- Wird vorausgesetzt von: Mutation-Tooltip-System, Rarity-gewichtete Picks

---

## 1. Kontext

Mutationen wirken seit v0.0.2 mathematisch. Der Spieler kann sie aber
nicht ingame picken — sie werden bisher nur per `PlayerMutations.pick()`
von außen aufgerufen. Das Mutations-System ist nicht **diegetisch
komplett**.

Anforderungen v1:

- **Wave-Ende → Pick-Phase**: nach `wave_cleared` werden 3 zufällige
  Mutationen (nicht-gepickt) als Auswahl angezeigt
- **Spiel pausiert** während Pick (kein Run-Timer-Tick, kein Auto-Spawn,
  keine Bewegung)
- **Spieler klickt → Pick + Resume**: PlayerMutations.pick(),
  Pause aus, nächste Welle startet
- **Edge-Cases**: < 3 verfügbare Mutationen → fewer Buttons; 0 verfügbar
  → Phase überspringen
- **Headless-testbar**: Pick-Logik (welche Mutationen) trennbar vom
  visuellen Button-Click

Bewusst NICHT in v1:

- **Rarity-gewichtete Picks** (Common 70%, Rare 25%, Epic 4.5%, Legendary 0.5%)
  — kommt mit Rarity-System-ADR
- **Reroll-Button** (Mutation neu würfeln gegen Currency)
- **Tooltips** mit längeren Beschreibungen
- **Mutation-Icons / Visuelles Polish**
- **Skip-Button** (Pick verzichten gegen Heal o.ä.)

## 2. Optionen

### Option A — Pause + auto_advance-Flag (empfohlen)

```
WaveSpawner
├── @export var auto_advance: bool = true   # Default: alte Tests bleiben grün
├── _on_wave_timeout: feuert wave_cleared, ruft _start_next_wave NUR
│                     wenn auto_advance == true
└── request_next_wave(): Public-API für Pick-Overlay

MutationPickOverlay (CanvasLayer, process_mode=WHEN_PAUSED)
├── _ready: WaveSpawner.auto_advance = false
├── EventBus.wave_cleared → show_pick_phase()
└── show_pick_phase: Pause + Random-Pick + Buttons
```

**Pro**
- Kompatibel mit bestehenden Tests (auto_advance=true Default)
- Pause-Strategie ist Godot-idiomatisch (process_mode + paused)
- Klare Trennung: WaveSpawner kennt nichts von Pick-UI

**Contra**
- WaveSpawner hat jetzt zwei Pfade (auto / manual) — leichte Komplexität

### Option B — Komplett auf Bus-Signal-Workflow

WaveSpawner feuert wave_cleared, wartet auf `next_wave_requested`-Signal.
Kein auto_advance-Mode.

**Pro**
- Sauberer; eine Strategie

**Contra**
- Bricht alle existierenden Tests
- Tests, die ohne UI laufen, müssten manuell next_wave_requested feuern

### Option C — get_tree().paused = true ohne auto_advance-Flag

Nur Pause; WaveSpawner pausiert wie alles andere.

**Pro**
- Minimaler Code-Change

**Contra**
- WaveSpawner würde nach Resume sofort die nächste Welle starten
  (über noch laufenden Timer) — Pick-Result-Anzeige wird sofort
  überschrieben
- Race-Condition zwischen Pause-Ende und WaveSpawner-Tick

## 3. Empfehlung

**Option A** — Pause + auto_advance-Flag.

**Begründung**
- Backward-kompatibel, neue Behavior nur opt-in
- Pause-Strategie über `get_tree().paused` ist Godot-Standard
- WaveSpawner.request_next_wave() ist saubere Public-API

**MutationPickOverlay-API**

```gdscript
class_name MutationPickOverlay extends CanvasLayer

func show_pick_phase() -> void   # Pause + 3 zufällige Buttons
func hide_overlay() -> void      # Resume + verstecken
func get_offered_ids() -> Array[StringName]  # für Tests

# Pick wird via Button-Press getriggert; Test-Hook:
func _on_pick(mutation_id: StringName) -> void  # public für Tests
```

**Pick-Logic**

```gdscript
func _pick_random_mutations(count: int) -> Array[StringName]:
    var all := ContentLoader.all_ids(&"mutation")
    var available: Array[StringName] = []
    for id in all:
        if not PlayerMutations.has(id):
            available.append(id)
    available.shuffle()
    return available.slice(0, min(count, available.size()))
```

**Lifecycle**

1. `_ready`: WaveSpawner.auto_advance = false; EventBus.wave_cleared.connect
2. `wave_cleared` → `show_pick_phase()`
3. `show_pick_phase`:
   - 3 zufällige verfügbare Mutationen wählen
   - Wenn 0 verfügbar: sofort `hide_overlay()` + `WaveSpawner.request_next_wave()`
   - Sonst: Buttons rendern, get_tree().paused = true, visible = true
4. Spieler-Click auf Button N → `_on_pick(offered_ids[N])`:
   - `PlayerMutations.pick(id)`
   - `hide_overlay()`
5. `hide_overlay`:
   - get_tree().paused = false
   - visible = false
   - WaveSpawner.request_next_wave()

**Pause-Disziplin**

- MutationPickOverlay process_mode = WHEN_PAUSED → läuft während Pause
- Game-World (Player, Enemies, WaveSpawner): default INHERIT → pausiert
- HUD process_mode = WHEN_PAUSED auch (Timer soll trotzdem stehen?
  → ja: HUD-Timer pollt RunState.get_run_time, aber Time.get_ticks_msec
  basiert auf real time. Pause-aware-Timer ist eigenes ADR.)

## 4. Konsequenzen

**Positiv**
- **Mutations-System ist diegetisch komplett**: Spieler pickt selbst,
  spürt die Konsequenz seiner Wahl in der nächsten Welle
- WaveSpawner.auto_advance ist clean Backward-Kompatibilität
- Headless-Tests: Pick-Logic trennbar vom UI-Click

**Negativ**
- Run-Timer läuft während Pause technisch weiter (RunState nutzt Time.now)
  → Spieler bekommt mehr Zeit als gespielt. Akzeptiert v1, Pause-aware-
  Timer ist eigenes ADR.
- Random ohne Rarity-Weighting ist suboptimal — Common und Legendary
  haben gleiche Chance. Rarity-System-ADR adressiert das.

**Risiken**
- **Risiko:** Spieler hat alle Mutationen gepickt → keine mehr → Phase
  läuft jedes Mal trivial-skip durch.
  → **Akzeptiert v1**: bei 3 Mutationen schnell erreicht, wir warten
  auf mehr Content.
- **Risiko:** Pick-Phase nach Welle 1 unterbricht Flow-State des
  Spielers.
  → **Akzeptiert**: Survivor-likes-Standard, Spieler erwarten das.

## 5. Betroffene Dateien & Systeme

Anzulegen:
- `core/ui/mutation_pick_overlay.gd` + `.tscn`
- `tests/unit/test_mutation_pick_overlay.gd`

Berührt:
- `core/wave_spawner.gd` (auto_advance-Flag, request_next_wave)
- `core/run_scene/run.tscn` (PickOverlay als Child)
- `tests/unit/test_wave_spawner.gd` (neue Tests für auto_advance + request_next_wave)

## 6. Folge-Entscheidungen (Backlog)

- ADR — Rarity-gewichtete Picks
- ADR — Reroll-Button gegen Currency
- ADR — Mutation-Tooltips bei Hover
- ADR — Pause-aware Run-Timer
- ADR — Skip-Pick gegen Heal-Bonus
