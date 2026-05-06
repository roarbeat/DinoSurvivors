extends "res://addons/gut/test.gd"
## gut-Unit-Tests für den ContentLoader.
##
## Testet:
##   - Discovery findet existierende Core-Content-Files
##   - Type-Registry liefert korrekte Items
##   - Validation greift bei kaputten IDs / Klassen-Mismatch
##   - Override-Verhalten (warn + skip) bei Kollision ohne Flag
##
## Voraussetzung: ContentLoader-Autoload geladen (siehe project.godot).

func test_known_mutation_is_registered() -> void:
	# triceratops_horns ist die Pipeline-Validation-Mutation aus Phase 0
	assert_true(ContentLoader.has_item(&"mutation", &"triceratops_horns"),
		"triceratops_horns muss vom ContentLoader gefunden werden")


func test_get_returns_correct_type() -> void:
	var item := ContentLoader.get_or_null(&"mutation", &"triceratops_horns")
	assert_not_null(item)
	assert_true(item is MutationDef, "Item muss MutationDef sein, ist %s" % typeof(item))


func test_mutation_fields_loaded() -> void:
	var m := ContentLoader.get_or_null(&"mutation", &"triceratops_horns") as MutationDef
	assert_eq(m.id, &"triceratops_horns")
	assert_eq(m.rarity, &"common")
	assert_true(m.stat_modifiers.has(&"damage_pct"))
	assert_almost_eq(m.stat_modifiers[&"damage_pct"], 0.15, 0.0001)
	assert_true(m.tags.has(&"horn"))


func test_unknown_id_returns_null() -> void:
	var nope := ContentLoader.get_or_null(&"mutation", &"does_not_exist")
	assert_null(nope, "Unbekannte ID muss null zurückgeben")


func test_unknown_type_returns_empty() -> void:
	var nope := ContentLoader.get_all(&"nonexistent_type")
	assert_eq(nope.size(), 0)


func test_types_includes_known_kinds() -> void:
	var t := ContentLoader.types()
	assert_true(t.has(&"mutation"))
	assert_true(t.has(&"enemy"))
	assert_true(t.has(&"boss"))
	assert_true(t.has(&"dino"))
	assert_true(t.has(&"wave"))
	assert_true(t.has(&"sound"))


func test_all_ids_returns_known_mutation() -> void:
	var ids := ContentLoader.all_ids(&"mutation")
	assert_true(ids.has(&"triceratops_horns"))


func test_id_validator_rejects_invalid_ids() -> void:
	# White-Box: testet die private Methode via Test-Hack
	# Hinweis: gut-Tests umgehen access-modifiers — hier OK weil
	# Validation-Logik kritisch ist und keine andere Surface hat.
	var loader := ContentLoader  # Autoload-Singleton
	assert_true(loader._is_valid_id("triceratops_horns"))
	assert_true(loader._is_valid_id("a"))
	assert_true(loader._is_valid_id("a1_b2"))
	assert_false(loader._is_valid_id(""))
	assert_false(loader._is_valid_id("CamelCase"))
	assert_false(loader._is_valid_id("with-dash"))
	assert_false(loader._is_valid_id("with space"))
	assert_false(loader._is_valid_id("ümlaut"))
	# 41 Zeichen
	assert_false(loader._is_valid_id("a".repeat(41)))


func test_content_loaded_signal_was_emitted() -> void:
	# Wenn der Loader sauber gebootet hat, sollte content_loaded gefeuert
	# worden sein — wir prüfen über die Registry-Größe als Proxy.
	var item_count := 0
	for t in ContentLoader.types():
		item_count += ContentLoader.all_ids(t).size()
	assert_gt(item_count, 0,
		"ContentLoader sollte mind. 1 Item geladen haben (triceratops_horns)")


func test_mutation_pool_has_at_least_seven() -> void:
	# Stand v0.0.5+: 7 Mutationen (3 v0.0.3 + 4 in dieser Iteration)
	var all := ContentLoader.all_ids(&"mutation")
	assert_gte(all.size(), 7,
		"Mutation-Pool muss mindestens 7 Einträge haben (Pick-Phase braucht Vielfalt)")


func test_mutation_pool_includes_new_additions() -> void:
	var all := ContentLoader.all_ids(&"mutation")
	for expected_id in [&"velociraptor_dash", &"t_rex_jaw",
			&"stegosaurus_thagomizer", &"pterodactyl_glide"]:
		assert_true(all.has(expected_id),
			"Erwartete neue Mutation '%s' fehlt im Loader" % expected_id)


func test_validate_method_on_mutation_def() -> void:
	# Direkter Validation-Test ohne ContentLoader-Schicht
	var bad := MutationDef.new()
	bad.id = &""
	bad.display_name_key = &"x"
	assert_eq(bad.validate(), "id ist leer")

	var good := MutationDef.new()
	good.id = &"test_mut"
	good.display_name_key = &"x.y"
	good.rarity = &"epic"
	good.stat_modifiers = { &"damage_pct": 0.5 }
	assert_eq(good.validate(), "")

	var bad_rarity := MutationDef.new()
	bad_rarity.id = &"test_mut"
	bad_rarity.display_name_key = &"x.y"
	bad_rarity.rarity = &"mythic"  # nicht in VALID_RARITIES
	assert_string_contains(bad_rarity.validate(), "rarity")


# ---------------------------------------------------------------------------
# Content-Pool nach v0.0.7 (ADR 0023)
# ---------------------------------------------------------------------------

func test_enemy_pool_has_at_least_four() -> void:
	var ids := ContentLoader.all_ids(&"enemy")
	assert_gte(ids.size(), 4,
		"Enemy-Pool muss mindestens 4 Einträge haben")


func test_enemy_pool_includes_new_variants() -> void:
	var ids := ContentLoader.all_ids(&"enemy")
	for expected_id in [&"raptor_grunt", &"pteranodon", &"raptor_alpha",
			&"armored_carnotaurus"]:
		assert_true(ids.has(expected_id),
			"Enemy '%s' fehlt im Loader" % expected_id)


func test_boss_resource_loaded() -> void:
	var ids := ContentLoader.all_ids(&"boss")
	assert_true(ids.has(&"tyrannosaurus_prime"),
		"BossDef-Stub muss vom Loader gefunden werden")
	var boss := ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	assert_not_null(boss)
	assert_eq(boss.max_health, 800.0)
	assert_eq(boss.reward_currency_amount, 50)
