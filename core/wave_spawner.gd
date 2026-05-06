extends Node
## Globaler WaveSpawner-Autoload.
##
## Implementiert ADR 0006 — der **Lifecycle-Skelett**-Teil ohne tatsächliche
## Gegner-Spawns. Combat-System wird das später um Spawns ergänzen
## (siehe ADR Combat).
##
## Verantwortung:
##   - Subscribed run_started/run_ended am EventBus
##   - Hält einen Timer, der nach wave_duration `wave_cleared` feuert
##   - Direkt danach: nächste Welle starten und `wave_started` feuern
##   - Pflegt Wave-Counter über RunState._set_current_wave()
##
## Game-Code triggert WaveSpawner NIE direkt — nur indirekt über
## EventBus.run_started/ended.

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

const DEFAULT_WAVE_DURATION_SEC := 30.0

## Auto-Advance: nach wave_cleared automatisch die nächste Welle starten?
## Default true (Backward-Kompatibilität). Mutation-Pick-Overlay setzt
## das beim _ready auf false und triggert request_next_wave() nach Pick.
@export var auto_advance: bool = true

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _wave_duration: float = DEFAULT_WAVE_DURATION_SEC
var _timer: Timer
var _current_wave: int = 0
var _active: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Timer als Child anlegen
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_wave_timeout)

	# EventBus-Hooks
	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_started.connect(_on_run_started)
		EventBus.run_ended.connect(_on_run_ended)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Setzt die Wellen-Dauer in Sekunden. Wirkt auf die NÄCHSTE Welle —
## eine laufende Welle wird nicht abgebrochen.
func set_wave_duration(seconds: float) -> void:
	if seconds <= 0.0:
		push_warning("WaveSpawner.set_wave_duration: Wert muss > 0 sein")
		return
	_wave_duration = seconds


## Aktuelle Wellen-Dauer.
func get_wave_duration() -> float:
	return _wave_duration


## true wenn gerade eine Welle läuft (Run aktiv).
func is_active() -> bool:
	return _active


## Triggert die nächste Welle. Wird vom Mutation-Pick-Overlay nach Pick
## gerufen, wenn auto_advance=false. No-op wenn Run nicht aktiv oder
## Wave bereits läuft (durch laufenden Timer).
func request_next_wave() -> void:
	if not _active:
		return
	# Falls noch ein Welle-Timer läuft (Spieler clearen vor Ablauf):
	# stoppen, neue Welle starten.
	_timer.stop()
	_start_next_wave()


## Aktueller Wave-Index. 0 wenn idle.
func current_wave() -> int:
	return _current_wave


## Direktes Trigger des Wave-Endes (Test-Hook und potenzielles Cheat-Tool).
## Game-Code sollte das NICHT routinemäßig aufrufen.
func _force_wave_end() -> void:
	if not _active:
		return
	_timer.stop()
	_on_wave_timeout()


# ---------------------------------------------------------------------------
# Spawn-API (ADR 0009)
# ---------------------------------------------------------------------------

const DEFAULT_ENEMY_SCENE: PackedScene = preload("res://core/enemy/enemy_mob.tscn")

# Auto-Spawn-Curve-Konstanten (ADR 0013)
const BASE_SPAWN_RATE: float = 0.5         # Spawns/s in Welle 1
const SPAWN_RATE_PER_WAVE: float = 0.3     # +pro Welle
const MAX_SPAWN_RATE: float = 5.0          # Cap
const SPAWN_RADIUS_FROM_PLAYER: float = 400.0

# Boss-Wellen (ADR 0025) — alle BOSS_WAVE_INTERVAL Wellen erscheint ein Boss
const BOSS_WAVE_INTERVAL: int = 5

var _spawn_root: Node = null

# Auto-Spawn-State
var _auto_spawn_timer: float = 0.0
var _current_spawn_interval: float = 0.0


## Setzt den Parent-Node, unter dem Spawns angelegt werden. Game-Code ruft
## das beim Run-Start (z.B. von der Run-Scene aus). Ohne spawn_root sind
## Spawns no-op + warning.
func set_spawn_root(node: Node) -> void:
	_spawn_root = node


func get_spawn_root() -> Node:
	return _spawn_root


## Spawnt einen Enemy an `position`. Liefert die Instance oder null.
##
## null wird zurückgegeben bei:
##   - kein spawn_root gesetzt
##   - unbekannte enemy_id (nicht im ContentLoader)
func spawn_enemy_at(enemy_id: StringName, position: Vector2) -> EnemyMob:
	if _spawn_root == null:
		push_warning("WaveSpawner.spawn_enemy_at: kein spawn_root gesetzt — skip")
		return null

	if get_node_or_null("/root/ContentLoader") == null:
		return null
	var def: EnemyDef = ContentLoader.get_or_null(&"enemy", enemy_id) as EnemyDef
	if def == null:
		push_warning("WaveSpawner.spawn_enemy_at: unbekannter Enemy '%s'" % enemy_id)
		return null

	# Scene aus def.scene oder Default
	var scene: PackedScene = def.scene if def.scene != null else DEFAULT_ENEMY_SCENE
	var mob: EnemyMob = scene.instantiate() as EnemyMob
	if mob == null:
		push_error("WaveSpawner.spawn_enemy_at: Scene ergibt keinen EnemyMob")
		return null

	_spawn_root.add_child(mob)
	mob.setup(def, position)
	return mob


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_run_started(_dino_id: StringName) -> void:
	_active = true
	_current_wave = 0
	_start_next_wave()


