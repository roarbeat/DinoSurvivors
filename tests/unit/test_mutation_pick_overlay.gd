extends "res://addons/gut/test.gd"
## MutationPickOverlay-Tests (ADR 0021).

var _overlay: MutationPickOverlay


func before_each() -> void:
	# State zurücksetzen
	if RunState.is_running(): RunState.end(&"test_setup")
	RunState.reset()
	PlayerMutations.reset()
	WaveSpawner.auto_advance = true  # Default für andere Tests sichern
	get_tree().paused = false

	var packed := load("res://core/ui/mutation_pick_overlay.tscn") as PackedScene
	_overlay = packed.instantiate() as MutationPickOverlay
	add_child(_overlay)


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	WaveSpawner.auto_advance = true
	PlayerMutations.reset()


# ---------------------------------------------------------------------------
# Initial-State
# ---------------------------------------------------------------------------

func test_initial_invisible() -> void:
	assert_false(_overlay.visible)


func test_overlay_disables_auto_advance_on_ready() -> void:
	# _ready setzt WaveSpawner.auto_advance = false
	assert_false(WaveSpawner.auto_advance,
		"Overlay muss WaveSpawner.auto_advance auf false setzen")


# ---------------------------------------------------------------------------
# Pick-Logic
# ---------------------------------------------------------------------------

func test_pick_random_returns_at_most_count() -> void:
	# Wir haben 3 Mutationen total — count=3 sollte alle 3 liefern
	var picks := _overlay._pick_random_mutations(3)
	assert_eq(picks.size(), 3,
		"Bei 3 verfügbaren und count=3 sollten alle 3 zurückkommen")


func test_pick_random_excludes_already_picked() -> void:
	PlayerMutations.pick(&"triceratops_horns")
	var picks := _overlay._pick_random_mutations(3)
	assert_false(picks.has(&"triceratops_horns"),
		"Bereits gepickte Mutation darf nicht angeboten werden")
	# Mindestens 2 (irgendeine Mutation neben triceratops), bei wachsendem
	# Pool maximal PICK_COUNT (3)
	assert_gte(picks.size(), 2,
		"Mindestens 2 Mutationen sollten nach Ausschluss verfügbar sein")
	assert_lte(picks.size(), 3,
		"PICK_COUNT-Cap muss greifen")


func test_pick_random_returns_empty_when_all_picked() -> void:
	# Robust gegen Pool-Wachstum: alle Mutationen aus Loader picken
	for mid in ContentLoader.all_ids(&"mutation"):
		PlayerMutations.pick(mid)
	var picks := _overlay._pick_random_mutations(3)
	assert_eq(picks.size(), 0,
		"Wenn alle Mutationen gepickt: keine mehr verfügbar")


# ---------------------------------------------------------------------------
# show_pick_phase
# ---------------------------------------------------------------------------

func test_show_pick_phase_makes_visible() -> void:
	_overlay.show_pick_phase()
	assert_true(_overlay.visible)


func test_show_pick_phase_pauses_tree() -> void:
	_overlay.show_pick_phase()
	assert_true(get_tree().paused, "Show muss Pause aktivieren")


func test_show_pick_phase_offered_ids_populated() -> void:
	_overlay.show_pick_phase()
	var offered := _overlay.get_offered_ids()
	assert_eq(offered.size(), 3)


# ---------------------------------------------------------------------------
# Edge: keine Mutationen verfügbar
# ---------------------------------------------------------------------------

func test_show_skips_if_no_mutations_available() -> void:
	# Alle Mutationen aus dem Loader picken — robust gegen Pool-Wachstum
	for mid in ContentLoader.all_ids(&"mutation"):
		PlayerMutations.pick(mid)

	_overlay.show_pick_phase()
	# Overlay bleibt unsichtbar
	assert_false(_overlay.visible,
		"Bei 0 verfügbaren Mutationen → Phase überspringen")
	assert_false(get_tree().paused,
		"Tree darf nicht pausiert bleiben bei Skip")


# ---------------------------------------------------------------------------
# Pick-Action
# ---------------------------------------------------------------------------

func test_on_pick_adds_mutation_and_resumes() -> void:
	_overlay.show_pick_phase()
	assert_true(_overlay.visible)
	assert_true(get_tree().paused)

	# Programmatisch einen Pick triggern
	var first_id := _overlay.get_offered_ids()[0]
	_overlay._on_pick(first_id)

	# Mutation wurde gepickt
	assert_true(PlayerMutations.has(first_id))
	# Overlay ist verschwunden
	assert_false(_overlay.visible)
	# Pause aufgehoben
	assert_false(get_tree().paused)


func test_on_pick_triggers_next_wave() -> void:
	# Run starten, Welle 1 läuft
	WaveSpawner.set_wave_duration(60.0)
	WaveSpawner.auto_advance = false
	RunState.start(&"trex")
	assert_eq(WaveSpawner.current_wave(), 1)

	# wave_cleared simulieren → Overlay zeigt Pick-Phase
	WaveSpawner._force_wave_end()
	assert_true(_overlay.visible)

	# Pick → Overlay schließt + WaveSpawner.request_next_wave wurde gerufen
	_overlay._on_pick(_overlay.get_offered_ids()[0])
	assert_eq(WaveSpawner.current_wave(), 2,
		"Nach Pick muss nächste Welle gestartet sein")

	# Cleanup
	RunState.end(&"test_cleanup")
	RunState.reset()


