class_name ContentItem
extends Resource
## Abstract Base-Klasse für alle Content-Resources.
##
## Jede konkrete Content-Art (MutationDef, EnemyDef, …) erbt davon.
## Felder hier sind universell, type-spezifische Felder leben in den
## Subklassen.
##
## REGELN:
##   - `id` ist snake_case, einmalig pro Type, NIE umbenannt.
##   - User-facing Strings NIEMALS direkt — nur i18n-Keys hier ablegen.
##   - `source_mod_id` wird vom ContentLoader gesetzt, nicht vom Author.
##   - `override_existing` ist Mod-only — Core-Files lassen das auf false.

## Eindeutige ID innerhalb des Content-Types. snake_case, max 40 Zeichen.
@export var id: StringName = &""

## i18n-Key für den Anzeigenamen, z.B. &"mutation.triceratops_horns.name".
@export var display_name_key: StringName = &""

## i18n-Key für die Tooltip-Beschreibung.
@export var description_key: StringName = &""

## Mod-ID des Ursprungs. Vom ContentLoader gesetzt:
##   &""              für Core-Content
##   &"<mod_id>"      für Mod-Content
## Author lässt das leer.
@export var source_mod_id: StringName = &""

## Erlaubt einem Mod-Resource, eine Core-ID zu überschreiben.
## Standard: false → Loader warnt und ignoriert das Mod-Resource.
@export var override_existing: bool = false


## Validierungs-Hook. Subklassen können overriden, um eigene Felder zu
## prüfen. Rückgabe: leerer String = OK, sonst Fehlertext.
func validate() -> String:
	if String(id) == "":
		return "id ist leer"
	if String(display_name_key) == "":
		return "display_name_key ist leer"
	# description_key darf leer sein (z.B. interne Items ohne Tooltip)
	return ""
