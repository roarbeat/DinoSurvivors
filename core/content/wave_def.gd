class_name WaveDef
extends ContentItem
## Definition einer Welle (ADR 0026).
##
## Zwei Modi:
##   - is_default = true: definiert die **Curve-Default**-Parameter
##     (Spawn-Rate-Curve, Default-Pool). Genau eine WaveDef sollte
##     is_default=true tragen.
##   - target_wave_index > 0: **Override** für genau diese Welle
##     (Boss-Welle, Event-Welle, …). Hat Vorrang vor is_default.
##
## Der WaveSpawner-Resolver (siehe wave_spawner.gd::get_wave_def_for):
##   1. Override-Match (target_wave_index == idx) → diese WaveDef
##   2. Default (is_default=true) → diese WaveDef
##   3. null → Spawner fällt auf hardcoded Konstanten zurück (Backward-Kompat)

# ---------------------------------------------------------------------------
# Marker-Felder — exakt einer der beiden gesetzt
# ---------------------------------------------------------------------------

## Marker für „diese WaveDef ist die Curve-Default". Nur die Curve-Felder
## (base_spawn_rate, spawn_rate_per_wave, max_spawn_rate) werden gelesen.
@export var is_default: bool = false

## Override für genau diese Wave-Index (1-basiert). 0 = nicht spezifisch.
## Wenn >0 gesetzt, ist diese WaveDef NUR für die Welle relevant.
@export var target_wave_index: int = 0

# ---------------------------------------------------------------------------
# Curve-Parameter (relevant wenn is_default=true)
# ---------------------------------------------------------------------------

## Spawn-Rate in Welle 1 (Spawns/Sekunde).
@export var base_spawn_rate: float = 0.5

## Pro-Welle-Increase auf base_spawn_rate.
@export var spawn_rate_per_wave: float = 0.3

## Cap für Spawn-Rate.
@export var max_spawn_rate: float = 5.0

# ---------------------------------------------------------------------------
# Pool / Boss / Duration (relevant wenn target_wave_index>0,
# oder als Default-Pool bei is_default=true)
# ---------------------------------------------------------------------------

## Enemy-Pool für diese Welle. Leer = WaveSpawner-Fallback (hardcoded
## Pool-Curve aus ADR 0023).
@export var enemy_pool: Array[StringName] = []

## Boss-ID für Boss-Wellen. Nur sinnvoll wenn target_wave_index>0.
## Leer = kein Boss in dieser Welle.
@export var boss_id: StringName = &""

## Welle-Dauer in Sekunden. 0.0 = WaveSpawner.DEFAULT_WAVE_DURATION nutzen.
@export var duration_sec: float = 0.0


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func validate() -> String:
	var base := super.validate()
	if base != "":
		return base

	# Genau einer der beiden Marker sollte gesetzt sein
	if is_default and target_wave_index > 0:
		return "WaveDef darf NICHT gleichzeitig is_default=true und target_wave_index>0 haben"
	if not is_default and target_wave_index <= 0:
		return "WaveDef braucht entweder is_default=true ODER target_wave_index>0"

	if base_spawn_rate < 0.0:
		return "base_spawn_rate darf nicht negativ sein"
	if spawn_rate_per_wave < 0.0:
		return "spawn_rate_per_wave darf nicht negativ sein"
	if max_spawn_rate < base_spawn_rate:
		return "max_spawn_rate muss >= base_spawn_rate sein"
	if duration_sec < 0.0:
		return "duration_sec darf nicht negativ sein"

	# boss_id nur sinnvoll auf Override-WaveDefs
	if is_default and boss_id != &"":
		return "boss_id darf nur auf Override-WaveDefs (target_wave_index>0) gesetzt sein"

	return ""