# ---------------------------------------------------------------------------
# wave_cleared-Hook
# ---------------------------------------------------------------------------

func test_wave_cleared_triggers_show_pick_phase() -> void:
	# Direkt das Signal feuern
	EventBus.wave_cleared.emit(1)
	assert_true(_overlay.visible,
		"wave_cleared muss Overlay einblenden")
	# Cleanup
	get_tree().paused = false


# ---------------------------------------------------------------------------
# Rarity-Weighting (ADR 0022)
# ---------------------------------------------------------------------------

func test_rarity_weights_constants() -> void:
	# Verifiziert die Public-API-Konstante
	assert_almost_eq(MutationPickOverlay.RARITY_WEIGHTS[&"common"], 70.0, 0.001)
	assert_almost_eq(MutationPickOverlay.RARITY_WEIGHTS[&"rare"], 25.0, 0.001)
	assert_almost_eq(MutationPickOverlay.RARITY_WEIGHTS[&"epic"], 4.5, 0.001)
	assert_almost_eq(MutationPickOverlay.RARITY_WEIGHTS[&"legendary"], 0.5, 0.001)


func test_weighted_pick_with_seeded_rng_is_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_overlay.set_rng(rng)
	var picks_a := _overlay._pick_random_mutations(3)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	_overlay.set_rng(rng2)
	var picks_b := _overlay._pick_random_mutations(3)

	assert_eq(picks_a, picks_b,
		"Gleicher RNG-Seed → identische Picks (Determinismus für Tests)")


func test_weighted_pick_only_common_pool() -> void:
	# Wir setzen alle nicht-common-Mutationen als gepickt, dann darf Pool
	# nur Common-Mutationen liefern.
	for id in ContentLoader.all_ids(&"mutation"):
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		if mut != null and mut.rarity != &"common":
			PlayerMutations.pick(id)

	var picks := _overlay._pick_random_mutations(3)
	for id in picks:
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		assert_eq(mut.rarity, &"common",
			"Pool ohne Rare/Epic/Legendary muss nur Common liefern")


func test_weighted_pick_only_rare_pool() -> void:
	# Alle Common-Mutationen picken
	for id in ContentLoader.all_ids(&"mutation"):
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		if mut != null and mut.rarity == &"common":
			PlayerMutations.pick(id)

	var picks := _overlay._pick_random_mutations(3)
	for id in picks:
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		assert_eq(mut.rarity, &"rare",
			"Pool ohne Common muss Rare liefern")


func test_weighted_pick_no_replacement() -> void:
	# 3 Picks → 3 unique IDs (no duplicates)
	var picks := _overlay._pick_random_mutations(3)
	assert_eq(picks.size(), 3)
	var unique: Array = []
	for id in picks:
		assert_false(unique.has(id),
			"Without-Replacement: Pick %s erscheint zweimal" % id)
		unique.append(id)


func test_weighted_pick_distribution_with_seed() -> void:
	# Statistischer Sanity-Check: 100 Picks aus dem Pool, prüfen, dass
	# Common dominiert (>50%) und Rare präsent ist (>5%). Wir brauchen
	# einen reset-bare Pick — also setzen wir vor jedem Pick die
	# PlayerMutations zurück.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_overlay.set_rng(rng)

	var rarity_counts: Dictionary = {&"common": 0, &"rare": 0}
	var trials := 100
	for i in trials:
		PlayerMutations.reset()
		var pick := _overlay._weighted_pick_one(_collect_all_mutations())
		if pick == null:
			continue
		rarity_counts[pick.rarity] = rarity_counts.get(pick.rarity, 0) + 1

	var common_pct := float(rarity_counts[&"common"]) / float(trials)
	var rare_pct := float(rarity_counts[&"rare"]) / float(trials)
	# Mit 4 Common (70 weight each) und 3 Rare (25 weight each):
	# weight_sum = 4×70 + 3×25 = 280 + 75 = 355
	# Common-Pct: 280/355 ≈ 78.9% (jeder einzelne Common ist 70/355 ≈ 19.7%)
	# Rare-Pct: 75/355 ≈ 21.1%
	# Toleranz: ±10% wegen statistischem Rauschen bei N=100
	assert_gt(common_pct, 0.65, "Common sollte > 65% sein (erwartet ~79%)")
	assert_lt(common_pct, 0.95, "Common sollte < 95% sein")
	assert_gt(rare_pct, 0.10, "Rare sollte > 10% sein (erwartet ~21%)")


# Helper: alle Mutationen als MutationDef-Liste
func _collect_all_mutations() -> Array:
	var result := []
	for id in ContentLoader.all_ids(&"mutation"):
		var mut := ContentLoader.get_or_null(&"mutation", id) as MutationDef
		if mut != null:
			result.append(mut)
	return result
