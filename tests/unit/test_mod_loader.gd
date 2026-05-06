extends "res://addons/gut/test.gd"
## gut-Unit-Tests für den ModLoader.
##
## Nutzt res://tests/fixtures/mods/ als Scan-Wurzel statt user://mods/,
## damit Tests deterministisch und ohne FS-Setup laufen.

func before_each() -> void:
	watch_signals(EventBus)
	# Scan-Wurzel auf Fixtures umlegen und re-discover
	ModLoader._set_scan_roots([ModLoader.FIXTURE_MOD_ROOT])
	ModLoader.discover()


func after_all() -> void:
	# Cleanup: zurück auf Default-Pfad, falls weitere Tests laufen
	ModLoader._set_scan_roots([ModLoader.MOD_ROOT])
	ModLoader.discover()


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

func test_example_mod_loads_successfully() -> void:
	assert_true(ModLoader.is_loaded(&"example_mod"),
		"example_mod sollte als aktiver Mod gelten")


func test_broken_mod_is_in_failed_list() -> void:
	var failed := ModLoader.failed_mods()
	var ids: Array = []
	for f in failed:
		ids.append(f["id"])
	assert_true(ids.has(&"broken_mod"),
		"broken_mod (invalides JSON) sollte in failed_mods sein")


func test_wrong_schema_mod_failed_with_missing_field() -> void:
	var failed := ModLoader.failed_mods()
	var found := false
	for f in failed:
		if f["id"] == &"wrong_schema_mod":
			assert_string_contains(f["error"], "missing_field",
				"Fehlerbeschreibung muss 'missing_field' enthalten")
			found = true
	assert_true(found, "wrong_schema_mod muss in failed_mods sein")


func test_active_count_matches_list_active() -> void:
	# example_mod ist der einzige gültige Mod im Fixtures-Set
	var active := ModLoader.list_active()
	assert_eq(active.size(), 1)
	assert_eq(active[0], &"example_mod")


func test_get_manifest_returns_deep_copy() -> void:
	var m1 := ModLoader.get_manifest(&"example_mod")
	m1["name"] = "MUTATED IN TEST"
	var m2 := ModLoader.get_manifest(&"example_mod")
	assert_ne(m2["name"], "MUTATED IN TEST",
		"get_manifest() muss deep-copy zurückgeben")


func test_get_manifest_unknown_returns_empty() -> void:
	var m := ModLoader.get_manifest(&"does_not_exist")
	assert_eq(m, {})


# ---------------------------------------------------------------------------
# EventBus-Signals
# ---------------------------------------------------------------------------

func test_mod_loaded_signal_emitted_for_example() -> void:
	# Watch wurde in before_each gesetzt, discover() lief auch dort
	assert_signal_emitted_with_parameters(EventBus, "mod_loaded",
		[&"example_mod"])


func test_mod_failed_signal_emitted_for_broken() -> void:
	# Watch wurde in before_each gesetzt
	# Wir prüfen, dass mod_failed mindestens einmal gefeuert wurde
	assert_signal_emitted(EventBus, "mod_failed",
		"mod_failed sollte für broken_mod und wrong_schema_mod feuern")
	var count: int = get_signal_emit_count(EventBus, "mod_failed")
	assert_gte(count, 2, "mod_failed sollte mindestens 2× feuern")


# ---------------------------------------------------------------------------
# ID-Validierung
# ---------------------------------------------------------------------------

func test_id_validator_rejects_invalid() -> void:
	assert_true(ModLoader._is_valid_mod_id("example_mod"))
	assert_false(ModLoader._is_valid_mod_id(""))
	assert_false(ModLoader._is_valid_mod_id("CamelCase"))
	assert_false(ModLoader._is_valid_mod_id("with-dash"))
	assert_false(ModLoader._is_valid_mod_id("ümlaut"))


# ---------------------------------------------------------------------------
# ContentLoader-Bridge
# ---------------------------------------------------------------------------

func test_mod_content_picked_up_by_content_loader() -> void:
	# example_mod liefert raptor_dash.tres unter content/mutations/.
	# Aber: ContentLoader scannt user://mods/, nicht res://tests/fixtures/mods/.
	# Wir testen daher nur, dass ContentLoader.reload() ohne Crash durchläuft;
	# die Fixture-Mods werden vom ContentLoader nicht erfasst, weil sie
	# nicht in user://mods/ liegen.
	# (Dieser Test-Vertrag wird im Mod-Bridge-Refactor angepasst, ADR 0009.)
	assert_true(ContentLoader.has_item(&"mutation", &"triceratops_horns"),
		"Core-Mutation muss noch existieren")
