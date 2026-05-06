extends "res://addons/gut/test.gd"
## HealthComponent-Tests — Hot-Path-Logik isoliert von Bus.

var _hp: HealthComponent

func before_each() -> void:
	_hp = HealthComponent.new()
	_hp.max_hp = 100.0
	_hp.is_player = false
	add_child(_hp)
	# _ready muss laufen, damit _current_hp gesetzt wird
	# add_child triggert _ready


func after_each() -> void:
	if is_instance_valid(_hp):
		_hp.queue_free()
	_hp = null


# ---------------------------------------------------------------------------
# Initial State
# ---------------------------------------------------------------------------

func test_initial_hp_is_max() -> void:
	assert_eq(_hp.get_hp(), 100.0)
	assert_almost_eq(_hp.get_hp_pct(), 1.0, 0.0001)
	assert_false(_hp.is_dead())


# ---------------------------------------------------------------------------
# Take damage
# ---------------------------------------------------------------------------

func test_take_damage_reduces_hp() -> void:
	_hp.take_damage(DamageInfo.make(30.0))
	assert_eq(_hp.get_hp(), 70.0)
	assert_almost_eq(_hp.get_hp_pct(), 0.7, 0.0001)


func test_take_damage_emits_local_signal() -> void:
	var captured: Array = [false, 0.0]  # by-ref Workaround für Lambda-Write
	_hp.damage_taken.connect(func(_info, hp_after):
		captured[0] = true
		captured[1] = hp_after)
	_hp.take_damage(DamageInfo.make(30.0))
	assert_true(captured[0], "damage_taken sollte gefeuert haben")
	assert_eq(captured[1], 70.0)


func test_take_damage_zero_or_negative_is_noop() -> void:
	_hp.take_damage(DamageInfo.make(0.0))
	assert_eq(_hp.get_hp(), 100.0)


func test_take_damage_null_info_is_noop() -> void:
	_hp.take_damage(null)
	assert_eq(_hp.get_hp(), 100.0)


func test_take_damage_clamps_to_zero() -> void:
	_hp.take_damage(DamageInfo.make(999.0))
	assert_eq(_hp.get_hp(), 0.0)
	assert_true(_hp.is_dead())


# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------

func test_died_signal_fires_at_zero_hp() -> void:
	var died_count: Array = [0]
	_hp.died.connect(func(_info): died_count[0] += 1)
	_hp.take_damage(DamageInfo.make(100.0))
	assert_eq(died_count[0], 1)


func test_take_damage_after_death_is_noop() -> void:
	var died_count: Array = [0]
	_hp.died.connect(func(_info): died_count[0] += 1)
	_hp.take_damage(DamageInfo.make(100.0))
	_hp.take_damage(DamageInfo.make(50.0))  # zweiter Treffer
	assert_eq(died_count[0], 1, "died darf nur einmal feuern")


# ---------------------------------------------------------------------------
# Heal
# ---------------------------------------------------------------------------

func test_heal_increases_hp() -> void:
	_hp.take_damage(DamageInfo.make(50.0))
	_hp.heal(20.0)
	assert_eq(_hp.get_hp(), 70.0)


func test_heal_clamps_to_max() -> void:
	_hp.heal(50.0)
	assert_eq(_hp.get_hp(), 100.0, "Heal darf nicht über max_hp")


func test_heal_dead_target_is_noop() -> void:
	_hp.take_damage(DamageInfo.make(100.0))
	_hp.heal(50.0)
	assert_true(_hp.is_dead())
	assert_eq(_hp.get_hp(), 0.0)


# ---------------------------------------------------------------------------
# Bus-Integration (player-Signale)
# ---------------------------------------------------------------------------

func test_player_damaged_fires_for_player() -> void:
	_hp.is_player = true
	watch_signals(EventBus)
	_hp.take_damage(DamageInfo.make(15.0, &"boss"))
	assert_signal_emitted_with_parameters(EventBus, "player_damaged", [15.0, &"boss"])


func test_player_died_fires_for_player_at_zero() -> void:
	_hp.is_player = true
	watch_signals(EventBus)
	_hp.take_damage(DamageInfo.make(999.0))
	assert_signal_emitted(EventBus, "player_died")


func test_enemy_died_uses_owner_property() -> void:
	# Owner-Node mit enemy_id und Position2D
	var owner := Node2D.new()
	owner.set_meta("enemy_id", &"raptor_grunt")  # Meta funktioniert nicht für "in"-Check
	# Wir setzen das Property dynamisch via Script-Klasse
	# Einfacher: ein temporäres Script.
	var owner_script := GDScript.new()
	owner_script.source_code = """
extends Node2D
var enemy_id: StringName = &\"raptor_grunt\"
"""
	owner_script.reload()
	owner.set_script(owner_script)
	add_child(owner)
	# HealthComponent anhängen
	var hp := HealthComponent.new()
	hp.max_hp = 10.0
	hp.is_player = false
	owner.add_child(hp)

	watch_signals(EventBus)
	hp.take_damage(DamageInfo.make(20.0, &"player"))

	assert_signal_emitted(EventBus, "enemy_died")
	var params: Array = get_signal_parameters(EventBus, "enemy_died")
	assert_eq(params[0], &"raptor_grunt")

	owner.queue_free()
