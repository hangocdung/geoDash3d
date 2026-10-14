# Recorder note editing: picking, nudging/adding/moving on the grid, deleting, clearing a segment, undo/redo,
# and the shared recording path of levels built from a recording.
# Related: src/authoring/recorder/recording_editor.gd, recording.gd
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


func test_delete_keeps_a_valid_selection() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0])
	assert_false(editor.delete_selected(), "nothing selected")
	editor.selected = 1
	assert_true(editor.delete_selected())
	assert_eq(editor.recording.count(), 1)
	assert_eq(editor.selected, 0)


func test_clear_range_only_touches_its_taps() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0, 3.0, 4.0])
	assert_eq(editor.clear_range(5.0, 6.0), 0)
	assert_false(editor.can_undo(), "nothing removed, no undo step")
	assert_eq(editor.clear_range(2.0, 4.0), 2)
	assert_eq(editor.recording.tap_times, PackedFloat64Array([1.0, 4.0]))


func test_add_and_move_snap_to_the_grid() -> void:
	var editor: RecordingEditor = _make_editor([1.0])
	editor.add_tap(1.6, 0.5)
	assert_almost_eq(editor.selected_time(), 1.5, 0.000001, "beat 3.2 snaps to 3")
	assert_true(editor.move_selected(0.3, 0.5))
	assert_eq(editor.selected, 0, "moved before the tap at 1.0 s")
	assert_almost_eq(editor.selected_time(), 0.25)


func test_undo_redo_restores_taps_and_selection() -> void:
	var editor: RecordingEditor = _make_editor([1.0, 2.0])
	editor.record_tap(1.5)
	editor.selected = 2
	editor.delete_selected()
	assert_eq(editor.recording.count(), 2)
	assert_true(editor.undo())
	assert_eq(editor.recording.count(), 3)
	assert_eq(editor.selected, 2, "selection comes back with the deleted tap")
	assert_true(editor.undo())
	assert_eq(editor.recording.tap_times, PackedFloat64Array([1.0, 2.0]))
	assert_false(editor.undo())
	assert_true(editor.redo())
	assert_true(editor.redo())
	assert_eq(editor.recording.tap_times, PackedFloat64Array([1.0, 1.5]))
	editor.record_tap(3.0)
	assert_false(editor.can_redo(), "a new edit drops the redo history")


func test_built_level_shares_the_source_recording() -> void:
	assert_eq(Recording.path_for_chart("res://assets/music/song.chart.json"), "res://assets/music/song.recording.json")
	assert_eq(Recording.path_for_chart("res://assets/music/song.rec.chart.json"), "res://assets/music/song.recording.json")


func test_align_removes_a_steady_delay() -> void:
	# Taps 0.1 s (0.2 beat) late around beats 2, 4 and 6, plus one tap outside the range.
	var editor: RecordingEditor = _make_editor([1.1, 2.08, 3.12, 9.1])
	var shift: float = editor.align_range(0.0, 5.0, 1.0)
	assert_almost_eq(shift, -0.1, 0.005)
	assert_almost_eq(editor.recording.tap_times[0], 1.0, 0.005)
	assert_almost_eq(editor.recording.tap_times[2], 3.02, 0.005)
	assert_almost_eq(editor.recording.tap_times[3], 9.1, 0.000001, "outside the range")
	assert_true(editor.undo())
	assert_almost_eq(editor.recording.tap_times[0], 1.1)
	assert_almost_eq(editor.align_range(20.0, 30.0, 1.0), 0.0, 0.000001, "no taps, no shift")
