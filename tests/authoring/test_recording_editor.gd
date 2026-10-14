# Recorder note editing: picking, nudging on the grid, lanes, loop re-record, and the shared recording path
# of levels built from a recording. Related: src/authoring/recorder/recording_editor.gd, recording.gd
extends TestCase


## 120 BPM, no offset: beat b is at b / 2 seconds.
func _make_editor(times: Array[float]) -> RecordingEditor:
	var recording := Recording.new()
	for time_sec: float in times:
		recording.add_tap(time_sec, 0)
	return RecordingEditor.new(recording, TempoMap.constant(120.0, 0.0))


func test_nearest_respects_radius() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0, 3.0])
	assert_true(editor.select_near(2.04, 0.1))
	assert_eq(editor.selected, 1)
	assert_false(editor.select_near(2.5, 0.1))
	assert_eq(editor.selected, -1)


func test_select_step_starts_at_the_playhead() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0, 3.0])
	editor.select_step(1.5, 1)
	assert_eq(editor.selected, 1)
	editor.select_step(1.5, 1)
	assert_eq(editor.selected, 2)
	editor.select_step(1.5, 1)
	assert_eq(editor.selected, 2, "stays on the last tap")
	editor.deselect()
	editor.select_step(1.5, -1)
	assert_eq(editor.selected, 0)


func test_nudge_snaps_then_moves_and_keeps_order() -> void:
	var editor: RecordingEditor = _make_editor([1.03, 2.0])
	editor.selected = 0
	assert_true(editor.nudge_selected(0, 0.5))
	assert_almost_eq(editor.recording.tap_times[0], 1.0, 0.000001, "snapped to beat 2")
	for step: int in 5:
		editor.nudge_selected(1, 0.5)
	assert_almost_eq(editor.selected_time(), 2.25, 0.000001, "beat 4.5")
	assert_eq(editor.selected, 1, "the moved tap is now after the one at 2.0 s")
	assert_almost_eq(editor.recording.tap_times[0], 2.0)


func test_lane_and_delete() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0])
	assert_false(editor.set_selected_lane(2), "nothing selected")
	editor.selected = 1
	assert_true(editor.set_selected_lane(2))
	assert_eq(editor.recording.tap_lanes[1], 2)
	assert_true(editor.delete_selected())
	assert_eq(editor.recording.count(), 1)
	assert_eq(editor.selected, 0)


func test_loop_clears_only_its_taps() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0, 3.0, 4.0])
	editor.set_loop_start(2.0)
	assert_false(editor.has_loop())
	assert_eq(editor.clear_loop_taps(), 0)
	editor.set_loop_end(4.0)
	assert_true(editor.has_loop())
	assert_eq(editor.clear_loop_taps(), 2)
	assert_eq(editor.recording.tap_times, PackedFloat64Array([1.0, 4.0]))


func test_loop_end_before_start_is_rejected() -> void:
	var editor: RecordingEditor = _make_editor([])
	editor.set_loop_start(3.0)
	expect_errors(1)
	editor.set_loop_end(2.0)
	assert_false(editor.has_loop())


func test_built_level_shares_the_source_recording() -> void:
	assert_eq(Recording.path_for_chart("res://assets/music/song.chart.json"), "res://assets/music/song.recording.json")
	assert_eq(Recording.path_for_chart("res://assets/music/song.rec.chart.json"), "res://assets/music/song.recording.json")
