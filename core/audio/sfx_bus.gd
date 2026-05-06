extends Node
## Globaler SFX-Bus (ADR 0028).
##
## Lauscht auf bedeutsame EventBus-Signals und triggert SoundDef-basierte
## SFX-Playback über einen AudioStreamPlayer-Pool. SoundDefs ohne Stream
## sind no-op (v1-Default — Audio-Assets landen später).
##
## Public-API:
##   play(sound_id: StringName)       — explizit eine SoundDef abspielen
##   set_muted(muted: bool)            — Test-Hook + globale Stumm-Schaltung
##   is_muted() -> bool
##   pool_size() -> int                — für Tests
##   add_signal_mapping(signal_name, sound_id) — Mod-API-Erweiterung

# ---------------------------------------------------------------------------
# Konstanten
# ---------------------------------------------------------------------------

const POOL_SIZE: int = 8

## Default-Mapping zwischen EventBus-Signal und SoundDef-ID.
## Modder können via add_signal_mapping ergänzen, aber das Default
## ist die Single-Source-of-Truth.
const SIGNAL_TO_SOUND: Dictionary = {
	&"enemy_died":      &"sfx_enemy_died",
	&"boss_defeated":   &"sfx_boss_defeated",
	&"player_damaged":  &"sfx_player_damaged",
	&"player_died":     &"sfx_player_died",
	&"mutation_picked": &"sfx_mutation_picked",
	&"wave_started":    &"sfx_wave_started",
}


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var _muted: bool = false
var _signal_mappings: Dictionary = {}  # signal_name → sound_id (zur Laufzeit erweitert)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Pool aufbauen
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Player_%d" % i
		add_child(p)
		_pool.append(p)

	# Default-Mappings übernehmen
	for k in SIGNAL_TO_SOUND.keys():
		_signal_mappings[k] = SIGNAL_TO_SOUND[k]

	# EventBus-Subscriptions
	# Defensiv: in isolierten Test-Scenes ohne EventBus-Autoload skippen.
	if get_node_or_null("/root/EventBus") == null:
		return

	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.mutation_picked.connect(_on_mutation_picked)
	EventBus.wave_started.connect(_on_wave_started)


# ---------------------------------------------------------------------------
# Public-API
# ---------------------------------------------------------------------------

## Spielt eine SoundDef ab. No-op wenn:
##   - SfxBus stumm geschaltet ist
##   - SoundDef nicht im ContentLoader existiert
##   - SoundDef.stream null ist (v1-Default)
##
## Liefert true wenn ein AudioStream tatsächlich getriggert wurde,
## false bei No-op.
func play(sound_id: StringName) -> bool:
	if _muted:
		return false
	if get_node_or_null("/root/ContentLoader") == null:
		return false
	var def: SoundDef = ContentLoader.get_or_null(&"sound", sound_id) as SoundDef
	if def == null:
		return false
	if def.stream == null:
		return false  # v1-No-op

	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = def.stream
	p.volume_db = def.volume_db
	if def.pitch_random_range > 0.0:
		p.pitch_scale = 1.0 + randf_range(-def.pitch_random_range, def.pitch_random_range)
	else:
		p.pitch_scale = 1.0
	p.play()
	return true


## Setzt globale Stumm-Schaltung. play() wird zum no-op solange muted=true.
func set_muted(muted: bool) -> void:
	_muted = muted
	if muted:
		for p in _pool:
			p.stop()


func is_muted() -> bool:
	return _muted


## Pool-Größe (für Tests + Debug-UI).
func pool_size() -> int:
	return _pool.size()


## Aktuelles signal_name → sound_id-Mapping.
func get_signal_mapping(signal_name: StringName) -> StringName:
	return _signal_mappings.get(signal_name, &"")


## Modder-API: zusätzliche Signal → Sound-Mappings registrieren.
## Hat keinen Effekt auf die Default-Subscriptions (die sind hardcoded).
func add_signal_mapping(signal_name: StringName, sound_id: StringName) -> void:
	_signal_mappings[signal_name] = sound_id


# ---------------------------------------------------------------------------
# Signal-Handler
# ---------------------------------------------------------------------------

func _on_enemy_died(_enemy_id: StringName, _position: Vector2) -> void:
	play(_signal_mappings.get(&"enemy_died", &""))


func _on_boss_defeated(_boss_id: StringName, _run_time: float) -> void:
	play(_signal_mappings.get(&"boss_defeated", &""))


func _on_player_damaged(_amount: float, _source_id: StringName) -> void:
	play(_signal_mappings.get(&"player_damaged", &""))


func _on_player_died() -> void:
	play(_signal_mappings.get(&"player_died", &""))


func _on_mutation_picked(_mutation_id: StringName) -> void:
	play(_signal_mappings.get(&"mutation_picked", &""))


func _on_wave_started(_wave_index: int, _difficulty: float) -> void:
	play(_signal_mappings.get(&"wave_started", &""))
