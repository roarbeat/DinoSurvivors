extends "res://addons/gut/test.gd"
## DamageInfo-Resource-Tests.

func test_make_factory_sets_fields() -> void:
	var info := DamageInfo.make(15.0, &"triceratops_horns", &"physical", true)
	assert_eq(info.amount, 15.0)
	assert_eq(info.source_id, &"triceratops_horns")
	assert_eq(info.damage_type, &"physical")
	assert_true(info.is_crit)


func test_make_defaults() -> void:
	var info := DamageInfo.make(5.0)
	assert_eq(info.damage_type, &"physical")
	assert_false(info.is_crit)
	assert_false(info.pierce_armor)
	assert_eq(info.source_id, &"")


func test_validate_rejects_negative_amount() -> void:
	var info := DamageInfo.make(-1.0)
	assert_string_contains(info.validate(), "amount")


func test_validate_rejects_empty_damage_type() -> void:
	var info := DamageInfo.make(5.0)
	info.damage_type = &""
	assert_string_contains(info.validate(), "damage_type")


func test_validate_passes_for_positive() -> void:
	var info := DamageInfo.make(10.0, &"src", &"fire", false)
	assert_eq(info.validate(), "")


func test_with_amount_returns_copy() -> void:
	var orig := DamageInfo.make(10.0, &"src", &"fire", true)
	var copy := orig.with_amount(20.0)
	assert_ne(orig, copy, "with_amount muss neue Instanz liefern")
	assert_eq(orig.amount, 10.0, "Original darf nicht modifiziert werden")
	assert_eq(copy.amount, 20.0)
	assert_eq(copy.source_id, &"src")
	assert_eq(copy.is_crit, true)
