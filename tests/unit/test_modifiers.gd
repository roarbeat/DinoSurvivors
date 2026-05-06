extends "res://addons/gut/test.gd"
## Modifier-Pipeline-Tests (ADR 0010).
##
## Pure-Function-Konvention wird mit Identity-Checks abgesichert:
## der Modifier darf die übergebene DamageInfo NICHT in-place mutieren.

# ---------------------------------------------------------------------------
# Pure-Function-Garantie
# ---------------------------------------------------------------------------

func test_flat_bonus_does_not_mutate_input() -> void:
	var orig := DamageInfo.make(10.0)
	var m := FlatBonusModifier.new()
	m.bonus_amount = 5.0
	var out := m.apply(orig)
	assert_ne(orig, out, "Modifier muss neue Resource liefern")
	assert_eq(orig.amount, 10.0, "Original darf nicht modifiziert werden")
	assert_eq(out.amount, 15.0)


func test_multiplier_does_not_mutate_input() -> void:
	var orig := DamageInfo.make(10.0)
	var m := MultiplierModifier.new()
	m.multiplier = 1.5
	var out := m.apply(orig)
	assert_ne(orig, out)
	assert_eq(orig.amount, 10.0)
	assert_eq(out.amount, 15.0)


# ---------------------------------------------------------------------------
# FlatBonusModifier
# ---------------------------------------------------------------------------

func test_flat_bonus_adds_amount() -> void:
	var m := FlatBonusModifier.new()
	m.bonus_amount = 7.5
	var out := m.apply(DamageInfo.make(10.0))
	assert_eq(out.amount, 17.5)


func test_flat_bonus_default_priority() -> void:
	var m := FlatBonusModifier.new()
	assert_eq(m.priority, 150)


func test_flat_bonus_null_info_is_passthrough() -> void:
	var m := FlatBonusModifier.new()
	m.bonus_amount = 5.0
	var out := m.apply(null)
	assert_null(out)


# ---------------------------------------------------------------------------
# MultiplierModifier
# ---------------------------------------------------------------------------

func test_multiplier_default_is_identity() -> void:
	var m := MultiplierModifier.new()
	# Default multiplier=1.0 → unverändert
	var out := m.apply(DamageInfo.make(42.0))
	assert_eq(out.amount, 42.0)


func test_multiplier_doubles_damage() -> void:
	var m := MultiplierModifier.new()
	m.multiplier = 2.0
	var out := m.apply(DamageInfo.make(10.0))
	assert_eq(out.amount, 20.0)


func test_multiplier_default_priority() -> void:
	var m := MultiplierModifier.new()
	assert_eq(m.priority, 250)


# ---------------------------------------------------------------------------
# CritModifier
# ---------------------------------------------------------------------------

func test_crit_chance_zero_never_crits() -> void:
	var m := CritModifier.new()
	m.chance = 0.0
	m.multiplier = 2.0
	var out := m.apply(DamageInfo.make(10.0))
	assert_eq(out.amount, 10.0, "chance=0 darf NIE crit")
	assert_false(out.is_crit)


func test_crit_chance_one_always_crits() -> void:
	var m := CritModifier.new()
	m.chance = 1.0
	m.multiplier = 2.5
	var out := m.apply(DamageInfo.make(10.0))
	assert_eq(out.amount, 25.0)
	assert_true(out.is_crit)


func test_crit_with_seeded_rng_is_deterministic() -> void:
	var m := CritModifier.new()
	m.chance = 0.5
	m.multiplier = 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	m.set_rng(rng)

	# Gleicher Seed → gleiche Sequence
	var results: Array = []
	for i in 5:
		results.append(m.apply(DamageInfo.make(10.0)).is_crit)

	# Reset mit gleichem Seed
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	m.set_rng(rng2)
	var results2: Array = []
	for i in 5:
		results2.append(m.apply(DamageInfo.make(10.0)).is_crit)

	assert_eq(results, results2, "Gleicher RNG-Seed → identische Crit-Sequenz")


# ---------------------------------------------------------------------------
# ArmorModifier
# ---------------------------------------------------------------------------

func test_armor_reduces_amount() -> void:
	var m := ArmorModifier.new()
	m.reduction_pct = 0.5
	var out := m.apply(DamageInfo.make(20.0))
	assert_eq(out.amount, 10.0)


func test_armor_clamps_reduction() -> void:
	var m := ArmorModifier.new()
	m.reduction_pct = 2.0  # zu hoch
	assert_eq(m.reduction_pct, 1.0, "reduction_pct muss auf 1.0 geclampt werden")


