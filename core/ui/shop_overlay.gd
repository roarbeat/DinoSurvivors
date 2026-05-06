class_name ShopOverlay
extends CanvasLayer
## Meta-Shop-UI (ADR 0040).
##
## CanvasLayer auf layer=90 (zwischen MutationPickLayer und GameOverLayer).
## Zeigt Liste aller Upgrades, Cost und aktuelles Level. Buy-Button
## triggert MetaProgression.purchase_upgrade(id).
##
## Public-API:
##   show_shop()   — Overlay einblenden
##   hide_shop()   — Overlay ausblenden
##   refresh_list() — UI neu zeichnen (z.B. nach Kauf)
##   get_offered_ids() — Test-Hook: was wird gerade angezeigt
##
## Headless-testbar: Liste wird programmatisch in _refresh_list aufgebaut,
## kann vom Test gegen ContentLoader gemocked werden.

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

@export var auto_show_on_run_end: bool = false  # Test-Default false


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _container: VBoxContainer
var _title_label: Label
var _close_button: Button
var _offered_ids: Array[StringName] = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build_ui()
	hide_shop()
	# Re-refresh wenn Upgrade gekauft
	if get_node_or_null("/root/EventBus") != null:
		EventBus.upgrade_purchased.connect(_on_upgrade_purchased)


func _build_ui() -> void:
	# Background-Panel
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	add_child(bg)

	_container = VBoxContainer.new()
	_container.name = "ShopList"
	_container.anchor_left = 0.25
	_container.anchor_right = 0.75
	_container.anchor_top = 0.15
	_container.anchor_bottom = 0.85
	_container.offset_left = 0
	_container.offset_right = 0
	_container.offset_top = 0
	_container.offset_bottom = 0
	add_child(_container)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "META-SHOP"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Close"
	_close_button.pressed.connect(_on_close_pressed)
	_container.add_child(_close_button)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Blendet das Overlay ein und baut die Upgrade-Liste auf.
func show_shop() -> void:
	visible = true
	_refresh_list()


func hide_shop() -> void:
	visible = false


## Zeichnet die Upgrade-Liste neu. Wird intern bei show + bei
## upgrade_purchased gerufen, kann auch extern gerufen werden.
func refresh_list() -> void:
	_refresh_list()


## Test-Hook: Liste der aktuell angezeigten Upgrade-IDs.
func get_offered_ids() -> Array[StringName]:
	return _offered_ids.duplicate()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _refresh_list() -> void:
	# Bestehende Upgrade-Rows aufräumen (alle Children außer Title + Close)
	for child in _container.get_children():
		if child == _title_label or child == _close_button:
			continue
		_container.remove_child(child)
		child.queue_free()
	_offered_ids.clear()

	if get_node_or_null("/root/ContentLoader") == null:
		return

	var all: Array = ContentLoader.get_all(&"upgrade")
	for item in all:
		var def: UpgradeDef = item as UpgradeDef
		if def == null:
			continue
		_offered_ids.append(def.id)
		var row := _build_upgrade_row(def)
		# Row vor Close-Button einfügen
		_container.add_child(row)
		_container.move_child(row, _container.get_child_count() - 2)


func _build_upgrade_row(def: UpgradeDef) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % String(def.id)

	var name_label := Label.new()
	name_label.text = tr(String(def.display_name_key))
	row.add_child(name_label)

	var level: int = 0
	if get_node_or_null("/root/MetaProgression") != null:
		level = MetaProgression.get_upgrade_level(def.id)

	var level_label := Label.new()
	level_label.text = "Lv %d/%d" % [level, def.max_level]
	row.add_child(level_label)

	var buy_button := Button.new()
	if level >= def.max_level:
		buy_button.text = "MAX"
		buy_button.disabled = true
	else:
		var cost: int = def.get_cost_for_level(level)
		buy_button.text = "Buy (%d %s)" % [cost, String(def.cost_currency)]
		var can_afford: bool = false
		if get_node_or_null("/root/MetaProgression") != null:
			can_afford = MetaProgression.can_afford_upgrade(def.id)
		buy_button.disabled = not can_afford
		var captured_id: StringName = def.id
		buy_button.pressed.connect(func(): _on_buy_pressed(captured_id))
	row.add_child(buy_button)

	return row


func _on_buy_pressed(upgrade_id: StringName) -> void:
	if get_node_or_null("/root/MetaProgression") != null:
		MetaProgression.purchase_upgrade(upgrade_id)


func _on_close_pressed() -> void:
	hide_shop()


func _on_upgrade_purchased(_id: StringName, _new_level: int) -> void:
	# Liste neu zeichnen, damit Lv und Cost stimmen
	if visible:
		_refresh_list()
