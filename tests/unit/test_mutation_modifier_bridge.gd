extends "res://addons/gut/test.gd"
## Tests für die Mutation→Modifier-Bridge (ADR 0014).
##
## Pure-Function-Konvention: gleicher Input → gleicher Output. Keine
## Setup-Reihenfolge-Abhängigkeit, keine Bus-Hooks.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_mut(stat_modifiers: Dictionary) -> MutationDef:
	var m := MutationDef.new()
	m.id = &"test_mut"
	m.display_name_key = &"x.y"
	m.rarity = &"common"
	m.stat_modifiers = stat_modifiers.duplicate(true)
	return m


# ---------------------------------------------------------------------------
# Edge-Cases: null, empty
# ---------------------------------------------------------------------------

func test_null_mutation_returns_empty_result() -> void:
	var r := MutationModifierBridge.build(null)
	assert_eq(r["outgoing"].size(), 0)
	assert_eq(r["incoming"].size(), 0)
	assert_eq(r["unhandled"].size(), 0)


func test_empty_stat_modifiers_returns_empty_result() -> void:
	var r := MutationModifierBridge.build(_make_mut({}))
	assert_eq(r["outgoing"].size(), 0)
	assert_eq(r["incoming"].size(), 0)
	assert_eq(r["unhandled"].size(), 0)


# ---------------------------------------------------------------------------
# damage_pct → MultiplierModifier
# ---------------------------------------------------------------------------

func test_damage_pct_yields_multiplier_modifier() -> void:
	var r := MutationModifierBridge.build(_make_mut({ &"damage_pct": 0.15 }))
	assert_eq(r["outgoing"].size(), 1)
	var m: MultiplierModifier = r["outgoing"][0]
	assert_almost_eq(m.multiplier, 1.15, 0.0001)


func test_damage_pct_zero_yields_no_modifier() -> void:
	var r := MutationModifierBridge.build(_make_mut({ &"damage_pct": 0.0 }))
	assert_eq(r["outgoing"].size(), 0)


# ---------------------------------------------------------------------------
# crit_chance + crit_damage_pct → CritModifier
# ---------------------------------------------------------------------------

func test_crit_chance_alone_yields_crit_modifier_with_default_multi() -> void:
	var r := MutationModifierBridge.build(_make_mut({ &"crit_chance": 0.10 }))
	assert_eq(r["outgoing"].size(), 1)
	var c: CritModifier = r["outgoing"][0]
	assert_almost_eq(c.chance, 0.10, 0.0001)
	assert_almost_eq(c.multiplier, 2.0, 0.0001)


func test_crit_chance_with_crit_damage_pct_bundles() -> void:
	var r := MutationModifierBridge.build(_make_mut({
		&"crit_chance": 0.05,
		&"crit_damage_pct": 0.5,
	}))
	assert_eq(r["outgoing"].size(), 1)
	var c: CritModifier = r["outgoing"][0]
	assert_almost_eq(c.chance, 0.05, 0.0001)
	assert_almost_eq(c.multiplier, 2.5, 0.0001)


func test_crit_damage_pct_alone_goes_to_unhandled() -> void:
	var r := MutationModifierBridge.build(_make_mut({ &"crit_damage_pct": 0.5 }))
	assert_eq(r["outgoing"].size(), 0,
		"Crit-Damage ohne Crit-Chance ist sinnlos → kein Modifier")
	assert_true(r["unhandled"].has(&"crit_damage_pct"))


# ---------------------------------------------------------------------------
# armor_pct → ArmorModifier (incoming)
# ---------------------------------------------------------------------------

func test_armor_pct_yields_incoming_modifier() -> void:
	var r := MutationModifierBridge.build(_make_mut({ &"armor_pct": 0.30 }))
	assert_eq(r["outgoing"].size(), 0)
	assert_eq(r["incoming"].size(), 1)
	var a: ArmorModifier = r["incoming"][0]
	assert_almost_eq(a.reduction_pct, 0.30, 0.0001)


# ---------------------------------------------------------------------------
# unhandled stat_keys werden durchgereicht
# ---------------------------------------------------------------------------

