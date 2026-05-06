extends "res://addons/gut/test.gd"
## RunCamera-Tests (ADR 0032).

const RUN_CAMERA_SCENE: PackedScene = preload("res://core/world/run_camera.tscn")


# ---------------------------------------------------------------------------
# Pure-Function compute_next_position
# ---------------------------------------------------------------------------

func test_zero_smoothing_snaps_to_target() -> void:
	var p := RunCamera.compute_next_position(
		Vector2(0, 0), Vector2(100, 50), 0.0, 0.016, false)
	assert_eq(p, Vector2(100, 50))


func test_zero_delta_snaps_to_target() -> void:
	# delta=0 → no time elapsed → fallback to target
	var p := RunCamera.compute_next_position(
		Vector2(0, 0), Vector2(100, 50), 5.0, 0.0, false)
	assert_eq(p, Vector2(100, 50))


func test_smoothing_lerp_moves_partially() -> void:
	# Mit smoothing=5, delta=0.1: alpha = 1 - exp(-0.5) ≈ 0.393
	# Camera startet bei (0,0), target bei (100, 0)
	# new ≈ lerp(0, 100, 0.393) ≈ 39.3 → snap auf 39
	var p := RunCamera.compute_next_position(
		Vector2(0, 0), Vector2(100, 0), 5.0, 0.1, true)
	# Approximation, +/- 2 Pixel Toleranz für round-Effekt
	assert_between(p.x, 35.0, 45.0)
	assert_eq(p.y, 0.0)


func test_pixel_snap_rounds_to_int() -> void:
	# Mit pixel_snap=true sollte das Ergebnis ganzzahlig sein
	var p := RunCamera.compute_next_position(
		Vector2(0, 0), Vector2(100.7, 50.3), 0.0, 0.016, true)
	assert_eq(p.x, round(p.x))
	assert_eq(p.y, round(p.y))


func test_pixel_snap_disabled_keeps_float() -> void:
	# Ohne pixel_snap kann Position float sein
	var p := RunCamera.compute_next_position(
		Vector2(0, 0), Vector2(50.0, 25.5), 5.0, 0.05, false)
	# Erwarte float, also nicht zwingend gleich round(p)
	# (Mit smoothing>0 und float target bleibt es float)
	assert_almost_eq(p.y, 25.5 * (1.0 - exp(-5.0 * 0.05)), 0.01)


func test_smoothing_converges_over_many_frames() -> void:
	# Über 60 Frames bei 60Hz mit smoothing=5 sollte Camera ~95% am Target sein
	var current := Vector2(0, 0)
	var target_pos := Vector2(1000, 0)
	for i in 60:
		current = RunCamera.compute_next_position(
			current, target_pos, 5.0, 1.0 / 60.0, false)
	assert_gt(current.x, 990.0,
		"Nach 60 Frames sollte Camera-X > 990 sein (sehr nah an target=1000)")


# ---------------------------------------------------------------------------
# RunCamera-Instance
# ---------------------------------------------------------------------------

func test_camera_starts_with_no_target() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	assert_null(cam.target)
	cam.queue_free()


func test_set_target_assigns_target() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var dummy := Node2D.new()
	add_child(dummy)
	dummy.global_position = Vector2(123, 456)

	cam.set_target(dummy)
	assert_eq(cam.target, dummy)

	cam.queue_free()
	dummy.queue_free()


func test_snap_to_target_moves_camera_immediately() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var dummy := Node2D.new()
	add_child(dummy)
	dummy.global_position = Vector2(200, 100)

	cam.set_target(dummy)
	cam.snap_to_target()
	assert_eq(cam.global_position, Vector2(200, 100))

	cam.queue_free()
	dummy.queue_free()


func test_snap_to_target_with_pixel_snap_rounds() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	cam.pixel_snap = true
	add_child(cam)
	var dummy := Node2D.new()
	add_child(dummy)
	dummy.global_position = Vector2(200.7, 100.3)

	cam.set_target(dummy)
	cam.snap_to_target()
	# pixel_snap=true → round
	assert_eq(cam.global_position, Vector2(201, 100))

	cam.queue_free()
	dummy.queue_free()


func test_snap_to_target_without_target_is_noop() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.global_position = Vector2(50, 50)
	cam.snap_to_target()  # target=null → no-op
	assert_eq(cam.global_position, Vector2(50, 50))
	cam.queue_free()


# ---------------------------------------------------------------------------
# set_follow_smoothing
# ---------------------------------------------------------------------------

func test_set_follow_smoothing_clamps_negative_to_zero() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.set_follow_smoothing(-5.0)
	assert_eq(cam.follow_smoothing, 0.0)
	cam.queue_free()


func test_set_follow_smoothing_accepts_positive() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.set_follow_smoothing(10.0)
	assert_eq(cam.follow_smoothing, 10.0)
	cam.queue_free()


# ---------------------------------------------------------------------------
# set_bounds
# ---------------------------------------------------------------------------

func test_set_bounds_enables_limits() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.set_bounds(Vector2(-500, -500), Vector2(500, 500))
	assert_true(cam.enable_limits)
	assert_eq(cam.bound_min, Vector2(-500, -500))
	assert_eq(cam.bound_max, Vector2(500, 500))
	cam.queue_free()


func test_set_bounds_swaps_inverted_min_max() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	# Inverted: max in min-Slot, min in max-Slot
	cam.set_bounds(Vector2(500, 500), Vector2(-500, -500))
	assert_eq(cam.bound_min, Vector2(-500, -500))
	assert_eq(cam.bound_max, Vector2(500, 500))
	cam.queue_free()


func test_set_bounds_writes_camera2d_limits() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.set_bounds(Vector2(-200, -100), Vector2(300, 400))
	assert_eq(cam.limit_left, -200)
	assert_eq(cam.limit_top, -100)
	assert_eq(cam.limit_right, 300)
	assert_eq(cam.limit_bottom, 400)
	cam.queue_free()


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_default_smoothing_is_5() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	assert_almost_eq(cam.follow_smoothing, 5.0, 0.001)
	cam.queue_free()


func test_default_pixel_snap_enabled() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	assert_true(cam.pixel_snap)
	cam.queue_free()


func test_default_zoom_is_2x() -> void:
	# Pixel-Art-Konvention: 2× Zoom für 540×270 logische Pixel
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	assert_eq(cam.zoom, Vector2(2, 2))
	cam.queue_free()


# ---------------------------------------------------------------------------
# Crash-Protection: Camera mit freigegebenem Target
# ---------------------------------------------------------------------------

func test_camera_does_not_crash_when_target_freed() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var dummy := Node2D.new()
	add_child(dummy)
	cam.set_target(dummy)

	# Target freen
	dummy.queue_free()
	await get_tree().process_frame  # warten bis free durch ist

	# _process sollte sicher durchlaufen ohne Crash
	cam._process(0.016)
	pass_test("Camera überlebt freed target")

	cam.queue_free()
