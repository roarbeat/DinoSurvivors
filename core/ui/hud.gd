class_name HUDOverlay
extends CanvasLayer
## In-Game-HUD (ADR 0020).
##
## Drei Anzeigen: Run-Timer, Wave-Counter, Mutation-Liste.
## Listet auf EventBus-Signals + pollt RunState pro Frame für den Timer.

@onready var timer_label: Label = $Container/TimerLabel
@onready var wave_label: Label = $Container/WaveLabel
@onready var mutations_label: Label = $Container/MutationsLabel


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive Stubs für Tests, die HUD ohne Scene-Children instanzieren
	if not has_node("Container/TimerLabel"):
		_init_default_labels()

	visible = false  # erst aktivieren wenn Run läuft

	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_started.connect(_on_run_started)
		EventBus.run_ended.connect(_on_run_ended)
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.mutations_changed.connect(_on_mutations_changed)


func _init_default_labels() -> void:
	# Defensive Construction für Tests
	var c := MarginContainer.new()
	c.name = "Container"
	add_child(c)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	c.add_child(timer_label)
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	c.add_child(wave_label)
	mutations_label = Label.new()
	mutations_label.name = "MutationsLabel"
	c.add_child(mutations_label)


func _process(_delta: float) -> void:
	if not visible:
		return
	if get_node_or_null("/root/RunState") == null:
		return
	if not RunState.is_running():
		return
	timer_label.text = _format_time(RunState.get_run_time())


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

func set_run_active(active: bool) -> void:
	visible = active


func update_wave(wave_idx: int, difficulty: float) -> void:
	if wave_label == null:
		return
	wave_label.text = "Wave %d" % wave_idx
	# difficulty als zweite Zeile (optional, hilft Spielern Pressure-Anstieg
	# zu sehen). Format: "Wave 3\n×1.2"
	if difficulty > 1.0:
		wave_label.text += "\n×%.1f" % difficulty


func update_mutations(mutation_ids: Array) -> void:
	if mutations_label == null:
		return
	if mutation_ids.is_empty():
		mutations_label.text = "(no mutations)"
		return
	var lines: Array[String] = []
	for id in mutation_ids:
		lines.append(String(id))
	mutations_label.text = "\n".join(lines)


# ---------------------------------------------------------------------------
# Format-Helper (testbar)
# ---------------------------------------------------------------------------

static func _format_time(seconds: float) -> String:
	var s_int: int = int(max(0.0, seconds))
	var minutes: int = s_int / 60
	var secs: int = s_int % 60
	return "%d:%02d" % [minutes, secs]


# ---------------------------------------------------------------------------
# EventBus-Hooks
# ---------------------------------------------------------------------------

func _on_run_started(_dino_id: StringName) -> void:
	set_run_active(true)
	update_wave(1, 1.0)
	update_mutations([])
	if timer_label != null:
		timer_label.text = "0:00"


func _on_run_ended(_reason: StringName, _run_time: float) -> void:
	# HUD bleibt sichtbar bis zum Restart? Nein — GameOver liegt darüber
	# und blockiert die Sicht. Wir verstecken den HUD beim run_ended,
	# damit beim Restart der HUD durch run_started wieder einblendet.
	set_run_active(false)


func _on_wave_started(wave_idx: int, difficulty: float) -> void:
	update_wave(wave_idx, difficulty)


func _on_mutations_changed() -> void:
	if get_node_or_null("/root/PlayerMutations") == null:
		return
	update_mutations(PlayerMutations.get_picked())
