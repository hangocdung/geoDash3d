# Recorder timeline: shows one whole segment (fixed view, the playhead moves across it) with the beat grid,
# taps per lane (raw dot + snapped diamond) and the selection. Mouse: click/drag on empty space = seek,
# click a note = select, drag it = move (time + lane), double-click = add a note, right-click = delete.
# Related: src/authoring/recorder/recorder.gd, src/authoring/recorder/recording_editor.gd
class_name RecorderTimeline
extends Control

signal seek_requested(time_sec: float)
signal add_requested(time_sec: float, lane: int)
signal move_requested(time_sec: float, lane: int)
signal delete_requested
signal selection_changed

const LANE_COUNT: int = 3
## Lane meaning for tools/charting/recording_level.py; colors match the gameplay hazards.
const LANE_NAMES: Array[String] = ["AUTO", "WALL", "GATE"]
const LANE_COLORS: Array[Color] = [Color(1.0, 0.3, 0.85), Color(1.0, 0.6, 0.2), Color(0.55, 1.0, 0.35)]
const RULER_HEIGHT: float = 34.0
const MARGIN_BEATS: float = 1.0
const PICK_RADIUS_PX: float = 20.0
const DRAG_THRESHOLD_PX: float = 6.0

var tempo: TempoMap
var editor: RecordingEditor
var now_sec: float = 0.0
var grid_beats: float = 0.5
var segment_start_beat: float = 0.0
var segment_end_beat: float = 16.0
var _drag_from: Vector2 = Vector2.INF
var _dragging: bool = false
var _seeking: bool = false


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if tempo == null or editor == null:
		return
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _drag_from != Vector2.INF:
		var mouse_position: Vector2 = (event as InputEventMouseMotion).position
		_dragging = _dragging or mouse_position.distance_to(_drag_from) > DRAG_THRESHOLD_PX
	elif event is InputEventMouseMotion and _seeking:
		seek_requested.emit(time_at_x((event as InputEventMouseMotion).position.x))


func _on_button(event: InputEventMouseButton) -> void:
	var time_sec: float = time_at_x(event.position.x)
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _pick(event.position) >= 0:
			editor.selected = _pick(event.position)
			delete_requested.emit()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if _dragging:
			move_requested.emit(time_sec, lane_at_y(event.position.y))
		_drag_from = Vector2.INF
		_dragging = false
		_seeking = false
		return
	var picked: int = _pick(event.position) if event.position.y > RULER_HEIGHT else -1
	if picked >= 0:
		editor.selected = picked
		_drag_from = event.position
		selection_changed.emit()
	elif event.double_click and event.position.y > RULER_HEIGHT:
		add_requested.emit(time_sec, lane_at_y(event.position.y))
	else:
		editor.deselect()
		selection_changed.emit()
		_seeking = true
		seek_requested.emit(time_sec)


func _draw() -> void:
	if tempo == null or editor == null:
		return
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.06))
	var left: float = _x_for(tempo.beat_to_time(segment_start_beat))
	var right: float = _x_for(tempo.beat_to_time(segment_end_beat))
	draw_rect(Rect2(left, 0, right - left, size.y), Color(0.07, 0.04, 0.16))
	draw_rect(Rect2(0, 0, size.x, RULER_HEIGHT), Color(0.1, 0.07, 0.22))
	for lane: int in LANE_COUNT:
		var y: float = _y_for_lane(lane)
		draw_line(Vector2(0, y), Vector2(size.x, y), LANE_COLORS[lane] * Color(1, 1, 1, 0.15), 1.0)
		draw_string(font, Vector2(8, y - 14), LANE_NAMES[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				LANE_COLORS[lane] * Color(1, 1, 1, 0.7))
	var first_step: int = ceili((segment_start_beat - MARGIN_BEATS) / grid_beats)
	var last_step: int = floori((segment_end_beat + MARGIN_BEATS) / grid_beats)
	for step: int in range(first_step, last_step + 1):
		var beat: float = step * grid_beats
		var x: float = _x_for(tempo.beat_to_time(beat))
		var whole: bool = is_equal_approx(beat, roundf(beat))
		var bar: bool = whole and posmod(roundi(beat), 4) == 0
		draw_line(Vector2(x, RULER_HEIGHT), Vector2(x, size.y),
				Color(0.45, 0.4, 0.9, 0.9 if bar else (0.4 if whole else 0.15)), 2.0 if bar else 1.0)
		if whole:
			var text: String = "%d" % (roundi(beat) / 4 + 1) if bar else ".%d" % (posmod(roundi(beat), 4) + 1)
			draw_string(font, Vector2(x + 3, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if bar else 14,
					Color(0.8, 0.8, 1.0, 1.0 if bar else 0.55))
	_draw_taps(font)
	var playhead: float = _x_for(now_sec)
	draw_line(Vector2(playhead, 0), Vector2(playhead, size.y), Color(0.4, 1.0, 1.0), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(playhead - 9, 0), Vector2(playhead + 9, 0),
			Vector2(playhead, 14)]), Color(0.4, 1.0, 1.0))


