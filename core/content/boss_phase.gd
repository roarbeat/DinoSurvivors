class_name BossPhase
extends Resource
## Boss-Phasen-Definition (ADR 0029).
##
## Eine Phase wird aktiv, wenn `current_hp / max_hp <= hp_threshold`.
## Konfiguration in BossDef.phases als sortierte Array (absteigend nach
## hp_threshold — 1.0 zuerst, 0.0 zuletzt).
##
## Phasen sind monoton: einmal eine niedrigere Phase erreicht, kehrt der
## Boss bei Heal nicht in eine höhere zurück (würde das Spielerlebnis
## kaputt machen).

## HP-Schwellwert (0.0–1.0). Phase ist aktiv, sobald
## `current_hp / max_hp <= hp_threshold`. 1.0 = Spawn-Phase, 0.0 = Final.
@export var hp_threshold: float = 1.0

## Speed-Multiplikator. 1.0 = BossDef.speed unverändert.
@export var speed_multiplier: float = 1.0

## Damage-Multiplikator. 1.0 = BossDef.damage unverändert.
@export var damage_multiplier: float = 1.0

## Color-Tint für visuelle Phase-Marker. Im ColorRect-Mode wird
## body.color mit color_tint multipliziert. Im Sprite-Mode (ADR 0027)
## wird Visual.modulate gesetzt.
@export var color_tint: Color = Color.WHITE

## Optionaler i18n-Key für Phase-Banner (z.B. "boss.t_prime.phase_rage").
## Leer = kein Banner-UI.
@export var label_key: StringName = &""

## Abilities, die in dieser Phase periodisch ausgelöst werden (ADR 0038).
## Leer = keine aktiven Abilities (nur Speed/Damage-Multiplikatoren).
@export var abilities: Array[BossAbility] = []


func validate() -> String:
	if hp_threshold < 0.0 or hp_threshold > 1.0:
		return "hp_threshold muss in [0.0, 1.0] sein"
	if speed_multiplier <= 0.0:
		return "speed_multiplier muss > 0 sein"
	if damage_multiplier < 0.0:
		return "damage_multiplier darf nicht negativ sein"
	return ""
