extends "res://addons/gut/test.gd"
## IsoWorld-Tests (ADR 0031).

const ISO_WORLD_SCENE: PackedScene = preload("res://core/world/iso_world.tscn")


# ---------------------------------------------------------------------------
# Iso-Math (Pure-Function-Tests)
# ---------------------------------------------------------------------------

func test_tile_to_iso_origin_is_zero() -> void:
	assert_eq(IsoWorld.tile_to_iso(Vector2i(0, 0)), Vector2.ZERO)


func test_tile_to_iso_x_axis() -> void:
	# (1, 0) → (32, 16) bei TILE_SIZE 64×32
	var p := IsoWorld.tile_to_iso(Vector2i(1, 0))
	assert_almost_eq(p.x, 32.0, 0.001)
	assert_almost_eq(p.y, 16.0, 0.001)


func test_tile_to_iso_y_axis() -> void:
	# (0, 1) → (-32, 16)
	var p := IsoWorld.tile_to_iso(Vector2i(0, 1))
	assert_almost_eq(p.x, -32.0, 0.001)
	assert_almost_eq(p.y, 16.0, 0.001)


func test_tile_to_iso_diagonal() -> void:
	# (1, 1) → (0, 32)
	var p := IsoWorld.tile_to_iso(Vector2i(1, 1))
	assert_almost_eq(p.x, 0.0, 0.001)
	assert_almost_eq(p.y, 32.0, 0.001)


func test_iso_to_tile_inverse_of_tile_to_iso() -> void:
	# Roundtrip: tile → iso → tile
	for x in 5:
		for y in 5:
			var t := Vector2i(x, y)
			var iso := IsoWorld.tile_to_iso(t)
			var back := IsoWorld.iso_to_tile(iso)
			assert_eq(back, t,
				"Roundtrip muss identity sein für %s" % t)


func test_iso_to_tile_origin() -> void:
	assert_eq(IsoWorld.iso_to_tile(Vector2.ZERO), Vector2i(0, 0))


# ---------------------------------------------------------------------------
# IsoWorld-Instanz: Tile-Generation
# ---------------------------------------------------------------------------

func test_iso_world_creates_grid_size_tiles() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(4, 4)
	add_child(world)
	var tiles_root := world.get_node_or_null("Tiles")
	assert_not_null(tiles_root)
	# 4×4 = 16 Polygon2D-Children
	assert_eq(tiles_root.get_child_count(), 16)
	world.queue_free()


func test_iso_world_default_grid_is_8x8() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	add_child(world)
	var tiles_root := world.get_node_or_null("Tiles")
	assert_not_null(tiles_root)
	assert_eq(tiles_root.get_child_count(), 64)
	world.queue_free()


func test_iso_world_tiles_are_polygon2d() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(2, 2)
	add_child(world)
	var tiles_root := world.get_node_or_null("Tiles")
	for tile in tiles_root.get_children():
		assert_true(tile is Polygon2D, "Tile soll Polygon2D sein, ist %s" % tile.get_class())
	world.queue_free()


# ---------------------------------------------------------------------------
# Path-Logik
# ---------------------------------------------------------------------------

func test_is_path_tile_on_path_row() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.path_row = 4
	world.path_col = 4
	add_child(world)
	assert_true(world.is_path_tile(Vector2i(0, 4)),
		"y=4 ist Path-Row, also Path-Tile")
	assert_true(world.is_path_tile(Vector2i(7, 4)))
	world.queue_free()


func test_is_path_tile_on_path_col() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.path_row = 4
	world.path_col = 4
	add_child(world)
	assert_true(world.is_path_tile(Vector2i(4, 0)))
	assert_true(world.is_path_tile(Vector2i(4, 7)))
	world.queue_free()


func test_is_path_tile_off_path() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.path_row = 4
	world.path_col = 4
	add_child(world)
	assert_false(world.is_path_tile(Vector2i(0, 0)))
	assert_false(world.is_path_tile(Vector2i(2, 3)))
	world.queue_free()


func test_path_tiles_use_dirt_color() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(8, 8)
	world.path_row = 4
	world.path_col = 4
	world.deterministic_colors = true
	add_child(world)
	var tile_node := world.get_node_or_null("Tiles/Tile_0_4") as Polygon2D
	assert_not_null(tile_node)
	assert_eq(tile_node.color, Palette.DIRT_PATH,
		"Tile auf Path-Row sollte DIRT_PATH-Farbe tragen")
	world.queue_free()


func test_grass_tiles_use_one_of_three_grass_shades() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(8, 8)
	world.path_row = 4
	world.path_col = 4
	world.deterministic_colors = true
	add_child(world)
	var grass_tile := world.get_node_or_null("Tiles/Tile_0_0") as Polygon2D
	assert_not_null(grass_tile)
	var c := grass_tile.color
	var ok := (c == Palette.GRASS_LIGHT or c == Palette.GRASS_MID or c == Palette.GRASS_DARK)
	assert_true(ok, "Grass-Tile muss eine der drei Grass-Color-Konstanten haben")
	world.queue_free()


