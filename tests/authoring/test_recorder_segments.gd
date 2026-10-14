# Recorder segments: sections cut into 16-beat chunks, short leftovers merged, lookup by beat.
# Related: src/authoring/recorder/recorder_segments.gd
extends TestCase


func _spans(segments: Array[RecorderSegments.Segment]) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for segment: RecorderSegments.Segment in segments:
		spans.append(Vector2(segment.start_beat, segment.end_beat))
	return spans


func test_sections_are_cut_into_chunks() -> void:
	var segments: Array[RecorderSegments.Segment] = RecorderSegments.split(
			PackedFloat64Array([-16.0, 32.0, 52.0]), PackedStringArray(["intro", "drop", "outro"]), 70.0)
	assert_eq(_spans(segments), [Vector2(0, 16), Vector2(16, 32), Vector2(32, 52), Vector2(52, 70)] as Array[Vector2],
			"the 20-beat drop keeps its 4-beat leftover; the 18-beat outro stays whole")
	assert_eq(segments[0].label, "intro 1/2")
	assert_eq(segments[2].label, "drop")


func test_long_leftover_gets_its_own_chunk() -> void:
	var segments: Array[RecorderSegments.Segment] = RecorderSegments.split(
			PackedFloat64Array([0.0]), PackedStringArray(["verse"]), 24.0)
	assert_eq(_spans(segments), [Vector2(0, 16), Vector2(16, 24)] as Array[Vector2])


func test_index_at_clamps() -> void:
	var segments: Array[RecorderSegments.Segment] = RecorderSegments.split(
			PackedFloat64Array([0.0]), PackedStringArray(["verse"]), 48.0)
	assert_eq(RecorderSegments.index_at(segments, -3.0), 0)
	assert_eq(RecorderSegments.index_at(segments, 20.0), 1)
	assert_eq(RecorderSegments.index_at(segments, 99.0), 2)


func test_mismatched_input_is_rejected() -> void:
	expect_errors(1)
	assert_eq(RecorderSegments.split(PackedFloat64Array([0.0]), PackedStringArray([]), 16.0).size(), 0)
