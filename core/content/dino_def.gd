class_name DinoDef
extends ContentItem
## Spielbare Dino-Charakter-Definition.
##
## In v1 (ADR 0006) sind das reine Stat-Container — der Combat-Implementation
## wird hier später z.B. abilities[]-Felder ergänzen.

@export var max_health: float = 100.0
@export var base_speed: float = 200.0
@export var base_damage: float = 10.0
@export var base_attack_rate: float = 1.0  # Attacks pro Sekunde
@export var pickup_radius: float = 80.0

## Player-Controller-Scene. Bleibt null bis Combat-System steht.
@export var character_scene: PackedScene

## Visual-Provider (ADR 0027). Optionale PackedScene, die statt der
## ColorRect-Body instanziert wird. Wenn null, bleibt ColorRect-Mode.
@export var visual_scene: PackedScene

## Pivot-Offset für die HealthBar relativ zum Sprite-Pivot.
@export var visual_pivot_offset: Vector2 = Vector2.ZERO


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if max_health <= 0.0:
		return "max_health muss > 0 sein"
	if base_speed < 0.0:
		return "base_speed darf nicht negativ sein"
	if base_attack_rate <= 0.0:
		return "base_attack_rate muss > 0 sein"
	if pickup_radius < 0.0:
		return "pickup_radius darf nicht negativ sein"
	return ""
