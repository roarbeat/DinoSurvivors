extends "res://addons/gut/test.gd"
## WaveDef-Resource-Validation-Tests (ADR 0026).

# ---------------------------------------------------------------------------
# ContentLoader-Discovery
# ---------------------------------------------------------------------------

func test_wave_default_is_loaded() -> void:
	assert_true(ContentLoader.has_item(&"wave", &"wave_default"),
		"wave_default muss vom ContentLoader gefunden werden")


func test_wave_5_tyrannosaurus_is_loaded() -> void:
	assert_true(ContentLoader.has_item(&"wave", &"wave_5_tyrannosaurus"))


func test_wave_default_is_wavedef_instance() -> void:
	var item := ContentLoader.get_or_null(&"wave", &"wave_default")
	assert_not_null(item)
	assert_true(item is WaveDef)


func test_wave_default_fields() -> void:
	var w := ContentLoader.get_or_null(&"wave", &"wave_default") as WaveDef
	assert_true(w.is_default)
	assert_eq(w.target_wave_index, 0)
	assert_almost_eq(w.base_spawn_rate, 0.5, 0.001)
	assert_almost_eq(w.spawn_rate_per_wave, 0.3, 0.001)
	assert_almost_eq(w.max_spawn_rate, 5.0, 0.001)


func test_wave_5_tyrannosaurus_fields() -> void:
	var w := ContentLoader.get_or_null(&"wave", &"wave_5_tyrannosaurus") as WaveDef
	assert_false(w.is_default)
	assert_eq(w.target_wave_index, 5)
	assert_eq(w.boss_id, &"tyrannosaurus_prime")
	assert_true(w.enemy_pool.has(&"raptor_grunt"))
	assert_true(w.enemy_pool.has(&"raptor_alpha"))


func test_wave_10_tyrannosaurus_fields() -> void:
	var w := ContentLoader.get_or_null(&"wave", &"wave_10_tyrannosaurus") as WaveDef
	assert_false(w.is_default)
	assert_eq(w.target_wave_index, 10)
	assert_eq(w.boss_id, &"tyrannosaurus_prime")
	assert_eq(w.enemy_pool.size(), 4)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _make_minimal_default() -> WaveDef:
	var w := WaveDef.new()
	w.id = &"test_wave"
	w.display_name_key = &"wave.test.name"
	w.is_default = true
	w.target_wave_index = 0
	w.base_spawn_rate = 0.5
	w.spawn_rate_per_wave = 0.3
	w.max_spawn_rate = 5.0
	return w


func _make_minimal_override(idx: int) -> WaveDef:
	var w := WaveDef.new()
	w.id = StringName("test_wave_%d" % idx)
	w.display_name_key = &"wave.test.name"
	w.is_default = false
	w.target_wave_index = idx
	return w


func test_validate_passes_for_default() -> void:
	var w := _make_minimal_default()
	assert_eq(w.validate(), "")


func test_validate_passes_for_override() -> void:
	var w := _make_minimal_override(5)
	assert_eq(w.validate(), "")


func test_validate_rejects_both_default_and_override() -> void:
	var w := _make_minimal_default()
	w.target_wave_index = 5
	assert_string_contains(w.validate(), "is_default=true und target_wave_index>0")


func test_validate_rejects_neither_default_nor_override() -> void:
	var w := WaveDef.new()
	w.id = &"test_wave"
	w.display_name_key = &"wave.test.name"
	w.is_default = false
	w.target_wave_index = 0
	assert_string_contains(w.validate(), "is_default=true ODER target_wave_index>0")


func test_validate_rejects_negative_base_spawn_rate() -> void:
	var w := _make_minimal_default()
	w.base_spawn_rate = -0.1
	assert_string_contains(w.validate(), "base_spawn_rate")


func test_validate_rejects_negative_spawn_rate_per_wave() -> void:
	var w := _make_minimal_default()
	w.spawn_rate_per_wave = -0.1
	assert_string_contains(w.validate(), "spawn_rate_per_wave")


func test_validate_rejects_max_lower_than_base() -> void:
	var w := _make_minimal_default()
	w.base_spawn_rate = 2.0
	w.max_spawn_rate = 1.0
	assert_string_contains(w.validate(), "max_spawn_rate")


func test_validate_rejects_negative_duration() -> void:
	var w := _make_minimal_default()
	w.duration_sec = -1.0
	assert_string_contains(w.validate(), "duration_sec")


func test_validate_rejects_boss_id_on_default() -> void:
	var w := _make_minimal_default()
	w.boss_id = &"tyrannosaurus_prime"
	assert_string_contains(w.validate(), "boss_id")


func test_validate_passes_for_default_loaded_from_content() -> void:
	var w := ContentLoader.get_or_null(&"wave", &"wave_default") as WaveDef
	assert_eq(w.validate(), "", "wave_default darf keinen Validation-Error haben")


func test_validate_passes_for_override_loaded_from_content() -> void:
	var w := ContentLoader.get_or_null(&"wave", &"wave_5_tyrannosaurus") as WaveDef
	assert_eq(w.validate(), "")


# ---------------------------------------------------------------------------
# ContentLoader-Type-Registration
# ---------------------------------------------------------------------------

func test_wave_type_is_registered() -> void:
	var t := ContentLoader.types()
	assert_true(t.has(&"wave"), "ContentLoader sollte 'wave' als Type kennen")


func test_get_all_waves_non_empty() -> void:
	var all := ContentLoader.get_all(&"wave")
	assert_gt(all.size(), 0)
