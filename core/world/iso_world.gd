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

## Decoration-Density (ADR 0041). Anteil der Grass-Tiles, auf denen
## eine Blume oder ein Crystal erscheint. 0.0 = keine Decor.
@export var decoration_density: float = 0.20

## Sichtbare Tiefe der Dirt-Side-Faces in Pixeln.
@export var side_face_depth: float = 18.0

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
	var existing_sides := get_node_or_null("Sides")
	if existing_sides != null:
		remove_child(existing_sides)
		existing_sides.queue_free()
	var existing_decor := get_node_or_null("Decorations")
	if existing_decor != null:
		remove_child(existing_decor)
		existing_decor.queue_free()

	# Sides zuerst (z-Order: hinter Tiles)
	var sides_container := Node2D.new()
	sides_container.name = "Sides"
	add_child(sides_container)

	var container := Node2D.new()
	container.name = "Tiles"
	add_child(container)

	# Decorations zuletzt (über Tiles, hinter Mobs)
	var decor_container := Node2D.new()
	decor_container.name = "Decorations"
	add_child(decor_container)

	for y in grid_size.y:
		for x in grid_size.x:
			var tile := Vector2i(x, y)
			var poly := _make_tile_polygon(tile)
			container.add_child(poly)

			# Side-Face nur an unteren/rechten Edge-Tiles (ADR 0041)
			if _is_edge_tile(tile):
				var side := _make_side_polygon(tile)
				if side != null:
					sides_container.add_child(side)

	# Decorations nach allen Tiles (deterministisch)
	_build_decorations(decor_container)


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


# ---------------------------------------------------------------------------
# Side-Faces + Decorations (ADR 0041)
# ---------------------------------------------------------------------------

## true wenn Tile am unteren oder rechten Plattform-Rand sitzt
## (Iso-View: nur unten/rechts sichtbar — oben/links liegen
## nicht im Frustum).
func _is_edge_tile(tile: Vector2i) -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return false
	return tile.x == grid_size.x - 1 or tile.y == grid_size.y - 1


## Erzeugt das Dirt-Side-Polygon unter einem Edge-Tile. Trapez-Form,
## reicht side_face_depth Pixel nach unten.
func _make_side_polygon(tile: Vector2i) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "Side_%d_%d" % [tile.x, tile.y]
	poly.position = tile_to_iso(tile)

	var hw := float(TILE_SIZE.x) * 0.5
	var hh := float(TILE_SIZE.y) * 0.5
	var d := side_face_depth

	# Trapez-Form: oben = unteres Diamond-Profil, unten verschoben um (0, d).
	# Sichtbar nur die Hälfte des Diamonds (links und rechts unten).
	poly.polygon = PackedVector2Array([
		Vector2(-hw, 0),       # links Diamond-Mitte
		Vector2(0, hh),        # unten Diamond-Spitze
		Vector2(hw, 0),        # rechts Diamond-Mitte
		Vector2(hw, d),        # rechts unten
		Vector2(0, hh + d),    # unten unten
		Vector2(-hw, d),       # links unten
	])
	# Gradient von DIRT_SIDE_TOP nach _BOTTOM via vertex_colors
	var c_top := Palette.DIRT_SIDE_TOP
	var c_bot := Palette.DIRT_SIDE_BOTTOM
	poly.vertex_colors = PackedColorArray([
		c_top, c_top, c_top,
		c_bot, c_bot, c_bot,
	])
	return poly


## Verteilt Decorations deterministisch auf Grass-Tiles.
func _build_decorations(container: Node2D) -> void:
	if decoration_density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_size.x * 73 + grid_size.y * 191
	for y in grid_size.y:
		for x in grid_size.x:
			var tile := Vector2i(x, y)
			if is_path_tile(tile):
				continue
			if rng.randf() > decoration_density:
				continue
			var decor := _make_random_decor(rng, tile)
			if decor != null:
				container.add_child(decor)


## Erzeugt eine zufällige Decor (Blume oder Crystal) auf einem Tile.
func _make_random_decor(rng: RandomNumberGenerator, tile: Vector2i) -> Node2D:
	var node := Polygon2D.new()
	node.name = "Decor_%d_%d" % [tile.x, tile.y]
	node.position = tile_to_iso(tile)
	# Leichter Offset innerhalb des Diamond
	node.position += Vector2(
		rng.randf_range(-12.0, 12.0),
		rng.randf_range(-4.0, 4.0),
	)
	# Decor-Type wählen
	var t := rng.randf()
	if t < 0.30:
		_make_flower_polygon(node, Palette.FLOWER_RED)
	elif t < 0.55:
		_make_flower_polygon(node, Palette.FLOWER_YELLOW)
	elif t < 0.75:
		_make_flower_polygon(node, Palette.FLOWER_LILA)
	else:
		_make_crystal_polygon(node, Palette.CRYSTAL_GREEN)
	return node


## Setzt das Polygon-Shape auf eine kleine Blume (5-eckig).
func _make_flower_polygon(poly: Polygon2D, c: Color) -> void:
	var r: float = 3.0
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 5:
		var ang: float = TAU * float(i) / 5.0 - PI * 0.5
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	poly.polygon = pts
	poly.color = c


## Setzt das Polygon-Shape auf einen Crystal-Spike (hexagonal, schmal hoch).
func _make_crystal_polygon(poly: Polygon2D, c: Color) -> void:
	poly.polygon = PackedVector2Array([
		Vector2(0, -6),
		Vector2(3, -2),
		Vector2(3, 2),
		Vector2(0, 4),
		Vector2(-3, 2),
		Vector2(-3, -2),
	])
	poly.color = c


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
