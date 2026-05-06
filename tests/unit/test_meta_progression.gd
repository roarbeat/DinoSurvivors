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
