class_name PlayerCharacter
extends CharacterBody2D
## Player-Char (ADR 0008).
##
## Generisch — der konkrete Dino kommt als DinoDef-Resource via set_dino().
## Stats (max_hp, speed, damage) werden aus DinoDef geladen und durch
## PlayerMutations-Aggregat-Stats modifiziert.
##
## Komponenten:
##   $Health (HealthComponent)         — HP-Container, is_player=true
##   $Dealer (DamageDealerComponent)   — Damage-Quelle für Player-Attacks
##
## Movement-Logik ist in `_compute_velocity()` extrahiert — pure Funktion,
## headless-testbar.

# ---------------------------------------------------------------------------
# Konstanten (Hit-Detection v1 — ADR 0011)
# ---------------------------------------------------------------------------

const TOUCH_HIT_RADIUS: float = 25.0
const IFRAMES_DURATION: float = 0.5
const ATTACK_RANGE_FALLBACK: float = 80.0


# ---------------------------------------------------------------------------
# Children (per @onready im Scene-Tree)
# ---------------------------------------------------------------------------

@onready var health: HealthComponent = $Health
@onready var dealer: DamageDealerComponent = $Dealer


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _dino: DinoDef
var _attack_timer: float = 0.0     # Sekunden bis nächster Auto-Attack-Tick
var _invulnerable_for: float = 0.0  # Sekunden Restdauer iframes


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Group-Konvention (ADR 0011): EnemyMobs finden Player über diese Group.
	add_to_group(&"player")

	# Für Tests, die PlayerCharacter ohne .tscn-Setup direkt instantiieren:
	# wenn keine Children existieren, legen wir HealthComponent + Dealer an.
	if has_node("Health"):
		health = $Health
	else:
		health = HealthComponent.new()
		health.name = "Health"
		add_child(health)
	if has_node("Dealer"):
		dealer = $Dealer
	else:
		dealer = DamageDealerComponent.new()
		dealer.name = "Dealer"
		add_child(dealer)

	health.is_player = true
	dealer.default_source_id = &"player"

	# HP-Bar binden, sofern in der Scene angelegt (ADR 0018)
	if has_node("HealthBar"):
		var hpbar: HealthBar = $HealthBar
		hpbar.set_health(health)

	# Auf Mutations-Änderungen reagieren
	if get_node_or_null("/root/EventBus") != null:
		EventBus.mutations_changed.connect(_on_mutations_changed)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Setzt den aktiven Dino. Initialisiert Stats und Komponenten.
func set_dino(dino: DinoDef) -> void:
	_dino = dino
	if dino == null:
		return
	# Initial-Stats aus DinoDef. Mutations sind standardmäßig leer beim Set;
	# wenn welche gepickt sind, ruft _on_mutations_changed sie sowieso auf.
	_apply_stats(get_aggregated_or_empty())
	# HP auf max setzen (initial Spawn)
	health.reset_to_full()


func get_dino() -> DinoDef:
	return _dino


func get_health_component() -> HealthComponent:
	return health


func get_dealer_component() -> DamageDealerComponent:
	return dealer


## Berechnete max_hp inkl. Mutations-Bonus.
func get_effective_max_hp() -> float:
	if _dino == null:
		return 0.0
	var bonus_pct: float = float(get_aggregated_or_empty()["unhandled"].get(&"max_health_pct", 0.0))
	return _dino.max_health * (1.0 + max(0.0, bonus_pct))


## Berechnete Geschwindigkeit inkl. Mutations-Bonus.
func get_effective_speed() -> float:
	if _dino == null:
		return 0.0
	var bonus_pct: float = float(get_aggregated_or_empty()["unhandled"].get(&"move_speed_pct", 0.0))
	return _dino.base_speed * (1.0 + max(0.0, bonus_pct))


## Pure Movement-Berechnung — testbar ohne Physics-Step.
func _compute_velocity(input_vec: Vector2) -> Vector2:
	if input_vec.length_squared() <= 0.0:
		return Vector2.ZERO
	return input_vec.normalized() * get_effective_speed()


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# Input-Actions: move_left/right/up/down (siehe project.godot)
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	velocity = _compute_velocity(input)
	move_and_slide()

	# Hit-Detection-Tick (ADR 0011)
	_update_hit_detection(delta)


# ---------------------------------------------------------------------------
# Hit-Detection (ADR 0011)
# ---------------------------------------------------------------------------

