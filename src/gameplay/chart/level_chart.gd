# In-memory level: tempo, speed (beat→distance), sections, track shape, terrain and timed events.
# Built by ChartLoader from *.chart.json (plus ReferenceRun annotations); read-only afterwards.
# Related: src/gameplay/chart/chart_loader.gd, src/gameplay/chart/chart_items.gd, src/gameplay/track/terrain.gd
class_name LevelChart
extends RefCounted

var title: String = ""
var revision: int = 1
var artist: String = ""
var song_path: String = ""
var end_beat: float = 0.0
var tempo: TempoMap
## beat → distance along the track (units).
var distance_map: PiecewiseLinearMap
var sections: Array[ChartItems.Section] = []
## Sorted by beat; empty = one phase for the whole level.
var phases: Array[ChartItems.Phase] = []
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
## Underside runs (GD3-112): x = the beat a flip_down has the player under the track, y = its flip_up's beat.
var underside_ranges: PackedVector2Array = []
## Also from ReferenceRun: the perfect run's vertical state from each beat on (empty for flat charts).
var reference_beats: PackedFloat64Array = []
var reference_motions: Array[VerticalMotion] = []
## Flight sections (gameplay v4): x = start beat, y = end beat, sorted; `fly_gaps` = their narrowest corridor.
var fly_ranges: PackedVector2Array = []
var fly_gaps: PackedFloat32Array = []
## Spike corridor of the flight sections, built from the perfect run (null when the chart has none).
var flight: FlightCorridor = null


func distance_at(beat: float) -> float:
	return distance_map.map(beat)


func beat_at_distance(distance: float) -> float:
	return distance_map.inverse(distance)


## Track units travelled per beat at `beat`.
func speed_at(beat: float) -> float:
	return distance_map.rate_at(beat)


func time_at(beat: float) -> float:
	return tempo.beat_to_time(beat)


func beat_at_time(time_sec: float) -> float:
	return tempo.time_to_beat(time_sec)


## Ground height under the player at `beat` for visuals (gaps report the ground before them).
func surface_height_at(beat: float) -> float:
	return terrain.surface_height_at(distance_at(beat))


## True while the player runs under the track (between a flip_down's end and its flip_up).
func is_underside_at(beat: float) -> bool:
	for run: Vector2 in underside_ranges:
		if run.x <= beat and beat < run.y:
			return true
	return false


## True when the player taps `cue` from under the track (jumps of an underside run and its flip_up).
func is_cue_underside(cue: ChartItems.ActionCue) -> bool:
	return cue.action.flip_part == ActionDefinition.FlipPart.UP or is_underside_at(cue.beat)


## True when `hazard` placed at `beat` hangs under the track (HazardDefinition.face).
func is_hazard_underside(hazard: HazardDefinition, beat: float) -> bool:
	match hazard.face:
		HazardDefinition.Face.TOP:
			return false
		HazardDefinition.Face.UNDERSIDE:
			return true
	return is_underside_at(beat)


## The perfect run's vertical state in effect at `beat`, or null (flat chart, or before it starts).
## Index of the flight section containing `beat` ([start, end)), or -1.
func fly_range_at(beat: float) -> int:
	for index: int in fly_ranges.size():
		if fly_ranges[index].x <= beat and beat < fly_ranges[index].y:
			return index
	return -1


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


## Index into `phases` of the phase in effect at `beat` (0 before the first phase starts, -1 without phases).
func phase_index_at(beat: float) -> int:
	if phases.is_empty():
		return -1
	var current: int = 0
	for index: int in phases.size():
		if phases[index].beat > beat:
			break
		current = index
	return current


## Latest beat <= `beat` where a run can start without stranding the player in front of a hazard
## whose cue was skipped (practice / capture starts mid-chart), and never in mid-air.
## `lead_beats` = run-up before a cue or take-off.
func safe_start_beat(beat: float, lead_beats: float = 1.0) -> float:
	var result: float = beat
	while true:
		var earlier: float = _underside_safe_start(_ground_safe_start(_cue_safe_start(result, lead_beats), lead_beats),
				lead_beats)
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


## Moves `beat` before an underside run it falls in (from its flip_down to the end of its flip_up).
func _underside_safe_start(beat: float, lead_beats: float) -> float:
	const FLIP_BEATS: float = 1.0
	var result: float = beat
	for run: Vector2 in underside_ranges:
		if run.x - FLIP_BEATS < result and result < run.y + FLIP_BEATS:
			result = run.x - FLIP_BEATS - lead_beats
	return result


## Sorts events and fills derived fields. Called once by the loader.
func finalize() -> void:
	sections.sort_custom(func(a: ChartItems.Section, b: ChartItems.Section) -> bool: return a.beat < b.beat)
	phases.sort_custom(func(a: ChartItems.Phase, b: ChartItems.Phase) -> bool: return a.beat < b.beat)
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
	underside_ranges.clear()
	var open: float = NAN
	for cue: ChartItems.ActionCue in cues:
		match cue.action.flip_part if cue.action.kind == ActionDefinition.Kind.FLIP else -1:
			ActionDefinition.FlipPart.DOWN:
				open = cue.beat + cue.action.duration_beats
			ActionDefinition.FlipPart.UP:
				if not is_nan(open):
					underside_ranges.append(Vector2(open, cue.beat))
				open = NAN
	for placement: ChartItems.HazardPlacement in hazards:
		placement.distance = distance_at(placement.beat)
		placement.underside = is_hazard_underside(placement.hazard, placement.beat)
		placement.base_height = 0.0 if placement.underside else terrain.surface_height_at(placement.distance)
	for pad: ChartItems.PadPlacement in pads:
		pad.distance = distance_at(pad.beat)
		pad.base_height = terrain.surface_height_at(pad.distance)
	pads.sort_custom(func(a: ChartItems.PadPlacement, b: ChartItems.PadPlacement) -> bool: return a.distance < b.distance)
	hazards.sort_custom(
			func(a: ChartItems.HazardPlacement, b: ChartItems.HazardPlacement) -> bool:
				return a.distance < b.distance)
