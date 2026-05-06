class_name ArmorModifier
extends DamageModifier
## Reduziert eingehenden Damage um einen Prozentsatz (ADR 0010).
##
## Wird auf HealthComponent.incoming_modifiers gehängt. Respektiert das
## `pierce_armor`-Flag der DamageInfo — penetrierender Damage wird
## NICHT reduziert.
##
## reduction_pct = 0.0  → keine Reduktion
## reduction_pct = 1.0  → 100% Reduktion (immune)

@export var reduction_pct: float = 0.0:
	set(value):
		reduction_pct = clamp(value, 0.0, 1.0)


func _init() -> void:
	priority = 300  # Defensive-Range


func apply(info: DamageInfo) -> DamageInfo:
	if info == null:
		return info
	if info.pierce_armor:
		return info
	var new_amount := info.amount * (1.0 - reduction_pct)
	return info.with_amount(new_amount)