# ---------------------------------------------------------------------------
# world_size
# ---------------------------------------------------------------------------

func test_world_size_for_8x8_grid() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)
	var size := world.world_size()
	# (8+8-1) * 64/2 = 15 * 32 = 480
	# (8+8-1) * 32/2 = 15 * 16 = 240
	assert_almost_eq(size.x, 480.0, 0.1)
	assert_almost_eq(size.y, 240.0, 0.1)
	world.queue_free()


func test_world_size_zero_for_empty_grid() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(0, 0)
	add_child(world)
	assert_eq(world.world_size(), Vector2.ZERO)
	world.queue_free()


# ---------------------------------------------------------------------------
# world_bounds (ADR 0033)
# ---------------------------------------------------------------------------

func test_world_bounds_for_empty_grid_is_zero_rect() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(0, 0)
	add_child(world)
	var b := world.world_bounds()
	assert_eq(b.size, Vector2.ZERO)
	world.queue_free()


func test_world_bounds_for_1x1_grid() -> void:
	# Ein einzelner Tile bei (0,0): pivot bei (0,0), Diamond ragt
	# ±32 in X und ±16 in Y.
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(1, 1)
	add_child(world)
	var b := world.world_bounds()
	assert_almost_eq(b.position.x, -32.0, 0.1)
	assert_almost_eq(b.position.y, -16.0, 0.1)
	assert_almost_eq(b.size.x, 64.0, 0.1)
	assert_almost_eq(b.size.y, 32.0, 0.1)
	world.queue_free()


func test_world_bounds_for_8x8_grid() -> void:
	# 8×8 Grid:
	# linkester Tile-Pivot: (0, 7) → x = -7*32 = -224, minus 32 (Diamond) = -256
	# rechtester Tile-Pivot: (7, 0) → x = +7*32 = +224, plus 32 = +256
	# oberster Tile-Pivot: (0, 0) → y = 0, minus 16 (Diamond) = -16
	# unterster Tile-Pivot: (7, 7) → y = (7+7)*16 = 224, plus 16 = +240
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)
	var b := world.world_bounds()
	assert_almost_eq(b.position.x, -256.0, 0.1)
	assert_almost_eq(b.position.y, -16.0, 0.1)
	assert_almost_eq(b.size.x, 512.0, 0.1)
	assert_almost_eq(b.size.y, 256.0, 0.1)
	world.queue_free()


# ---------------------------------------------------------------------------
# set_map_def (ADR 0036)
# ---------------------------------------------------------------------------

func test_set_map_def_applies_grid_size() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	add_child(world)
	var def := MapDef.new()
	def.id = &"test_map_5x5"
	def.display_name_key = &"x.y"
	def.grid_size = Vector2i(5, 5)
	def.path_row = 2
	def.path_col = 2
	def.deterministic_colors = true

	world.set_map_def(def)
	assert_eq(world.grid_size, Vector2i(5, 5))
	assert_eq(world.path_row, 2)
	assert_eq(world.path_col, 2)
	# 5×5 = 25 Tiles im neuen Grid
	var tiles_root := world.get_node_or_null("Tiles")
	assert_eq(tiles_root.get_child_count(), 25)
	world.queue_free()


func test_set_map_def_with_null_is_noop() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	add_child(world)
	world.grid_size = Vector2i(8, 8)
	world.set_map_def(null)
	assert_eq(world.grid_size, Vector2i(8, 8),
		"null-MapDef darf grid_size nicht ändern")
	world.queue_free()


func test_get_map_def_returns_last_set() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	add_child(world)
	var def := MapDef.new()
	def.id = &"test_map_get"
	def.display_name_key = &"x.y"
	def.grid_size = Vector2i(3, 3)

	world.set_map_def(def)
	assert_eq(world.get_map_def(), def)
	world.queue_free()


func test_get_map_def_returns_null_initially() -> void:
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	add_child(world)
	assert_null(world.get_map_def())
	world.queue_free()


func test_world_bounds_contains_all_tile_pivots() -> void:
	# Sanity: jeder Tile-Pivot muss innerhalb des bounds-Rect liegen
	var world: IsoWorld = ISO_WORLD_SCENE.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)
	var b := world.world_bounds()
	for x in 8:
		for y in 8:
			var p := IsoWorld.tile_to_iso(Vector2i(x, y))
			assert_true(b.has_point(p),
				"Tile-Pivot %s muss in bounds-Rect %s liegen" % [p, b])
	world.queue_free()
