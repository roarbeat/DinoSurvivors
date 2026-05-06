class_name RunScene
extends Node2D
## Run-Scene-Glue (ADR 0016).
##
## Diese Scene ist die main_scene beim Boot. Verantwortung:
##   - Player aus DinoDef.character_scene instantiieren
##   - WaveSpawner.set_spawn_root auf den EnemyContainer setzen
##   - RunState.start(dino_id) triggern
##
## Kein Game-Code im Skript — alles delegiert an Autoloads.

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

## Welcher Dino wird gespawnt? Default: trex.
## In späteren Phasen wird das durch eine Char-Selection-UI gesetzt.
@export var dino_id: StringName = &"trex"

## Demo-Enemies, die beim Run-Start sichtbar sind. Kommt mit Auto-Spawn-
## Curves weg. v1: hilft dabei, im Editor zu sehen, dass die Pipeline läuft.
@export var demo_enemy_id: StringName = &"raptor_grunt"
@export var demo_enemy_count: int = 3


# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

@onready var player_slot: Node = $PlayerSlot
@onready var enemy_container: Node = $EnemyContainer
@onready var game_over_layer: GameOverOverlay = $GameOverLayer
@onready var run_camera: RunCamera = $RunCamera


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _player: PlayerCharacter


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Defensive: Falls schon ein Run läuft (Hot-Reload, Quick-Restart),
	# zurücksetzen.
	if get_node_or_null("/root/RunState") != null and RunState.is_running():
		RunState.end(&"run_scene_reload")
		RunState.reset()

	# 1. Dino-Resource auflösen
	var def: DinoDef = null
	if get_node_or_null("/root/ContentLoader") != null:
		def = ContentLoader.get_or_null(&"dino", dino_id) as DinoDef
	if def == null:
		push_warning("RunScene: dino_id '%s' nicht im ContentLoader" % dino_id)
		return

	# 2. Player aus DinoDef.character_scene instantiieren
	if def.character_scene == null:
		push_warning("RunScene: dino '%s' hat keine character_scene" % dino_id)
		return
	_player = def.character_scene.instantiate() as PlayerCharacter
	if _player == null:
		push_error("RunScene: character_scene ergibt keinen PlayerCharacter")
		return
	player_slot.add_child(_player)
	_player.set_dino(def)

	# 2b. Camera auf Player zentrieren (ADR 0032)
	if run_camera != null:
		run_camera.set_target(_player)
		run_camera.snap_to_target()

	# 3. WaveSpawner spawn_root setzen
	if get_node_or_null("/root/WaveSpawner") != null:
		WaveSpawner.set_spawn_root(enemy_container)

	# 4. Run starten
	if get_node_or_null("/root/RunState") != null:
		RunState.start(dino_id)

	# 5. Game-Over-Listener
	if get_node_or_null("/root/EventBus") != null:
		EventBus.run_ended.connect(_on_run_ended)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Liefert den aktuellen Player. null bis _ready durch ist.
func get_player() -> PlayerCharacter:
	return _player


## Liefert den EnemyContainer-Node — Spawns hängen sich hier an.
func get_enemy_container() -> Node:
	return enemy_container


# ---------------------------------------------------------------------------
# Test-/Demo-Hooks
# ---------------------------------------------------------------------------

## Spawnt N Demo-Enemies um den Player herum. Wird in v1 manuell oder
## via Test gerufen — Auto-Spawn-Curves sind Backlog.
func _spawn_demo_enemies() -> void:
	if get_node_or_null("/root/WaveSpawner") == null:
		return
	var origin := Vector2.ZERO
	if _player != null:
		origin = _player.global_position
	for i in demo_enemy_count:
		var angle := TAU * float(i) / float(max(1, demo_enemy_count))
		var pos := origin + Vector2.RIGHT.rotated(angle) * 200.0
		WaveSpawner.spawn_enemy_at(demo_enemy_id, pos)


# ---------------------------------------------------------------------------
# Game-Over + Restart (ADR 0019)
# ---------------------------------------------------------------------------

func _on_run_ended(reason: StringName, run_time: float) -> void:
	# Save-Trigger: Bernstein und sonstige Meta-Progression persistieren.
	# ADR 0030 — MetaProgression schreibt sich beim save_requested raus,
	# SaveSystem schreibt das ganze data-Dict atomar auf Disk.
	if get_node_or_null("/root/EventBus") != null:
		EventBus.save_requested.emit(&"run_end")

	if game_over_layer == null:
		return
	var wave_idx: int = 0
	if get_node_or_null("/root/WaveSpawner") != null:
		wave_idx = WaveSpawner.current_wave()
	game_over_layer.show_run_ended(reason, run_time, wave_idx)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("restart"):
		return
	if get_node_or_null("/root/RunState") == null:
		return
	if not RunState.is_ended():
		return
	restart_run()


## Setzt den ganzen Run zurück und startet neu. Headless-aufrufbar
## für Tests.
func restart_run() -> void:
	# Cleanup Enemies
	for child in enemy_container.get_children():
		child.queue_free()

	# Cleanup Player
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null

	# RunState reset
	if get_node_or_null("/root/RunState") != null:
		RunState.reset()

	# Game-Over verstecken
	if game_over_layer != null:
		game_over_layer.hide_overlay()

	# Run neu starten — nutzt _ready-Logik wieder
	_spawn_player_and_start()


## Wird sowohl von _ready als auch von restart_run gerufen.
func _spawn_player_and_start() -> void:
	var def: DinoDef = null
	if get_node_or_null("/root/ContentLoader") != null:
		def = ContentLoader.get_or_null(&"dino", dino_id) as DinoDef
	if def == null:
		return
	if def.character_scene == null:
		return
	_player = def.character_scene.instantiate() as PlayerCharacter
	if _player == null:
		return
	player_slot.add_child(_player)
	_player.set_dino(def)
	# Camera-Re-Wire nach Restart (ADR 0032)
	if run_camera != null:
		run_camera.set_target(_player)
		run_camera.snap_to_target()
	if get_node_or_null("/root/WaveSpawner") != null:
		WaveSpawner.set_spawn_root(enemy_container)
	if get_node_or_null("/root/RunState") != null:
		RunState.start(dino_id)
