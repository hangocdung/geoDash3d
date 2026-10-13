# Practice mode checkpoints: one every CHECKPOINT_SPACING beats plus every section start. A checkpoint
# counts once the player passes it alive; after a death the run restarts a short run-up before it.
# Related: src/presentation/level/level_runner.gd, src/gameplay/chart/level_chart.gd
class_name PracticeTracker
extends RefCounted

const CHECKPOINT_SPACING: float = 16.0
## Beats of run-up before the checkpoint when restarting.
const RUN_UP_BEATS: float = 2.0
const PASS_MARGIN_BEATS: float = 0.5

var checkpoints: PackedFloat64Array = []
var _chart: LevelChart
var _reached_index: int = -1


func _init(chart: LevelChart) -> void:
	_chart = chart
	var beat: float = CHECKPOINT_SPACING
	while beat < chart.end_beat:
		checkpoints.append(beat)
		beat += CHECKPOINT_SPACING
	for section: ChartItems.Section in chart.sections:
		if section.beat > 0.0 and section.beat < chart.end_beat and not checkpoints.has(section.beat):
			checkpoints.append(section.beat)
	checkpoints.sort()


## Returns true when `beat` passes a new checkpoint.
func update(beat: float) -> bool:
	var passed: bool = false
	while _reached_index + 1 < checkpoints.size() and beat >= checkpoints[_reached_index + 1] + PASS_MARGIN_BEATS:
		_reached_index += 1
		passed = true
	return passed


## Where the next attempt should start (safe start with a run-up before the last checkpoint).
func restart_beat(default_start: float) -> float:
	if _reached_index < 0:
		return default_start
	return _chart.safe_start_beat(checkpoints[_reached_index] - RUN_UP_BEATS)


func reached_count() -> int:
	return _reached_index + 1
