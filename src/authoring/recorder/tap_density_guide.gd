# Suggests how many taps a recorder segment should get: taps per second as a line over section energy, fitted
# on a reference chart (the main map, rated HARD), scaled down for easier difficulties.
# Related: src/authoring/recorder/recorder.gd, src/authoring/recorder/recorder_segments.gd
class_name TapDensityGuide
extends RefCounted

const REFERENCE_CHART: String = "res://assets/music/the_dawn_assembly.chart.json"
const LEVEL_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
## Share of the reference density per difficulty (the reference itself is HARD).
const LEVEL_FACTORS: Array[float] = [0.5, 0.75, 1.0]
const DEFAULT_LEVEL: int = 1

## Taps per second at energy 0 and per unit of energy (HARD).
var intercept: float = 0.0
var slope: float = 0.0


## Least-squares fit of taps/second against energy, each span weighted by its length.
## Spans: Vector3(energy, duration_sec, taps).
static func fit(spans: Array[Vector3]) -> TapDensityGuide:
	var guide := TapDensityGuide.new()
	var weight: float = 0.0
	var mean_energy: float = 0.0
	var mean_density: float = 0.0
	for span: Vector3 in spans:
		if span.y <= 0.0:
			continue
		weight += span.y
		mean_energy += span.x * span.y
		mean_density += span.z
	if weight <= 0.0:
		push_error("TapDensityGuide: no reference spans with a duration")
		return guide
	mean_energy /= weight
	mean_density /= weight
	var covariance: float = 0.0
	var variance: float = 0.0
	for span: Vector3 in spans:
		if span.y <= 0.0:
			continue
		covariance += span.y * (span.x - mean_energy) * (span.z / span.y - mean_density)
		variance += span.y * (span.x - mean_energy) * (span.x - mean_energy)
	guide.slope = maxf(covariance / variance, 0.0) if variance > 0.0 else 0.0
	guide.intercept = mean_density - guide.slope * mean_energy
	return guide


## Fits on a chart's sections (taps = action cues inside each section).
static func from_chart(chart: LevelChart) -> TapDensityGuide:
	var spans: Array[Vector3] = []
	for index: int in chart.sections.size():
		var section: ChartItems.Section = chart.sections[index]
		var start: float = maxf(section.beat, 0.0)
		var end: float = chart.sections[index + 1].beat if index + 1 < chart.sections.size() else chart.end_beat
		var taps: int = 0
		for cue: ChartItems.ActionCue in chart.cues:
			if cue.beat >= start and cue.beat < end:
				taps += 1
		spans.append(Vector3(section.energy, chart.time_at(end) - chart.time_at(start), taps))
	return fit(spans)


## Guide fitted on REFERENCE_CHART (no suggestions if it cannot be loaded).
static func from_reference() -> TapDensityGuide:
	var reference: LevelChart = ChartLoader.load_file(REFERENCE_CHART, GameplayConfig.create_default())
	if reference == null:
		push_error("TapDensityGuide: cannot load reference chart '%s'" % REFERENCE_CHART)
		return TapDensityGuide.new()
	return from_chart(reference)


## Suggested tap count for `duration_sec` of music at `energy`, for difficulty `level` (index in LEVEL_NAMES).
func suggested_taps(energy: float, duration_sec: float, level: int) -> int:
	var density: float = maxf(intercept + slope * energy, 0.0) * LEVEL_FACTORS[clampi(level, 0, LEVEL_FACTORS.size() - 1)]
	return roundi(density * duration_sec)
