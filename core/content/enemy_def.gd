class_name EnemyDef
extends ContentItem
## Definition eines Standard-Gegners.

@export var max_health: float = 10.0
@export var speed: float = 100.0
@export var damage: float = 5.0
@export var xp_reward: int = 1

## Optionale Scene-Referenz für die visuelle Darstellung. Bleibt null
## solange das Combat-System noch nicht steht — Loader-Validation
## verlangt das Feld nicht.
@export var scene: PackedScene


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if max_health <= 0.0:
		return "max_health muss > 0 sein"
	if speed < 0.0:
		return "speed darf nicht negativ sein"
	return ""
