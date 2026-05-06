class_name BossAbility
extends Resource
## Boss-Ability-Base-Klasse (ADR 0038).
##
## Wird vom BossMob pro aktiver Phase periodisch getickt:
##   - `cooldown` Sekunden zwischen Triggers
##   - `initial_delay` Sekunden bis erster Trigger nach Phase-Start
##
## Subklassen überschreiben `trigger(boss)` für ihren Effekt
## (Stomp = AOE-Damage, Roar = Buff für Adds, Charge = Move-Burst).
##
## Public-API:
##   trigger(boss: BossMob) -> void   # virtual, von Subclass überschrieben

## Eindeutige ID — wird von EventBus.boss_ability_used emit'ed.
@export var id: StringName = &""

## Sekunden zwischen Triggers in derselben Phase.
@export var cooldown: float = 5.0

## Sekunden bis erster Trigger nach Phase-Start (verhindert Sofort-
## Spam beim Phase-Wechsel).
@export var initial_delay: float = 1.0


## Virtual: wird vom BossMob beim Cooldown-Trigger aufgerufen.
## Subklassen überschreiben das.
func trigger(_boss: Node) -> void:
	pass


func validate() -> String:
	if cooldown <= 0.0:
		return "cooldown muss > 0 sein"
	if initial_delay < 0.0:
		return "initial_delay darf nicht negativ sein"
	return ""
