class_name RunCamera
extends Camera2D
## Run-Camera (ADR 0032).
##
## Folgt einem Target-Node2D mit Smooth-Lerp. Pixel-Snap für Pixel-Art-
## Crispness. Optionale World-Bounds.
##
## Public-API:
##   set_target(node)              — Target wechseln
##   set_follow_smoothing(value)   — Lerp-Geschwindigkeit
##   set_bounds(min_pos, max_pos)  — Camera-Limits
##
## Pure Function (für Tests):
##   compute_next_position(current, target, smoothing, delta, pixel_snap)
##   → testbar ohne Frame-Dispatch.

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Target-Node, dem die Camera folgt. null = Camera bleibt stehen.
@export var target: Node2D

## Lerp-Geschwindigkeit. 0.0 = harter Snap, 5.0 = smooth Survivor-likes
## Standard, höher = schnellerer Catch-up.
@export var follow_smoothing: float = 5.0

## Pixel-Snap: Camera-Position rundet auf ganze Pixel (Pixel-Art-Style).
## Bei false: smooth, kann zwischen Pixeln liegen → Sub-Pixel-Wackeln.
@export var pixel_snap: bool = true

## World-Bounds aktivieren? Wenn true werden die Camera2D.limit_*-Werte
## aus bound_min/bound_max gesetzt. Bei false: Camera kann frei laufen.
@export var enable_limits: bool = false

## Bounds-Konfiguration (nur wirksam wenn enable_limits=true).
@export var bound_min: Vector2 = Vector2(-1000, -1000)
@export var bound_max: Vector2 = Vector2(1000, 1000)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Camera2D-Built-in-Smoothing deaktivieren — wir machen es selbst,
	# damit pixel_snap und compute_next_position-Test-Hook konsistent sind.
	position_smoothing_enabled = false

	if enable_limits:
		_apply_limits()

	make_current()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = compute_next_position(
		global_position,
		target.global_position,
		follow_smoothing,
		delta,
		pixel_snap,
	)
	if enable_limits:
		_clamp_position_to_bounds()


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Setzt das Target. null = Camera bleibt am aktuellen Spot stehen.
## Bei nicht-null Target wird die Camera-Position NICHT sofort gesnapt
## — das passiert erst über _process-Lerp. Wer ein Hard-Snap will,
## ruft `snap_to_target()` separat auf.
func set_target(t: Node2D) -> void:
	target = t


## Hard-Snap an die aktuelle Target-Position. Nützlich nach
## set_target wenn man kein "fly-in" will.
func snap_to_target() -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = target.global_position
	if pixel_snap:
		global_position = Vector2(round(global_position.x), round(global_position.y))


func set_follow_smoothing(value: float) -> void:
	follow_smoothing = max(0.0, value)


## Setzt die Bounds. Wenn min > max in einer Achse, wird automatisch
## getauscht. enable_limits wird auf true gesetzt.
func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	# Auto-Sort
	if min_pos.x > max_pos.x:
		var tmp := min_pos.x
		min_pos.x = max_pos.x
		max_pos.x = tmp
	if min_pos.y > max_pos.y:
		var tmp_y := min_pos.y
		min_pos.y = max_pos.y
		max_pos.y = tmp_y
	bound_min = min_pos
	bound_max = max_pos
	enable_limits = true
	_apply_limits()


# ---------------------------------------------------------------------------
# Pure Function (Test-Hook)
# ---------------------------------------------------------------------------

## Berechnet die nächste Camera-Position basierend auf Smooth-Lerp.
## Pure function — testbar ohne Frame-Dispatch.
##
## Frame-Rate-Independence-Formel:
##   alpha = 1 - exp(-smoothing * delta)
##   new = lerp(current, target, alpha)
##
## smoothing=0.0 → harter Snap auf target.
static func compute_next_position(
	current: Vector2,
	target_pos: Vector2,
	smoothing: float,
	delta: float,
	pixel_snap_enabled: bool = true,
) -> Vector2:
	var result: Vector2
	if smoothing <= 0.0 or delta <= 0.0:
		result = target_pos
	else:
		var alpha: float = 1.0 - exp(-smoothing * delta)
		result = current.lerp(target_pos, alpha)
	if pixel_snap_enabled:
		result = Vector2(round(result.x), round(result.y))
	return result


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _apply_limits() -> void:
	limit_left = int(bound_min.x)
	limit_top = int(bound_min.y)
	limit_right = int(bound_max.x)
	limit_bottom = int(bound_max.y)


func _clamp_position_to_bounds() -> void:
	global_position.x = clamp(global_position.x, bound_min.x, bound_max.x)
	global_position.y = clamp(global_position.y, bound_min.y, bound_max.y)
