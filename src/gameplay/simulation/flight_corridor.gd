# Spike corridor of a chart's flight sections (gameplay v4): a floor and a ceiling height per bucket of track
# distance, built once at load from the perfect run tapped on time, early and late (fly_timing_margin_sec), padded
# by fly_clearance and widened to the section's gap. Collision is one lookup per step, however many spikes are drawn.
# Floating hazards (HazardDefinition.airborne) are lifted just above the path (below it when it flies high) and the
# corridor is widened around them.
# Related: run_simulation.gd, player_body.gd, src/gameplay/chart/flight_sections.gd, docs/design/gameplay_v4.md
class_name FlightCorridor
extends RefCounted

## Above this the path counts as high: floating hazards go under it instead of over it.
const HIGH_PATH: float = 6.0
## Corridor runs start this long before their section, on the road.
const SAMPLE_LEAD_BEATS: float = 0.5
## Floor value meaning "no floor spikes here" (the lift-off at a section's start).
const NO_FLOOR: float = -1000.0
## Buckets on each side merged into one (min floor / max ceiling) so the walls do not zigzag.
const SMOOTH_BUCKETS: int = 2

var bucket_length: float = 1.0
## Per section: distance of its first bucket, index of that bucket in `floors` / `ceilings`, and bucket count.
var starts: PackedFloat64Array = []
var offsets: PackedInt32Array = []
var counts: PackedInt32Array = []
var floors: PackedFloat32Array = []
var ceilings: PackedFloat32Array = []


## Builds chart.flight (null when the chart has no flight). Reports problems with push_error; false = invalid chart.
static func build(chart: LevelChart, config: GameplayConfig, source_name: String) -> bool:
	chart.flight = null
	if chart.fly_ranges.is_empty():
		for placement: ChartItems.HazardPlacement in chart.hazards:
			if placement.hazard.airborne:
				push_error("ChartLoader: %s: '%s' at beat %.3f must float inside a fly section" % [source_name,
						placement.hazard.id, placement.beat])
				return false
		return true
	var errors: PackedStringArray = FlightSections.validate(chart, config)
	var corridor := FlightCorridor.new()
	if errors.is_empty():
		errors = corridor._measure(chart, config)
	for message: String in errors:
		push_error("ChartLoader: %s: %s" % [source_name, message])
	if not errors.is_empty():
		return false
	chart.flight = corridor
	return true


## True when a box from `bottom` to `top` (heights above the road) at `distance` touches the spikes.
func hits(distance: float, bottom: float, top: float) -> bool:
	var index: int = bucket_at(distance)
	return index >= 0 and (bottom < floors[index] or top > ceilings[index])


## Index into `floors` / `ceilings` of the bucket at `distance`, or -1 outside every section.
func bucket_at(distance: float) -> int:
	for section: int in starts.size():
		var local: int = floori((distance - starts[section]) / bucket_length)
		if local >= 0 and local < counts[section]:
			return offsets[section] + local
	return -1


func _measure(chart: LevelChart, config: GameplayConfig) -> PackedStringArray:
	bucket_length = config.fly_bucket_length
	var errors: PackedStringArray = []
	var low: PackedFloat32Array = []
	var high: PackedFloat32Array = []
	for section: Vector2 in chart.fly_ranges:
		starts.append(chart.distance_at(section.x))
		offsets.append(low.size())
		var count: int = ceili((chart.distance_at(section.y) - starts[starts.size() - 1]) / bucket_length)
		counts.append(count)
		for index: int in count:
			low.append(INF)
			high.append(-INF)
	for section: Vector2 in chart.fly_ranges:
		for air: Vector2 in chart.airborne_ranges:
			if air.x < section.x and air.y > section.x - SAMPLE_LEAD_BEATS:
				errors.append("fly section %.3f..%.3f must lift off from the road (the player is in the air at %.3f)"
						% [section.x, section.y, section.x - SAMPLE_LEAD_BEATS])
	if not errors.is_empty():
		return errors
	var margin: float = config.fly_timing_margin_sec
	for shift: float in [0.0, -margin, margin]:
		_sample(chart, config, _taps(chart, config, shift), low, high)
	_place_floating_hazards(chart, config, low, high, errors)
	for section: int in starts.size():
		_shape(chart, config, section, low, high, errors)
	return errors


