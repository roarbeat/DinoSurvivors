class_name Palette
extends RefCounted
## Single-Source-of-Truth-Palette (ADR 0031).
##
## Color-Konstanten aus docs/art/VISUAL-TARGET.md. EnemyDef/BossDef/HUD/
## IsoWorld lesen ihre Default-Farben hier ab. Mods können eigene Werte
## in ihren .tres-Files setzen — die Palette ist nur Fallback.
##
## Pure-Constants-Klasse, kein Instance-State. Aufruf via Klassen-Name:
##   var c: Color = Palette.GRASS_MID

# ---------------------------------------------------------------------------
# Background / World
# ---------------------------------------------------------------------------

## Spielfläche-Hintergrund (außerhalb der Plattform)
const BG_CHARCOAL: Color = Color("#3a3d40")

# ---------------------------------------------------------------------------
# Grass-Tiles (3 Schattierungen für Tile-Variation)
# ---------------------------------------------------------------------------

const GRASS_LIGHT: Color = Color("#7ec850")
const GRASS_MID:   Color = Color("#5fa83a")
const GRASS_DARK:  Color = Color("#3e8528")
## Tile-Edge oben (dunkler Grün-Saum am Diamond-Rim)
const GRASS_EDGE:  Color = Color("#2c5e1c")

# ---------------------------------------------------------------------------
# Dirt-Path + Plattform-Sides
# ---------------------------------------------------------------------------

const DIRT_PATH:        Color = Color("#a87455")
const DIRT_SIDE_TOP:    Color = Color("#8a5a3a")
const DIRT_SIDE_BOTTOM: Color = Color("#5e3e28")

# ---------------------------------------------------------------------------
# Player + Accent
# ---------------------------------------------------------------------------

const PLAYER_BODY:   Color = Color("#5fa83a")  # gleichmäßiges Grün (matcht Grass-Mid)
const PLAYER_ACCENT: Color = Color("#2c5e1c")  # dunkelgrüner Rücken-Akzent

# ---------------------------------------------------------------------------
# Pickups
# ---------------------------------------------------------------------------

const COIN_GOLD:      Color = Color("#d6a64f")
const COIN_HIGHLIGHT: Color = Color("#f0c878")
const CRYSTAL_GREEN:  Color = Color("#3acf6e")

# ---------------------------------------------------------------------------
# Decorations (Blumen etc.)
# ---------------------------------------------------------------------------

const FLOWER_RED:    Color = Color("#c84e44")
const FLOWER_YELLOW: Color = Color("#e8c84a")
const FLOWER_LILA:   Color = Color("#a86ed4")


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

## Liefert eine zufällige Grass-Variation (light/mid/dark) — wird vom
## IsoWorld genutzt, um Tiles visuell zu unterscheiden.
static func random_grass(rng: RandomNumberGenerator = null) -> Color:
	var r: float
	if rng != null:
		r = rng.randf()
	else:
		r = randf()
	if r < 0.33:
		return GRASS_LIGHT
	if r < 0.66:
		return GRASS_MID
	return GRASS_DARK
