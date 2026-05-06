extends "res://addons/gut/test.gd"
## MetaProgression-Tests (ADR 0030).

func before_each() -> void:
	MetaProgression.reset()
	# SaveSystem zurücksetzen, sonst leakt Currency aus vorherigen Tests
	if SaveSystem.has_save_file():
		SaveSystem.delete_save()
	watch_signals(EventBus)


func after_each() -> void:
	MetaProgression.reset()
	if SaveSystem.has_save_file():
		SaveSystem.delete_save()


# ---------------------------------------------------------------------------
# Default-State + Public-API
# ---------------------------------------------------------------------------

func test_default_amber_is_zero() -> void:
	assert_eq(MetaProgression.get_currency(&"amber"), 0)


func test_default_currency_default_arg_is_amber() -> void:
	# get_currency() ohne Argument → DEFAULT_CURRENCY = amber
	assert_eq(MetaProgression.get_currency(), 0)


func test_default_currency_constant() -> void:
	assert_eq(MetaProgression.DEFAULT_CURRENCY, &"amber")


func test_unknown_currency_returns_zero() -> void:
	assert_eq(MetaProgression.get_currency(&"nonexistent"), 0)


# ---------------------------------------------------------------------------
# add_currency
# ---------------------------------------------------------------------------

func test_add_currency_increases_value() -> void:
	var new_value := MetaProgression.add_currency(&"amber", 50)
	assert_eq(new_value, 50)
	assert_eq(MetaProgression.get_currency(&"amber"), 50)


func test_add_currency_emits_signal() -> void:
	MetaProgression.add_currency(&"amber", 25)
	assert_signal_emitted(EventBus, "currency_changed")
	var params: Array = get_signal_parameters(EventBus, "currency_changed")
	assert_eq(params[0], &"amber")
	assert_eq(params[1], 25)


func test_add_currency_with_negative_amount_subtracts() -> void:
	MetaProgression.add_currency(&"amber", 100)
	var new_value := MetaProgression.add_currency(&"amber", -30)
	assert_eq(new_value, 70)


func test_add_currency_clamps_at_zero() -> void:
	MetaProgression.add_currency(&"amber", 50)
	var new_value := MetaProgression.add_currency(&"amber", -200)
	assert_eq(new_value, 0,
		"Currency darf nicht negativ werden (Lower-Cap bei 0)")


func test_add_currency_zero_amount_is_noop() -> void:
	MetaProgression.add_currency(&"amber", 100)
	# Reset signal-watcher danach
	watch_signals(EventBus)
	MetaProgression.add_currency(&"amber", 0)
	assert_signal_not_emitted(EventBus, "currency_changed",
		"add_currency(_, 0) soll kein Signal feuern (kein Wert-Change)")


func test_add_currency_creates_new_currency_id() -> void:
	# Beliebige Currency-ID kann angelegt werden — z.B. von Mods
	MetaProgression.add_currency(&"crystals", 5)
	assert_eq(MetaProgression.get_currency(&"crystals"), 5)


# ---------------------------------------------------------------------------
# set_currency
# ---------------------------------------------------------------------------

func test_set_currency_sets_value() -> void:
	MetaProgression.set_currency(&"amber", 200)
	assert_eq(MetaProgression.get_currency(&"amber"), 200)


func test_set_currency_clamps_negative_to_zero() -> void:
	MetaProgression.set_currency(&"amber", -5)
	assert_eq(MetaProgression.get_currency(&"amber"), 0)


func test_set_currency_emits_signal_only_on_change() -> void:
	MetaProgression.set_currency(&"amber", 100)
	watch_signals(EventBus)
	MetaProgression.set_currency(&"amber", 100)
	assert_signal_not_emitted(EventBus, "currency_changed",
		"set_currency mit gleichem Wert soll kein Signal feuern")


# ---------------------------------------------------------------------------
# list_currencies
# ---------------------------------------------------------------------------

func test_list_currencies_returns_copy() -> void:
	MetaProgression.add_currency(&"amber", 42)
	var snapshot := MetaProgression.list_currencies()
	assert_eq(snapshot.get(&"amber"), 42)
	# Mutation am Snapshot wirkt nicht auf den Bus-State
	snapshot[&"amber"] = 999
	assert_eq(MetaProgression.get_currency(&"amber"), 42,
		"list_currencies() soll Kopie liefern, nicht Original")


