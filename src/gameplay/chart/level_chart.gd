# In-memory level: tempo, speed (beat→distance), sections, track shape and timed events.
# Built by ChartLoader from *.chart.json; read-only afterwards.
# Related: src/gameplay/chart/chart_loader.gd, src/gameplay/chart/chart_items.gd
class_name LevelChart
extends RefCounted

var title: String = ""
var artist: String = ""
var song_path: String = ""
var end_beat: float = 0.0
var tempo: TempoMap
## beat → distance along the track (units).
var distance_map: PiecewiseLinearMap
var sections: Array[ChartItems.Section] = []
var track_segments: Array[ChartItems.TrackSegment] = []
## Sorted by beat.
var cues: Array[ChartItems.ActionCue] = []
## Sorted by distance.
var hazards: Array[ChartItems.HazardPlacement] = []
var camera_cues: Array[ChartItems.CameraCue] = []
var vfx_cues: Array[ChartItems.VfxCue] = []


func distance_at(beat: float) -> float:
	return distance_map.map(beat)


func beat_at_distance(distance: float) -> float:
	return distance_map.inverse(distance)


func time_at(beat: float) -> float:
	return tempo.beat_to_time(beat)


func beat_at_time(time_sec: float) -> float:
	return tempo.time_to_beat(time_sec)


func progress_at(beat: float) -> float:
	if end_beat <= 0.0:
		return 0.0
	return clampf(beat / end_beat, 0.0, 1.0)


func section_at(beat: float) -> ChartItems.Section:
	var current: ChartItems.Section = null
	for section: ChartItems.Section in sections:
		if section.beat > beat:
			break
		current = section
	return current


## Latest beat <= `beat` where a run can start without stranding the player in front of a hazard
## whose cue was skipped (practice / capture starts mid-chart). `lead_beats` = run-up before a cue.
func safe_start_beat(beat: float, lead_beats: float = 1.0) -> float:
	const HAZARD_MARGIN_BEATS: float = 0.5
	var result: float = beat
	for index: int in range(cues.size() - 1, -1, -1):
		var cue: ChartItems.ActionCue = cues[index]
		if cue.beat >= result:
			continue
		var hazard_end: float = cue.beat + cue.action.hazard_beat_offset + HAZARD_MARGIN_BEATS
		if hazard_end < result:
			break
		result = cue.beat - lead_beats
	return result


## Sorts events and fills derived fields. Called once by the loader.
func finalize() -> void:
	sections.sort_custom(func(a: ChartItems.Section, b: ChartItems.Section) -> bool: return a.beat < b.beat)
	track_segments.sort_custom(
			func(a: ChartItems.TrackSegment, b: ChartItems.TrackSegment) -> bool: return a.beat < b.beat)
	cues.sort_custom(func(a: ChartItems.ActionCue, b: ChartItems.ActionCue) -> bool: return a.beat < b.beat)
	camera_cues.sort_custom(
			func(a: ChartItems.CameraCue, b: ChartItems.CameraCue) -> bool: return a.beat < b.beat)
	vfx_cues.sort_custom(func(a: ChartItems.VfxCue, b: ChartItems.VfxCue) -> bool: return a.beat < b.beat)
	for placement: ChartItems.HazardPlacement in hazards:
		placement.distance = distance_at(placement.beat)
	hazards.sort_custom(
			func(a: ChartItems.HazardPlacement, b: ChartItems.HazardPlacement) -> bool:
				return a.distance < b.distance)
