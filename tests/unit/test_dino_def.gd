extends "res://addons/gut/test.gd"
## DinoDef-Resource-Validation-Tests.

func test_trex_loaded_via_content_loader() -> void:
	assert_true(ContentLoader.has_item(&"dino", &"trex"),
		"trex muss vom ContentLoader gefunden werden")


func test_trex_is_dino_def_instance() -> void:
	var item := ContentLoader.get_or_null(&"dino", &"trex")
	assert_not_null(item)
	assert_true(item is DinoDef)


func test_trex_fields_loaded() -> void:
	var d := ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	assert_eq(d.id, &"trex")
	assert_eq(d.max_health, 120.0)
	assert_eq(d.base_damage, 15.0)
	assert_almost_eq(d.base_attack_rate, 0.8, 0.001)


func test_validate_rejects_zero_health() -> void:
	var d := DinoDef.new()
	d.id = &"test_dino"
	d.display_name_key = &"x.y"
	d.max_health = 0.0
	d.base_speed = 1.0
	d.base_attack_rate = 1.0
	assert_string_contains(d.validate(), "max_health")


func test_validate_rejects_negative_pickup_radius() -> void:
	var d := DinoDef.new()
	d.id = &"test_dino"
	d.display_name_key = &"x.y"
	d.max_health = 10.0
	d.base_speed = 1.0
	d.base_attack_rate = 1.0
	d.pickup_radius = -1.0
	assert_string_contains(d.validate(), "pickup_radius")


func test_validate_passes_for_trex() -> void:
	var d := ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	assert_eq(d.validate(), "", "trex darf keinen Validation-Error haben")
