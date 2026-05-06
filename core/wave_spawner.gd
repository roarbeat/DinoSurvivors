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
	_timer.start(_wave_duration)
	# Auto-Spawn-Rate für diese Welle setzen
	_current_spawn_interval = 1.0 / _spawn_rate_for_wave(_current_wave)
	_auto_spawn_timer = _current_spawn_interval
	if get_node_or_null("/root/EventBus") != null:
		EventBus.wave_started.emit(_current_wave, _difficulty_for_wave(_current_wave))


func _on_wave_timeout() -> void:
	if not _active:
		return
	if get_node_or_null("/root/EventBus") != null:
		EventBus.wave_cleared.emit(_current_wave)
	# Sofort nächste Welle starten — solange Run noch läuft.
	if _active:
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
## Linear, geclampt auf MAX_SPAWN_RATE.
func _spawn_rate_for_wave(idx: int) -> float:
	var rate: float = BASE_SPAWN_RATE + SPAWN_RATE_PER_WAVE * float(max(0, idx - 1))
	return min(rate, MAX_SPAWN_RATE)


## Welcher Enemy-Typ für diese Welle? v1: nur raptor_grunt.
## Ersetzt durch WaveDef-Lookup mit eigenem ADR.
func _enemy_id_for_wave(_idx: int) -> StringName:
	return &"raptor_grunt"


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
