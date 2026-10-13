# Parses *.chart.json (format documented in docs/chart_format.md) into a LevelChart.
# Collects every validation problem, reports them with push_error and returns null on failure.
# Related: src/gameplay/chart/level_chart.gd, src/gameplay/defs/gameplay_config.gd
class_name ChartLoader
extends RefCounted

const SUPPORTED_VERSION: int = 1
const NO_HAZARD: String = "none"

var _errors: PackedStringArray = []
var _config: GameplayConfig


static func load_file(path: String, config: GameplayConfig) -> LevelChart:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("ChartLoader: cannot read '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	return parse_text(text, config, path)


static func parse_text(text: String, config: GameplayConfig, source_name: String = "<text>") -> LevelChart:
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("ChartLoader: %s line %d: %s" % [source_name, json.get_error_line(), json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("ChartLoader: %s root must be an object" % source_name)
		return null
	var loader := ChartLoader.new()
	loader._config = config
	var chart: LevelChart = loader._parse(json.data as Dictionary)
	if not loader._errors.is_empty():
		for message: String in loader._errors:
			push_error("ChartLoader: %s: %s" % [source_name, message])
		return null
	return chart


func _parse(root: Dictionary) -> LevelChart:
	var version: int = int(_number(root, "version", 0.0))
	if version != SUPPORTED_VERSION:
		_errors.append("unsupported version %d (expected %d)" % [version, SUPPORTED_VERSION])
		return null
	var chart := LevelChart.new()
	chart.title = str(root.get("title", ""))
	chart.artist = str(root.get("artist", ""))
	chart.song_path = str(root.get("song", ""))
	chart.end_beat = _number(root, "end_beat", 0.0)
	if chart.song_path.is_empty():
		_errors.append("'song' is required")
	if chart.end_beat <= 0.0:
		_errors.append("'end_beat' must be > 0")
	chart.tempo = _parse_tempo(root)
	chart.distance_map = _parse_speed(root)
	_parse_sections(root, chart)
	_parse_track(root, chart)
	_parse_events(root, chart)
	if chart.tempo == null or chart.distance_map == null:
		return null
	chart.finalize()
	return chart


func _parse_tempo(root: Dictionary) -> TempoMap:
	var beats: PackedFloat64Array = []
	var bpms: PackedFloat64Array = []
	for entry: Dictionary in _objects(root, "tempo"):
		beats.append(_number(entry, "beat", 0.0))
		bpms.append(_number(entry, "bpm", 0.0))
	if beats.is_empty():
		_errors.append("'tempo' needs at least one {beat, bpm} entry")
		return null
	var tempo: TempoMap = TempoMap.create(beats, bpms, _number(root, "offset_sec", 0.0))
	if tempo == null:
		_errors.append("invalid 'tempo' entries")
	return tempo


func _parse_speed(root: Dictionary) -> PiecewiseLinearMap:
	var beats: PackedFloat64Array = []
	var rates: PackedFloat64Array = []
	for entry: Dictionary in _objects(root, "speed"):
		beats.append(_number(entry, "beat", 0.0))
		rates.append(_number(entry, "units_per_beat", 0.0))
	if beats.is_empty():
		_errors.append("'speed' needs at least one {beat, units_per_beat} entry")
		return null
	# Distance 0 is at beat 0 regardless of where the first speed key sits.
	var first_value: float = beats[0] * rates[0]
	var mapping: PiecewiseLinearMap = PiecewiseLinearMap.build(beats, rates, first_value)
	if mapping == null:
		_errors.append("invalid 'speed' entries")
	return mapping


func _parse_sections(root: Dictionary, chart: LevelChart) -> void:
	for entry: Dictionary in _objects(root, "sections"):
		chart.sections.append(ChartItems.Section.new(
				_number(entry, "beat", 0.0), StringName(str(entry.get("name", "section"))),
				clampf(_number(entry, "energy", 0.5), 0.0, 1.0)))


func _parse_track(root: Dictionary, chart: LevelChart) -> void:
	for entry: Dictionary in _objects(root, "track"):
		var beat: float = _number(entry, "beat", 0.0)
		var shape_name: String = str(entry.get("shape", "straight"))
		match shape_name:
			"straight":
				chart.track_segments.append(ChartItems.TrackSegment.new(beat, ChartItems.TrackSegment.Shape.STRAIGHT))
			"turn":
				var turn := ChartItems.TrackSegment.new(beat, ChartItems.TrackSegment.Shape.TURN)
				turn.angle_deg = _number(entry, "angle_deg", 0.0)
				chart.track_segments.append(turn)
			"slope":
				var slope := ChartItems.TrackSegment.new(beat, ChartItems.TrackSegment.Shape.SLOPE)
				slope.rise = _number(entry, "rise", 0.0)
				chart.track_segments.append(slope)
			_:
				_errors.append("track segment at beat %.3f has unknown shape '%s'" % [beat, shape_name])


func _parse_events(root: Dictionary, chart: LevelChart) -> void:
	for entry: Dictionary in _objects(root, "events"):
		var beat: float = _number(entry, "beat", NAN)
		var type_name: String = str(entry.get("type", ""))
		if is_nan(beat):
			_errors.append("event '%s' is missing 'beat'" % type_name)
			continue
		match type_name:
			"camera":
				chart.camera_cues.append(ChartItems.CameraCue.new(
						beat, StringName(str(entry.get("shot", "side"))), _number(entry, "blend_beats", 1.0)))
			"vfx":
				chart.vfx_cues.append(ChartItems.VfxCue.new(beat, StringName(str(entry.get("name", "")))))
			"hazard":
				_add_hazard(chart, beat, str(entry.get("hazard", "")))
			_:
				_add_action_event(chart, beat, type_name, entry)


func _add_action_event(chart: LevelChart, beat: float, type_name: String, entry: Dictionary) -> void:
	var action: ActionDefinition = _config.find_action(StringName(type_name))
	if action == null:
		_errors.append("event at beat %.3f has unknown type '%s'" % [beat, type_name])
		return
	chart.cues.append(ChartItems.ActionCue.new(beat, action))
	var hazard_name: String = str(entry.get("hazard", String(action.paired_hazard)))
	if hazard_name.is_empty() or hazard_name == NO_HAZARD:
		return
	var hazard_offset: float = _number(entry, "hazard_offset", action.hazard_beat_offset)
	_add_hazard(chart, beat + hazard_offset, hazard_name)


func _add_hazard(chart: LevelChart, beat: float, hazard_name: String) -> void:
	var hazard: HazardDefinition = _config.find_hazard(StringName(hazard_name))
	if hazard == null:
		_errors.append("hazard at beat %.3f has unknown id '%s'" % [beat, hazard_name])
		return
	chart.hazards.append(ChartItems.HazardPlacement.new(beat, hazard))


func _objects(root: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = root.get(key, [])
	if typeof(value) != TYPE_ARRAY:
		_errors.append("'%s' must be an array" % key)
		return result
	for item: Variant in value as Array:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item as Dictionary)
		else:
			_errors.append("'%s' contains a non-object entry" % key)
	return result


func _number(source: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = source.get(key, fallback)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	_errors.append("'%s' must be a number (got %s)" % [key, str(value)])
	return fallback
