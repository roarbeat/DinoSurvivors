extends Node
## Globaler RunState-Autoload.
##
## Implementiert ADR 0006. Reine State-Maschine + Run-Metadaten — kein
## Combat, kein Spawn-Logik. Game-Code triggert Übergänge:
##
##   start(dino_id)  IDLE → RUNNING   (feuert run_started)
##   end(reason)     RUNNING → ENDED  (feuert run_ended)
##   reset()         ENDED → IDLE     (kein Signal)
##
## State-Maschine ist explizit; ungültige Übergänge (z.B. start aus RUNNING)
## sind no-ops mit push_warning.

# ---------------------------------------------------------------------------
# Zustände
# ---------------------------------------------------------------------------
enum State { IDLE, RUNNING, ENDED }

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _state: State = State.IDLE
var _active_dino: DinoDef = null
var _run_started_at_msec: int = 0
var _last_end_reason: StringName = &""
var _current_wave: int = 0


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Startet einen neuen Run mit dem angegebenen Dino.
## Rückgabe: true wenn erfolgreich, false bei ungültigem State oder Dino.
func start(dino_id: StringName) -> bool:
	if _state != State.IDLE:
		push_warning("RunState.start: nur aus IDLE möglich (aktueller State: %s)"
			% _state_name(_state))
		return false

	# Dino aus ContentLoader holen — Single Source of Truth.
	if get_node_or_null("/root/ContentLoader") == null:
		push_error("RunState.start: ContentLoader nicht verfügbar")
		return false

	var dino := ContentLoader.get_or_null(&"dino", dino_id) as DinoDef
	if dino == null:
		push_warning("RunState.start: unbekannter Dino '%s'" % dino_id)
		return false

	_state = State.RUNNING
	_active_dino = dino
	_run_started_at_msec = Time.get_ticks_msec()
	_current_wave = 0
	_last_end_reason = &""

	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_started.emit(dino_id)
	return true


## Beendet den Run mit einem Grund. `reason` z.B. &"player_died",
## &"player_quit", &"boss_defeated_final".
func end(reason: StringName) -> void:
	if _state != State.RUNNING:
		push_warning("RunState.end: nur aus RUNNING möglich (aktueller State: %s)"
			% _state_name(_state))
		return

	var run_time := get_run_time()
	_state = State.ENDED
	_last_end_reason = reason

	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_ended.emit(reason, run_time)


## Setzt RunState zurück auf IDLE. Für „zurück ins Hauptmenü" oder
## „neuen Run starten" nach Game-Over-Screen.
func reset() -> void:
	_state = State.IDLE
	_active_dino = null
	_run_started_at_msec = 0
	_current_wave = 0
	_last_end_reason = &""


func is_running() -> bool:
	return _state == State.RUNNING


func is_idle() -> bool:
	return _state == State.IDLE


func is_ended() -> bool:
	return _state == State.ENDED


func get_active_dino() -> DinoDef:
	return _active_dino


## Sekunden seit Run-Start. 0 wenn idle/ended.
## Achtung: pause-blind — Pause-Korrektur kommt mit ADR 0012.
func get_run_time() -> float:
	if _state == State.IDLE or _run_started_at_msec == 0:
		return 0.0
	if _state == State.ENDED:
		# get_run_time während ENDED liefert die letzte Run-Dauer
		# bis zum end()-Aufruf. Wir berechnen ab _run_started_at_msec.
		# Zugriff nach reset() liefert 0.
		pass
	return (Time.get_ticks_msec() - _run_started_at_msec) / 1000.0


func get_current_wave() -> int:
	return _current_wave


func get_last_end_reason() -> StringName:
	return _last_end_reason


# ---------------------------------------------------------------------------
# Internals — von WaveSpawner gerufen
# ---------------------------------------------------------------------------

## WaveSpawner pflegt den Wave-Counter über RunState (Single Source of Truth).
## NICHT von Game-Code direkt aufrufen.
func _set_current_wave(wave: int) -> void:
	_current_wave = wave


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _state_name(s: State) -> String:
	match s:
		State.IDLE: return "IDLE"
		State.RUNNING: return "RUNNING"
		State.ENDED: return "ENDED"
	return "?"
