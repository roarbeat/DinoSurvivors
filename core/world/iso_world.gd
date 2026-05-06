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
