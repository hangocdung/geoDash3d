# Generates a sample-accurate metronome click track (AudioStreamWAV) from a TempoMap, so clicks
# can be mixed in sync with the song via AudioStreamSynchronized, or played alone for calibration.
# Related: src/authoring/metronome/metronome.gd, src/ui/calibration/calibration_screen.gd
class_name ClickTrack
extends RefCounted

const MIX_RATE: int = 44100
const CLICK_LENGTH_SEC: float = 0.03
const CLICK_DECAY_SEC: float = 0.006
const ACCENT_FREQUENCY: float = 1760.0
const NORMAL_FREQUENCY: float = 1175.0
const ACCENT_GAIN: float = 0.9
const NORMAL_GAIN: float = 0.55


## Click on every whole beat from time 0 to `duration_sec`. With `accent_downbeats` the first beat of each
## bar uses a higher click (metronome); without it every click is identical (calibration).
static func generate(tempo: TempoMap, duration_sec: float, beats_per_bar: int = 4,
		accent_downbeats: bool = true) -> AudioStreamWAV:
	if duration_sec <= 0.0:
		push_error("ClickTrack: duration must be > 0 (got %f)" % duration_sec)
		return null
	var frame_count: int = int(ceil(duration_sec * MIX_RATE))
	var data := PackedByteArray()
	data.resize(frame_count * 2)  # 16-bit mono, zero-filled = silence
	var beat: int = ceili(tempo.time_to_beat(0.0))
	while true:
		var click_time: float = tempo.beat_to_time(float(beat))
		if click_time >= duration_sec:
			break
		var accent: bool = accent_downbeats and posmod(beat, beats_per_bar) == 0
		_write_click(data, roundi(click_time * MIX_RATE), ACCENT_FREQUENCY if accent else NORMAL_FREQUENCY,
				ACCENT_GAIN if accent else NORMAL_GAIN)
		beat += 1
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _write_click(data: PackedByteArray, start_frame: int, frequency: float, gain: float) -> void:
	var length: int = int(CLICK_LENGTH_SEC * MIX_RATE)
	var frame_total: int = data.size() / 2
	for index: int in length:
		var frame: int = start_frame + index
		if frame < 0 or frame >= frame_total:
			continue
		var t: float = float(index) / MIX_RATE
		var envelope: float = exp(-t / CLICK_DECAY_SEC) * minf(t / 0.0005, 1.0)
		var sample: float = sin(TAU * frequency * t) * envelope * gain
		data.encode_s16(frame * 2, clampi(int(sample * 32767.0), -32768, 32767))
