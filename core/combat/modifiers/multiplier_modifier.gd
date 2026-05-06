class_name MultiplierModifier
extends DamageModifier
## Multipliziert den Damage-Wert.
##
## Konvention: Mehrere MultiplierModifier multiplizieren sich
## (multiplikativ stacking). Wer additives Stacking will (z.B. +15% +20%
## = +35%), kombiniert es vorher zu einer einzigen Instanz.

@export var multiplier: float = 1.0


func _init() -> void:
	priority = 250


func apply(info: DamageInfo) -> DamageInfo:
	if info == null:
		return info
	return info.with_amount(info.amount * multiplier)
