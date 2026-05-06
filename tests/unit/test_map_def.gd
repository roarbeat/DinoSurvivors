extends "res://addons/gut/test.gd"
## MapDef-Tests (ADR 0036).

# ---------------------------------------------------------------------------
# Discovery + Field-Loading
# ---------------------------------------------------------------------------

func test_default_map_is_loaded() -> void:
	assert_true(ContentLoader.has_item(&"map", &"default"))


func test_default_map_is_mapdef_instance() -> void:
	var item := ContentLoader.get_or_null(&"map", &"default")
	assert_not_null(item)
	assert_true(item is MapDef)


func test_default_map_fields() -> void:
	var m := ContentLoader.get_or_null(&"map", &"default") as MapDef
	assert_eq(m.grid_size, Vector2i(8, 8))
	assert_eq(m.path_row, 4)
	assert_eq(m.path_col, 4)
	assert_true(m.deterministic_colors)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _make_minimal() -> MapDef:
	var m := MapDef.new()
	m.id = &"test_map"
	m.display_name_key = &"map.test.name"
	return m


func test_validate_passes_for_default() -> void:
	var m := _make_minimal()
	assert_eq(m.validate(), "")


func test_validate_rejects_negative_grid_size() -> void:
	var m := _make_minimal()
	m.grid_size = Vector2i(-1, 5)
	assert_string_contains(m.validate(), "grid_size")


func test_validate_passes_for_default_loaded_from_content() -> void:
	var m := ContentLoader.get_or_null(&"map", &"default") as MapDef
	assert_eq(m.validate(), "")


# ---------------------------------------------------------------------------
# ContentLoader-Type-Registration
# ---------------------------------------------------------------------------

func test_map_type_is_registered() -> void:
	var t := ContentLoader.types()
	assert_true(t.has(&"map"))
