class_name SoundDef
extends ContentItem
## Sound-Effect-Definition (ADR 0028).
##
## Wird vom SfxBus-Autoload geladen und bei EventBus-Signalen abgespielt.
## Modder können eigene SoundDefs unter `user://mods/<mod_id>/content/sounds/`
## ablegen oder Core-IDs via `override_existing = true` ersetzen.

## AudioStream-Resource (.ogg/.wav). Null = no-op (v1-Default).
## SfxBus skippt das Playback, wenn stream null ist.
@export var stream: AudioStream

## Volume-Offset in dB. 0.0 = unverändert, -6.0 = halb so laut,
## +6.0 = doppelt so laut.
@export var volume_db: float = 0.0

## ±Range für pitch_scale-Random pro Playback. 0.0 = kein Random,
## 0.1 = pitch wird um ±10% variiert (1.0 ± 0.1 → 0.9–1.1).
## Verhindert „identische Klang-Wiederholungen" bei Spam (z.B. mehrere
## Enemies sterben gleichzeitig).
@export var pitch_random_range: float = 0.0


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if pitch_random_range < 0.0:
		return "pitch_random_range darf nicht negativ sein"
	if pitch_random_range > 1.0:
		return "pitch_random_range darf max. 1.0 sein"
	return ""
