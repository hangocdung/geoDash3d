# Flight sections of a chart (gameplay v4): reads the optional `fly` list into LevelChart.fly_ranges and checks the
# rules: sections inside the chart and apart, over flat unbroken road, only `flap` cues inside them (and flaps only
# there), no pads / hazards / underside runs inside, time to land before the next ground cue.
# Related: src/gameplay/chart/chart_loader.gd, src/gameplay/simulation/flight_corridor.gd, docs/design/gameplay_v4.md
class_name FlightSections
extends RefCounted


## Fills chart.fly_ranges / fly_gaps from the `fly` entries; returns the problems found.
static func parse(entries: Array[Dictionary], chart: LevelChart, config: GameplayConfig) -> PackedStringArray:
	var errors: PackedStringArray = []
	var sections: Array[Vector3] = []
	for entry: Dictionary in entries:
		var start: Variant = entry.get("beat")
		var end: Variant = entry.get("end")
		if not (start is float or start is int) or not (end is float or end is int):
			errors.append("fly entries need numeric 'beat' and 'end'")
			continue
		var gap: float = float(entry.get("gap", config.fly_min_gap))
		if float(end) - float(start) < 2.0:
			errors.append("fly section at beat %.3f is shorter than 2 beats" % float(start))
			continue
		if gap < config.fly_min_gap:
			errors.append("fly section at beat %.3f: 'gap' %.2f is below the minimum %.2f" % [float(start), gap,
					config.fly_min_gap])
			gap = config.fly_min_gap
		sections.append(Vector3(float(start), float(end), gap))
	sections.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	for section: Vector3 in sections:
		chart.fly_ranges.append(Vector2(section.x, section.y))
		chart.fly_gaps.append(section.z)
	return errors


## Checks a finalized chart's flight sections against its cues, terrain, pads, hazards and underside runs.
static func validate(chart: LevelChart, config: GameplayConfig) -> PackedStringArray:
	var errors: PackedStringArray = []
	for index: int in chart.fly_ranges.size():
		var section: Vector2 = chart.fly_ranges[index]
		var where: String = "fly section %.3f..%.3f" % [section.x, section.y]
		if section.x < 0.0 or section.y > chart.end_beat:
			errors.append("%s is outside the chart" % where)
		if index > 0 and section.x < chart.fly_ranges[index - 1].y + config.fly_exit_beats:
			errors.append("%s starts before the previous one has landed" % where)
		var road_from: float = chart.distance_at(section.x - 1.0)
		var road_to: float = chart.distance_at(section.y + config.fly_exit_beats)
		if not chart.terrain.is_level(road_from, road_to, 0.0):
			errors.append("%s needs flat, unbroken road under it and until the landing" % where)
		for run: Vector2 in chart.underside_ranges:
			if run.x < section.y + config.fly_exit_beats and section.x < run.y:
				errors.append("%s overlaps an underside run" % where)
		for pad: ChartItems.PadPlacement in chart.pads:
			if section.x - 1.0 <= pad.beat and pad.beat < section.y + config.fly_exit_beats:
				errors.append("%s has a pad at beat %.3f" % [where, pad.beat])
		for placement: ChartItems.HazardPlacement in chart.hazards:
			if section.x <= placement.beat and placement.beat < section.y + 1.0 and not placement.hazard.airborne:
				errors.append("%s has the ground hazard '%s' at beat %.3f" % [where, placement.hazard.id,
						placement.beat])
	for cue: ChartItems.ActionCue in chart.cues:
		var inside: int = chart.fly_range_at(cue.beat)
		var is_flap: bool = cue.action.id == config.flap_action
		if inside >= 0 and not is_flap:
			errors.append("%s at beat %.3f: only flap cues are allowed in a fly section" % [cue.action.id, cue.beat])
		elif inside < 0 and is_flap:
			errors.append("flap at beat %.3f is outside every fly section" % cue.beat)
		elif inside < 0 and _lands_too_late(chart, config, cue.beat):
			errors.append("%s at beat %.3f comes less than %.1f beats after a fly section" % [cue.action.id, cue.beat,
					config.fly_exit_beats])
	return errors


static func _lands_too_late(chart: LevelChart, config: GameplayConfig, beat: float) -> bool:
	for section: Vector2 in chart.fly_ranges:
		if section.y <= beat and beat < section.y + config.fly_exit_beats:
			return true
	return false
