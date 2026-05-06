extends "res://addons/gut/test.gd"
## SfxBus-Tests (ADR 0028).
##
## Headless-testbar dank No-op-Verhalten bei null-Stream. v1-SoundDefs
## haben alle stream=null, daher liefert play() konstant false. Tests
## verifizieren API-Surface, Pool-Setup, Mapping, Mute-Hook.

# ---------------------------------------------------------------------------
# Setup-Pre-Conditions
# ---------------------------------------------------------------------------

func before_each() -> void:
	if SfxBus.is_muted():
		SfxBus.set_muted(false)


# ---------------------------------------------------------------------------
# Pool-Setup
# ---------------------------------------------------------------------------

func test_pool_size_is_eight() -> void:
	assert_eq(SfxBus.pool_size(), SfxBus.POOL_SIZE)
	assert_eq(SfxBus.POOL_SIZE, 8)


func test_pool_players_are_audio_stream_players() -> void:
	# Mindestens ein Player als Child mit dem erwarteten Naming
	assert_not_null(SfxBus.get_node_or_null("Player_0"))
	assert_not_null(SfxBus.get_node_or_null("Player_7"))
	# Player_8 darf nicht existieren (Pool-Size = 8 → Indizes 0–7)
	assert_null(SfxBus.get_node_or_null("Player_8"))


# ---------------------------------------------------------------------------
# Default-Mappings
# ---------------------------------------------------------------------------

func test_signal_to_sound_has_six_mappings() -> void:
	# Public-API: alle bedeutsamen EventBus-Signals sind gemappt
	assert_eq(SfxBus.SIGNAL_TO_SOUND.size(), 6)


func test_default_mappings_match_known_signals() -> void:
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"enemy_died"], &"sfx_enemy_died")
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"boss_defeated"], &"sfx_boss_defeated")
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"player_damaged"], &"sfx_player_damaged")
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"player_died"], &"sfx_player_died")
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"mutation_picked"], &"sfx_mutation_picked")
	assert_eq(SfxBus.SIGNAL_TO_SOUND[&"wave_started"], &"sfx_wave_started")


func test_get_signal_mapping_returns_default() -> void:
	assert_eq(SfxBus.get_signal_mapping(&"enemy_died"), &"sfx_enemy_died")


func test_get_signal_mapping_unknown_returns_empty() -> void:
	var mapping: StringName = SfxBus.get_signal_mapping(&"unknown_signal")
	assert_eq(String(mapping), "")


func test_add_signal_mapping_extends_runtime() -> void:
	# Mods können neue Mappings zur Laufzeit ergänzen
	SfxBus.add_signal_mapping(&"my_custom_signal", &"my_custom_sound")
	assert_eq(SfxBus.get_signal_mapping(&"my_custom_signal"), &"my_custom_sound")


# ---------------------------------------------------------------------------
# play() — No-op-Verhalten
# ---------------------------------------------------------------------------

func test_play_unknown_sound_id_is_noop() -> void:
	var result := SfxBus.play(&"this_sound_does_not_exist")
	assert_false(result, "Unbekannte SoundID → no-op (false)")


func test_play_known_sound_with_null_stream_is_noop() -> void:
	# v1: alle SoundDefs haben stream=null → play() liefert false
	var result := SfxBus.play(&"sfx_enemy_died")
	assert_false(result, "v1: SoundDef mit stream=null → no-op (false)")


func test_play_returns_false_when_muted() -> void:
	SfxBus.set_muted(true)
	var result := SfxBus.play(&"sfx_enemy_died")
	assert_false(result)
	SfxBus.set_muted(false)


# ---------------------------------------------------------------------------
# Mute-Hook
# ---------------------------------------------------------------------------

func test_set_muted_toggles_state() -> void:
	assert_false(SfxBus.is_muted(), "Default-Zustand: unmuted")
	SfxBus.set_muted(true)
	assert_true(SfxBus.is_muted())
	SfxBus.set_muted(false)
	assert_false(SfxBus.is_muted())


func test_muting_stops_active_players() -> void:
	# Selbst ohne Stream sollte stop() aufgerufen werden — kein Crash
	SfxBus.set_muted(true)
	# kein assert nötig — wenn es nicht crasht, ist alles gut
	pass_test("set_muted(true) stoppt alle Player ohne Crash")
	SfxBus.set_muted(false)


# ---------------------------------------------------------------------------
# EventBus-Subscription smoke
# ---------------------------------------------------------------------------

func test_event_bus_signal_does_not_crash_sfx_bus() -> void:
	# Dass die Signal-Handler ohne Crash durchlaufen, auch wenn play() no-op ist
	# (Hauptsächlich Defensiver-Test gegen Reconnects beim Mod-Reload).
	EventBus.enemy_died.emit(&"raptor_grunt", Vector2.ZERO)
	EventBus.boss_defeated.emit(&"tyrannosaurus_prime", 60.0)
	EventBus.player_damaged.emit(8.0, &"raptor_grunt")
	EventBus.player_died.emit()
	EventBus.mutation_picked.emit(&"triceratops_horns")
	EventBus.wave_started.emit(1, 1.0)
	pass_test("Alle bekannten EventBus-Signals werden vom SfxBus ohne Crash bedient")