func test_reset_clears_all_currencies() -> void:
	MetaProgression.add_currency(&"amber", 100)
	MetaProgression.add_currency(&"crystals", 50)
	MetaProgression.reset()
	assert_eq(MetaProgression.get_currency(&"amber"), 0)
	assert_eq(MetaProgression.get_currency(&"crystals"), 0)


# ---------------------------------------------------------------------------
# Boss-Defeat-Auto-Reward
# ---------------------------------------------------------------------------

func test_boss_defeated_pays_reward() -> void:
	# tyrannosaurus_prime.tres hat reward_currency_amount = 50
	EventBus.boss_defeated.emit(&"tyrannosaurus_prime", 60.0)
	# Signal-Handler ist synchron via direct connect → Wert ist sofort da
	assert_eq(MetaProgression.get_currency(&"amber"), 50)


func test_unknown_boss_defeated_does_not_pay() -> void:
	EventBus.boss_defeated.emit(&"unknown_boss_id", 60.0)
	assert_eq(MetaProgression.get_currency(&"amber"), 0)


# ---------------------------------------------------------------------------
# Save/Load-Roundtrip
# ---------------------------------------------------------------------------

func test_save_persists_currency() -> void:
	MetaProgression.add_currency(&"amber", 75)
	# save_requested → MetaProgression schreibt sich raus, SaveSystem speichert
	EventBus.save_requested.emit(&"test")
	# Direkter SaveSystem.save erfolgt im _on_save_requested-Handler des Systems
	# Wir verifizieren über SaveSystem.get_data
	var data := SaveSystem.get_data()
	var meta = data.get("meta_progression", null)
	assert_not_null(meta, "Save sollte meta_progression-Slot enthalten")
	assert_eq(int((meta as Dictionary).get("amber", 0)), 75)


func test_load_restores_currency() -> void:
	MetaProgression.add_currency(&"amber", 123)
	EventBus.save_requested.emit(&"test")
	# Schreibt auf Disk
	SaveSystem.save(&"test")

	# Reset in-memory
	MetaProgression.reset()
	assert_eq(MetaProgression.get_currency(&"amber"), 0)

	# Neu laden — feuert save_loaded → MetaProgression liest sich rein
	SaveSystem.load_save()
	assert_eq(MetaProgression.get_currency(&"amber"), 123,
		"Nach load_save soll Bernstein wieder bei 123 sein")


# ---------------------------------------------------------------------------
# Integration: Save-Schema-Backward-Kompat
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Upgrade-API (ADR 0040)
# ---------------------------------------------------------------------------

func test_default_upgrade_levels_are_zero() -> void:
	assert_eq(MetaProgression.get_upgrade_level(&"stronger_jaws"), 0)
	assert_eq(MetaProgression.get_upgrade_level(&"unknown_id"), 0)


func test_get_upgrade_cost_for_unknown_id_is_neg1() -> void:
	assert_eq(MetaProgression.get_upgrade_cost(&"does_not_exist"), -1)


func test_get_upgrade_cost_at_level_zero() -> void:
	# stronger_jaws cost_per_level = [50, 100, 200]
	assert_eq(MetaProgression.get_upgrade_cost(&"stronger_jaws"), 50)


func test_can_afford_upgrade_false_when_no_currency() -> void:
	# Reset → 0 amber
	MetaProgression.reset()
	assert_false(MetaProgression.can_afford_upgrade(&"stronger_jaws"))


func test_can_afford_upgrade_true_when_currency_sufficient() -> void:
	MetaProgression.add_currency(&"amber", 100)
	assert_true(MetaProgression.can_afford_upgrade(&"stronger_jaws"))


func test_purchase_upgrade_succeeds_and_subtracts_currency() -> void:
	MetaProgression.add_currency(&"amber", 100)
	var ok := MetaProgression.purchase_upgrade(&"stronger_jaws")
	assert_true(ok)
	assert_eq(MetaProgression.get_upgrade_level(&"stronger_jaws"), 1)
	# 100 - 50 = 50
	assert_eq(MetaProgression.get_currency(&"amber"), 50)


func test_purchase_upgrade_fails_when_no_currency() -> void:
	# Reset → 0 amber, dann purchase versuchen
	MetaProgression.reset()
	var ok := MetaProgression.purchase_upgrade(&"stronger_jaws")
	assert_false(ok)
	assert_eq(MetaProgression.get_upgrade_level(&"stronger_jaws"), 0)


