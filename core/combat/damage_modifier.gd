class_name DamageModifier
extends Resource
## Basis-Klasse für Damage-Modifier (ADR 0010).
##
## Subklassen überschreiben `apply(info)`. Default-Verhalten: returns
## info unverändert.
##
## REGELN (verbindlich):
##   - apply() ist eine PURE FUNCTION: gleicher Input → gleicher Output,
##     KEINE Mutation der übergebenen DamageInfo. Liefere immer eine
##     neue Resource zurück (z.B. via info.with_amount(...)).
##   - priority bestimmt die Reihenfolge im Stack (niedrige Priorität zuerst).

## Sortier-Priorität. Konvention siehe ADR 0010 §3:
##   0..99   Pre-Calc
##   100..199 Flat-Boni
##   200..299 Multiplier
##   300..399 Defensive
##   400..499 Post-Calc
@export var priority: int = 100


## Default: Identitäts-Funktion. Subklassen überschreiben.
func apply(info: DamageInfo) -> DamageInfo:
	return info