func _on_run_ended(_reason: StringName, _run_time: float) -> void:
	_active = false
	_timer.stop()
	_auto_spawn_timer = 0.0
	_current_spawn_interval = 0.0
	_current_wave = 0
	if get_node_or_null("/root/RunState") != null:
		RunState._set_current_wave(0)


func _start_next_wave() -> void:
	_current_wave += 1
	if get_node_or_null("/root/RunState") != null:
		RunState._set_current_wave(_current_wave)
	# WaveDef-Lookup (ADR 0026) — falls Override-WaveDef die duration setzt
	var def := get_wave_def_for(_current_wave)
	var duration: float = _wave_duration
	if def != null and def.duration_sec > 0.0:
		duration = def.duration_sec
	_timer.start(duration)
	# Auto-Spawn-Rate für diese Welle setzen
	_current_spawn_interval = 1.0 / _spawn_rate_for_wave(_current_wave)
	_auto_spawn_timer = _current_spawn_interval
	if get_node_or_null("/root/EventBus") != null:
		EventBus.wave_started.emit(_current_wave, _difficulty_for_wave(_current_wave))

	# Boss-Welle? (ADR 0025/0026)
	# Resolver: WaveDef.boss_id (Override) → _is_boss_wave + _boss_for_wave (Konstanten-Fallback)
	var boss_id: StringName = _resolve_boss_id_for_wave(_current_wave)
	if String(boss_id) != "" and _spawn_root != null:
		var pos: Vector2 = _random_spawn_position()
		spawn_boss_at(boss_id, pos)


func _on_wave_timeout() -> void:
	if not _active:
		return
	if get_node_or_null("/root/EventBus") != null:
		EventBus.wave_cleared.emit(_current_wave)
	# Auto-Advance: direkt nächste Welle starten. Wer Pick-Phase
	# einschiebt, setzt auto_advance=false und ruft request_next_wave
	# nach dem Pick.
	if _active and auto_advance:
		_start_next_wave()


## Einfache Schwierigkeits-Kurve für v1: linear von 1.0 mit +0.1 pro Welle.
## Wird vom Combat-System später ersetzt durch echte Stats-Skalierung.
func _difficulty_for_wave(wave: int) -> float:
	return 1.0 + 0.1 * (wave - 1)


# ---------------------------------------------------------------------------
# Auto-Spawn (ADR 0013)
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_tick_auto_spawn(delta)


## Tick-Logik für Auto-Spawn. Direkt aus Tests aufrufbar.
## Spawnt einen Enemy, sobald Timer abgelaufen ist; reset Timer.
func _tick_auto_spawn(delta: float) -> void:
	if _current_spawn_interval <= 0.0:
		return
	_auto_spawn_timer = max(0.0, _auto_spawn_timer - delta)
	if _auto_spawn_timer <= 0.0:
		_do_auto_spawn()
		_auto_spawn_timer = _current_spawn_interval


## Erzeugt einen Enemy an zufälliger Position um den Player.
func _do_auto_spawn() -> EnemyMob:
	if _spawn_root == null:
		return null
	var pos: Vector2 = _random_spawn_position()
	return spawn_enemy_at(_enemy_id_for_wave(_current_wave), pos)


## Spawn-Rate für eine Wave-Index (Wellen sind 1-basiert).
## Linear, geclampt auf max_spawn_rate.
##
## Resolver (ADR 0026): WaveDef-Default (is_default=true) → Konstanten-Fallback.
func _spawn_rate_for_wave(idx: int) -> float:
	var def := _get_default_wave_def()
	if def != null:
		var def_rate: float = def.base_spawn_rate + def.spawn_rate_per_wave * float(max(0, idx - 1))
		return min(def_rate, def.max_spawn_rate)
	# Fallback (Backward-Kompat — keine Default-WaveDef vorhanden)
	var const_rate: float = BASE_SPAWN_RATE + SPAWN_RATE_PER_WAVE * float(max(0, idx - 1))
	return min(const_rate, MAX_SPAWN_RATE)


## Pool-Curve nach Welle (ADR 0023 / ADR 0026).
##
## Resolver:
##   1. Override-WaveDef für diesen Index mit non-empty enemy_pool → return
##   2. Default-WaveDef mit non-empty enemy_pool → return
##   3. Konstanten-Fallback (ADR 0023 hardcoded Tiers)
func _pool_for_wave(idx: int) -> Array[StringName]:
	var override_def := _get_override_wave_def(idx)
	if override_def != null and not override_def.enemy_pool.is_empty():
		return override_def.enemy_pool.duplicate()
	var default_def := _get_default_wave_def()
	if default_def != null and not default_def.enemy_pool.is_empty():
		return default_def.enemy_pool.duplicate()
	# Konstanten-Fallback (ADR 0023)
	if idx <= 2:
		return [&"raptor_grunt"]
	if idx <= 5:
		return [&"raptor_grunt", &"raptor_alpha"]
	if idx <= 10:
		return [&"raptor_grunt", &"raptor_alpha", &"pteranodon"]
	return [&"raptor_grunt", &"raptor_alpha", &"pteranodon", &"armored_carnotaurus"]


