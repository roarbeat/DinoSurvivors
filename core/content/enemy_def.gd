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

## Visuelle Differenzierung (ADR 0024). Default = rot 16×16
## (matcht enemy_mob.tscn-Default für Backward-Kompat).
@export var body_color: Color = Color(0.82, 0.18, 0.18)
@export var body_size: Vector2 = Vector2(16, 16)

## Visual-Provider (ADR 0027). Optionale PackedScene, die statt der
## ColorRect-Body instanziert wird. Wenn null, bleibt ColorRect-Mode aktiv.
## Erlaubt Mods/Designer, eigene Sprites/Animationen einzuhängen, ohne
## Code zu schreiben.
@export var visual_scene: PackedScene

## Pivot-Offset für die HealthBar relativ zum Sprite-Pivot. Nur relevant
## wenn visual_scene gesetzt ist (ColorRect-Mode nutzt body_size).
@export var visual_pivot_offset: Vector2 = Vector2.ZERO


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if max_health <= 0.0:
		return "max_health muss > 0 sein"
	if speed < 0.0:
		return "speed darf nicht negativ sein"
	return ""
