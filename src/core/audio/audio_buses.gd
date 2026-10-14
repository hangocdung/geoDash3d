# Audio bus layout created at startup (no hand-edited bus .tres): Music, SFX and UI under Master.
# UserSettings drives their volumes. Related: src/core/user_settings.gd, src/core/audio/sfx.gd
class_name AudioBuses
extends RefCounted

const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"
const UI: StringName = &"UI"
const MUTED_DB: float = -80.0


static func ensure_layout() -> void:
	for bus_name: StringName in [MUSIC, SFX, UI]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


## Spectrum analyzer on the Music bus (added on first use; the music meter reads it).
static func music_spectrum() -> AudioEffectSpectrumAnalyzerInstance:
	var index: int = AudioServer.get_bus_index(MUSIC)
	if index < 0:
		push_error("AudioBuses: bus '%s' does not exist" % MUSIC)
		return null
	for effect: int in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect) is AudioEffectSpectrumAnalyzer:
			return AudioServer.get_bus_effect_instance(index, effect) as AudioEffectSpectrumAnalyzerInstance
	var analyzer := AudioEffectSpectrumAnalyzer.new()
	analyzer.buffer_length = 0.5
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	AudioServer.add_bus_effect(index, analyzer)
	return AudioServer.get_bus_effect_instance(index, AudioServer.get_bus_effect_count(index) - 1) 			as AudioEffectSpectrumAnalyzerInstance


static func set_volume(bus_name: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioBuses: bus '%s' does not exist" % bus_name)
		return
	AudioServer.set_bus_volume_db(index, volume_db)
	AudioServer.set_bus_mute(index, volume_db <= MUTED_DB + 0.5)
