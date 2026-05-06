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

## Bounds-Padding (ADR 0037). Erweitert die Bounds nach außen, sodass
## Camera Breathing-Room um die Plattform zeigen kann. Default Zero =
## ADR 0033-Verhalten (Camera klemmt strikt am Plattform-Rand).
@export var bounds_padding: Vector2 = Vector2.ZERO

## Internes Last-World-Bounds-Caching für set_bounds_padding-Re-Apply.
var _last_world_bounds: Rect2 = Rect2()


# ---------------------------------------------------------------------------
# Camera-Shake (Trauma-System, ADR 0035)
# ---------------------------------------------------------------------------

## Maximaler Shake-Offset in Pixel bei trauma=1.0.
@export var max_shake_offset: float = 8.0

## Trauma-Decay-Geschwindigkeit. 1.5 = von 1.0 auf 0.0 in ~0.67s.
@export var trauma_decay_per_second: float = 1.5

## Trauma-Wert bei EventBus.player_damaged.
@export var trauma_on_player_damaged: float = 0.3

## Trauma-Wert bei EventBus.boss_defeated.
@export var trauma_on_boss_defeated: float = 0.7

## Shake-Mute (Test-Hook). Wenn true, ignoriert add_trauma().
@export var shake_muted: bool = false

## Aktueller Trauma-Wert (0.0 – 1.0). Public-Read für Tests/Debug-UI.
var trauma: float = 0.0

var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Camera2D-Built-in-Smoothing deaktivieren — wir machen es selbst,
	# damit pixel_snap und compute_next_position-Test-Hook konsistent sind.
	position_smoothing_enabled = false

	if enable_limits:
		_apply_limits()

	# RNG für Shake-Noise initialisieren (deterministische Tests können
	# _shake_rng.seed = N setzen).
	_shake_rng.randomize()

	# EventBus-Hooks für Camera-Shake (ADR 0035)
	if get_node_or_null("/root/EventBus") != null:
		EventBus.player_damaged.connect(_on_player_damaged)
		EventBus.boss_defeated.connect(_on_boss_defeated)

	make_current()


func _process(delta: float) -> void:
	# Follow-Logic
	if target != null and is_instance_valid(target):
		global_position = compute_next_position(
			global_position,
			target.global_position,
			follow_smoothing,
			delta,
			pixel_snap,
		)
		if enable_limits:
			_clamp_position_to_bounds()

	# Trauma-Decay (ADR 0035) — pro Sekunde, nicht pro Frame
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay_per_second * delta)
	# Shake-Offset additiv auf Camera2D.offset, damit follow-Position
	# unverändert bleibt
	offset = compute_shake_offset(trauma, max_shake_offset, _shake_rng)


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


## Bindet die Camera an die Bounds einer IsoWorld (ADR 0033/0037).
## Liest `IsoWorld.world_bounds()` und ruft set_bounds() entsprechend.
## Padding (ADR 0037) erweitert die Bounds nach außen — wenn nicht
## angegeben, wird das aktuelle bounds_padding-Property genutzt.
##
## No-op wenn world null ist oder leeres Rect liefert.
func attach_to_world(world: IsoWorld, padding: Vector2 = Vector2(-1, -1)) -> void:
	if world == null:
		return
	var b: Rect2 = world.world_bounds()
	if b.size == Vector2.ZERO:
		return
	# Padding-Override-Sentinel: (-1, -1) heißt "nutze aktuelles bounds_padding"
	if padding.x >= 0.0 and padding.y >= 0.0:
		bounds_padding = padding
	_last_world_bounds = b
	_apply_bounds_with_padding(b, bounds_padding)


## Setzt das Padding zur Laufzeit. Wenn die Camera bereits an eine World
## gehängt ist, werden die Bounds sofort neu berechnet.
func set_bounds_padding(p: Vector2) -> void:
	bounds_padding = Vector2(max(0.0, p.x), max(0.0, p.y))
	if _last_world_bounds.size != Vector2.ZERO:
		_apply_bounds_with_padding(_last_world_bounds, bounds_padding)


## Pure Function: erweitert ein World-Rect um das Padding.
## Result-Rect.position = world.position - padding.
## Result-Rect.size     = world.size + padding * 2.
static func compute_padded_bounds(world_rect: Rect2, padding: Vector2) -> Rect2:
	var pos: Vector2 = world_rect.position - padding
	var size: Vector2 = world_rect.size + padding * 2.0
	return Rect2(pos, size)


func _apply_bounds_with_padding(world_rect: Rect2, padding: Vector2) -> void:
	var padded: Rect2 = compute_padded_bounds(world_rect, padding)
	set_bounds(padded.position, padded.position + padded.size)


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

# ---------------------------------------------------------------------------
# Camera-Shake API (ADR 0035)
# ---------------------------------------------------------------------------

## Erhöht den Trauma-Wert um amount, geclamped auf [0, 1].
## No-op wenn shake_muted=true (Test-Hook).
func add_trauma(amount: float) -> void:
	if shake_muted:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Setzt den Trauma-Wert direkt. Für Test-Hooks.
func set_trauma(value: float) -> void:
	trauma = clampf(value, 0.0, 1.0)


## Pure Function: berechnet den Shake-Offset basierend auf Trauma².
## Squared-Curve gibt sanften Einstieg (kleines Trauma → wenig Shake)
## und starken Peak (großes Trauma → spürbarer Tremor).
##
## Test-Hook: RNG kann gesetzt werden, um deterministische Tests zu
## ermöglichen.
static func compute_shake_offset(
	current_trauma: float,
	max_offset: float,
	rng: RandomNumberGenerator,
) -> Vector2:
	if current_trauma <= 0.0:
		return Vector2.ZERO
	var t2: float = current_trauma * current_trauma
	var dx: float = (rng.randf() * 2.0 - 1.0) * max_offset * t2
	var dy: float = (rng.randf() * 2.0 - 1.0) * max_offset * t2
	return Vector2(dx, dy)


## Trauma-Decay-Helper als pure function (Test-Hook).
static func compute_trauma_after_decay(
	current_trauma: float,
	decay_per_second: float,
	delta: float,
) -> float:
	return max(0.0, current_trauma - decay_per_second * delta)


## EventBus-Handler — wird in _ready() verbunden.
func _on_player_damaged(_amount: float, _source_id: StringName) -> void:
	add_trauma(trauma_on_player_damaged)


func _on_boss_defeated(_boss_id: StringName, _run_time: float) -> void:
	add_trauma(trauma_on_boss_defeated)


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
