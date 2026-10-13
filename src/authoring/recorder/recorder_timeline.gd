# Scrolling timeline for the recorder: beat/bar grid, recorded taps per lane (raw dot + snapped
# diamond at the current grid) and a fixed playhead. Pure drawing, fed by Recorder each frame.
# Related: src/authoring/recorder/recorder.gd, src/authoring/recorder/recording.gd
class_name RecorderTimeline
extends Control

const PAST_SEC: float = 2.5
const FUTURE_SEC: float = 5.0
const LANE_COUNT: int = 3
const LANE_COLORS: Array[Color] = [Color(1.0, 0.3, 0.85), Color(1.0, 0.75, 0.2), Color(0.55, 1.0, 0.35)]

var tempo: TempoMap
var recording: Recording
var now_sec: float = 0.0
var grid_beats: float = 0.5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if tempo == null or recording == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.12, 0.9))
	var start_time: float = now_sec - PAST_SEC
	var end_time: float = now_sec + FUTURE_SEC
	var font: Font = get_theme_default_font()
	var first_beat: int = floori(tempo.time_to_beat(start_time) / grid_beats)
	var last_beat: int = ceili(tempo.time_to_beat(end_time) / grid_beats)
	for step: int in range(first_beat, last_beat + 1):
		var beat: float = step * grid_beats
		var x: float = _x_for(tempo.beat_to_time(beat))
		var whole: bool = is_equal_approx(beat, roundf(beat))
		var bar: bool = whole and posmod(roundi(beat), 4) == 0
		var color := Color(0.45, 0.4, 0.9, 0.9 if bar else (0.45 if whole else 0.18))
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 2.0 if bar else 1.0)
		if bar:
			draw_string(font, Vector2(x + 4, 22), str(roundi(beat) / 4 + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
					Color(0.7, 0.7, 1.0))
	var from_index: int = recording.tap_times.bsearch(start_time)
	for index: int in range(from_index, recording.count()):
		var tap_time: float = recording.tap_times[index]
		if tap_time > end_time:
			break
		var lane: int = clampi(recording.tap_lanes[index], 0, LANE_COUNT - 1)
		var y: float = _y_for_lane(lane)
		var snapped_beat: float = roundf(tempo.time_to_beat(tap_time) / grid_beats) * grid_beats
		var snapped_x: float = _x_for(tempo.beat_to_time(snapped_beat))
		draw_circle(Vector2(_x_for(tap_time), y), 3.0, Color(1, 1, 1, 0.5))
		_draw_diamond(Vector2(snapped_x, y), 11.0, LANE_COLORS[lane])
	var playhead: float = _x_for(now_sec)
	draw_line(Vector2(playhead, 0), Vector2(playhead, size.y), Color(0.4, 1.0, 1.0), 3.0)


func _x_for(time_sec: float) -> float:
	return (time_sec - (now_sec - PAST_SEC)) / (PAST_SEC + FUTURE_SEC) * size.x


func _y_for_lane(lane: int) -> float:
	return size.y * (float(lane) + 1.0) / float(LANE_COUNT + 1)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
