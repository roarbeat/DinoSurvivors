extends "res://addons/gut/test.gd"
## DamageNumber-VFX-Tests (ADR 0012).

# ---------------------------------------------------------------------------
# Format-Helper (static, isoliert testbar)
# ---------------------------------------------------------------------------

func test_format_amount_integer() -> void:
	assert_eq(DamageNumber._format_amount(15.0), "15")


func test_format_amount_rounds_half() -> void:
	assert_eq(DamageNumber._format_amount(17.25), "17",
		"Standard-Round: 17.25 → 17")


func test_format_amount_rounds_up() -> void:
	assert_eq(DamageNumber._format_amount(17.6), "18")


func test_format_amount_compact_for_thousands() -> void:
	assert_eq(DamageNumber._format_amount(1500.0), "1.5K")


func test_format_amount_compact_for_large() -> void:
	assert_eq(DamageNumber._format_amount(12500.0), "12.5K")


# ---------------------------------------------------------------------------
# Lifecycle: show_damage setzt amount, is_crit, position
# ---------------------------------------------------------------------------

var _dn: DamageNumber


func before_each() -> void:
	var packed := load("res://core/ui/damage_number.tscn") as PackedScene
	_dn = packed.instantiate() as DamageNumber
	add_child(_dn)


func after_each() -> void:
	if is_instance_valid(_dn):
		_dn.queue_free()
	_dn = null


func test_show_damage_stores_amount_and_crit() -> void:
	_dn.show_damage(42.0, true, Vector2(100, 200))
	assert_eq(_dn.get_amount(), 42.0)
	assert_true(_dn.is_crit())


func test_show_damage_sets_position_with_offset() -> void:
	_dn.show_damage(15.0, false, Vector2(100, 200))
	# SPAWN_OFFSET = (0, -15) → erwartete Position (100, 185)
	assert_eq(_dn.global_position, Vector2(100, 185))


func test_show_damage_label_text() -> void:
	_dn.show_damage(15.0, false, Vector2.ZERO)
	assert_eq(_dn.label.text, "15")


func test_show_damage_crit_label_text() -> void:
	_dn.show_damage(30.0, true, Vector2.ZERO)
	assert_eq(_dn.label.text, "30")
	# is_crit → größere Font + gelb. Wir prüfen den Color-Override.
	var color := _dn.label.get_theme_color("font_color")
	assert_eq(color, DamageNumber.CRIT_COLOR)


# ---------------------------------------------------------------------------
# HealthBar-Integration: _on_damage_taken spawnt DamageNumber
# ---------------------------------------------------------------------------

func test_health_bar_spawns_damage_number_on_damage() -> void:
	# HealthBar setup
	var hpbar_packed := load("res://core/ui/health_bar.tscn") as PackedScene
	var hpbar: HealthBar = hpbar_packed.instantiate()
	add_child(hpbar)

	var hp := HealthComponent.new()
	hp.max_hp = 100.0
	add_child(hp)
	hpbar.set_health(hp)

	# Vor dem Damage: kein DamageNumber im Tree
	var dn_before := _count_damage_numbers()

	# Damage zufügen
	hp.take_damage(DamageInfo.make(15.0))

	# Nach dem Damage: 1 DamageNumber existiert (irgendwo im Tree)
	var dn_after := _count_damage_numbers()
	assert_eq(dn_after - dn_before, 1,
		"HealthBar muss 1 DamageNumber pro Treffer spawnen")

	# Cleanup
	hpbar.queue_free()
	hp.queue_free()


func test_health_bar_can_disable_damage_numbers() -> void:
	var hpbar_packed := load("res://core/ui/health_bar.tscn") as PackedScene
	var hpbar: HealthBar = hpbar_packed.instantiate()
	hpbar.spawn_damage_numbers = false
	add_child(hpbar)

	var hp := HealthComponent.new()
	hp.max_hp = 100.0
	add_child(hp)
	hpbar.set_health(hp)

	var dn_before := _count_damage_numbers()
	hp.take_damage(DamageInfo.make(15.0))
	var dn_after := _count_damage_numbers()

	assert_eq(dn_after, dn_before,
		"Mit spawn_damage_numbers=false darf nichts gespawnt werden")

	hpbar.queue_free()
	hp.queue_free()


# Helper: zählt DamageNumber-Instanzen im Tree
func _count_damage_numbers() -> int:
	var count := 0
	for n in _gather_all_descendants(get_tree().root):
		if n is DamageNumber:
			count += 1
	return count


func _gather_all_descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_gather_all_descendants(child))
	return out
