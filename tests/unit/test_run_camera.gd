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

# ---------------------------------------------------------------------------
# attach_to_world (ADR 0033)
# ---------------------------------------------------------------------------

const ISO_WORLD_SCENE_FOR_CAMERA: PackedScene = preload("res://core/world/iso_world.tscn")


func test_attach_to_world_sets_bounds_from_iso_world() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var world: IsoWorld = ISO_WORLD_SCENE_FOR_CAMERA.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)

	cam.attach_to_world(world)
	# 8×8 Grid → bounds (-256, -16) bis (256, 240)
	assert_true(cam.enable_limits)
	assert_almost_eq(cam.bound_min.x, -256.0, 0.1)
	assert_almost_eq(cam.bound_min.y, -16.0, 0.1)
	assert_almost_eq(cam.bound_max.x, 256.0, 0.1)
	assert_almost_eq(cam.bound_max.y, 240.0, 0.1)

	cam.queue_free()
	world.queue_free()


func test_attach_to_world_with_null_is_noop() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.enable_limits = false
	cam.attach_to_world(null)
	assert_false(cam.enable_limits, "null-world soll bounds nicht verändern")
	cam.queue_free()


func test_compute_padded_bounds_pure() -> void:
	# Pure-Function-Test (ADR 0037)
	var world := Rect2(Vector2(-100, -50), Vector2(200, 100))
	var padded := RunCamera.compute_padded_bounds(world, Vector2(20, 10))
	assert_eq(padded.position, Vector2(-120, -60))
	assert_eq(padded.size, Vector2(240, 120))


func test_compute_padded_bounds_zero_padding_unchanged() -> void:
	var world := Rect2(Vector2(0, 0), Vector2(64, 32))
	var padded := RunCamera.compute_padded_bounds(world, Vector2.ZERO)
	assert_eq(padded.position, world.position)
	assert_eq(padded.size, world.size)


func test_attach_to_world_with_padding_extends_bounds() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var world: IsoWorld = ISO_WORLD_SCENE_FOR_CAMERA.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)

	# 8×8 Grid: bounds (-256, -16) bis (256, 240)
	# Mit padding (50, 30) → bounds (-306, -46) bis (306, 270)
	cam.attach_to_world(world, Vector2(50, 30))
	assert_almost_eq(cam.bound_min.x, -306.0, 0.1)
	assert_almost_eq(cam.bound_min.y, -46.0, 0.1)
	assert_almost_eq(cam.bound_max.x, 306.0, 0.1)
	assert_almost_eq(cam.bound_max.y, 270.0, 0.1)
	assert_eq(cam.bounds_padding, Vector2(50, 30))

	cam.queue_free()
	world.queue_free()


func test_set_bounds_padding_reapplies_to_existing_bounds() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	var world: IsoWorld = ISO_WORLD_SCENE_FOR_CAMERA.instantiate()
	world.grid_size = Vector2i(8, 8)
	add_child(world)
	cam.attach_to_world(world)  # ohne Padding zuerst
	assert_almost_eq(cam.bound_min.x, -256.0, 0.1)

	# Jetzt Padding nachträglich setzen → Bounds re-applied
	cam.set_bounds_padding(Vector2(20, 10))
	assert_almost_eq(cam.bound_min.x, -276.0, 0.1)
	assert_almost_eq(cam.bound_max.x, 276.0, 0.1)

	cam.queue_free()
	world.queue_free()


func test_set_bounds_padding_clamps_negative_to_zero() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.set_bounds_padding(Vector2(-10, -5))
	assert_eq(cam.bounds_padding, Vector2.ZERO)
	cam.queue_free()


func test_attach_to_world_with_empty_grid_is_noop() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.enable_limits = false
	var world: IsoWorld = ISO_WORLD_SCENE_FOR_CAMERA.instantiate()
	world.grid_size = Vector2i(0, 0)
	add_child(world)

	cam.attach_to_world(world)
	assert_false(cam.enable_limits,
		"Leeres Grid → keine Bounds gesetzt")

	cam.queue_free()
	world.queue_free()


