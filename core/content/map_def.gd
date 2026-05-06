class_name MapDef
extends ContentItem
## Map-Layout-Definition (ADR 0036).
##
## Konfiguriert eine IsoWorld data-driven: Grid-Size, Pfad-Pattern,
## Color-Variation. Modder können eigene MapDefs unter
## `user://mods/<mod_id>/content/maps/` ablegen oder Core-Maps via
## `override_existing = true` ersetzen.
##
## In v1 lädt RunScene beim Boot `&"default"` als Standard-Map.
## Map-Selection-UI ist Backlog (eigenes ADR).

## Grid-Größe in Tiles.
@export var grid_size: Vector2i = Vector2i(8, 8)

## Cross-Pfad: horizontale Pfad-Reihe. -1 = kein Pfad.
@export var path_row: int = 4

## Cross-Pfad: vertikale Pfad-Spalte. -1 = kein Pfad.
@export var path_col: int = 4

## Deterministische Tile-Color-Variation (Hash-basiert für stable Tests).
## false = randomisiert pro Boot.
@export var deterministic_colors: bool = true

## Optionaler i18n-Key für Map-Banner ("Wald-Lichtung", "Vulkan-Krater").
## Leer = kein Banner.
@export var biome_label_key: StringName = &""

## Camera-Bounds-Padding (ADR 0037). Erweitert die Bounds nach außen
## beim attach_to_world, sodass Camera Breathing-Room um die Plattform
## zeigen kann. Default Zero = strikt an Plattform-Rand klemmen.
@export var camera_padding: Vector2 = Vector2.ZERO


func validate() -> String:
	var base := super.validate()
	if base != "":
		return base
	if grid_size.x < 0 or grid_size.y < 0:
		return "grid_size darf nicht negativ sein"
	return ""