## Aktualisiert Auto-Attack-Tick und Touch-Damage-Frame.
## Wird einmal pro physics-Frame gerufen.
func _update_hit_detection(delta: float) -> void:
	# iframes runter zählen
	if _invulnerable_for > 0.0:
		_invulnerable_for = max(0.0, _invulnerable_for - delta)

	# Auto-Attack-Tick
	_attack_timer = max(0.0, _attack_timer - delta)
	if _attack_timer <= 0.0:
		_do_auto_attack()
		_attack_timer = 1.0 / max(0.01, _effective_attack_rate())

	# Touch-Damage (nur wenn nicht in iframes)
	if _invulnerable_for <= 0.0:
		_check_touch_damage()


## Findet alle Enemies in attack_range und fügt jedem base_damage zu.
## Rückgabe: Anzahl getroffener Enemies (für Tests + Telemetrie).
func _do_auto_attack() -> int:
	if _dino == null:
		return 0
	var range_sq := get_attack_range() * get_attack_range()
	var info := DamageInfo.make(_dino.base_damage, &"player_attack")
	var hits := 0
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == null or not (node is EnemyMob):
			continue
		var enemy: EnemyMob = node
		if enemy.get_health_component().is_dead():
			continue
		var dist_sq := (enemy.global_position - global_position).length_squared()
		if dist_sq <= range_sq:
			dealer.deal_damage(enemy.get_health_component(), info)
			hits += 1
	return hits


## Prüft, ob ein Enemy nah genug ist für Touch-Damage.
## Rückgabe: true wenn Touch passiert (Test-/Telemetrie-Hook).
func _check_touch_damage() -> bool:
	var nearest: EnemyMob = null
	var nearest_dist_sq: float = TOUCH_HIT_RADIUS * TOUCH_HIT_RADIUS
	for node in get_tree().get_nodes_in_group(&"enemy"):
		if node == null or not (node is EnemyMob):
			continue
		var enemy: EnemyMob = node
		if enemy.get_health_component().is_dead():
			continue
		var dist_sq := (enemy.global_position - global_position).length_squared()
		if dist_sq <= nearest_dist_sq:
			nearest = enemy
			nearest_dist_sq = dist_sq

	if nearest == null:
		return false

	# Touch-Damage durch Enemy.dealer (Symmetrie zur Attack-Pipeline).
	var touch_amount: float = nearest.get_def().damage if nearest.get_def() != null else 0.0
	nearest.get_dealer_component().deal_damage(
		health,
		DamageInfo.make(touch_amount, nearest.enemy_id)
	)
	_invulnerable_for = IFRAMES_DURATION
	return true


func is_invulnerable() -> bool:
	return _invulnerable_for > 0.0


## Effektive Attack-Range (DinoDef.pickup_radius oder Fallback).
## In v1 ist pickup_radius gleichzeitig Attack-Range; ein dediziertes
## attack_range-Feld kommt mit eigenem ADR.
func get_attack_range() -> float:
	if _dino == null:
		return ATTACK_RANGE_FALLBACK
	if _dino.pickup_radius > 0.0:
		return _dino.pickup_radius
	return ATTACK_RANGE_FALLBACK


## Effektive Attack-Rate (DinoDef.base_attack_rate, später durch Modifier
## erweiterbar — in v1 noch nicht).
func _effective_attack_rate() -> float:
	if _dino == null:
		return 1.0
	return max(0.01, _dino.base_attack_rate)


# ---------------------------------------------------------------------------
# Mutations-Hook
# ---------------------------------------------------------------------------

func _on_mutations_changed() -> void:
	_apply_stats(get_aggregated_or_empty())


## Holt aggregierte Mutations-Stats vom PlayerMutations-Autoload.
## Liefert leeres Result-Schema, wenn der Autoload nicht da ist (z.B. Tests
## ohne PlayerMutations).
func get_aggregated_or_empty() -> Dictionary:
	if get_node_or_null("/root/PlayerMutations") == null:
		return { "outgoing": [], "incoming": [], "unhandled": {} }
	return PlayerMutations.get_aggregated()


func _apply_stats(agg: Dictionary) -> void:
	if _dino == null:
		return

	# Outgoing Modifier auf Dealer
	dealer.outgoing_modifiers = []
	for m in agg["outgoing"]:
		dealer.add_modifier(m)

	# Incoming Modifier auf Health
	health.incoming_modifiers = []
	for m in agg["incoming"]:
		health.add_modifier(m)

	# Player-Stat-Application (max_health_pct)
	var bonus_hp_pct: float = float(agg["unhandled"].get(&"max_health_pct", 0.0))
	var new_max_hp: float = _dino.max_health * (1.0 + max(0.0, bonus_hp_pct))
	# Aktuelles HP cappen falls max gesunken ist
	var prev_hp: float = health.get_hp()
	health.max_hp = new_max_hp
	if prev_hp > new_max_hp:
		# max_hp-Setter clampt nicht das current_hp — hier explizit kappen
		health.take_damage(DamageInfo.make(prev_hp - new_max_hp, &"stat_recalc"))
