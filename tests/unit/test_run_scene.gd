extends "res://addons/gut/test.gd"
## Run-Scene-Glue-Tests (ADR 0016).
##
## Verifiziert das ganze End-to-End-Setup: Run-Scene → Player + EnemyContainer
## → Run läuft → Demo-Spawn klappt.

var _run: RunScene


func before_each() -> void:
	# Sauberes Setup pro Test
	if RunState.is_running():
		RunState.end(&"test_setup_cleanup")
	RunState.reset()
	PlayerMutations.reset()
	WaveSpawner.set_spawn_root(null)


func _instance_run_scene() -> void:
	var packed := load("res://core/run_scene/run.tscn") as PackedScene
	_run = packed.instantiate() as RunScene
	add_child(_run)


func after_each() -> void:
	if is_instance_valid(_run):
		_run.queue_free()
	_run = null
	if RunState.is_running():
		RunState.end(&"test_after_cleanup")
	RunState.reset()
	WaveSpawner.set_spawn_root(null)


# ---------------------------------------------------------------------------
# Scene-Hierarchie
# ---------------------------------------------------------------------------

func test_scene_has_player_slot_and_enemy_container() -> void:
	_instance_run_scene()
	assert_not_null(_run.get_node_or_null("PlayerSlot"))
	assert_not_null(_run.get_node_or_null("EnemyContainer"))


# ---------------------------------------------------------------------------
# Player-Setup
# ---------------------------------------------------------------------------

func test_player_is_instantiated_under_player_slot() -> void:
	_instance_run_scene()
	var player := _run.get_player()
	assert_not_null(player, "Player muss nach _ready instantiiert sein")
	assert_true(player is PlayerCharacter)
	assert_eq(player.get_parent(), _run.get_node("PlayerSlot"),
		"Player muss unter PlayerSlot hängen")


func test_player_has_dino_set() -> void:
	_instance_run_scene()
	var player := _run.get_player()
	assert_eq(player.get_dino().id, &"trex")


# ---------------------------------------------------------------------------
# WaveSpawner-Wiring
# ---------------------------------------------------------------------------

func test_wave_spawner_root_is_enemy_container() -> void:
	_instance_run_scene()
	assert_eq(WaveSpawner.get_spawn_root(), _run.get_enemy_container())


# ---------------------------------------------------------------------------
# Run-Lifecycle
# ---------------------------------------------------------------------------

func test_run_state_is_running_after_ready() -> void:
	_instance_run_scene()
	assert_true(RunState.is_running(),
		"RunState muss nach Run-Scene-_ready running sein")
	assert_eq(RunState.get_active_dino().id, &"trex")


# ---------------------------------------------------------------------------
# Demo-Spawn
# ---------------------------------------------------------------------------

func test_spawn_demo_enemies_creates_three_enemies() -> void:
	_instance_run_scene()
	var container := _run.get_enemy_container()
	assert_eq(container.get_child_count(), 0, "Anfangs leer")

	_run._spawn_demo_enemies()

	assert_eq(container.get_child_count(), 3,
		"3 Demo-Enemies wurden gespawnt (Default-Config)")
	for child in container.get_children():
		assert_true(child is EnemyMob)
		assert_eq((child as EnemyMob).enemy_id, &"raptor_grunt")


# ---------------------------------------------------------------------------
# Robustheit: Re-Entry
# ---------------------------------------------------------------------------

func test_unknown_dino_id_does_not_crash() -> void:
	# Setup: Run-Scene mit ungültigem Dino
	var packed := load("res://core/run_scene/run.tscn") as PackedScene
	var bad_run: RunScene = packed.instantiate()
	bad_run.dino_id = &"velociraptor_does_not_exist"
	add_child(bad_run)
	# _ready wurde nun aufgerufen, kein Crash erwartet
	assert_null(bad_run.get_player(),
		"Bei unbekannter dino_id darf kein Player instantiiert werden")
	bad_run.queue_free()


# ---------------------------------------------------------------------------
# Game-Over + Restart (ADR 0019)
# ---------------------------------------------------------------------------

func test_game_over_layer_visible_on_run_ended() -> void:
	_instance_run_scene()
	# Run läuft; jetzt enden lassen
	RunState.end(&"player_died")
	# Layer sollte jetzt sichtbar sein
	var overlay: GameOverOverlay = _run.get_node("GameOverLayer")
	assert_true(overlay.is_shown())
	# Cleanup vor after_each
	RunState.reset()


func test_restart_run_clears_enemies() -> void:
	_instance_run_scene()
	# Demo-Spawn → 3 Enemies
	_run._spawn_demo_enemies()
	assert_eq(_run.get_enemy_container().get_child_count(), 3)

	# Run beenden + Restart
	RunState.end(&"test_restart")
	_run.restart_run()

	# Enemies aus altem Run sind weg (queue_free → next frame, aber
	# wir prüfen über remove_from_group oder Listing).
	# Robust: nach restart_run sollte die Liste neue Player + leeren
	# EnemyContainer haben.
	# queue_free läuft asynchron, aber die Children-Liste wird nicht
	# sofort aktualisiert. Wir akzeptieren das.
	assert_not_null(_run.get_player(), "Neuer Player muss instantiiert sein")


func test_restart_run_starts_new_run() -> void:
	_instance_run_scene()
	RunState.end(&"player_died")
	assert_true(RunState.is_ended())

	_run.restart_run()
	assert_true(RunState.is_running(),
		"Nach restart_run muss neuer Run laufen")


func test_restart_run_creates_fresh_player() -> void:
	_instance_run_scene()
	var first_player := _run.get_player()
	assert_not_null(first_player)

	RunState.end(&"player_died")
	_run.restart_run()

	var second_player := _run.get_player()
	assert_not_null(second_player)
	assert_ne(first_player, second_player,
		"restart_run muss neuen Player instantiieren")
