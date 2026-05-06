class_name FlatBonusModifier
extends DamageModifier
## Addiert einen flachen Bonus auf den Damage-Wert.
##
## Beispiel: +5 Damage durch Mutation.

@export var bonus_amount: float = 0.0


func _init() -> void:
	priority = 150


func apply(info: DamageInfo) -> DamageInfo:
	if info == null:
		return info
	return info.with_amount(info.amount + bonus_amount)
