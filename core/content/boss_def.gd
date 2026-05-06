class_name BossDef
extends ContentItem
## Definition eines Bosses. Stub für Phase 0 — Phasen-System wird
## ergänzt sobald Boss-Mechaniken designed sind.

@export var max_health: float = 1000.0

## Phasen-Definitionen (ADR 0029). Array von BossPhase-Resources, in
## absteigender hp_threshold-Reihenfolge konfiguriert (1.0 zuerst,
## 0.0 zuletzt). Leeres Array = keine Phasen-Logik (altes Verhalten).
@export var phases: Array[BossPhase] = []

## i18n-Key für die Boss-Intro-Card („BOSS! TYRANNOSAURUS PRIME!").
@export var intro_text_key: StringName = &""

## Optionale Scene-Referenz für die visuelle Darstellung (analog EnemyDef).
@export var scene: PackedScene

## Bernstein-Belohnung (oder andere Persistent-Currency) bei Defeat.
@export var reward_currency_amount: int = 0

## Movement-Stats (ADR 0025). Boss läuft mit `speed`, fügt `damage` zu.
## Default-Werte konservativ — Boss ist langsamer als die meisten Enemies.
@export var speed: float = 80.0
@export var damage: float = 40.0

## Visuelle Differenzierung (analog ADR 0024). Default = dunkelviolett 40×40.
@export var body_color: Color = Color(0.227, 0.094, 0.314)
@export var body_size: Vector2 = Vector2(40, 40)

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
	if reward_currency_amount < 0:
		return "reward_currency_amount darf nicht negativ sein"

	# Phasen-Validation (ADR 0029):
	# - jede Phase muss valide sein
	# - phases müssen absteigend nach hp_threshold sortiert sein
	var prev_threshold: float = 2.0  # > 1.0 als Sentinel
	for i in phases.size():
		var p: BossPhase = phases[i]
		if p == null:
			return "phases[%d] ist null" % i
		var pe := p.validate()
		if pe != "":
			return "phases[%d]: %s" % [i, pe]
		if p.hp_threshold > prev_threshold:
			return "phases müssen absteigend nach hp_threshold sortiert sein (Index %d bricht Reihenfolge)" % i
		prev_threshold = p.hp_threshold

	return ""