# ---------------------------------------------------------------------------
# Camera-Shake (ADR 0035)
# ---------------------------------------------------------------------------

func test_default_trauma_is_zero() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	assert_eq(cam.trauma, 0.0)
	cam.queue_free()


func test_add_trauma_increases_trauma() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.add_trauma(0.5)
	assert_almost_eq(cam.trauma, 0.5, 0.001)
	cam.queue_free()


func test_add_trauma_clamps_at_one() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.add_trauma(0.6)
	cam.add_trauma(0.6)
	assert_almost_eq(cam.trauma, 1.0, 0.001,
		"Trauma muss bei 1.0 clamped sein")
	cam.queue_free()


func test_add_trauma_when_muted_is_noop() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	cam.shake_muted = true
	cam.add_trauma(0.5)
	assert_eq(cam.trauma, 0.0)
	cam.queue_free()


func test_compute_trauma_after_decay_reduces() -> void:
	# trauma=1.0, decay=2.0/s, delta=0.5 → 1.0 - 2.0*0.5 = 0.0
	var t := RunCamera.compute_trauma_after_decay(1.0, 2.0, 0.5)
	assert_almost_eq(t, 0.0, 0.001)


func test_compute_trauma_after_decay_clamps_at_zero() -> void:
	# Mit großem delta soll Trauma nicht negativ werden
	var t := RunCamera.compute_trauma_after_decay(0.3, 2.0, 1.0)
	assert_eq(t, 0.0)


func test_compute_trauma_after_decay_no_time() -> void:
	# delta=0 → kein Decay
	var t := RunCamera.compute_trauma_after_decay(0.5, 1.5, 0.0)
	assert_almost_eq(t, 0.5, 0.001)


# ---------------------------------------------------------------------------
# Shake-Offset
# ---------------------------------------------------------------------------

func test_shake_offset_zero_for_zero_trauma() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var off := RunCamera.compute_shake_offset(0.0, 8.0, rng)
	assert_eq(off, Vector2.ZERO)


func test_shake_offset_within_max_for_full_trauma() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var off := RunCamera.compute_shake_offset(1.0, 8.0, rng)
	# Trauma² × max_offset = 1.0 × 8.0 = 8.0 als max betrag pro Achse
	assert_lte(absf(off.x), 8.0, "Shake-X muss in [-max, max] liegen")
	assert_lte(absf(off.y), 8.0)


func test_shake_offset_smaller_for_low_trauma() -> void:
	# trauma=0.3 → trauma²=0.09 → max betrag = 8.0 × 0.09 = 0.72
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var off := RunCamera.compute_shake_offset(0.3, 8.0, rng)
	assert_lte(absf(off.x), 0.73)


func test_shake_offset_deterministic_with_seeded_rng() -> void:
	# Gleicher RNG-Seed → gleicher Offset
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 100
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 100
	var off_a := RunCamera.compute_shake_offset(0.7, 8.0, rng_a)
	var off_b := RunCamera.compute_shake_offset(0.7, 8.0, rng_b)
	assert_eq(off_a, off_b)


# ---------------------------------------------------------------------------
# EventBus-Hooks
# ---------------------------------------------------------------------------

func test_player_damaged_signal_adds_trauma() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	# Default trauma_on_player_damaged = 0.3
	EventBus.player_damaged.emit(10.0, &"raptor_grunt")
	assert_almost_eq(cam.trauma, 0.3, 0.001)
	cam.queue_free()


func test_boss_defeated_signal_adds_trauma() -> void:
	var cam: RunCamera = RUN_CAMERA_SCENE.instantiate()
	add_child(cam)
	# Default trauma_on_boss_defeated = 0.7
	EventBus.boss_defeated.emit(&"tyrannosaurus_prime", 60.0)
	assert_almost_eq(cam.trauma, 0.7, 0.001)
	cam.queue_free()


# ---------------------------------------------------------------------------
# Crash-Protection
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
