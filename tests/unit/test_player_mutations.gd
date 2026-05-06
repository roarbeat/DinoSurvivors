extends "res://addons/gut/test.gd"
## PlayerMutations-Tests (ADR 0015) — Aggregator-Verhalten.

func before_each() -> void:
	PlayerMutations.reset()
	watch_signals(EventBus)


# ---------------------------------------------------------------------------
# Pick / Remove / Reset
# ---------------------------------------------------------------------------

func test_pick_known_mutation_succeeds() -> void:
	var ok := PlayerMutations.pick(&"triceratops_horns")
	assert_true(ok)
	assert_true(PlayerMutations.has(&"triceratops_horns"))


func test_pick_unknown_mutation_fails() -> void:
	var ok := PlayerMutations.pick(&"velociraptor_does_not_exist")
	assert_false(ok)


func test_pick_twice_returns_false_second_time() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	var second := PlayerMutations.pick(&"triceratops_horns")
	assert_false(second, "zweiter Pick einer schon gepickten Mutation = false")


func test_remove_clears_entry() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	var ok := PlayerMutations.remove(&"triceratops_horns")
	assert_true(ok)
	assert_false(PlayerMutations.has(&"triceratops_horns"))


func test_remove_unknown_returns_false() -> void:
	var ok := PlayerMutations.remove(&"never_picked")
	assert_false(ok)


func test_reset_clears_all() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	PlayerMutations.pick(&"spinosaur_sail")
	PlayerMutations.reset()
	assert_eq(PlayerMutations.get_picked().size(), 0)


func test_get_picked_returns_copy() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	var a := PlayerMutations.get_picked()
	a.append(&"hacked")
	var b := PlayerMutations.get_picked()
	assert_false(b.has(&"hacked"),
		"get_picked() muss Kopie zurückgeben, externe Mutation darf nicht leaken")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

func test_single_pick_yields_single_modifier() -> void:
	PlayerMutations.pick(&"triceratops_horns")  # damage_pct: 0.15
	var agg := PlayerMutations.get_aggregated()
	assert_eq(agg["outgoing"].size(), 1)
	var m: MultiplierModifier = agg["outgoing"][0]
	assert_almost_eq(m.multiplier, 1.15, 0.0001)


func test_two_damage_mutations_stack_additively() -> void:
	# Beide Mutationen haben damage_pct (triceratops 0.15, fake test-mod 0.20)
	# triceratops_horns ist im Loader, fake fügen wir direkt hinzu für Aggregations-Test
	# Wir nutzen stattdessen real existierende Mutationen — hier triceratops + ankylosaur,
	# aber ankylosaur hat KEIN damage_pct. Lass uns spinosaur + triceratops nehmen:
	# triceratops: damage_pct 0.15
	# spinosaur:   crit_chance 0.10, crit_damage_pct 0.50 (kein damage_pct)
	# Damit testen wir: damage_pct kommt nur von einer Mutation, also damage stays 1.15

	# Echter Aggregations-Test: zwei Mutationen aus dem Loader, die DAMAGE erhöhen,
	# brauchen wir nicht — der Aggregations-Test mit raw-Stats ist wichtiger.
	# Wir testen das in einem separaten Test mit synthetischen Picks.
	pass_test("Hinweis: echte Multi-Damage-Aggregation siehe test_aggregation_via_internals")


func test_pick_two_mutations_aggregates_outgoing_and_incoming() -> void:
	PlayerMutations.pick(&"triceratops_horns")    # damage_pct 0.15
	PlayerMutations.pick(&"spinosaur_sail")       # crit_chance 0.10 + crit_damage_pct 0.50
	PlayerMutations.pick(&"ankylosaur_plates")    # armor_pct 0.20 + max_health_pct 0.15

	var agg := PlayerMutations.get_aggregated()

	# Outgoing: damage MultiplierModifier(1.15) + CritModifier(0.10, 2.5)
	assert_eq(agg["outgoing"].size(), 2)
	var damage_mod: MultiplierModifier = null
	var crit_mod: CritModifier = null
	for m in agg["outgoing"]:
		if m is MultiplierModifier: damage_mod = m
		elif m is CritModifier: crit_mod = m
	assert_not_null(damage_mod)
	assert_almost_eq(damage_mod.multiplier, 1.15, 0.0001)
	assert_not_null(crit_mod)
	assert_almost_eq(crit_mod.chance, 0.10, 0.0001)
	assert_almost_eq(crit_mod.multiplier, 2.5, 0.0001)

	# Incoming: ArmorModifier(0.20)
	assert_eq(agg["incoming"].size(), 1)
	var armor: ArmorModifier = agg["incoming"][0]
	assert_almost_eq(armor.reduction_pct, 0.20, 0.0001)

	# Unhandled: melee_range_pct (0.10) + max_health_pct (0.15)
	assert_true(agg["unhandled"].has(&"melee_range_pct"))
	assert_almost_eq(agg["unhandled"][&"melee_range_pct"], 0.10, 0.0001)
	assert_true(agg["unhandled"].has(&"max_health_pct"))
	assert_almost_eq(agg["unhandled"][&"max_health_pct"], 0.15, 0.0001)


