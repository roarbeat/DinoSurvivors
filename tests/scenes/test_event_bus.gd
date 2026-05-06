extends Control
## Manuelle Smoke-Test-Scene für den EventBus.
##
## Zeigt eine Liste aller Signals und einen Button pro Signal.
## Klick → Signal feuert mit Beispiel-Payload, EventBus loggt in den Output
## (sofern enable_debug_logging() aktiv ist) und ein UI-Counter zählt hoch.
##
## Dient als visuelle Gegenprobe zum gut-Test und als Demo für Modder.

@onready var _list: VBoxContainer = $Margin/Scroll/List
@onready var _log_label: Label = $Margin/Footer/LogLabel
var _fire_count: int = 0
var _last_signal: String = "-"


func _ready() -> void:
	EventBus.enable_debug_logging()
	# Globaler Counter: bei JEDEM Signal-Empfang +1, egal welches.
	# `bind()` würde Args am Ende anhängen und die Variadic-Lambda
	# unsauber machen — wir zählen daher ohne Signal-Namen-Bind und
	# setzen den Namen stattdessen beim Klick.
	for sig_name in EventBus.list_signals():
		EventBus.connect(sig_name, _on_any_signal)
		_add_button_for_signal(sig_name)


func _add_button_for_signal(sig_name: String) -> void:
	var btn := Button.new()
	btn.text = sig_name
	btn.pressed.connect(_fire_example.bind(sig_name))
	_list.add_child(btn)


func _fire_example(sig_name: String) -> void:
	# `_last_signal` setzen BEVOR emit, damit der Counter-Callback
	# bereits den richtigen Namen sieht.
	_last_signal = sig_name
	# Beispiel-Payloads — bewusst hier hardcoded, weil reine Test-Scene.
	# Im Game-Code sind solche Payloads niemals hardcoded.
	match sig_name:
		"enemy_died":
			EventBus.enemy_died.emit(&"trex_grunt", Vector2(100, 200))
		"player_damaged":
			EventBus.player_damaged.emit(15.0, &"boss_acid_pool")
		"player_died":
			EventBus.player_died.emit()
		"wave_started":
			EventBus.wave_started.emit(3, 1.4)
		"wave_cleared":
			EventBus.wave_cleared.emit(3)
		"boss_spawned":
			EventBus.boss_spawned.emit(&"tyrannosaurus_prime", Vector2(0, 0))
		"boss_defeated":
			EventBus.boss_defeated.emit(&"tyrannosaurus_prime", 612.4)
		"mutation_offered":
			EventBus.mutation_offered.emit([&"triceratops_horns", &"raptor_dash"])
		"mutation_picked":
			EventBus.mutation_picked.emit(&"triceratops_horns")
		"xp_gained":
			EventBus.xp_gained.emit(50)
		"level_up":
			EventBus.level_up.emit(7)
		"currency_changed":
			EventBus.currency_changed.emit(&"amber", 1280)
		"save_requested":
			EventBus.save_requested.emit(&"manual_smoke_test")
		"save_completed":
			EventBus.save_completed.emit()
		"save_loaded":
			EventBus.save_loaded.emit(1)
		"mod_loaded":
			EventBus.mod_loaded.emit(&"example_mod")
		"mod_failed":
			EventBus.mod_failed.emit(&"broken_mod", "manifest.json missing")
		"content_loaded":
			EventBus.content_loaded.emit(3, 1)
		"run_started":
			EventBus.run_started.emit(&"trex")
		"run_ended":
			EventBus.run_ended.emit(&"player_died", 612.4)
		"mutations_changed":
			EventBus.mutations_changed.emit()


# Variadic-fähig — Godot ruft mit der Anzahl Args auf, die das Signal
# deklariert. Wir benutzen die Args nicht, sondern lesen `_last_signal`,
# das vor dem emit() gesetzt wurde.
func _on_any_signal(_a = null, _b = null, _c = null) -> void:
	_fire_count += 1
	# Bewusst kein tr() — Dev-Tooling, nicht User-facing.
	_log_label.text = "Signals total: %d  •  zuletzt: %s" % [_fire_count, _last_signal]
