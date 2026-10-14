# In-memory level: tempo, speed (beat→distance), sections, track shape, terrain and timed events.
# Built by ChartLoader from *.chart.json (plus ReferenceRun annotations); read-only afterwards.
# Related: src/gameplay/chart/chart_loader.gd, src/gameplay/chart/chart_items.gd, src/gameplay/track/terrain.gd
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
var terrain_segments: Array[ChartItems.TerrainSegment] = []
## Ground profile by distance, built from terrain_segments in finalize().
var terrain: Terrain
## Sorted by beat.
var cues: Array[ChartItems.ActionCue] = []
## Sorted by distance.
var hazards: Array[ChartItems.HazardPlacement] = []
## Sorted by distance.
var pads: Array[ChartItems.PadPlacement] = []
var camera_cues: Array[ChartItems.CameraCue] = []
var vfx_cues: Array[ChartItems.VfxCue] = []
## Filled by ReferenceRun (autoplay): player height at each cue (same index as `cues`) and the beat
## ranges (x = take-off, y = landing) where the autoplay player is in the air.
var cue_heights: PackedFloat32Array = []
var airborne_ranges: PackedVector2Array = []
## Also from ReferenceRun: the perfect run's vertical state from each beat on (empty for flat charts).
var reference_beats: PackedFloat64Array = []
var reference_motions: Array[VerticalMotion] = []


func distance_at(beat: float) -> float:
	return distance_map.map(beat)


func beat_at_distance(distance: float) -> float:
	return distance_map.inverse(distance)


func time_at(beat: float) -> float:
	return tempo.beat_to_time(beat)


func beat_at_time(time_sec: float) -> float:
	return tempo.time_to_beat(time_sec)


## Ground height under the player at `beat` for visuals (gaps report the ground before them).
func surface_height_at(beat: float) -> float:
	return terrain.surface_height_at(distance_at(beat))


## The perfect run's vertical state in effect at `beat`, or null (flat chart, or before it starts).
func reference_motion_at(beat: float) -> VerticalMotion:
	var index: int = reference_beats.bsearch(beat, false) - 1
	return reference_motions[index] if index >= 0 else null


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
## whose cue was skipped (practice / capture starts mid-chart), and never in mid-air.
## `lead_beats` = run-up before a cue or take-off.
func safe_start_beat(beat: float, lead_beats: float = 1.0) -> float:
	var result: float = beat
	while true:
		var earlier: float = _ground_safe_start(_cue_safe_start(result, lead_beats), lead_beats)
		if earlier >= result:
			return result
		result = earlier
	return result


func _cue_safe_start(beat: float, lead_beats: float) -> float:
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


## Moves `beat` before any jump or fall the autoplay player is still in (or has just landed from).
func _ground_safe_start(beat: float, lead_beats: float) -> float:
	const LANDING_MARGIN_BEATS: float = 0.25
	var result: float = beat
	for index: int in range(airborne_ranges.size() - 1, -1, -1):
		var air: Vector2 = airborne_ranges[index]
		if air.x < result and result < air.y + LANDING_MARGIN_BEATS:
			result = air.x - lead_beats
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
	terrain_segments.sort_custom(
			func(a: ChartItems.TerrainSegment, b: ChartItems.TerrainSegment) -> bool: return a.beat < b.beat)
	var starts: PackedFloat64Array = []
	var heights: PackedFloat64Array = []
	for segment: ChartItems.TerrainSegment in terrain_segments:
		starts.append(distance_at(segment.beat))
		heights.append(segment.height)
	terrain = Terrain.build(starts, heights)
	for placement: ChartItems.HazardPlacement in hazards:
		placement.distance = distance_at(placement.beat)
		placement.base_height = terrain.surface_height_at(placement.distance)
	for pad: ChartItems.PadPlacement in pads:
		pad.distance = distance_at(pad.beat)
		pad.base_height = terrain.surface_height_at(pad.distance)
	pads.sort_custom(func(a: ChartItems.PadPlacement, b: ChartItems.PadPlacement) -> bool: return a.distance < b.distance)
	hazards.sort_custom(
			func(a: ChartItems.HazardPlacement, b: ChartItems.HazardPlacement) -> bool:
				return a.distance < b.distance)
