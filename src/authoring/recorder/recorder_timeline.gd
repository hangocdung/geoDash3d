# Scrolling timeline for the recorder: beat/bar grid, recorded taps per lane (raw dot + snapped
# diamond at the current grid), the selected tap, the A–B loop and a fixed playhead. Pure drawing, fed
# by Recorder each frame; time_at_x() maps mouse clicks back to song time.
# Related: src/authoring/recorder/recorder.gd, src/authoring/recorder/recording_editor.gd
class_name RecorderTimeline
extends Control

const PAST_SEC: float = 2.5
const FUTURE_SEC: float = 5.0
const LANE_COUNT: int = 3
## Lane meaning for tools/charting/recording_level.py; colors match the gameplay hazards.
const LANE_NAMES: Array[String] = ["AUTO", "WALL", "GATE"]
const LANE_COLORS: Array[Color] = [Color(1.0, 0.3, 0.85), Color(1.0, 0.6, 0.2), Color(0.55, 1.0, 0.35)]
const LOOP_COLOR: Color = Color(0.3, 0.9, 1.0, 0.12)

var tempo: TempoMap
var editor: RecordingEditor
var now_sec: float = 0.0
var grid_beats: float = 0.5
## Seconds of song shown across the width (shrinks at slow speed so the notes spread out).
var zoom: float = 1.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if tempo == null or editor == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.12, 0.9))
	var start_time: float = time_at_x(0.0)
	var end_time: float = time_at_x(size.x)
	var font: Font = get_theme_default_font()
	if editor.has_loop_start():
		var loop_end: float = editor.loop_end_sec if editor.has_loop() else now_sec
		var left: float = _x_for(editor.loop_start_sec)
		draw_rect(Rect2(left, 0, _x_for(loop_end) - left, size.y), LOOP_COLOR)
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
	for lane: int in LANE_COUNT:
		draw_string(font, Vector2(8, _y_for_lane(lane) - 16), LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				LANE_COLORS[lane] * Color(1, 1, 1, 0.6))
	_draw_taps(start_time, end_time)
	var playhead: float = _x_for(now_sec)
	draw_line(Vector2(playhead, 0), Vector2(playhead, size.y), Color(0.4, 1.0, 1.0), 3.0)


func _draw_taps(start_time: float, end_time: float) -> void:
	var recording: Recording = editor.recording
	var from_index: int = recording.tap_times.bsearch(start_time)
	for index: int in range(from_index, recording.count()):
		var tap_time: float = recording.tap_times[index]
		if tap_time > end_time:
			break
		var lane: int = clampi(recording.tap_lanes[index], 0, LANE_COUNT - 1)
		var y: float = _y_for_lane(lane)
		var snapped_beat: float = roundf(tempo.time_to_beat(tap_time) / grid_beats) * grid_beats
		var snapped: Vector2 = Vector2(_x_for(tempo.beat_to_time(snapped_beat)), y)
		draw_circle(Vector2(_x_for(tap_time), y), 3.0, Color(1, 1, 1, 0.5))
		if index == editor.selected:
			draw_circle(snapped, 18.0, Color(1, 1, 1, 0.9), false, 3.0)
		_draw_diamond(snapped, 11.0, LANE_COLORS[lane])


func time_at_x(x: float) -> float:
	return now_sec - PAST_SEC * zoom + x / size.x * (PAST_SEC + FUTURE_SEC) * zoom


## Song seconds covered by `pixels` on screen (for click pick radii).
func seconds_per_pixels(pixels: float) -> float:
	return pixels / size.x * (PAST_SEC + FUTURE_SEC) * zoom


func _x_for(time_sec: float) -> float:
	return (time_sec - (now_sec - PAST_SEC * zoom)) / ((PAST_SEC + FUTURE_SEC) * zoom) * size.x


func _y_for_lane(lane: int) -> float:
	return size.y * (float(lane) + 1.0) / float(LANE_COUNT + 1)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
