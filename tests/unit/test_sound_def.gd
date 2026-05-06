extends "res://addons/gut/test.gd"
## SoundDef-Resource-Validation-Tests (ADR 0028).

# ---------------------------------------------------------------------------
# ContentLoader-Discovery
# ---------------------------------------------------------------------------

func test_sfx_enemy_died_is_loaded() -> void:
	assert_true(ContentLoader.has_item(&"sound", &"sfx_enemy_died"))


func test_all_six_initial_sounds_loaded() -> void:
	assert_true(ContentLoader.has_item(&"sound", &"sfx_enemy_died"))
	assert_true(ContentLoader.has_item(&"sound", &"sfx_boss_defeated"))
	assert_true(ContentLoader.has_item(&"sound", &"sfx_player_damaged"))
	assert_true(ContentLoader.has_item(&"sound", &"sfx_player_died"))
	assert_true(ContentLoader.has_item(&"sound", &"sfx_mutation_picked"))
	assert_true(ContentLoader.has_item(&"sound", &"sfx_wave_started"))


func test_sound_is_sounddef_instance() -> void:
	var item := ContentLoader.get_or_null(&"sound", &"sfx_enemy_died")
	assert_not_null(item)
	assert_true(item is SoundDef)


func test_sound_fields_loaded() -> void:
	var s := ContentLoader.get_or_null(&"sound", &"sfx_enemy_died") as SoundDef
	assert_almost_eq(s.volume_db, -3.0, 0.001)
	assert_almost_eq(s.pitch_random_range, 0.1, 0.001)


func test_sound_stream_is_null_in_v1() -> void:
	# v1: alle SoundDefs sind Stubs ohne Stream
	var s := ContentLoader.get_or_null(&"sound", &"sfx_boss_defeated") as SoundDef
	assert_null(s.stream, "v1: stream defaults to null bis Audio-Assets landen")


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _make_minimal() -> SoundDef:
	var s := SoundDef.new()
	s.id = &"test_sound"
	s.display_name_key = &"sfx.test.name"
	return s


func test_validate_passes_for_minimal() -> void:
	var s := _make_minimal()
	assert_eq(s.validate(), "")


func test_validate_rejects_negative_pitch_range() -> void:
	var s := _make_minimal()
	s.pitch_random_range = -0.1
	assert_string_contains(s.validate(), "pitch_random_range")


func test_validate_rejects_pitch_range_above_one() -> void:
	var s := _make_minimal()
	s.pitch_random_range = 1.5
	assert_string_contains(s.validate(), "pitch_random_range")


func test_validate_passes_for_loaded_sounds() -> void:
	for id in [&"sfx_enemy_died", &"sfx_boss_defeated", &"sfx_player_damaged",
		&"sfx_player_died", &"sfx_mutation_picked", &"sfx_wave_started"]:
		var s := ContentLoader.get_or_null(&"sound", id) as SoundDef
		assert_eq(s.validate(), "", "%s sollte keinen Validation-Error haben" % id)


# ---------------------------------------------------------------------------
# ContentLoader-Type-Registration
# ---------------------------------------------------------------------------

func test_sound_type_is_registered() -> void:
	var t := ContentLoader.types()
	assert_true(t.has(&"sound"), "ContentLoader sollte 'sound' als Type kennen")


func test_get_all_sounds_has_six() -> void:
	var all := ContentLoader.get_all(&"sound")
	assert_gte(all.size(), 6, "Sechs initiale Sound-Stubs sollten registriert sein")
