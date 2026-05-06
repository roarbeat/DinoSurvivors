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
