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
## Highest checkpoint earned so far (kept across attempts).
var _reached_index: int = -1
## Next checkpoint to watch in the current attempt.
var _cursor: int = 0


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


## Call when an attempt starts: checkpoints before `start_beat` are not earned by this attempt.
func begin(start_beat: float) -> void:
	_cursor = 0
	while _cursor < checkpoints.size() and checkpoints[_cursor] < start_beat:
		_cursor += 1


## Returns true when `beat` passes a checkpoint not earned before.
func update(beat: float) -> bool:
	var passed: bool = false
	while _cursor < checkpoints.size() and beat >= checkpoints[_cursor] + PASS_MARGIN_BEATS:
		if _cursor > _reached_index:
			_reached_index = _cursor
			passed = true
		_cursor += 1
	return passed


## Where the next attempt should start (safe start with a run-up before the last checkpoint).
func restart_beat(default_start: float) -> float:
	if _reached_index < 0:
		return default_start
	return _chart.safe_start_beat(checkpoints[_reached_index] - RUN_UP_BEATS)


func reached_count() -> int:
	return _reached_index + 1