func _draw_taps(font: Font) -> void:
	var recording: Recording = editor.recording
	var start_time: float = time_at_x(0.0)
	var end_time: float = time_at_x(size.x)
	for index: int in range(recording.tap_times.bsearch(start_time), recording.count()):
		var tap_time: float = recording.tap_times[index]
		if tap_time > end_time:
			break
		var lane: int = clampi(recording.tap_lanes[index], 0, LANE_COUNT - 1)
		var center := Vector2(_x_for(editor.snap_time(tap_time, grid_beats)), _y_for_lane(lane))
		draw_circle(Vector2(_x_for(tap_time), center.y), 3.0, Color(1, 1, 1, 0.5))
		if index == editor.selected:
			draw_circle(center, 18.0, Color(1, 1, 1, 0.9), false, 3.0)
			if _dragging:
				var mouse: Vector2 = get_local_mouse_position()
				var ghost := Vector2(_x_for(editor.snap_time(time_at_x(mouse.x), grid_beats)),
						_y_for_lane(lane_at_y(mouse.y)))
				_draw_diamond(ghost, 13.0, Color(1, 1, 1, 0.6))
		_draw_diamond(center, 11.0, LANE_COLORS[lane])
	if recording.count() == 0:
		draw_string(font, Vector2(0, size.y * 0.5), "Press Play and tap along (J / K / L or the pads below)",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.7, 0.75, 0.9, 0.6))


func time_at_x(x: float) -> float:
	var start: float = tempo.beat_to_time(segment_start_beat - MARGIN_BEATS)
	var end: float = tempo.beat_to_time(segment_end_beat + MARGIN_BEATS)
	return start + clampf(x / size.x, 0.0, 1.0) * (end - start)


func lane_at_y(y: float) -> int:
	var lane_height: float = (size.y - RULER_HEIGHT) / float(LANE_COUNT)
	return clampi(floori((y - RULER_HEIGHT) / lane_height), 0, LANE_COUNT - 1)


## Index of the tap whose diamond is under `point`, or -1.
func _pick(point: Vector2) -> int:
	var radius: float = (time_at_x(PICK_RADIUS_PX) - time_at_x(0.0))
	var index: int = editor.recording.nearest(time_at_x(point.x), radius * 2.0)
	if index < 0:
		return -1
	var center := Vector2(_x_for(editor.snap_time(editor.recording.tap_times[index], grid_beats)),
			_y_for_lane(editor.recording.tap_lanes[index]))
	return index if center.distance_to(point) <= PICK_RADIUS_PX else -1


func _x_for(time_sec: float) -> float:
	var start: float = tempo.beat_to_time(segment_start_beat - MARGIN_BEATS)
	var end: float = tempo.beat_to_time(segment_end_beat + MARGIN_BEATS)
	return (time_sec - start) / (end - start) * size.x


func _y_for_lane(lane: int) -> float:
	var lane_height: float = (size.y - RULER_HEIGHT) / float(LANE_COUNT)
	return RULER_HEIGHT + lane_height * (float(lane) + 0.5)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
