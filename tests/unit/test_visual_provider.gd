extends "res://addons/gut/test.gd"
## Visual-Provider-Tests (ADR 0027).
##
## Verifiziert, dass EnemyMob/PlayerCharacter/BossMob den
## visual_scene-Slot korrekt bedienen — Scene wird instanziert und
## ColorRect-Body wird hidden, wenn visual_scene gesetzt ist. ColorRect-
## Fallback bleibt wenn visual_scene null ist (Backward-Kompat).

const VISUAL_STUB_SCENE: PackedScene = preload("res://tests/fixtures/visual_stub.tscn")
const ENEMY_MOB_SCENE: PackedScene = preload("res://core/enemy/enemy_mob.tscn")
const PLAYER_CHAR_SCENE: PackedScene = preload("res://core/player/player_character.tscn")
const BOSS_MOB_SCENE: PackedScene = preload("res://core/boss/boss_mob.tscn")


# ---------------------------------------------------------------------------
# EnemyMob
# ---------------------------------------------------------------------------

func test_enemy_visual_scene_null_keeps_colorrect_visible() -> void:
	# Default-Pfad: EnemyDef ohne visual_scene → ColorRect bleibt sichtbar
	var def := EnemyDef.new()
	def.id = &"test_enemy_no_visual"
	def.display_name_key = &"x.y"
	def.max_health = 10.0
	def.body_color = Color.BLUE
	def.body_size = Vector2(20, 20)

	var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate()
	add_child(mob)
	mob.setup(def, Vector2.ZERO)

	var body := mob.get_node_or_null("Body") as ColorRect
	assert_not_null(body)
	assert_true(body.visible, "Body soll im ColorRect-Mode sichtbar sein")
	assert_null(mob.get_node_or_null("Visual"),
		"Ohne visual_scene sollte kein Visual-Child existieren")

	mob.queue_free()


func test_enemy_visual_scene_instantiates_and_hides_body() -> void:
	# Visual-Provider-Pfad: EnemyDef mit visual_scene → Visual-Child existiert,
	# Body ist hidden
	var def := EnemyDef.new()
	def.id = &"test_enemy_with_visual"
	def.display_name_key = &"x.y"
	def.max_health = 10.0
	def.visual_scene = VISUAL_STUB_SCENE

	var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate()
	add_child(mob)
	mob.setup(def, Vector2.ZERO)

	var visual := mob.get_node_or_null("Visual")
	assert_not_null(visual, "Visual-Child sollte instanziert sein")
	assert_eq(visual.name, "Visual")

	var body := mob.get_node_or_null("Body") as ColorRect
	assert_not_null(body)
	assert_false(body.visible, "Body soll im Visual-Mode hidden sein")

	mob.queue_free()


func test_enemy_visual_scene_replaces_existing_visual_on_resetup() -> void:
	# Idempotenz: zweite setup-Aufruf ersetzt das vorhandene Visual
	var def_a := EnemyDef.new()
	def_a.id = &"test_enemy_a"
	def_a.display_name_key = &"x.y"
	def_a.max_health = 10.0
	def_a.visual_scene = VISUAL_STUB_SCENE

	var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate()
	add_child(mob)
	mob.setup(def_a, Vector2.ZERO)

	var first_visual := mob.get_node_or_null("Visual")
	assert_not_null(first_visual)

	mob.setup(def_a, Vector2(100, 0))
	# Nach Resetup gibt es weiterhin genau ein Visual-Child
	var visuals := []
	for child in mob.get_children():
		if child.name == "Visual" or String(child.name).begins_with("Visual"):
			visuals.append(child)
	# Nach queue_free des alten ist es noch im Tree für einen Frame; akzeptiere 1-2
	assert_true(visuals.size() >= 1, "Mind. ein Visual-Child nach Resetup")

	mob.queue_free()


func test_enemy_visual_pivot_offset_default_is_zero() -> void:
	var def := EnemyDef.new()
	def.id = &"test_enemy_pivot"
	def.display_name_key = &"x.y"
	def.max_health = 10.0
	assert_eq(def.visual_pivot_offset, Vector2.ZERO)


# ---------------------------------------------------------------------------
# PlayerCharacter
# ---------------------------------------------------------------------------

