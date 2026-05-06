extends "res://addons/gut/test.gd"
## Tests für PlayerCharacter (ADR 0008).
##
## Movement-Logik wird via _compute_velocity() pure-getestet — keine
## Physics-Step-Simulation nötig. Komponenten-Anschluss wird durch
## direktes Anlegen der Scene-Hierarchie geprüft.

var _player: PlayerCharacter
var _trex: DinoDef


func before_each() -> void:
	# Aufräumen vor jedem Test
	PlayerMutations.reset()
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()

	# Player aus der echten .tscn laden — so testen wir auch, dass die
	# Scene-Hierarchie korrekt aufgebaut ist.
	var packed := load("res://core/player/player_character.tscn") as PackedScene
	_player = packed.instantiate() as PlayerCharacter
	add_child(_player)

	_trex = ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	_player.set_dino(_trex)


func after_each() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
	PlayerMutations.reset()


# ---------------------------------------------------------------------------
# Komponenten-Setup
# ---------------------------------------------------------------------------

func test_health_component_attached() -> void:
	var hp := _player.get_health_component()
	assert_not_null(hp)
	assert_true(hp is HealthComponent)


func test_dealer_component_attached() -> void:
	var dl := _player.get_dealer_component()
	assert_not_null(dl)
	assert_true(dl is DamageDealerComponent)


func test_health_is_player_flag_set() -> void:
	assert_true(_player.get_health_component().is_player,
		"Player-Health muss is_player=true haben")


func test_dealer_default_source_is_player() -> void:
	assert_eq(_player.get_dealer_component().default_source_id, &"player")


# ---------------------------------------------------------------------------
# DinoDef-Stats werden übernommen
# ---------------------------------------------------------------------------

func test_set_dino_initializes_max_hp_from_dino() -> void:
	# trex.max_health = 120.0
	assert_almost_eq(_player.get_health_component().max_hp, 120.0, 0.0001)


func test_initial_hp_is_full() -> void:
	assert_almost_eq(_player.get_health_component().get_hp(), 120.0, 0.0001)


func test_get_dino_returns_set_dino() -> void:
	assert_eq(_player.get_dino().id, &"trex")


# ---------------------------------------------------------------------------
# _compute_velocity (pure)
# ---------------------------------------------------------------------------

func test_compute_velocity_zero_input_returns_zero() -> void:
	assert_eq(_player._compute_velocity(Vector2.ZERO), Vector2.ZERO)


func test_compute_velocity_right_returns_speed_right() -> void:
	# trex base_speed = 180
	var v := _player._compute_velocity(Vector2.RIGHT)
	assert_almost_eq(v.x, 180.0, 0.001)
	assert_almost_eq(v.y, 0.0, 0.001)


func test_compute_velocity_diagonal_normalized() -> void:
	# Vector2(1,1) → normalisiert (~0.707, 0.707) × 180
	var v := _player._compute_velocity(Vector2(1, 1))
	assert_almost_eq(v.length(), 180.0, 0.001,
		"Diagonal-Movement muss auf base_speed normalisiert sein")


# ---------------------------------------------------------------------------
# Mutations-Hook
# ---------------------------------------------------------------------------

func test_pick_damage_mutation_adds_outgoing_modifier() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	# mutations_changed wurde gefeuert → _apply_stats lief
	var dealer := _player.get_dealer_component()
	assert_eq(dealer.outgoing_modifiers.size(), 1,
		"triceratops_horns damage_pct → 1 outgoing modifier")
	var m: MultiplierModifier = dealer.outgoing_modifiers[0]
	assert_almost_eq(m.multiplier, 1.15, 0.0001)


func test_pick_armor_mutation_adds_incoming_modifier() -> void:
	PlayerMutations.pick(&"ankylosaur_plates")  # armor_pct=0.20, max_health_pct=0.15
	var hp := _player.get_health_component()
	assert_eq(hp.incoming_modifiers.size(), 1)
	var a: ArmorModifier = hp.incoming_modifiers[0]
	assert_almost_eq(a.reduction_pct, 0.20, 0.0001)


func test_max_health_pct_unhandled_increases_max_hp() -> void:
	# ankylosaur_plates hat max_health_pct=0.15 als unhandled
	PlayerMutations.pick(&"ankylosaur_plates")
	# Nach apply: max_hp = 120 × 1.15 = 138
	assert_almost_eq(_player.get_health_component().max_hp, 138.0, 0.001)
	assert_almost_eq(_player.get_effective_max_hp(), 138.0, 0.001)


func test_move_speed_pct_does_not_exist_in_current_mutations() -> void:
	# Aktuell hat keine Mutation move_speed_pct → effective_speed = base
	PlayerMutations.pick(&"triceratops_horns")
	assert_almost_eq(_player.get_effective_speed(), 180.0, 0.001)


# ---------------------------------------------------------------------------
# Stat-Recalc bei mutations_changed
# ---------------------------------------------------------------------------

func test_remove_mutation_removes_modifier() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	assert_eq(_player.get_dealer_component().outgoing_modifiers.size(), 1)
	PlayerMutations.remove(&"triceratops_horns")
	assert_eq(_player.get_dealer_component().outgoing_modifiers.size(), 0,
		"Nach remove muss der Modifier weg sein")


func test_reset_clears_all_modifiers() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	PlayerMutations.pick(&"ankylosaur_plates")
	PlayerMutations.reset()
	assert_eq(_player.get_dealer_component().outgoing_modifiers.size(), 0)
	assert_eq(_player.get_health_component().incoming_modifiers.size(), 0)


# ---------------------------------------------------------------------------
# Roundtrip: Combat-Pipeline End-to-End mit Player
# ---------------------------------------------------------------------------

func test_player_dealer_with_mutation_does_correct_damage() -> void:
	# trex base_damage 15, +15% durch triceratops_horns → 17.25
	# DamageInfo wird vom Caller erstellt (Player nutzt seinen base_damage)
	PlayerMutations.pick(&"triceratops_horns")

	var target := HealthComponent.new()
	target.max_hp = 1000.0
	add_child(target)

	# Player.dealer mit dem base_damage des Dinos
	_player.get_dealer_component().deal_damage(
		target,
		DamageInfo.make(_trex.base_damage)
	)
	# 15 × 1.15 = 17.25 → 1000 - 17.25 = 982.75
	assert_almost_eq(target.get_hp(), 982.75, 0.001)

	target.queue_free()
