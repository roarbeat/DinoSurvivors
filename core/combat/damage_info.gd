class_name DamageInfo
extends Resource
## Strukturierter Damage-Payload (ADR 0007).
##
## Wird zwischen DamageDealerComponent und HealthComponent übergeben.
## Mods dürfen eigene damage_types einführen — die Konvention ist
## offene StringName mit Resistance-Tabellen auf Empfängerseite.

@export var amount: float = 0.0
@export var damage_type: StringName = &"physical"
@export var source_id: StringName = &""
@export var is_crit: bool = false
@export var pierce_armor: bool = false


## Convenience-Constructor — DamageInfo wird oft ad-hoc erzeugt.
static func make(amount: float, source_id: StringName = &"", \
		damage_type: StringName = &"physical", is_crit: bool = false) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.source_id = source_id
	info.damage_type = damage_type
	info.is_crit = is_crit
	return info


## Validierung — leerer Return = OK, sonst Fehlertext.
func validate() -> String:
	if amount < 0.0:
		return "amount darf nicht negativ sein (heal nutzt heal(), nicht negative Damage)"
	if String(damage_type) == "":
		return "damage_type ist leer"
	return ""


## Liefert eine Kopie mit modifizierter `amount`. Nützlich für
## DamageDealer-Modifier-Pipeline (kommt mit ADR 0010).
func with_amount(new_amount: float) -> DamageInfo:
	var copy := DamageInfo.new()
	copy.amount = new_amount
	copy.damage_type = damage_type
	copy.source_id = source_id
	copy.is_crit = is_crit
	copy.pierce_armor = pierce_armor
	return copy
