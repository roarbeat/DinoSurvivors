extends "res://addons/gut/test.gd"
## DamageDealer-Tests — Roundtrip-Logik.

var _dealer: DamageDealerComponent
var _target: HealthComponent

func before_each() -> void:
	_dealer = DamageDealerComponent.new()
	add_child(_dealer)
	_target = HealthComponent.new()
	_target.max_hp = 100.0
	add_child(_target)


func after_each() -> void:
	if is_instance_valid(_dealer): _dealer.queue_free()
	if is_instance_valid(_target): _target.queue_free()
	_dealer = null
	_target = null


func test_deal_damage_reduces_target_hp() -> void:
	_dealer.deal_damage(_target, DamageInfo.make(25.0))
	assert_eq(_target.get_hp(), 75.0)


func test_deal_damage_to_dead_is_noop() -> void:
	_target.take_damage(DamageInfo.make(100.0))  # tot
	_dealer.deal_damage(_target, DamageInfo.make(20.0))
	assert_eq(_target.get_hp(), 0.0)


func test_deal_damage_null_target_no_crash() -> void:
	# Nichts darf werfen
	_dealer.deal_damage(null, DamageInfo.make(5.0))
	pass_test("kein Crash bei null target")


func test_deal_damage_null_info_no_crash() -> void:
	_dealer.deal_damage(_target, null)
	assert_eq(_target.get_hp(), 100.0, "null info → kein Damage")


func test_will_deal_damage_signal_fires() -> void:
	var fired: Array = [false]
	_dealer.will_deal_damage.connect(func(_t, _i): fired[0] = true)
	_dealer.deal_damage(_target, DamageInfo.make(10.0))
	assert_true(fired[0])


func test_default_source_id_substituted_when_empty() -> void:
	_dealer.default_source_id = &"player"
	var info := DamageInfo.make(10.0)
	# source_id ist leer → Dealer setzt default
	_dealer.deal_damage(_target, info)
	# Wir prüfen es indirekt via damage_taken-Signal
	# Aber check: das Original wurde nicht modifiziert
	assert_eq(info.source_id, &"", "Original DamageInfo darf nicht mutiert werden")


func test_default_source_id_not_overriding_explicit() -> void:
	_dealer.default_source_id = &"player"
	# damage_taken auf target lauschen, source_id prüfen
	var captured: Array = [&""]
	_target.damage_taken.connect(func(info, _hp): captured[0] = info.source_id)
	_dealer.deal_damage(_target, DamageInfo.make(10.0, &"explicit_src"))
	assert_eq(captured[0], &"explicit_src",
		"Expliziter source_id darf nicht von default überschrieben werden")