## The perfect run's tap beats, with the flap cues moved `shift_sec` (early < 0 < late).
static func _taps(chart: LevelChart, config: GameplayConfig, shift_sec: float) -> PackedFloat64Array:
	var taps: PackedFloat64Array = []
	for cue: ChartItems.ActionCue in chart.cues:
		var beat: float = cue.beat
		if cue.action.id == config.flap_action:
			beat = chart.beat_at_time(chart.time_at(beat) + shift_sec)
		taps.append(beat)
	taps.sort()
	return taps


## Runs the taps (invincible) through each section and records the player's lowest bottom / highest top per bucket.
## Each run starts on the road just before its section (sections lift off from the road, _measure checks it), so
## loading costs a few hundred steps per section instead of a whole-chart run.
func _sample(chart: LevelChart, config: GameplayConfig, taps: PackedFloat64Array, low: PackedFloat32Array,
		high: PackedFloat32Array) -> void:
	var step: float = config.simulation_step_beats * 2.0
	for section: Vector2 in chart.fly_ranges:
		var simulation := RunSimulation.new(chart, config, section.x - SAMPLE_LEAD_BEATS)
		simulation.invincible = true
		var next_tap: int = taps.bsearch(section.x - SAMPLE_LEAD_BEATS)
		var beat: float = section.x
		while beat < section.y:
			while next_tap < taps.size() and taps[next_tap] <= beat:
				simulation.tap(taps[next_tap])
				next_tap += 1
			simulation.advance_to(beat)
			var index: int = bucket_at(chart.distance_at(beat))
			if index >= 0:
				var height: float = simulation.player_height_at(beat)
				low[index] = minf(low[index], height + config.player_bottom)
				high[index] = maxf(high[index], height + config.player_top)
			beat += step


## Sets each floating hazard's height clear of the path (tapped on time, early or late) around it, and grows the
## envelope so the corridor encloses the hazard.
func _place_floating_hazards(chart: LevelChart, config: GameplayConfig, low: PackedFloat32Array,
		high: PackedFloat32Array, errors: PackedStringArray) -> void:
	for placement: ChartItems.HazardPlacement in chart.hazards:
		var hazard: HazardDefinition = placement.hazard
		if not hazard.airborne:
			continue
		var reach: float = hazard.half_length + config.player_half_length
		var first: int = bucket_at(placement.distance - reach)
		var last: int = bucket_at(placement.distance + reach)
		if first < 0 or last < 0:
			errors.append("'%s' at beat %.3f must float inside a fly section" % [hazard.id, placement.beat])
			continue
		var path_low: float = INF
		var path_high: float = -INF
		for index: int in range(first, last + 1):
			path_low = minf(path_low, low[index])
			path_high = maxf(path_high, high[index])
		var base: float = path_high + config.fly_clearance - hazard.bottom
		if path_high > HIGH_PATH:
			base = path_low - config.fly_clearance - hazard.top
		placement.base_height = base
		for index: int in range(first, last + 1):
			low[index] = minf(low[index], base + hazard.bottom)
			high[index] = maxf(high[index], base + hazard.top)


## Smooths, pads and widens one section's walls; the lift-off (first beat) has no floor.
func _shape(chart: LevelChart, config: GameplayConfig, section: int, low: PackedFloat32Array,
		high: PackedFloat32Array, errors: PackedStringArray) -> void:
	var range_beats: Vector2 = chart.fly_ranges[section]
	var lift_end: float = chart.distance_at(range_beats.x + 1.0)
	var gap: float = chart.fly_gaps[section]
	for local: int in counts[section]:
		var bottom: float = INF
		var top: float = -INF
		for near: int in range(maxi(local - SMOOTH_BUCKETS, 0), mini(local + SMOOTH_BUCKETS + 1, counts[section])):
			bottom = minf(bottom, low[offsets[section] + near])
			top = maxf(top, high[offsets[section] + near])
		var floor_height: float = bottom - config.fly_clearance
		var ceiling_height: float = top + config.fly_clearance
		var widen: float = maxf(gap - (ceiling_height - floor_height), 0.0) * 0.5
		floor_height -= widen
		ceiling_height += widen
		var distance: float = starts[section] + local * bucket_length
		if distance < lift_end:
			floor_height = NO_FLOOR
		elif bottom < config.fly_min_height:
			errors.append("fly section %.3f..%.3f: the perfect path dips to %.2f at beat %.2f (keep it above %.2f)"
					% [range_beats.x, range_beats.y, bottom, chart.beat_at_distance(distance), config.fly_min_height])
			floor_height = NO_FLOOR
		else:
			floor_height = maxf(floor_height, 0.0)
		floors.append(floor_height)
		ceilings.append(ceiling_height)
