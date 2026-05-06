class_name IsoWorld
extends Node2D
## Iso-World-Skelett (ADR 0031).
##
## Baut beim _ready() ein Grid von grid_size Tiles als Polygon2D-Diamonds.
## Tile-Farbe rotiert deterministisch über Grass-Light/Mid/Dark
## (Default-Variation). Cross-Pfad in DIRT-Color durch die Mitte.
##
## Wenn echte Sprite-Tiles landen, wird IsoWorld auf TileMapLayer +
## TileSet umgebaut — die Public-API (`tile_to_iso`, `iso_to_tile`,
## `world_size`) bleibt stabil.
##
## Pure-Function-Konventionen:
##   `tile_to_iso(tile, tile_size)` und `iso_to_tile(...)` sind static —
##   testbar ohne Instanz.

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

## Iso-Tile-Größe (Breite × Höhe). Default folgt Godot-Iso-Standard
## (2:1 Verhältnis).
const TILE_SIZE: Vector2i = Vector2i(64, 32)


# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Grid-Größe in Tiles.
@export var grid_size: Vector2i = Vector2i(8, 8)

## Cross-Pfad: Welche Reihe ist der horizontale Pfad? -1 = kein Pfad.
@export var path_row: int = 4

## Cross-Pfad: Welche Spalte ist der vertikale Pfad?
@export var path_col: int = 4

## Deterministisches Tile-Color-Rotation. Wenn rng nicht gesetzt ist,
## nutzen wir einen deterministischen Hash aus (x, y), damit Tests
## stabile Ergebnisse haben.
@export var deterministic_colors: bool = true

# State (ADR 0036)
var _map_def: MapDef = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_tiles()


# ---------------------------------------------------------------------------
# Public-API (pure functions als static — direkt aufrufbar via Klasse)
# ---------------------------------------------------------------------------

## Welt-Tile-Koords → Bildschirm-Iso-Koords (px).
## Pure function, testbar.
static func tile_to_iso(tile: Vector2i, tile_size: Vector2i = TILE_SIZE) -> Vector2:
	var px: float = float(tile.x - tile.y) * (tile_size.x * 0.5)
	var py: float = float(tile.x + tile.y) * (tile_size.y * 0.5)
	return Vector2(px, py)


## Bildschirm-Iso-Koords → Welt-Tile-Koords. Inverse zu tile_to_iso.
static func iso_to_tile(screen: Vector2, tile_size: Vector2i = TILE_SIZE) -> Vector2i:
	var tx: float = (screen.x / (tile_size.x * 0.5) + screen.y / (tile_size.y * 0.5)) * 0.5
	var ty: float = (screen.y / (tile_size.y * 0.5) - screen.x / (tile_size.x * 0.5)) * 0.5
	return Vector2i(int(round(tx)), int(round(ty)))


## Konfiguriert die IsoWorld aus einer MapDef (ADR 0036).
## Übernimmt grid_size, path_row, path_col, deterministic_colors und
## ruft `_build_tiles()` auf, sodass die neue Map sofort sichtbar ist.
##
## No-op wenn def null ist.
func set_map_def(def: MapDef) -> void:
	if def == null:
		return
	_map_def = def
	grid_size = def.grid_size
	path_row = def.path_row
	path_col = def.path_col
	deterministic_colors = def.deterministic_colors
	_build_tiles()


## Liefert die zuletzt gesetzte MapDef. null wenn `set_map_def`
## nie gerufen wurde (IsoWorld nutzt dann seine @export-Defaults).
func get_map_def() -> MapDef:
	return _map_def


## Bounding-Box des Iso-Grids in Pixel.
func world_size() -> Vector2:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return Vector2.ZERO
	# Iso-Bounding: maximale x = (gx-1) * tw/2 + (gy-1) * tw/2 = (gx+gy-2)*tw/2
	# minimale x = -(gy-1) * tw/2
	# maximale y = (gx+gy-2) * th/2
	var w: float = float(grid_size.x + grid_size.y - 1) * (TILE_SIZE.x * 0.5)
	var h: float = float(grid_size.x + grid_size.y - 1) * (TILE_SIZE.y * 0.5)
	return Vector2(w, h)


## Bounding-Rect des Iso-Grids in Welt-Koordinaten (ADR 0033).
##
## Berücksichtigt die Diamond-Form jedes Tiles: jeder Tile ragt
## TILE_SIZE/2 in jede Richtung von seinem Pivot. Das Result-Rect
## umschließt damit die gesamte sichtbare Plattform inklusive der
## äußeren Diamond-Spitzen.
##
## Pure function (deterministisch). Liefert leeres Rect bei grid_size 0.
func world_bounds() -> Rect2:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return Rect2()
	var hw: float = TILE_SIZE.x * 0.5
	var hh: float = TILE_SIZE.y * 0.5
	# Linkester Tile-Pivot ist (0, grid.y-1) → x = -(gy-1) * hw
	# Rechtester Tile-Pivot ist (gx-1, 0) → x = +(gx-1) * hw
	# Oberster Tile-Pivot ist (0, 0) → y = 0
	# Unterster Tile-Pivot ist (gx-1, gy-1) → y = (gx+gy-2) * hh
	var min_x: float = -float(grid_size.y - 1) * hw - hw
	var max_x: float =  float(grid_size.x - 1) * hw + hw
	var min_y: float = -hh
	var max_y: float =  float(grid_size.x + grid_size.y - 2) * hh + hh
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


## true wenn (tile.x, tile.y) auf dem Cross-Pfad liegt (Path-Tile statt Grass).
func is_path_tile(tile: Vector2i) -> bool:
	if path_row >= 0 and tile.y == path_row:
		return true
	if path_col >= 0 and tile.x == path_col:
		return true
	return false


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Erzeugt für jedes Tile im Grid ein Polygon2D als Iso-Diamond mit
## passender Color. Tiles werden als Children unter "Tiles" eingefügt.
func _build_tiles() -> void:
	# Vorhandene Tiles wegräumen (Idempotenz für Resetup)
	var existing := get_node_or_null("Tiles")
	if existing != null:
		remove_child(existing)
		existing.queue_free()

	var container := Node2D.new()
	container.name = "Tiles"
	add_child(container)

	for y in grid_size.y:
		for x in grid_size.x:
			var tile := Vector2i(x, y)
			var poly := _make_tile_polygon(tile)
			container.add_child(poly)


## Erzeugt einen einzelnen Tile-Diamond als Polygon2D.
func _make_tile_polygon(tile: Vector2i) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "Tile_%d_%d" % [tile.x, tile.y]
	poly.position = tile_to_iso(tile)

	# Iso-Diamond-Punkte (CW von oben)
	var hw := float(TILE_SIZE.x) * 0.5
	var hh := float(TILE_SIZE.y) * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(0, -hh),    # oben
		Vector2(hw, 0),     # rechts
		Vector2(0, hh),     # unten
		Vector2(-hw, 0),    # links
	])

	poly.color = _color_for_tile(tile)
	return poly


## Liefert die Color für ein Tile basierend auf Pfad-/Grass-Logik.
func _color_for_tile(tile: Vector2i) -> Color:
	if is_path_tile(tile):
		return Palette.DIRT_PATH

	if not deterministic_colors:
		return Palette.random_grass()

	# Deterministischer Hash → stable Color zwischen Runs/Tests
	var hash_val: int = (tile.x * 73 + tile.y * 191) % 3
	if hash_val == 0:
		return Palette.GRASS_LIGHT
	if hash_val == 1:
		return Palette.GRASS_MID
	return Palette.GRASS_DARK
