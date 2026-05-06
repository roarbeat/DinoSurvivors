extends "res://addons/gut/test.gd"
## Palette-Tests (ADR 0031).

# ---------------------------------------------------------------------------
# Color-Konstanten existieren
# ---------------------------------------------------------------------------

func test_bg_charcoal_constant() -> void:
	assert_eq(Palette.BG_CHARCOAL, Color("#3a3d40"))


func test_grass_constants_distinct() -> void:
	# Drei Grass-Schattierungen müssen unterschiedlich sein
	assert_ne(Palette.GRASS_LIGHT, Palette.GRASS_MID)
	assert_ne(Palette.GRASS_MID, Palette.GRASS_DARK)
	assert_ne(Palette.GRASS_LIGHT, Palette.GRASS_DARK)


func test_grass_light_lighter_than_dark() -> void:
	# Lightness-Sanity: light.v > mid.v > dark.v
	assert_gt(Palette.GRASS_LIGHT.v, Palette.GRASS_MID.v)
	assert_gt(Palette.GRASS_MID.v, Palette.GRASS_DARK.v)


func test_dirt_constants_distinct() -> void:
	assert_ne(Palette.DIRT_PATH, Palette.DIRT_SIDE_TOP)
	assert_ne(Palette.DIRT_SIDE_TOP, Palette.DIRT_SIDE_BOTTOM)


func test_player_body_matches_grass_mid() -> void:
	# Camo-Vibe aus VISUAL-TARGET.md: Player-Body matcht Grass-Mid
	assert_eq(Palette.PLAYER_BODY, Palette.GRASS_MID)


func test_pickup_colors_distinct_from_grass() -> void:
	# Coin und Crystal müssen sich vom Grass-Background abheben
	assert_ne(Palette.COIN_GOLD, Palette.GRASS_MID)
	assert_ne(Palette.CRYSTAL_GREEN, Palette.GRASS_MID)


# ---------------------------------------------------------------------------
# random_grass-Helper
# ---------------------------------------------------------------------------

func test_random_grass_returns_valid_color() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var c := Palette.random_grass(rng)
	# Muss eine der drei Grass-Konstanten sein
	var is_known := (c == Palette.GRASS_LIGHT or c == Palette.GRASS_MID or c == Palette.GRASS_DARK)
	assert_true(is_known)


func test_random_grass_is_deterministic_with_seeded_rng() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 100
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 100
	# Mit gleichem Seed muss random_grass die gleiche Color liefern
	assert_eq(Palette.random_grass(rng_a), Palette.random_grass(rng_b))


func test_random_grass_covers_all_variants_over_many_calls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := { Palette.GRASS_LIGHT: 0, Palette.GRASS_MID: 0, Palette.GRASS_DARK: 0 }
	for i in 50:
		var c := Palette.random_grass(rng)
		seen[c] = seen[c] + 1
	# Über 50 Calls sollte jede Variante mindestens einmal auftauchen
	assert_gt(seen[Palette.GRASS_LIGHT], 0)
	assert_gt(seen[Palette.GRASS_MID], 0)
	assert_gt(seen[Palette.GRASS_DARK], 0)