## Wählt einen zufälligen Enemy-Typ aus dem Pool für diese Welle.
## v1 uniform — Rarity-gewichtetes Spawn ist eigenes ADR.
func _enemy_id_for_wave(idx: int) -> StringName:
	var pool := _pool_for_wave(idx)
	if pool.is_empty():
		return &"raptor_grunt"
	var i := randi() % pool.size()
	return pool[i]


## Resolver für Boss-ID einer Welle (ADR 0026).
## Override-WaveDef.boss_id hat Vorrang vor Konstanten-mod-5-Hook.
func _resolve_boss_id_for_wave(idx: int) -> StringName:
	var override_def := _get_override_wave_def(idx)
	if override_def != null and override_def.boss_id != &"":
		return override_def.boss_id
	if _is_boss_wave(idx):
		return _boss_for_wave(idx)
	return &""


## Spawnt einen Boss an `position` (ADR 0025). Liefert die BossMob-Instanz.
##
## null wenn:
##   - kein spawn_root gesetzt
##   - unbekannte boss_id
##   - BossDef hat keine scene
func spawn_boss_at(boss_id: StringName, position: Vector2) -> BossMob:
	if _spawn_root == null:
		push_warning("WaveSpawner.spawn_boss_at: kein spawn_root gesetzt")
		return null
	if get_node_or_null("/root/ContentLoader") == null:
		return null
	var def: BossDef = ContentLoader.get_or_null(&"boss", boss_id) as BossDef
	if def == null:
		push_warning("WaveSpawner.spawn_boss_at: unbekannter Boss '%s'" % boss_id)
		return null
	if def.scene == null:
		push_warning("WaveSpawner.spawn_boss_at: BossDef '%s' hat keine scene" % boss_id)
		return null

	var boss: BossMob = def.scene.instantiate() as BossMob
	if boss == null:
		push_error("WaveSpawner.spawn_boss_at: Scene ergibt keinen BossMob")
		return null
	_spawn_root.add_child(boss)
	boss.setup(def, position)

	# EventBus.boss_spawned (Signal existiert seit ADR 0001)
	if get_node_or_null("/root/EventBus") != null:
		EventBus.boss_spawned.emit(boss_id, position)
	return boss


## true wenn diese Welle eine Boss-Welle ist (alle BOSS_WAVE_INTERVAL Wellen).
func _is_boss_wave(idx: int) -> bool:
	return idx > 0 and idx % BOSS_WAVE_INTERVAL == 0


## Welcher Boss spawnt in dieser Boss-Welle? v1: nur tyrannosaurus_prime.
func _boss_for_wave(_idx: int) -> StringName:
	return &"tyrannosaurus_prime"


## Zufällige Spawn-Position auf Kreis um den nähesten Player.
## Fallback bei keinem Player: (0,0).
func _random_spawn_position() -> Vector2:
	var center: Vector2 = Vector2.ZERO
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node2D and is_instance_valid(node):
			center = (node as Node2D).global_position
			break
	var angle: float = randf() * TAU
	return center + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS_FROM_PLAYER


# ---------------------------------------------------------------------------
# WaveDef-Resolver (ADR 0026)
# ---------------------------------------------------------------------------

## Liefert die WaveDef für diesen Wave-Index. Resolver-Reihenfolge:
##   1. Override-WaveDef (target_wave_index == idx)
##   2. Default-WaveDef (is_default == true)
##   3. null
##
## Public-API für Game-Code, UI (Wave-Banner) und Tests.
func get_wave_def_for(idx: int) -> WaveDef:
	var override_def := _get_override_wave_def(idx)
	if override_def != null:
		return override_def
	return _get_default_wave_def()


## Liefert die aktuelle WaveDef (für current_wave()).
func get_active_wave_def() -> WaveDef:
	return get_wave_def_for(_current_wave)


## Override-WaveDef für genau diesen Index. null wenn keine existiert.
func _get_override_wave_def(idx: int) -> WaveDef:
	if get_node_or_null("/root/ContentLoader") == null:
		return null
	var all: Array = ContentLoader.get_all(&"wave")
	for item in all:
		var wd: WaveDef = item as WaveDef
		if wd != null and wd.target_wave_index == idx:
			return wd
	return null


## Default-WaveDef (is_default=true). null wenn keine existiert.
func _get_default_wave_def() -> WaveDef:
	if get_node_or_null("/root/ContentLoader") == null:
		return null
	var all: Array = ContentLoader.get_all(&"wave")
	for item in all:
		var wd: WaveDef = item as WaveDef
		if wd != null and wd.is_default:
			return wd
	return null
