class_name MutationPickOverlay
extends CanvasLayer
## Mutation-Pick-Phase-Overlay (ADR 0021).
##
## Zeigt sich nach jedem wave_cleared: 3 zufällige nicht-gepickte
## Mutationen, Spieler wählt eine, Spiel pausiert dabei.

const PICK_COUNT: int = 3

# Rarity-Gewichte (ADR 0022). Werte summieren auf 100 (interpretierbar
# als Prozent), absolute Skala ist aber egal — Weighted-Random
# normalisiert zur Summe.
const RARITY_WEIGHTS: Dictionary = {
	&"common": 70.0,
	&"rare": 25.0,
	&"epic": 4.5,
	&"legendary": 0.5,
}
const FALLBACK_WEIGHT: float = 1.0  # für unbekannte Rarities

@onready var pick_buttons: Array[Button] = [$Container/Button1, $Container/Button2, $Container/Button3]


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _offered_ids: Array[StringName] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# RNG initialisieren — Tests können via set_rng() überschreiben
	_rng.randomize()

	# Sichergehen, dass dieses Overlay auch während Pause läuft
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Defensive für Tests ohne Scene-Setup
	if not has_node("Container/Button1"):
		_init_default_buttons()

	visible = false

	# Auto-Advance auf WaveSpawner abschalten — Pick-Overlay übernimmt
	if get_node_or_null("/root/WaveSpawner") != null:
		WaveSpawner.auto_advance = false

	# Wave-Cleared-Hook
	if get_node_or_null("/root/EventBus") != null:
		EventBus.wave_cleared.connect(_on_wave_cleared)

	# Buttons verbinden
	for i in pick_buttons.size():
		var btn := pick_buttons[i]
		var idx := i
		btn.pressed.connect(func(): _on_button_pressed(idx))


func _init_default_buttons() -> void:
	var c := VBoxContainer.new()
	c.name = "Container"
	add_child(c)
	pick_buttons.clear()
	for i in PICK_COUNT:
		var b := Button.new()
		b.name = "Button%d" % (i + 1)
		c.add_child(b)
		pick_buttons.append(b)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Liefert die aktuell angebotenen IDs (für Tests).
func get_offered_ids() -> Array[StringName]:
	return _offered_ids.duplicate()


## Zeigt die Pick-Phase an. Wählt 3 zufällige nicht-gepickte Mutationen.
## Wenn 0 verfügbar: sofort wieder hide + WaveSpawner.request_next_wave.
func show_pick_phase() -> void:
	_offered_ids = _pick_random_mutations(PICK_COUNT)

	if _offered_ids.is_empty():
		# Keine Mutationen mehr verfügbar → Pick-Phase überspringen
		_resume_without_pick()
		return

	# Buttons mit Mutation-Daten füllen
	for i in pick_buttons.size():
		var btn := pick_buttons[i]
		if i < _offered_ids.size():
			btn.text = _format_button_text(_offered_ids[i])
			btn.visible = true
		else:
			btn.visible = false

	visible = true
	get_tree().paused = true


## Versteckt das Overlay und resumed das Spiel + die nächste Welle.
func hide_overlay() -> void:
	visible = false
	get_tree().paused = false
	_offered_ids.clear()
	if get_node_or_null("/root/WaveSpawner") != null:
		WaveSpawner.request_next_wave()


## Test-Hook: deterministischer RNG für reproducible Tests (ADR 0022).
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Test-Hook: Pick programmatisch triggern (umgeht Button-Press).
func _on_pick(mutation_id: StringName) -> void:
	if get_node_or_null("/root/PlayerMutations") != null:
		PlayerMutations.pick(mutation_id)
	hide_overlay()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_wave_cleared(_wave_idx: int) -> void:
	show_pick_phase()


func _on_button_pressed(idx: int) -> void:
	if idx < 0 or idx >= _offered_ids.size():
		return
	_on_pick(_offered_ids[idx])


func _resume_without_pick() -> void:
	visible = false
	get_tree().paused = false
	if get_node_or_null("/root/WaveSpawner") != null:
		WaveSpawner.request_next_wave()


## Wählt N rarity-gewichtete Mutationen, die der Spieler noch nicht
## gepickt hat (ADR 0022). Without-Replacement.
func _pick_random_mutations(count: int) -> Array[StringName]:
	if get_node_or_null("/root/ContentLoader") == null:
		return []
	if get_node_or_null("/root/PlayerMutations") == null:
		return []
	# Pool als MutationDef-Liste (für Rarity-Lookup)
	var available: Array[MutationDef] = []
	for id in ContentLoader.all_ids(&"mutation"):
		if PlayerMutations.has(id):
			continue
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		if mut != null:
			available.append(mut)

	var picks: Array[StringName] = []
	for i in count:
		if available.is_empty():
			break
		var chosen := _weighted_pick_one(available)
		if chosen == null:
			break
		picks.append(chosen.id)
		available.erase(chosen)
	return picks


## Wählt eine Mutation aus dem Pool nach Rarity-Gewichten.
## null wenn Pool leer oder weight_sum == 0.
func _weighted_pick_one(pool: Array) -> MutationDef:
	if pool.is_empty():
		return null
	var weight_sum: float = 0.0
	for m in pool:
		weight_sum += float(RARITY_WEIGHTS.get(m.rarity, FALLBACK_WEIGHT))
	if weight_sum <= 0.0:
		return null
	var roll: float = _rng.randf() * weight_sum
	var cumulative: float = 0.0
	for m in pool:
		cumulative += float(RARITY_WEIGHTS.get(m.rarity, FALLBACK_WEIGHT))
		if roll <= cumulative:
			return m
	# Floating-Point-Rounding-Schutz
	return pool[-1]


func _format_button_text(mutation_id: StringName) -> String:
	# tr() für i18n-Keys (display_name + tooltip)
	var mut := ContentLoader.get_or_null(&"mutation", mutation_id) as MutationDef
	if mut == null:
		return String(mutation_id)
	var name_text: String = tr(String(mut.display_name_key))
	var desc_text: String = tr(String(mut.description_key))
	return "%s\n%s" % [name_text, desc_text]
