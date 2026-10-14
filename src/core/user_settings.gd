# Autoload "UserSettings": per-player preferences persisted to user://settings.cfg
# (audio calibration offset, quality tier, bus volumes, reduce flashing). Applies volumes to the buses.
# Related: src/core/song_clock.gd, src/core/quality_tier.gd, src/core/audio/audio_buses.gd
extends Node

signal changed

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "player"
const MAX_CALIBRATION_SEC: float = 0.5

## Extra delay (seconds) between the engine's audio clock and what the player hears.
## Positive values mean the player hears the music later than the engine thinks.
var audio_offset_sec: float = 0.0:
	set(value):
		audio_offset_sec = clampf(value, -MAX_CALIBRATION_SEC, MAX_CALIBRATION_SEC)
		changed.emit()

var quality_tier: QualityTier.Tier = QualityTier.default_for_platform():
	set(value):
		quality_tier = value
		changed.emit()

## When true, the menu benchmarks the attract run and lowers `quality_tier` until the FPS target is met.
var quality_auto: bool = true:
	set(value):
		quality_auto = value
		changed.emit()

## GD3-054: learn the audio offset from normal play (between runs).
var auto_offset: bool = true:
	set(value):
		auto_offset = value
		changed.emit()

## Calmer visuals: no sky beat pulse, weaker neon beat pulses and flashes.
var reduce_flashing: bool = false:
	set(value):
		reduce_flashing = value
		changed.emit()

## Diagnostic music meter in the level (spectrum + cue lane).
var show_music_meter: bool = false:
	set(value):
		show_music_meter = value
		changed.emit()

var music_volume_db: float = 0.0:
	set(value):
		music_volume_db = clampf(value, -60.0, 6.0)
		_apply_bus_volumes()
		changed.emit()

var sfx_volume_db: float = -2.0:
	set(value):
		sfx_volume_db = clampf(value, -60.0, 6.0)
		_apply_bus_volumes()
		changed.emit()


func _ready() -> void:
	AudioBuses.ensure_layout()
	load_settings()
	_apply_bus_volumes()


func load_settings() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("UserSettings: cannot read %s (%s)" % [SETTINGS_PATH, error_string(error)])
		return
	audio_offset_sec = float(config.get_value(SECTION, "audio_offset_sec", 0.0))
	quality_tier = QualityTier.from_int(int(config.get_value(SECTION, "quality_tier", quality_tier)))
	quality_auto = bool(config.get_value(SECTION, "quality_auto", true))
	auto_offset = bool(config.get_value(SECTION, "auto_offset", true))
	reduce_flashing = bool(config.get_value(SECTION, "reduce_flashing", false))
	show_music_meter = bool(config.get_value(SECTION, "show_music_meter", false))
	music_volume_db = float(config.get_value(SECTION, "music_volume_db", 0.0))
	sfx_volume_db = float(config.get_value(SECTION, "sfx_volume_db", -2.0))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "audio_offset_sec", audio_offset_sec)
	config.set_value(SECTION, "quality_tier", int(quality_tier))
	config.set_value(SECTION, "quality_auto", quality_auto)
	config.set_value(SECTION, "auto_offset", auto_offset)
	config.set_value(SECTION, "reduce_flashing", reduce_flashing)
	config.set_value(SECTION, "show_music_meter", show_music_meter)
	config.set_value(SECTION, "music_volume_db", music_volume_db)
	config.set_value(SECTION, "sfx_volume_db", sfx_volume_db)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("UserSettings: cannot write %s (%s)" % [SETTINGS_PATH, error_string(error)])


func _apply_bus_volumes() -> void:
	if not is_inside_tree():
		return
	AudioBuses.set_volume(AudioBuses.MUSIC, music_volume_db)
	AudioBuses.set_volume(AudioBuses.SFX, sfx_volume_db)
	AudioBuses.set_volume(AudioBuses.UI, sfx_volume_db)