func test_purchase_upgrade_fails_at_max_level() -> void:
	# Drei Käufe für stronger_jaws (max_level=3, cost 50+100+200=350)
	MetaProgression.add_currency(&"amber", 1000)
	for i in 3:
		MetaProgression.purchase_upgrade(&"stronger_jaws")
	assert_eq(MetaProgression.get_upgrade_level(&"stronger_jaws"), 3)
	# 4. Kauf soll scheitern
	var ok := MetaProgression.purchase_upgrade(&"stronger_jaws")
	assert_false(ok)


func test_purchase_upgrade_emits_signal() -> void:
	MetaProgression.add_currency(&"amber", 100)
	watch_signals(EventBus)
	MetaProgression.purchase_upgrade(&"stronger_jaws")
	assert_signal_emitted(EventBus, "upgrade_purchased")
	var params: Array = get_signal_parameters(EventBus, "upgrade_purchased")
	assert_eq(params[0], &"stronger_jaws")
	assert_eq(params[1], 1)


func test_purchase_upgrade_unknown_id_returns_false() -> void:
	MetaProgression.add_currency(&"amber", 1000)
	var ok := MetaProgression.purchase_upgrade(&"unknown_upgrade_id")
	assert_false(ok)


# ---------------------------------------------------------------------------
# get_aggregated_modifiers
# ---------------------------------------------------------------------------

func test_aggregated_modifiers_empty_at_start() -> void:
	MetaProgression.reset()
	var agg := MetaProgression.get_aggregated_modifiers()
	assert_eq(agg["outgoing"].size(), 0)
	assert_eq(agg["incoming"].size(), 0)
	assert_eq(agg["unhandled"].size(), 0)


func test_aggregated_modifiers_after_purchase() -> void:
	MetaProgression.reset()
	MetaProgression.add_currency(&"amber", 100)
	MetaProgression.purchase_upgrade(&"stronger_jaws")
	var agg := MetaProgression.get_aggregated_modifiers()
	# stronger_jaws Level 1 → damage_pct=0.05 → MultiplierModifier oder unhandled
	# Je nach Bridge-Implementation. Wir prüfen Outgoing-Liste oder unhandled.
	var has_modifier: bool = (
		agg["outgoing"].size() > 0
		or agg["incoming"].size() > 0
		or agg["unhandled"].size() > 0
	)
	assert_true(has_modifier,
		"Nach Purchase sollte aggregated_modifiers nicht leer sein")


# ---------------------------------------------------------------------------
# Save/Load Upgrade-Roundtrip
# ---------------------------------------------------------------------------

func test_save_persists_upgrade_levels() -> void:
	MetaProgression.add_currency(&"amber", 1000)
	MetaProgression.purchase_upgrade(&"stronger_jaws")
	MetaProgression.purchase_upgrade(&"tougher_hide")
	EventBus.save_requested.emit(&"test")
	var data := SaveSystem.get_data()
	var ul = data.get("upgrade_levels", null)
	assert_not_null(ul)
	assert_eq(int((ul as Dictionary).get("stronger_jaws", 0)), 1)
	assert_eq(int((ul as Dictionary).get("tougher_hide", 0)), 1)


func test_load_restores_upgrade_levels() -> void:
	MetaProgression.add_currency(&"amber", 1000)
	MetaProgression.purchase_upgrade(&"faster_legs")
	EventBus.save_requested.emit(&"test")
	SaveSystem.save(&"test")

	# Reset in-memory
	MetaProgression.reset()
	assert_eq(MetaProgression.get_upgrade_level(&"faster_legs"), 0)

	# Reload
	SaveSystem.load_save()
	assert_eq(MetaProgression.get_upgrade_level(&"faster_legs"), 1)


func test_legacy_save_without_meta_starts_with_zero() -> void:
	# Save-Datei manuell ohne meta_progression-Slot bauen — simuliert
	# v0.0.x-Save vor ADR 0030
	var legacy := {
		"schema_version": 1,
		"meta": {
			"created_at": "2026-05-06T12:00:00",
			"last_played_at": "2026-05-06T12:00:00",
			"last_save_reason": "manual",
		},
		"data": {},
	}
	var save_path: String = "user://saves/save.json"
	if not DirAccess.dir_exists_absolute("user://saves/"):
		DirAccess.make_dir_absolute("user://saves/")
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()

	MetaProgression.reset()
	MetaProgression.add_currency(&"amber", 999)  # In-memory dirty

	SaveSystem.load_save()
	assert_eq(MetaProgression.get_currency(&"amber"), 0,
		"Legacy-Save ohne meta_progression-Slot → MetaProgression startet mit 0")
