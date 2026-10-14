# Keeps the music at its original pitch while the recorder plays it slower: a pitch-shift effect on the
# Music bus undoes the player's pitch_scale. Removed again when the recorder leaves (or at 100% speed).
# Related: src/authoring/recorder/recorder.gd, src/core/audio/audio_buses.gd
class_name PitchKeeper
extends RefCounted

const FFT_SIZE: AudioEffectPitchShift.FFTSize = AudioEffectPitchShift.FFT_SIZE_2048
const FFT_SAMPLES: int = 2048
const OVERSAMPLING: int = 4

var _effect: AudioEffectPitchShift


## Sets the compensation for `playback_rate` (1.0 removes the effect).
func apply(playback_rate: float) -> void:
	if is_equal_approx(playback_rate, 1.0):
		release()
		return
	if _effect == null:
		var bus: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
		if bus < 0:
			push_error("PitchKeeper: bus '%s' does not exist" % AudioBuses.MUSIC)
			return
		_effect = AudioEffectPitchShift.new()
		_effect.fft_size = FFT_SIZE
		_effect.oversampling = OVERSAMPLING
		AudioServer.add_bus_effect(bus, _effect)
	_effect.pitch_scale = 1.0 / playback_rate


func release() -> void:
	if _effect == null:
		return
	var bus: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
	for index: int in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, index) == _effect:
			AudioServer.remove_bus_effect(bus, index)
	_effect = null


## Extra wall-clock delay the effect adds (one analysis frame minus a hop), 0 when inactive.
func latency_sec() -> float:
	if _effect == null:
		return 0.0
	return float(FFT_SAMPLES - FFT_SAMPLES / OVERSAMPLING) / AudioServer.get_mix_rate()
