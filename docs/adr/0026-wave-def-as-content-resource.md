# ADR 0026 – WaveDef als Content-Resource

- Status: **Accepted**
- Datum: 2026-05-06
- Entscheider: game-architect (Lead), godot-implementer + content-author + game-designer (konsultiert)
- Betrifft Prinzipien: #1 Data-driven, #5 Mod-friendly, #6 Stable Content-IDs, #7 testbar
- Voraussetzungen: ADR 0003 (ContentLoader), ADR 0006 (WaveSpawner), ADR 0013 (Auto-Spawn-Curves), ADR 0023 (Pool-Curve), ADR 0025 (Boss-Spawn)
- Wird vorausgesetzt von: ADR — WaveDef-Pacing-Modes (Rest-Welle / Slow-Welle / Elite-Welle)

---

## 1. Kontext

Der WaveSpawner kennt heute alle Wave-Parameter als hardcodierte Konstanten:

```gdscript
const BASE_SPAWN_RATE: float = 0.5
const SPAWN_RATE_PER_WAVE: float = 0.3
const MAX_SPAWN_RATE: float = 5.0
const BOSS_WAVE_INTERVAL: int = 5

func _pool_for_wave(idx: int) -> Array[StringName]:
    if idx <= 2: return [&"raptor_grunt"]
    ...

func _boss_for_wave(_idx: int) -> StringName:
    return &"tyrannosaurus_prime"
```

Konsequenzen:

- **Designer können Wellen nicht ohne Code-Änderung anpassen** — Balance-
  Tuning braucht Re-Compile, nicht Re-Import einer .tres.
- **Modder können keine Wellen-Composition definieren** — der Modding-
  Pakt (ADR 0003 §4) deckt Mutationen, Enemies, Bosse, Dinos ab, aber
  nicht Wellen.
- **Tests sind an Konstanten gekoppelt** — Unit-Tests müssen die
  WaveSpawner-Internals kennen (z.B. `BASE_SPAWN_RATE`), statt eine
  Test-WaveDef zu mocken.

Anforderungen v1:

- Neuer Content-Type `wave` parallel zu `mutation`/`enemy`/`boss`/`dino`
- WaveDef-Schema deckt: Spawn-Rate, Enemy-Pool, Boss-Hint
- WaveSpawner liest WaveDef über ContentLoader (Lookup nach Welle-Index)
- **Backward-Kompatibilität**: ohne WaveDef-Resource fällt der Spawner
  auf die bisherige Konstanten-Kurve zurück
- Tests können eigene WaveDefs mocken, ohne `_pool_for_wave` zu monkey-
  patchen

Bewusst NICHT in v1:

