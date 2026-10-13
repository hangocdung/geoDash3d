# Autoload "Sfx": catalog-driven one-shot sound effects (assets/audio/audio_catalog.json).
# Random variant + pitch per play, per-ID polyphony limit, pooled players per bus. Never touches the
# music player, so effects cannot affect SongClock. Missing IDs warn once and stay silent.
# Related: src/core/audio/audio_buses.gd, tools/audio/build_sfx.py, docs/design/sfx/sfx_video_prompts.md
extends Node

const CATALOG_PATH: String = "res://assets/audio/audio_catalog.json"
const POOL_SIZES: Dictionary[StringName, int] = {AudioBuses.SFX: 12, AudioBuses.UI: 4}


class Entry:
	var streams: Array[AudioStream] = []
	var bus: StringName = AudioBuses.SFX
	var volume_db: float = 0.0
	var pitch_random: float = 0.0
	var max_polyphony: int = 2


var enabled: bool = true
var _entries: Dictionary[StringName, Entry] = {}
var _pools: Dictionary[StringName, Array] = {}
var _next_player: Dictionary[StringName, int] = {}
var _playing_by_id: Dictionary[StringName, Array] = {}
var _warned: Dictionary[StringName, bool] = {}
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	AudioBuses.ensure_layout()
	for bus_name: StringName in POOL_SIZES:
		var pool: Array[AudioStreamPlayer] = []
		for index: int in POOL_SIZES[bus_name]:
			var player := AudioStreamPlayer.new()
			player.bus = bus_name
			add_child(player)
			pool.append(player)
		_pools[bus_name] = pool
		_next_player[bus_name] = 0
	load_catalog(CATALOG_PATH)


func load_catalog(path: String) -> void:
	_entries.clear()
	if not FileAccess.file_exists(path):
		push_warning("Sfx: no catalog at %s, effects are silent" % path)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Sfx: %s is not a JSON object" % path)
		return
	var sounds: Dictionary = (data as Dictionary).get("sounds", {}) as Dictionary
	for sound_id: String in sounds:
		var entry: Entry = _parse_entry(sound_id, sounds[sound_id] as Dictionary)
		if entry != null:
			_entries[StringName(sound_id)] = entry


func has_sound(sound_id: StringName) -> bool:
	return _entries.has(sound_id)


func play(sound_id: StringName, volume_offset_db: float = 0.0) -> void:
	if not enabled:
		return
	var entry: Entry = _entries.get(sound_id)
	if entry == null:
		if not _warned.has(sound_id):
			_warned[sound_id] = true
			push_warning("Sfx: unknown sound '%s'" % sound_id)
		return
	var active: Array = _playing_by_id.get(sound_id, [])
	active = active.filter(func(player: AudioStreamPlayer) -> bool: return player.playing)
	if active.size() >= entry.max_polyphony:
		(active.pop_front() as AudioStreamPlayer).stop()
	var player: AudioStreamPlayer = _take_player(entry.bus)
	player.stream = entry.streams[_random.randi() % entry.streams.size()]
	player.volume_db = entry.volume_db + volume_offset_db
	player.pitch_scale = 1.0 + _random.randf_range(-entry.pitch_random, entry.pitch_random)
	player.play()
	active.append(player)
	_playing_by_id[sound_id] = active


func _take_player(bus_name: StringName) -> AudioStreamPlayer:
	var pool: Array = _pools.get(bus_name, _pools[AudioBuses.SFX])
	var key: StringName = bus_name if _pools.has(bus_name) else AudioBuses.SFX
	var index: int = _next_player[key]
	_next_player[key] = (index + 1) % pool.size()
	var player: AudioStreamPlayer = pool[index] as AudioStreamPlayer
	player.stop()
	return player


func _parse_entry(sound_id: String, data: Dictionary) -> Entry:
	var entry := Entry.new()
	for file_path: Variant in data.get("files", []) as Array:
		var stream: AudioStream = load(str(file_path)) as AudioStream
		if stream == null:
			push_error("Sfx: '%s' cannot load %s" % [sound_id, str(file_path)])
			continue
		entry.streams.append(stream)
	if entry.streams.is_empty():
		return null
	entry.bus = StringName(str(data.get("bus", "SFX")))
	entry.volume_db = float(data.get("volume_db", 0.0))
	entry.pitch_random = float(data.get("pitch_random", 0.0))
	entry.max_polyphony = maxi(1, int(data.get("max_polyphony", 2)))
	return entry
