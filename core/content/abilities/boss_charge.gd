class_name BossCharge
extends BossAbility
## Charge-Burst-Ability (ADR 0043).
##
## Boss rennt für `charge_duration` Sekunden mit `charge_speed` Richtung
## Player. Während des Charges wird das normale Movement durch
## charge-Movement ersetzt. Touch-Damage bleibt erhalten — der Charge
## bringt damage durch Touch, kein eigener AOE-Hit.
##
## Implementation: Wir setzen einen Charge-State auf dem Boss
## (boss._charge_state). BossMob._move_toward_player liest den
## Charge-State und überschreibt Movement entsprechend.

## Charge-Geschwindigkeit (Pixel/Sekunde) während des Bursts.
@export var charge_speed: float = 600.0

## Wie lange der Charge dauert (Sekunden).
@export var charge_duration: float = 0.5

## Touch-Damage-Override während Charge. Wenn 0, wird BossDef.damage
## genutzt; wenn > 0, übersteuert das den Standard-Touch-Damage.
@export var damage: float = 35.0


func trigger(boss: Node) -> void:
	if boss == null:
		return
	if not (boss is Node2D):
		return
	# Charge-State auf Boss setzen (Convention: BossMob liest das im
	# _physics_process)
	if boss.has_method("start_charge"):
		boss.start_charge(self)

	# EventBus
	if boss.get_node_or_null("/root/EventBus") != null:
		EventBus.boss_ability_used.emit(
			boss.boss_id if "boss_id" in boss else &"",
			id,
			(boss as Node2D).global_position,
		)


## Pure-Function-Helper (Test-Hook): berechnet Charge-Velocity-Vector
## aus aktueller Boss-Position und Player-Position.
static func compute_charge_velocity(
	boss_pos: Vector2,
	player_pos: Vector2,
	speed: float,
) -> Vector2:
	var diff: Vector2 = player_pos - boss_pos
	if diff.length_squared() <= 0.0001:
		return Vector2.ZERO
	return diff.normalized() * speed