- Pacing-Modes (Rest-Welle, Slow-Welle, Elite-Welle)
- Pro-Spawn-Gewichte (heute uniform `randi() % pool.size()`)
- Wave-spezifische Difficulty-Multiplier (heute `_difficulty_for_wave`)
- Wave-Trigger-Conditions (z.B. „spawne erst, wenn Player Mutation X hat")

## 2. Optionen

### Option A — Pro Welle eine WaveDef.tres (1:1)

`content/waves/wave_001.tres`, `wave_002.tres`, …

**Pro**
- Maximale Designer-Kontrolle pro Welle
- Modder können beliebige Welle ergänzen/überschreiben

**Contra**
- 100+ .tres-Dateien für lange Runs
- Repetitive Inhalte (Welle 7 ≈ Welle 8) führen zu Copy-Paste-Bugs

### Option B — Curve-WaveDef (Default) + Override-WaveDefs (empfohlen)

Eine `wave_default.tres` definiert die **Curve-Parameter** (Base-Rate,
Per-Wave-Increase, Cap, Pool-Tiers, Boss-Interval). Spezifische Wellen
(z.B. `wave_5_tyrannosaurus.tres`) **überschreiben** einzelne Felder
für ihre Welle.

```
WaveDef.is_default = true       → Curve-Default
WaveDef.target_wave_index = 5   → Override für genau Welle 5
```

WaveSpawner:
1. Suche WaveDef mit `target_wave_index == idx` → wenn gefunden, nutze sie
2. Sonst: nutze WaveDef mit `is_default == true`
3. Sonst: Hardcoded-Fallback (Backward-Kompat)

**Pro**
- Wenige Files für „normale" Wellen, gezielte Overrides für Boss-/Event-Wellen
- Modder können Boss-Welle 5 austauschen, ohne Default neu zu schreiben
- Default-Curve bleibt eine zentrale Tuning-Stelle

**Contra**
- Resolver-Logik im Spawner ist 2-stufig (komplexer als A)

### Option C — Wave-Stages statt Wave-Index

`wave_def.stage = "early" | "mid" | "late"`. Spawner mappt Index auf
Stage.

**Pro**
- Sehr kompakt (3 .tres-Files für ganzes Spiel)

**Contra**
- Kein präziser Boss-Index-Hook möglich
- Designer-Workflow „pass Welle 7 an" wird umständlich

## 3. Empfehlung

**Option B** — `is_default` + `target_wave_index` Override.

**Begründung**
- Decken die zwei realen Workflows ab: Curve-Tuning + spezifische Welle
- Bleibt nahe an den Konstanten — Migration ist mechanisch
- Modder bekommen das volle Spektrum (Override pro Index oder Default tauschen)
- Backward-kompatibel: ohne WaveDef-Resource bleibt das Verhalten identisch

### WaveDef-Schema

```gdscript
class_name WaveDef extends ContentItem

# Marker-Felder (genau einer der beiden gesetzt)
@export var is_default: bool = false           # Curve-Default
@export var target_wave_index: int = 0         # 0 = nicht spezifisch; >0 = für diese Welle

# Spawn-Curve (wirken nur wenn is_default=true)
@export var base_spawn_rate: float = 0.5       # Spawns/s in Welle 1
@export var spawn_rate_per_wave: float = 0.3   # +pro Welle
@export var max_spawn_rate: float = 5.0        # Cap

# Enemy-Pool — wenn leer und is_default=true, Spawner nutzt
# Hardcoded-Pool (Backward-Kompat). Wenn target_wave_index>0, ersetzt
# das den Pool für genau diese Welle.
@export var enemy_pool: Array[StringName] = []

# Boss-Hint — relevant wenn target_wave_index>0. is_default=true ignoriert.
@export var boss_id: StringName = &""

# Wave-Length-Override (default 0.0 = WaveSpawner.DEFAULT_WAVE_DURATION nutzen)
@export var duration_sec: float = 0.0
```

### WaveSpawner-Erweiterung

Neue Public-API:

```gdscript
## Liefert die WaveDef für diesen Wave-Index. null wenn keine passt.
## Resolver: Override → Default → null.
func get_wave_def_for(idx: int) -> WaveDef

## Liefert die aktuelle WaveDef (entspricht get_wave_def_for(current_wave())).
func get_active_wave_def() -> WaveDef
```

Refactor der existierenden Konstanten-Lookups in private Helper, die
auf WaveDef schauen mit Konstanten-Fallback:

```gdscript
func _spawn_rate_for_wave(idx: int) -> float:
    var def := get_wave_def_for(idx)
    if def != null and def.is_default:
        var rate := def.base_spawn_rate + def.spawn_rate_per_wave * float(max(0, idx - 1))
        return min(rate, def.max_spawn_rate)
    # Fallback (Backward-Kompat — keine Test-Suite-Migration nötig)
    var rate := BASE_SPAWN_RATE + SPAWN_RATE_PER_WAVE * float(max(0, idx - 1))
    return min(rate, MAX_SPAWN_RATE)
```

Analog `_pool_for_wave` und `_boss_for_wave`.

**Wichtig**: Konstanten BASE_SPAWN_RATE etc. bleiben im Code — sie
sind der Fallback und die Single-Source-of-Truth für die Default-
WaveDef. Änderungen an der Default-Curve passieren in
`content/waves/wave_default.tres`, nicht im Code.

### Initial-Content

```
content/waves/
  wave_default.tres                    # Curve-Default (is_default=true)
  wave_5_tyrannosaurus.tres            # Override für Welle 5 (Boss + voller Pool)
  wave_10_tyrannosaurus.tres           # Welle 10 (Boss + erweiterter Pool)
```

`wave_default.tres` repliziert die heute hardcodierten Werte 1:1
(0.5/0.3/5.0). Das macht den Migration-Pfad mechanisch — nichts
ändert sich für den Spieler beim Roll-out.

### Boss-Spawn-Hook

`_start_next_wave` checkt jetzt:

```gdscript
var def := get_wave_def_for(_current_wave)
var boss_id: StringName
if def != null and def.boss_id != &"":
    boss_id = def.boss_id
elif _is_boss_wave(_current_wave):
    boss_id = _boss_for_wave(_current_wave)  # Konstanten-Fallback

if String(boss_id) != "" and _spawn_root != null:
    var pos := _random_spawn_position()
    spawn_boss_at(boss_id, pos)
```

Konsequenz: Boss-Wellen können jetzt EXAKT pro Index festgelegt
werden, statt mod-5-Lookup.

## 4. Konsequenzen

**Positiv**
- **Designer ändern Wellen ohne Code-Touch** — Balance-Iterations-
  zyklus geht von „Re-Compile" auf „Re-Import"
- **Modder bekommen `wave` als Mod-Override-Surface** — Konsistenz
  mit Mutation/Enemy/Boss/Dino
- **Tests können WaveDef mocken** statt Konstanten zu monkey-patchen
- Backward-Kompatibilität: ohne WaveDef-Files Verhalten identisch

**Negativ**
- ~30 Zeilen Resolver-Logic im WaveSpawner (Override/Default/Fallback)
- 2 zusätzliche Code-Pfade pro Lookup → mehr Tests nötig

**Risiken**
- **Risiko:** Default-WaveDef gefunden, aber `enemy_pool` versehentlich
  leer → Spieler sieht keine Spawns.
  → **Mitigation:** WaveDef.validate() prüft Schema-Integrität
  (siehe §5), und ContentLoader rejected ungültige Files mit Warning.
- **Risiko:** Mehrere `target_wave_index=5`-Files (Mod-Konflikt) — wer
  gewinnt?
  → **Konvention:** ContentLoader.has_item überprüft ID-Uniqueness, also
  Mods können nur per `override_existing=true` ablösen. Override-Reihen-
  folge folgt Mod-Load-Order (ADR 0005). Diskutiert in §6.

## 5. Validate-Regeln (WaveDef.validate())

```
- is_default und target_wave_index>0 dürfen NICHT beide gesetzt sein
- weder is_default noch target_wave_index>0 → Warning (ungenutzt)
- base_spawn_rate >= 0 und max_spawn_rate >= base_spawn_rate
- duration_sec >= 0
- boss_id darf nur gesetzt sein wenn target_wave_index>0
```

ContentLoader skipt Files mit validate()!="" — der Designer sieht
sofort beim nächsten Boot welcher File kaputt ist.

## 6. Betroffene Dateien & Systeme

Anzulegen:
- `core/content/wave_def.gd`
- `content/waves/wave_default.tres`
- `content/waves/wave_5_tyrannosaurus.tres`
- `content/waves/wave_10_tyrannosaurus.tres`
- `tests/unit/test_wave_def.gd`

Berührt:
- `core/content_loader.gd` (TYPE_CONFIG +`wave`)
- `core/wave_spawner.gd` (Resolver + private Helper auf def-aware)
- `tests/unit/test_wave_spawner.gd` (+WaveDef-Lookup-Tests)
- `tests/unit/test_content_loader.gd` (+wave-Type-Test)
- `locale/{de,en}.po` (wave.*-Keys)
- `BALANCE.csv` (Wave-Einträge)
- `docs/CONTENT.md` (Modder-Doku für wave-Type)
- `docs/ARCHITECTURE.md`, `agents/memory/mod-api-curator/public-api-surface.md`

## 7. Folge-Entscheidungen (Backlog)

- ADR — Wave-Pacing-Modes (Rest-Welle alle 10 Wellen, Slow-Welle nach Boss)
- ADR — Pro-Spawn-Gewichte (statt uniform `randi % pool.size()`)
- ADR — Wave-Difficulty-Multiplier-Override (statt Konstanten-Curve)
- ADR — Wave-Trigger-Conditions (z.B. Spawne Welle X nur wenn Mutation Y)
