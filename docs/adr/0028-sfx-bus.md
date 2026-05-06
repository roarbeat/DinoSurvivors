# ADR 0028 – SFX-Bus + SoundDef

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + shader-fx-specialist (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #2 EventBus, #5 Mod-friendly, #7 testbar
- Voraussetzungen: ADR 0001 (EventBus), ADR 0003 (ContentLoader), ADR 0007 (Combat)
- Wird vorausgesetzt von: ADR — Music-System, ADR — 3D-positionales Audio, ADR — Audio-Bus-Mixer

---

## 1. Kontext

Das Spiel hat keine Sounds. Treffer, Tod, Boss-Kill, Mutation-Pick —
alles passiert visuell mit Damage-Numbers + HUD-Updates, aber akustisch
ist es still.

Audio-Hooks brauchen wir an mehreren Bus-Signalen:

- `EventBus.enemy_died` → SFX „enemy-death-poof"
- `EventBus.boss_defeated` → SFX „boss-roar-final"
- `EventBus.player_damaged` → SFX „hit-grunt"
- `EventBus.player_died` → SFX „death-sting"
- `EventBus.mutation_picked` → SFX „mutation-confirm"
- `EventBus.wave_started` → SFX „wave-incoming"

Anforderungen v1:

- **Autoload `SfxBus`** als 8. Autoload (Reihenfolge nach PlayerMutations)
- **SoundDef-Resource** mit `stream: AudioStream` (optional null in v1),
  `volume_db`, `pitch_random_range`
- **EventBus → SoundDef-Mapping** als Konstante im Bus (signal_name → sound_id)
- **AudioStreamPlayer-Pool** (8 Instanzen) für concurrent Playback
- **No-op-Verhalten** wenn `stream == null` (= alle SFX in v1, bis Audio-
  Assets landen)
- **Headless-testbar**: Tests verifizieren API-Surface ohne tatsächliches
  Audio-Output

Bewusst NICHT in v1:

- Music-Streaming (BG-Tracks mit Loop-Punkten)
- 3D-positionales Audio (`AudioStreamPlayer2D` mit max_distance)
- Audio-Bus-Mixer (separate Master/SFX/Music-Volume-Slider)
- Cross-fade zwischen Tracks
- Audio-Ducking (SFX dämpft Music kurz)

## 2. Optionen

### Option A — Autoload + SoundDef-Resource + EventBus-Subscriptions (empfohlen)

```gdscript
# core/audio/sfx_bus.gd
extends Node

const SIGNAL_TO_SOUND: Dictionary = {
    "enemy_died":        &"sfx_enemy_died",
    "boss_defeated":     &"sfx_boss_defeated",
    "player_damaged":    &"sfx_player_damaged",
    "player_died":       &"sfx_player_died",
    "mutation_picked":   &"sfx_mutation_picked",
    "wave_started":      &"sfx_wave_started",
}

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0

func _ready():
    for i in 8:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _pool.append(p)
    EventBus.enemy_died.connect(func(_id, _pos): _play(&"sfx_enemy_died"))
    # ... weitere Subscriptions

func _play(sound_id: StringName) -> void:
    var def := ContentLoader.get_or_null(&"sound", sound_id) as SoundDef
    if def == null or def.stream == null:
        return  # No-op in v1
    var p := _pool[_pool_idx]
    _pool_idx = (_pool_idx + 1) % _pool.size()
    p.stream = def.stream
    p.volume_db = def.volume_db
    if def.pitch_random_range > 0.0:
        p.pitch_scale = 1.0 + randf_range(-def.pitch_random_range, def.pitch_random_range)
    else:
        p.pitch_scale = 1.0
    p.play()
```

**Pro**
- Vollständig data-driven (SoundDef.stream tauschbar ohne Code-Touch)
- Modder können eigene SFX einhängen via Mod-SoundDef + override_existing
- Pool-Pattern verhindert „cut off" bei vielen Treffern
- Headless-testbar (No-op bei null-Stream)

**Contra**
- 8 Player als Pool ist eine arbitrary Konstante — bei vielen
  parallelen Hits könnte „dropped" entstehen. v1 akzeptiert das.

### Option B — Direkte EventBus-Subscriptions in Game-Code

Jeder Mob-Death-Pfad ruft direkt `AudioStreamPlayer.play()` auf einer
lokalen Scene-Instanz.

**Pro**
- Kein zusätzlicher Autoload
- Per-Mob-Position-aware (3D-Audio möglich)

**Contra**
- Audio-Logik streut über alle Mobs/Scenes
- Modder können Audio nur durch Code-Patch ändern
- Schwer testbar — jeder Mob bräuchte einen Audio-Mock

### Option C — `AudioStreamPlayer` direkt im Mob

Jeder Mob (Player, Enemy, Boss) hat einen Audio-Player als Child, der
per Signal getriggert wird.

**Pro**
- Lokal saubere Pipeline pro Mob

**Contra**
- 50+ Mob-Instanzen × 1 Player = viel ungenutzter Audio-Code
- Mods bekommen keine zentrale Anlaufstelle

## 3. Empfehlung

**Option A** — Autoload `SfxBus` + SoundDef-Resource.

**Begründung**
- Konsistent mit dem EventBus-First-Architecture-Prinzip (#2)
- Modder bekommen `sound` als 6. Content-Type (parallel zu mutation/enemy/
  boss/dino/wave)
- Audio-Logik zentralisiert — Bug-Fixes / Sound-Polish an genau einer Stelle
- No-op-Verhalten erlaubt v1-Roll-out ohne Audio-Assets

### SoundDef-Schema

```gdscript
class_name SoundDef extends ContentItem

## AudioStream-Resource (.ogg/.wav). Null = no-op (v1-Default).
@export var stream: AudioStream

## Volume in dB. 0.0 = unverändert, -6.0 = halb so laut.
@export var volume_db: float = 0.0

## ±Range für pitch_scale-Random. 0.0 = kein Random, 0.1 = ±10%.
@export var pitch_random_range: float = 0.0
```

### EventBus-Mapping

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

Public-API: `SIGNAL_TO_SOUND` als Konstante exposed, sodass Mods
zusätzliche Mappings via `add_signal_mapping(signal_name, sound_id)`
registrieren können (kommt mit Mod-API-Erweiterung).

### Initial-Content

```
content/sounds/
├── sfx_enemy_died.tres        # stream=null in v1
├── sfx_boss_defeated.tres
├── sfx_player_damaged.tres
├── sfx_player_died.tres
├── sfx_mutation_picked.tres
└── sfx_wave_started.tres
```

Alle Stubs haben `stream = null` in v1. Der SfxBus skippt sie als no-op.
Echte .ogg-Assets landen in einem späteren Audio-Pass.

## 4. Konsequenzen

**Positiv**
- **Audio-Hooks bereit für Asset-Drop**: sobald .ogg-Files da sind,
  Re-Import → SFX laufen
- **Modder bekommen `sound` als Mod-Type** (6. Content-Type)
- **Pool-Pattern** verhindert Audio-Cut-off bei vielen Treffern
- **EventBus-zentriert** — keine direkten Audio-Calls in Game-Code

**Negativ**
- **Pool-Größe 8** ist arbitrary — bei extremen Wellen könnte „dropped"
  entstehen. v1 akzeptiert das.
- **Single-Player-only**: AudioStreamPlayer (nicht 2D) — keine
  positionale Information. Eigenes ADR für 3D-Audio.

**Risiken**
- **Risiko:** SFX feuern in Tests nervig oft. v1 hat null-Stream → no-op,
  aber sobald Assets landen, müssen Tests den Bus mocken können.
  → **Mitigation:** SfxBus.set_muted(true) als Test-Hook.

- **Risiko:** Gleicher Sound mehrfach pro Frame (Schwarm-Damage) →
  Audio-Spam.
  → **v1 akzeptiert.** Cooldown-Logik ist eigenes ADR.

## 5. Betroffene Dateien

Anzulegen:
- `core/audio/sfx_bus.gd` — Autoload mit Pool + Mapping
- `core/content/sound_def.gd` — Resource-Schema
- `content/sounds/sfx_enemy_died.tres` (+ 5 weitere Stubs)
- `tests/unit/test_sfx_bus.gd`
- `tests/unit/test_sound_def.gd`

Berührt:
- `core/content_loader.gd` — TYPE_CONFIG +`sound`
- `project.godot` — SfxBus als 8. Autoload
- `tests/unit/test_content_loader.gd` — sound-Type-Check

## 6. Folge-Entscheidungen (Backlog)

- ADR — Music-System (BG-Tracks, Loop-Punkte, Cross-fade)
- ADR — 3D-positionales Audio (`AudioStreamPlayer2D`)
- ADR — Audio-Bus-Mixer (Master/SFX/Music-Volume-Slider in Settings-UI)
- ADR — SFX-Cooldown-Logik (vermeidet Audio-Spam bei Schwarm-Damage)
- ADR — Audio-Ducking (SFX dämpft Music kurz)
