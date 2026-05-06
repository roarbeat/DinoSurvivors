extends "res://addons/gut/test.gd"
## Multi-Dino + Multi-Tab-Shop-Tests (ADR 0044).

func before_each() -> void:
	MetaProgression.reset()
	if SaveSystem.has_save_file():
		SaveSystem.delete_save()


func after_each() -> void:
	MetaProgression.reset()


# ---------------------------------------------------------------------------
# DinoDef-Schema-Erweiterung
# ---------------------------------------------------------------------------

func test_dinodef_default_unlock_upgrade_id_empty() -> void:
	var d := DinoDef.new()
	assert_eq(String(d.unlock_upgrade_id), "")


func test_trex_has_no_unlock_upgrade() -> void:
	var trex := ContentLoader.get_or_null(&"dino", &"trex") as DinoDef
	assert_eq(String(trex.unlock_upgrade_id), "",
		"trex muss always-unlocked sein (kein unlock_upgrade_id)")


func test_velociraptor_has_unlock_upgrade() -> void:
	var v := ContentLoader.get_or_null(&"dino", &"velociraptor") as DinoDef
	assert_not_null(v)
	assert_eq(v.unlock_upgrade_id, &"dino_unlock_velociraptor")


func test_stegosaurus_has_unlock_upgrade() -> void:
	var s := ContentLoader.get_or_null(&"dino", &"stegosaurus") as DinoDef
	assert_not_null(s)
	assert_eq(s.unlock_upgrade_id, &"dino_unlock_stegosaurus")


# ---------------------------------------------------------------------------
# UpgradeDef-Schema-Erweiterung
# ---------------------------------------------------------------------------

func test_upgrade_default_category_is_stat() -> void:
	var u := UpgradeDef.new()
	assert_eq(u.category, &"stat")


func test_stronger_jaws_is_stat_category() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"stronger_jaws") as UpgradeDef
	assert_eq(u.category, &"stat")


func test_dino_unlock_velociraptor_category() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"dino_unlock_velociraptor") as UpgradeDef
	assert_not_null(u)
	assert_eq(u.category, &"dino_unlock")
	assert_eq(u.unlock_dino_id, &"velociraptor")
	assert_eq(u.max_level, 1)
	assert_eq(u.cost_per_level[0], 200)


func test_dino_unlock_stegosaurus_category() -> void:
	var u := ContentLoader.get_or_null(&"upgrade", &"dino_unlock_stegosaurus") as UpgradeDef
	assert_eq(u.category, &"dino_unlock")
	assert_eq(u.unlock_dino_id, &"stegosaurus")
	assert_eq(u.cost_per_level[0], 300)


# ---------------------------------------------------------------------------
# MetaProgression.is_dino_unlocked
# ---------------------------------------------------------------------------

func test_trex_always_unlocked() -> void:
	assert_true(MetaProgression.is_dino_unlocked(&"trex"))


func test_velociraptor_locked_by_default() -> void:
	assert_false(MetaProgression.is_dino_unlocked(&"velociraptor"))


func test_velociraptor_unlocked_after_purchase() -> void:
	MetaProgression.add_currency(&"amber", 200)
	var ok := MetaProgression.purchase_upgrade(&"dino_unlock_velociraptor")
	assert_true(ok)
	assert_true(MetaProgression.is_dino_unlocked(&"velociraptor"))


func test_stegosaurus_locked_by_default() -> void:
	assert_false(MetaProgression.is_dino_unlocked(&"stegosaurus"))


func test_unknown_dino_id_returns_false() -> void:
	assert_false(MetaProgression.is_dino_unlocked(&"unknown_dino"))


# ---------------------------------------------------------------------------
# Shop-Overlay Tab-Filter
# ---------------------------------------------------------------------------

const SHOP_OVERLAY_SCENE: PackedScene = preload("res://core/ui/shop_overlay.tscn")


func test_shop_default_tab_is_stat() -> void:
	var shop: ShopOverlay = SHOP_OVERLAY_SCENE.instantiate()
	add_child(shop)
	assert_eq(shop.get_tab(), &"stat")
	shop.queue_free()


func test_shop_stats_tab_shows_only_stat_upgrades() -> void:
	var shop: ShopOverlay = SHOP_OVERLAY_SCENE.instantiate()
	add_child(shop)
	shop.show_shop()
	var ids: Array[StringName] = shop.get_offered_ids()
	# Erwarte: stronger_jaws/tougher_hide/faster_legs/sharper_eyes
	assert_true(ids.has(&"stronger_jaws"))
	assert_false(ids.has(&"dino_unlock_velociraptor"))
	assert_false(ids.has(&"dino_unlock_stegosaurus"))
	shop.queue_free()


func test_shop_dinos_tab_shows_only_dino_unlocks() -> void:
	var shop: ShopOverlay = SHOP_OVERLAY_SCENE.instantiate()
	add_child(shop)
	shop.set_tab(&"dino_unlock")
	shop.show_shop()
	var ids: Array[StringName] = shop.get_offered_ids()
	assert_false(ids.has(&"stronger_jaws"))
	assert_true(ids.has(&"dino_unlock_velociraptor"))
	assert_true(ids.has(&"dino_unlock_stegosaurus"))
	shop.queue_free()


func test_set_tab_changes_filter() -> void:
	var shop: ShopOverlay = SHOP_OVERLAY_SCENE.instantiate()
	add_child(shop)
	shop.show_shop()
	# Default tab=stat
	assert_true(shop.get_offered_ids().has(&"stronger_jaws"))
	# Switch to dino_unlock
	shop.set_tab(&"dino_unlock")
	assert_false(shop.get_offered_ids().has(&"stronger_jaws"))
	assert_true(shop.get_offered_ids().has(&"dino_unlock_velociraptor"))
	shop.queue_free()
