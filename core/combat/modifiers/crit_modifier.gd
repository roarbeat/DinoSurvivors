class_name CritModifier
extends DamageModifier
## Crit-Chance + Crit-Multiplier (ADR 0010).
##
## Tests injizieren via set_rng() einen seeded RNG. Default-RNG ist
## eine eigene Instanz, damit verschiedene CritModifier-Resourcen sich
## nicht gegenseitig stören.

@export var chance: float = 0.1   # 0.0..1.0
@export var multiplier: float = 2.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	priority = 250
	# Variable seed pro Resource-Instanz
	_rng.randomize()


## Test-Hook: deterministischer RNG für reproducible Tests.
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func apply(info: DamageInfo) -> DamageInfo:
	if info == null:
		return info
	if _rng.randf() <= chance:
		var crit := info.with_amount(info.amount * multiplier)
		crit.is_crit = true
		return crit
	return info
