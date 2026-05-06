class_name ShakeProfile
extends Resource
## Camera-Shake-Profile (ADR 0039).
##
## Konfiguriert pro EventBus-Signal, wieviel Trauma die RunCamera bekommt
## und wie der Shake aussieht (Decay, Max-Offset).
##
## v1: nur trauma_amount wirkt sich auf den Shake aus. Decay und
## max_offset sind Konfig-Slots für Layering-ADR (Backlog).

## Wieviel Trauma das Profile addiert (0.0 – 1.0).
@export var trauma_amount: float = 0.3

## Decay-Geschwindigkeit. 0.0 = nutze RunCamera.trauma_decay_per_second.
@export var decay_per_second: float = 0.0

## Maximaler Shake-Offset. 0.0 = nutze RunCamera.max_shake_offset.
@export var max_offset: float = 0.0


func validate() -> String:
	if trauma_amount < 0.0 or trauma_amount > 1.0:
		return "trauma_amount muss in [0.0, 1.0] sein"
	if decay_per_second < 0.0:
		return "decay_per_second darf nicht negativ sein"
	if max_offset < 0.0:
		return "max_offset darf nicht negativ sein"
	return ""