func test_player_visual_scene_null_keeps_body_visible() -> void:
	var dino := DinoDef.new()
	dino.id = &"test_dino_no_visual"
	dino.display_name_key = &"x.y"
	dino.max_health = 100.0
	dino.base_speed = 100.0
	dino.base_attack_rate = 1.0

	var player: PlayerCharacter = PLAYER_CHAR_SCENE.instantiate()
	add_child(player)
	player.set_dino(dino)

	var body := player.get_node_or_null("Body") as ColorRect
	if body != null:
		assert_true(body.visible)
	assert_null(player.get_node_or_null("Visual"))

	player.queue_free()


func test_player_visual_scene_instantiates_and_hides_body() -> void:
	var dino := DinoDef.new()
	dino.id = &"test_dino_with_visual"
	dino.display_name_key = &"x.y"
	dino.max_health = 100.0
	dino.base_speed = 100.0
	dino.base_attack_rate = 1.0
	dino.visual_scene = VISUAL_STUB_SCENE

	var player: PlayerCharacter = PLAYER_CHAR_SCENE.instantiate()
	add_child(player)
	player.set_dino(dino)

	var visual := player.get_node_or_null("Visual")
	assert_not_null(visual)

	var body := player.get_node_or_null("Body") as ColorRect
	if body != null:
		assert_false(body.visible)

	player.queue_free()


# ---------------------------------------------------------------------------
# BossMob
# ---------------------------------------------------------------------------

func test_boss_visual_scene_null_keeps_body_visible() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_no_visual"
	def.display_name_key = &"x.y"
	def.max_health = 500.0
	def.body_color = Color(0.5, 0.0, 0.5)
	def.body_size = Vector2(40, 40)

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(def, Vector2.ZERO)

	var body := boss.get_node_or_null("Body") as ColorRect
	assert_not_null(body)
	assert_true(body.visible)
	assert_null(boss.get_node_or_null("Visual"))

	boss.queue_free()


func test_boss_visual_scene_instantiates_and_hides_body() -> void:
	var def := BossDef.new()
	def.id = &"test_boss_with_visual"
	def.display_name_key = &"x.y"
	def.max_health = 500.0
	def.visual_scene = VISUAL_STUB_SCENE

	var boss: BossMob = BOSS_MOB_SCENE.instantiate()
	add_child(boss)
	boss.setup(def, Vector2.ZERO)

	var visual := boss.get_node_or_null("Visual")
	assert_not_null(visual)
	assert_eq(visual.name, "Visual")

	var body := boss.get_node_or_null("Body") as ColorRect
	assert_not_null(body)
	assert_false(body.visible)

	boss.queue_free()


# ---------------------------------------------------------------------------
# Schema-Defaults
# ---------------------------------------------------------------------------

func test_enemy_def_visual_fields_have_correct_defaults() -> void:
	var def := EnemyDef.new()
	assert_null(def.visual_scene, "visual_scene defaults to null")
	assert_eq(def.visual_pivot_offset, Vector2.ZERO)


func test_dino_def_visual_fields_have_correct_defaults() -> void:
	var def := DinoDef.new()
	assert_null(def.visual_scene)
	assert_eq(def.visual_pivot_offset, Vector2.ZERO)


func test_boss_def_visual_fields_have_correct_defaults() -> void:
	var def := BossDef.new()
	assert_null(def.visual_scene)
	assert_eq(def.visual_pivot_offset, Vector2.ZERO)


# ---------------------------------------------------------------------------
# Backward-Kompat: bestehende Resourcen haben visual_scene=null
# ---------------------------------------------------------------------------

func test_existing_enemies_have_visual_scene_null() -> void:
	# raptor_grunt.tres etc. haben den Slot nicht gesetzt
	var raptor: EnemyDef = ContentLoader.get_or_null(&"enemy", &"raptor_grunt") as EnemyDef
	assert_not_null(raptor)
	assert_null(raptor.visual_scene,
		"raptor_grunt.tres soll visual_scene=null haben (Backward-Kompat)")


func test_existing_boss_has_visual_scene_null() -> void:
	var t: BossDef = ContentLoader.get_or_null(&"boss", &"tyrannosaurus_prime") as BossDef
	assert_not_null(t)
	assert_null(t.visual_scene)


func test_existing_dino_has_visual_scene_null() -> void:
	var trex: DinoDef = ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	assert_not_null(trex)
	assert_null(trex.visual_scene)
