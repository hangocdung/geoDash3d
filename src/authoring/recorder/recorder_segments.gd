# Splits a song into short editing segments for the recorder: each chart section is cut into chunks of
# SEGMENT_BEATS (a short leftover joins the previous chunk). Pure data, no nodes.
# Related: src/authoring/recorder/recorder.gd, src/gameplay/chart/level_chart.gd
class_name RecorderSegments
extends RefCounted

const SEGMENT_BEATS: float = 16.0
## A leftover shorter than this is merged into the chunk before it.
const MIN_SEGMENT_BEATS: float = 6.0


class Segment:
	var start_beat: float
	var end_beat: float
	var label: String
	## Energy of the chart section it belongs to (0..1).
	var energy: float

	func _init(start: float, end: float, segment_label: String, segment_energy: float) -> void:
		start_beat = start
		end_beat = end
		label = segment_label
		energy = segment_energy


## Sections (beat, name, energy), sorted; sections before beat 0 start at 0.
static func split(section_beats: PackedFloat64Array, section_names: PackedStringArray,
		section_energies: PackedFloat32Array, end_beat: float) -> Array[Segment]:
	var segments: Array[Segment] = []
	if section_beats.size() != section_names.size() or section_beats.size() != section_energies.size():
		push_error("RecorderSegments: %d section beats, %d names, %d energies" % [section_beats.size(),
				section_names.size(), section_energies.size()])
		return segments
	var starts: PackedFloat64Array = [0.0]
	var names: PackedStringArray = ["intro"]
	var energies: PackedFloat32Array = [0.5]
	for index: int in section_beats.size():
		var beat: float = maxf(section_beats[index], 0.0)
		if beat >= end_beat:
			break
		if is_equal_approx(beat, starts[starts.size() - 1]):
			names[names.size() - 1] = section_names[index]
			energies[energies.size() - 1] = section_energies[index]
		else:
			starts.append(beat)
			names.append(section_names[index])
			energies.append(section_energies[index])
	starts.append(end_beat)
	for index: int in names.size():
		var span_start: float = starts[index]
		var span_end: float = starts[index + 1]
		var count: int = maxi(1, floori((span_end - span_start + SEGMENT_BEATS - MIN_SEGMENT_BEATS) / SEGMENT_BEATS))
		for chunk: int in count:
			var chunk_start: float = span_start + chunk * SEGMENT_BEATS
			var chunk_end: float = span_end if chunk == count - 1 else chunk_start + SEGMENT_BEATS
			var label: String = names[index] if count == 1 else "%s %d/%d" % [names[index], chunk + 1, count]
			segments.append(Segment.new(chunk_start, chunk_end, label, energies[index]))
	return segments


static func from_chart(chart: LevelChart) -> Array[Segment]:
	var beats: PackedFloat64Array = []
	var names: PackedStringArray = []
	var energies: PackedFloat32Array = []
	for section: ChartItems.Section in chart.sections:
		beats.append(section.beat)
		names.append(String(section.name))
		energies.append(section.energy)
	return split(beats, names, energies, chart.end_beat)


## Index of the segment containing `beat` (clamped to the first/last).
static func index_at(segments: Array[Segment], beat: float) -> int:
	for index: int in range(segments.size() - 1, -1, -1):
		if beat >= segments[index].start_beat:
			return index
	return 0
