class_name BossDef
extends ContentItem
## Definition eines Bosses. Stub für Phase 0 — Phasen-System wird
## ergänzt sobald Boss-Mechaniken designed sind.

@export var max_health: float = 1000.0

## Phasen-Definitionen. Jeder Eintrag ist ein Dictionary mit
## { &"hp_threshold": 0.66, &"behavior": &"raging" } o.ä.
## Wird in einem späteren ADR formalisiert (Phasen-Schema).
@export var phases: Array[Dictionary] = []

## i18n-Key für die Boss-Intro-Card („BOSS! TYRANNOSAURUS PRIME!").
@export var intro_text_key: StringName = &""

## Bernstein-Belohnung (oder andere Persistent-Currency) bei Defeat.
@export var reward_currency_amount: int = 0


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if max_health <= 0.0:
		return "max_health muss > 0 sein"
	if reward_currency_amount < 0:
		return "reward_currency_amount darf nicht negativ sein"
	return ""