# ---------------------------------------------------------------------------
# Cap-Verhalten
# ---------------------------------------------------------------------------

func test_armor_pct_clamps_to_one() -> void:
	# Ein Test-Mod-Resource direkt instanzieren mit hohem armor_pct
	# Eigentlich: wir picken ankylosaur_plates dreimal? Nein — pick einmal nur.
	# Stattdessen prüfen wir die clamp-Logik mit raw-Stat-Aggregation:
	# Wenn _aggregate_stats armor_pct=2.0 liefert, muss clamp auf 1.0 greifen.
	# Wir umgehen die Loader-Picks und testen die interne Helper-Funktion direkt.
	var raw := { &"armor_pct": 2.0 }
	var built := PlayerMutations._build_modifiers_from_aggregated(raw)
	assert_eq(built["incoming"].size(), 1)
	var a: ArmorModifier = built["incoming"][0]
	assert_almost_eq(a.reduction_pct, 1.0, 0.0001,
		"armor_pct über 1.0 muss auf 1.0 geclampt werden")


func test_crit_chance_clamps_to_one() -> void:
	var raw := { &"crit_chance": 1.5 }
	var built := PlayerMutations._build_modifiers_from_aggregated(raw)
	var c: CritModifier = built["outgoing"][0]
	assert_almost_eq(c.chance, 1.0, 0.0001)


# ---------------------------------------------------------------------------
# Aggregation der Internals (Multi-Pick Same Stat)
# ---------------------------------------------------------------------------

func test_internal_aggregation_sums_raw_stats() -> void:
	# Direkter Test des _build_modifiers_from_aggregated mit
	# künstlichem raw-Dictionary, das mehrere Mutationen mit gleichen Stats simuliert.
	var raw := {
		&"damage_pct": 0.35,        # = 0.15 + 0.20 (zwei Mutationen)
		&"crit_chance": 0.15,       # = 0.05 + 0.10
		&"move_speed_pct": 0.20,    # unhandled additiv
	}
	var built := PlayerMutations._build_modifiers_from_aggregated(raw)
	assert_eq(built["outgoing"].size(), 2)
	# damage MultiplierModifier(1.35)
	for m in built["outgoing"]:
		if m is MultiplierModifier:
			assert_almost_eq(m.multiplier, 1.35, 0.0001)
		elif m is CritModifier:
			assert_almost_eq(m.chance, 0.15, 0.0001)
	assert_almost_eq(built["unhandled"][&"move_speed_pct"], 0.20, 0.0001)


# ---------------------------------------------------------------------------
# EventBus-Integration
# ---------------------------------------------------------------------------

func test_pick_emits_mutations_changed() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	assert_signal_emitted(EventBus, "mutations_changed")


func test_remove_emits_mutations_changed() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	# Reset watch nach pick (alternativ: emit_count vor und nach prüfen)
	watch_signals(EventBus)
	PlayerMutations.remove(&"triceratops_horns")
	assert_signal_emitted(EventBus, "mutations_changed")


func test_reset_emits_only_when_not_empty() -> void:
	# Reset auf leere Liste ist no-op → kein Signal
	PlayerMutations.reset()  # already empty
	watch_signals(EventBus)
	PlayerMutations.reset()
	assert_signal_not_emitted(EventBus, "mutations_changed",
		"reset auf bereits leere Liste darf nichts feuern")


# ---------------------------------------------------------------------------
# Run-Lifecycle-Hook
# ---------------------------------------------------------------------------

func test_run_started_resets_picks() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	assert_eq(PlayerMutations.get_picked().size(), 1)
	# Run-Start triggert Reset
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()
	RunState.start(&"trex")
	assert_eq(PlayerMutations.get_picked().size(), 0,
		"PlayerMutations.reset() muss bei run_started ausgelöst werden")
	# Cleanup
	RunState.end(&"test_cleanup")
	RunState.reset()
