extends "res://addons/gut/test.gd"
## gut-Unit-Tests für den EventBus.
##
## Nutzt GUT's watch_signals + assert_signal_emitted statt
## lambda-Capture-Tricks — GDScript-Lambdas können äußere Variablen
## nicht durchgängig schreiben (kein Closure-Write-Through).

# Erwartete Signal-Surface — synchron halten mit core/event_bus.gd.
# Jede Änderung hier ist ein Mod-API-Breaking-Change → mod-api-curator
# konsultieren.
const EXPECTED_SIGNALS: Array[String] = [
	"enemy_died",
	"player_damaged",
	"player_died",
	"wave_started",
	"wave_cleared",
	"boss_spawned",
	"boss_defeated",
	"boss_phase_changed",
	"boss_ability_used",
	"upgrade_purchased",
	"mutation_offered",
	"mutation_picked",
	"xp_gained",
	"level_up",
	"currency_changed",
	"save_requested",
	"save_completed",
	"save_loaded",
	"mod_loaded",
	"mod_failed",
	"content_loaded",
	"run_started",
	"run_ended",
	"mutations_changed",
]


func before_each() -> void:
	# EventBus ist Autoload — bei jedem Test frisch beobachten
	watch_signals(EventBus)


# ---------------------------------------------------------------------------
# Surface-Tests
# ---------------------------------------------------------------------------

func test_all_expected_signals_present() -> void:
	var actual := EventBus.list_signals()
	for expected in EXPECTED_SIGNALS:
		assert_true(actual.has(expected),
			"Erwartetes Signal '%s' fehlt im EventBus" % expected)


func test_signal_count_matches_inventory() -> void:
	var actual := EventBus.list_signals()
	var our_signals: Array[String] = []
	for s in actual:
		if EXPECTED_SIGNALS.has(s):
			our_signals.append(s)
	assert_eq(our_signals.size(), EXPECTED_SIGNALS.size(),
		"EventBus hat unerwartete Anzahl an Signals — Liste pflegen")


# ---------------------------------------------------------------------------
# Verhaltens-Tests via watch_signals
# ---------------------------------------------------------------------------

func test_enemy_died_emit_and_receive() -> void:
	EventBus.enemy_died.emit(&"trex_grunt", Vector2(10, 20))
	assert_signal_emitted_with_parameters(EventBus, "enemy_died",
		[&"trex_grunt", Vector2(10, 20)])


func test_save_requested_passes_reason() -> void:
	EventBus.save_requested.emit(&"wave_end")
	assert_signal_emitted_with_parameters(EventBus, "save_requested",
		[&"wave_end"])


func test_mutation_offered_array_payload() -> void:
	var offer: Array = [&"triceratops_horns", &"spinosaur_sail", &"raptor_dash"]
	EventBus.mutation_offered.emit(offer)
	# Vergleich übers Param-Array
	assert_signal_emitted(EventBus, "mutation_offered",
		"mutation_offered nicht gefeuert")
	assert_eq(get_signal_emit_count(EventBus, "mutation_offered"), 1)
	var params: Array = get_signal_parameters(EventBus, "mutation_offered")
	assert_eq(params[0], offer)


func test_player_died_no_payload() -> void:
	EventBus.player_died.emit()
	assert_signal_emitted(EventBus, "player_died",
		"player_died wurde nicht empfangen")


func test_boss_defeated_run_time_float() -> void:
	EventBus.boss_defeated.emit(&"tyrannosaurus_prime", 1234.5)
	assert_signal_emitted(EventBus, "boss_defeated")
	var params: Array = get_signal_parameters(EventBus, "boss_defeated")
	assert_eq(params[0], &"tyrannosaurus_prime")
	assert_almost_eq(params[1], 1234.5, 0.001)