func test_armor_respects_pierce_armor() -> void:
	var m := ArmorModifier.new()
	m.reduction_pct = 0.9
	var info := DamageInfo.make(100.0)
	info.pierce_armor = true
	var out := m.apply(info)
	assert_eq(out.amount, 100.0, "pierce_armor → keine Reduktion")


func test_armor_default_priority() -> void:
	var m := ArmorModifier.new()
	assert_eq(m.priority, 300)


# ---------------------------------------------------------------------------
# Chain auf DamageDealerComponent
# ---------------------------------------------------------------------------

func test_dealer_applies_outgoing_chain() -> void:
	var dealer := DamageDealerComponent.new()
	add_child(dealer)
	var target := HealthComponent.new()
	target.max_hp = 1000.0
	add_child(target)

	# +5 flat, dann ×2 (multiplikativ) → (10 + 5) * 2 = 30
	var bonus := FlatBonusModifier.new()
	bonus.bonus_amount = 5.0
	var mult := MultiplierModifier.new()
	mult.multiplier = 2.0
	dealer.add_modifier(bonus)
	dealer.add_modifier(mult)

	dealer.deal_damage(target, DamageInfo.make(10.0))
	assert_eq(target.get_hp(), 970.0, "1000 - 30 = 970")

	dealer.queue_free()
	target.queue_free()


func test_dealer_modifier_priority_order() -> void:
	# multiplier (priority 250) MUSS nach bonus (priority 150) laufen,
	# auch wenn add-Reihenfolge umgekehrt ist
	var dealer := DamageDealerComponent.new()
	add_child(dealer)
	var target := HealthComponent.new()
	target.max_hp = 1000.0
	add_child(target)

	var mult := MultiplierModifier.new()
	mult.multiplier = 2.0
	var bonus := FlatBonusModifier.new()
	bonus.bonus_amount = 5.0
	# Mult zuerst hinzufügen (priority sortiert trotzdem korrekt)
	dealer.add_modifier(mult)
	dealer.add_modifier(bonus)

	dealer.deal_damage(target, DamageInfo.make(10.0))
	# bonus zuerst: 10 + 5 = 15, dann mult: 15 * 2 = 30
	assert_eq(target.get_hp(), 970.0)

	dealer.queue_free()
	target.queue_free()


# ---------------------------------------------------------------------------
# Chain auf HealthComponent (incoming)
# ---------------------------------------------------------------------------

func test_health_applies_incoming_armor() -> void:
	var hp := HealthComponent.new()
	hp.max_hp = 100.0
	add_child(hp)

	var armor := ArmorModifier.new()
	armor.reduction_pct = 0.5
	hp.add_modifier(armor)

	# 20 Damage → durch 50% Armor → 10 effective
	hp.take_damage(DamageInfo.make(20.0))
	assert_eq(hp.get_hp(), 90.0)

	hp.queue_free()


func test_health_pierce_armor_bypasses() -> void:
	var hp := HealthComponent.new()
	hp.max_hp = 100.0
	add_child(hp)

	var armor := ArmorModifier.new()
	armor.reduction_pct = 0.9
	hp.add_modifier(armor)

	var info := DamageInfo.make(20.0)
	info.pierce_armor = true
	hp.take_damage(info)
	assert_eq(hp.get_hp(), 80.0, "pierce_armor → voller Damage trotz 90% Armor")

	hp.queue_free()


func test_health_armor_can_block_completely() -> void:
	var hp := HealthComponent.new()
	hp.max_hp = 100.0
	add_child(hp)

	var armor := ArmorModifier.new()
	armor.reduction_pct = 1.0  # 100% blocked
	hp.add_modifier(armor)

	hp.take_damage(DamageInfo.make(50.0))
	assert_eq(hp.get_hp(), 100.0, "100% Armor → kein State-Change")

	hp.queue_free()


# ---------------------------------------------------------------------------
# Add/Remove
# ---------------------------------------------------------------------------

func test_dealer_add_remove_modifier() -> void:
	var dealer := DamageDealerComponent.new()
	add_child(dealer)
	var m := FlatBonusModifier.new()
	dealer.add_modifier(m)
	assert_eq(dealer.outgoing_modifiers.size(), 1)
	var ok := dealer.remove_modifier(m)
	assert_true(ok)
	assert_eq(dealer.outgoing_modifiers.size(), 0)
	dealer.queue_free()


func test_health_add_remove_modifier() -> void:
	var hp := HealthComponent.new()
	add_child(hp)
	var m := ArmorModifier.new()
	hp.add_modifier(m)
	assert_eq(hp.incoming_modifiers.size(), 1)
	hp.remove_modifier(m)
	assert_eq(hp.incoming_modifiers.size(), 0)
	hp.queue_free()
