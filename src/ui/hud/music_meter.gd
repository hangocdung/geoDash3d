# Diagnostic strip (Settings > Music meter): per-band bars of how much louder the music just got (dB above the
# band's recent average, so hits pop even in compressed mixes), plus a cue lane where each tap point scrolls
# toward a hit line. A well-placed cue reaches the line as the bars jump.
# The spectrum is read when audio is mixed (before the output latency), so frames are kept by playback position
# and shown when SongClock says that position is being heard. Related: hud.gd, src/core/song_clock.gd
class_name MusicMeter
extends Control

const BANDS: int = 24
const LOW_HZ: float = 40.0
const HIGH_HZ: float = 10000.0
const FLOOR_DB: float = -80.0
## A bar is full when its band is this many dB above its recent average (time constant AVERAGE_SEC).
const JUMP_RANGE_DB: float = 12.0
const AVERAGE_SEC: float = 0.5
const BAR_BASE: float = 0.08
const STRIP_HEIGHT: float = 120.0
const MARGIN: float = 24.0
## Seconds of cue lane shown ahead of / behind the hit line, and where the line sits (fraction of width).
const LOOK_AHEAD_SEC: float = 2.0
const LOOK_BEHIND_SEC: float = 0.5
const HIT_LINE_X: float = 0.25
const HISTORY_SEC: float = 1.0
const BAR_COLOR: Color = Color(0.35, 0.85, 1.0, 0.85)
const LANE_BACK: Color = Color(0.02, 0.0, 0.08, 0.55)

var _analyzer: AudioEffectSpectrumAnalyzerInstance
var _clock: SongClock
var _cue_times: PackedFloat64Array = []
var _cue_colors: Array[Color] = []
## Mixed spectra: playback position (s) and BANDS levels (0..1) per frame.
var _history_positions: PackedFloat64Array = []
var _history_levels: Array[PackedFloat32Array] = []
var _shown: PackedFloat32Array = []
var _average_db: PackedFloat32Array = []
var _heard_sec: float = 0.0
var _flash: float = 0.0
var _next_cue: int = 0


func setup(chart: LevelChart, clock: SongClock, analyzer: AudioEffectSpectrumAnalyzerInstance) -> void:
	_clock = clock
	_analyzer = analyzer
	for cue: ChartItems.ActionCue in chart.cues:
		_cue_times.append(chart.time_at(cue.beat))
		_cue_colors.append(cue.action.color)
	_shown.resize(BANDS)
	_average_db.resize(BANDS)
	_average_db.fill(FLOOR_DB)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -STRIP_HEIGHT - MARGIN
	offset_bottom = -MARGIN
	offset_left = MARGIN
	offset_right = -MARGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _analyzer == null or not _clock.audio_player.playing:
		return
	var player: AudioStreamPlayer = _clock.audio_player
	var mixed_position: float = player.get_playback_position() + AudioServer.get_time_since_last_mix()
	_history_positions.append(mixed_position)
	_history_levels.append(_read_spectrum())
	while _history_positions.size() > 2 and _history_positions[0] < mixed_position - HISTORY_SEC:
		_history_positions.remove_at(0)
		_history_levels.remove_at(0)
	_heard_sec = _clock.frame_time()
	var levels: PackedFloat32Array = _levels_at(_heard_sec)
	var blend: float = 1.0 - exp(-delta / AVERAGE_SEC)
	for band: int in BANDS:
		var jump: float = clampf((levels[band] - _average_db[band]) / JUMP_RANGE_DB, 0.0, 1.0)
		_average_db[band] = lerpf(_average_db[band], levels[band], blend)
		_shown[band] = maxf(jump, _shown[band] - delta * 4.0)
	_flash = maxf(_flash - delta * 6.0, 0.0)
	while _next_cue < _cue_times.size() and _cue_times[_next_cue] <= _heard_sec:
		_flash = 1.0
		_next_cue += 1
	while _next_cue > 0 and _cue_times[_next_cue - 1] > _heard_sec:
		_next_cue -= 1
	queue_redraw()


func _read_spectrum() -> PackedFloat32Array:
	var levels := PackedFloat32Array()
	levels.resize(BANDS)
	for band: int in BANDS:
		var low: float = LOW_HZ * pow(HIGH_HZ / LOW_HZ, float(band) / BANDS)
		var high: float = LOW_HZ * pow(HIGH_HZ / LOW_HZ, float(band + 1) / BANDS)
		var magnitude: float = _analyzer.get_magnitude_for_frequency_range(low, high).length()
		levels[band] = maxf(linear_to_db(magnitude), FLOOR_DB)
	return levels


## Spectrum mixed at the playback position being heard now (the newest one if that is still ahead).
func _levels_at(position: float) -> PackedFloat32Array:
	var best: int = _history_positions.size() - 1
	for index: int in _history_positions.size():
		if _history_positions[index] >= position:
			best = index
			break
	return _history_levels[best]


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), LANE_BACK)
	var bar_width: float = width / BANDS
	for band: int in BANDS:
		var bar_height: float = height * (BAR_BASE + (1.0 - BAR_BASE) * _shown[band])
		draw_rect(Rect2(band * bar_width + 2.0, height - bar_height, bar_width - 4.0, bar_height), BAR_COLOR)
	# Cue lane: ticks move right-to-left and cross the hit line at their tap time.
	var hit_x: float = width * HIT_LINE_X
	var seconds_to_x: float = (width - hit_x) / LOOK_AHEAD_SEC
	for index: int in _cue_times.size():
		var ahead: float = _cue_times[index] - _heard_sec
		if ahead < -LOOK_BEHIND_SEC:
			continue
		if ahead > LOOK_AHEAD_SEC:
			break
		var x: float = hit_x + ahead * seconds_to_x
		draw_line(Vector2(x, 0.0), Vector2(x, height), Color(_cue_colors[index], 0.35), 2.0)
		draw_rect(Rect2(x - 5.0, 0.0, 10.0, 18.0), _cue_colors[index])
	draw_line(Vector2(hit_x, 0.0), Vector2(hit_x, height), Color(1.0, 1.0, 1.0, 0.4 + 0.6 * _flash), 2.0 + 4.0 * _flash)
