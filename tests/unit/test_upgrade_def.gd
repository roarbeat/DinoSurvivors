extends "res://addons/gut/test.gd"
## UpgradeDef-Tests (ADR 0040).

# ---------------------------------------------------------------------------
# Discovery + Field-Loading
# ---------------------------------------------------------------------------

func test_stronger_jaws_loaded() -> void:
	assert_true(ContentLoader.has_item(&"upgrade", &"stronger_jaws"))


func test_all_initial_upgrades_loaded() -> void:
	assert_true(ContentLoader.has_item(&"upgrade", &"stronger_jaws"))
	assert_true(ContentLoader.has_item(&"upgrade", &"tougher_hide"))
	assert_true(ContentLoader.has_item(&"upgrade", &"faster_legs"))
	assert_true(ContentLoader.has_item(&"upgrade", &"sharper_eyes"))


func test_stronger_jaws_fields() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	assert_eq(u.max_level, 3)
	assert_eq(u.cost_per_level.size(), 3)
	assert_eq(u.cost_per_level[0], 50)
	assert_eq(u.cost_per_level[2], 200)
	assert_eq(u.cost_currency, &"amber")


# ---------------------------------------------------------------------------
# get_cost_for_level
# ---------------------------------------------------------------------------

func test_get_cost_for_level_zero_returns_first_cost() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	assert_eq(u.get_cost_for_level(0), 50)


func test_get_cost_for_level_at_max_returns_neg1() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	assert_eq(u.get_cost_for_level(u.max_level), -1)


func test_get_cost_for_level_repeats_last_when_short() -> void:
	# Wenn cost_per_level kürzer als max_level — letzter Eintrag wiederholt
	var u := UpgradeDef.new()
	u.max_level = 5
	u.cost_per_level = [10, 20]
	assert_eq(u.get_cost_for_level(0), 10)
	assert_eq(u.get_cost_for_level(1), 20)
	assert_eq(u.get_cost_for_level(2), 20)
	assert_eq(u.get_cost_for_level(4), 20)


# ---------------------------------------------------------------------------
# get_modifiers_for_level
# ---------------------------------------------------------------------------

func test_get_modifiers_for_level_zero_is_empty() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	var m := u.get_modifiers_for_level(0)
	assert_eq(m.size(), 0)


func test_get_modifiers_for_level_one_returns_first_dict() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	var m := u.get_modifiers_for_level(1)
	assert_almost_eq(float(m.get(&"damage_pct", 0.0)), 0.05, 0.001)


func test_get_modifiers_for_level_three_returns_third_dict() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	var m := u.get_modifiers_for_level(3)
	assert_almost_eq(float(m.get(&"damage_pct", 0.0)), 0.15, 0.001)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

func _make_minimal() -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = &"test_upgrade"
	u.display_name_key = &"x.y"
	u.max_level = 1
	u.cost_per_level = [10]
	return u


func test_validate_passes_for_minimal() -> void:
	var u := _make_minimal()
	assert_eq(u.validate(), "")


func test_validate_rejects_zero_max_level() -> void:
	var u := _make_minimal()
	u.max_level = 0
	assert_string_contains(u.validate(), "max_level")


func test_validate_rejects_empty_cost_array() -> void:
	var u := _make_minimal()
	u.cost_per_level = []
	assert_string_contains(u.validate(), "cost_per_level")


func test_validate_rejects_empty_currency() -> void:
	var u := _make_minimal()
	u.cost_currency = &""
	assert_string_contains(u.validate(), "cost_currency")


func test_validate_passes_for_loaded_upgrades() -> void:
	for id in [&"stronger_jaws", &"tougher_hide", &"faster_legs", &"sharper_eyes"]:
		var u := ContentLoader.get_or_null(&"upgrade", id) as UpgradeDef
		assert_eq(u.validate(), "", "%s sollte validieren" % id)


# ---------------------------------------------------------------------------
# ContentLoader-Type-Registration
# ---------------------------------------------------------------------------

func test_upgrade_type_registered() -> void:
	var t := ContentLoader.types()
	assert_true(t.has(&"upgrade"))
