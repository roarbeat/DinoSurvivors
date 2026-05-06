class_name BossStomp
extends BossAbility
## AOE-Damage-Stomp-Ability (ADR 0038).
##
## Boss schlägt periodisch zu — alle Players im radius bekommen damage.
## Erste konkrete BossAbility — Template für Roar/Charge/etc.

## Effekt-Radius in Pixel.
@export var radius: float = 120.0

## Damage pro Stomp.
@export var damage: float = 25.0


## Wendet AOE-Damage auf alle Players in Radius an.
## Feuert EventBus.boss_ability_used (für UI/SFX/VFX).
func trigger(boss: Node) -> void:
	if boss == null:
		return
	if not (boss is Node2D):
		return
	var boss_n2d: Node2D = boss
	var dealer = boss.get("dealer") if boss.has_method("get_dealer_component") else null
	# Für BossMob nutzen wir get_dealer_component()
	var dealer_comp = null
	if boss.has_method("get_dealer_component"):
		dealer_comp = boss.get_dealer_component()
	if dealer_comp == null:
		return

	# Players in Radius finden
	var hits: Array = find_player_health_in_radius(
		boss_n2d.global_position,
		radius,
		boss.get_tree().get_nodes_in_group(&"player"),
	)

	# Damage applizieren
	var info: DamageInfo = DamageInfo.make(damage, &"boss_stomp")
	for hp in hits:
		dealer_comp.deal_damage(hp, info)

	# EventBus für UI/SFX/VFX
	if boss.get_node_or_null("/root/EventBus") != null:
		EventBus.boss_ability_used.emit(
			boss.boss_id if "boss_id" in boss else &"",
			id,
			boss_n2d.global_position,
		)


## Pure-Function-Helper (Test-Hook): findet alle HealthComponents von
## Players im Radius. Liefert Array[HealthComponent].
static func find_player_health_in_radius(
	center: Vector2,
	radius: float,
	players: Array,
) -> Array:
	var out: Array = []
	var r2: float = radius * radius
	for p in players:
		if p == null or not (p is Node2D):
			continue
		if not is_instance_valid(p):
			continue
		var p_n2d: Node2D = p
		if (p_n2d.global_position - center).length_squared() > r2:
			continue
		var hp: HealthComponent = p.get_node_or_null("Health") as HealthComponent
		if hp != null:
			out.append(hp)
	return out