func test_unknown_stat_keys_go_to_unhandled() -> void:
	var r := MutationModifierBridge.build(_make_mut({
		&"move_speed_pct": 0.1,
		&"max_health_pct": 0.2,
		&"pickup_radius_pct": 0.05,
		&"melee_range_pct": 0.10,
	}))
	assert_eq(r["outgoing"].size(), 0)
	assert_eq(r["incoming"].size(), 0)
	assert_eq(r["unhandled"].size(), 4)
	assert_almost_eq(r["unhandled"][&"move_speed_pct"], 0.1, 0.0001)
	assert_almost_eq(r["unhandled"][&"melee_range_pct"], 0.10, 0.0001)


# ---------------------------------------------------------------------------
# Kombination: bekannt + unbekannt
# ---------------------------------------------------------------------------

func test_known_and_unknown_are_split() -> void:
	var r := MutationModifierBridge.build(_make_mut({
		&"damage_pct": 0.15,
		&"melee_range_pct": 0.10,
	}))
	assert_eq(r["outgoing"].size(), 1)
	assert_eq(r["incoming"].size(), 0)
	assert_eq(r["unhandled"].size(), 1)
	assert_true(r["unhandled"].has(&"melee_range_pct"))


# ---------------------------------------------------------------------------
# Pure-Function-Garantie
# ---------------------------------------------------------------------------

func test_build_does_not_mutate_input_mutation() -> void:
	var mut := _make_mut({ &"damage_pct": 0.15, &"melee_range_pct": 0.10 })
	var snapshot := mut.stat_modifiers.duplicate(true)
	MutationModifierBridge.build(mut)
	assert_eq(mut.stat_modifiers, snapshot,
		"build() darf MutationDef.stat_modifiers nicht modifizieren")


func test_build_is_deterministic() -> void:
	var mut := _make_mut({ &"damage_pct": 0.15 })
	var r1 := MutationModifierBridge.build(mut)
	var r2 := MutationModifierBridge.build(mut)
	assert_eq(r1["outgoing"].size(), r2["outgoing"].size())
	# Modifier sind verschiedene Instanzen, aber gleiche Werte
	assert_almost_eq(
		(r1["outgoing"][0] as MultiplierModifier).multiplier,
		(r2["outgoing"][0] as MultiplierModifier).multiplier,
		0.0001
	)


# ---------------------------------------------------------------------------
# Smoke-Test: triceratops_horns aus dem ContentLoader
# ---------------------------------------------------------------------------

func test_triceratops_horns_yields_expected_modifier() -> void:
	# Echte Resource aus dem Loader → Bridge → konkrete Modifier
	var mut := ContentLoader.get_or_null(&"mutation", &"triceratops_horns") as MutationDef
	assert_not_null(mut)

	var r := MutationModifierBridge.build(mut)

	# triceratops_horns hat damage_pct=0.15 + melee_range_pct=0.10
	assert_eq(r["outgoing"].size(), 1, "damage_pct erzeugt 1 Modifier")
	assert_eq(r["incoming"].size(), 0)
	assert_eq(r["unhandled"].size(), 1)
	assert_true(r["unhandled"].has(&"melee_range_pct"))

	var m: MultiplierModifier = r["outgoing"][0]
	assert_almost_eq(m.multiplier, 1.15, 0.0001,
		"+15% damage_pct → multiplier 1.15")


# ---------------------------------------------------------------------------
# Integration-Smoke: Bridge → DamageDealer → HealthComponent
# ---------------------------------------------------------------------------

func test_full_round_trip_against_health_component() -> void:
	# Bridge erzeugt Modifier, wir hängen sie an einen DamageDealer und feuern
	# einen Schlag — HP des Targets muss dem erwarteten Wert entsprechen.
	var mut := _make_mut({ &"damage_pct": 0.15 })
	var r := MutationModifierBridge.build(mut)

	var dealer := DamageDealerComponent.new()
	add_child(dealer)
	for m in r["outgoing"]:
		dealer.add_modifier(m)

	var target := HealthComponent.new()
	target.max_hp = 1000.0
	add_child(target)

	dealer.deal_damage(target, DamageInfo.make(10.0))
	# 10 × 1.15 = 11.5 → 1000 - 11.5 = 988.5
	assert_almost_eq(target.get_hp(), 988.5, 0.001)

	dealer.queue_free()
	target.queue_free()
