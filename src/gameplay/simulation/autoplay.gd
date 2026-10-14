# Perfect bot: taps exactly on every action cue (except `missed_beats`, to show misses, shields and
# deaths on purpose). Used by tests (prove a chart is passable), the capture tool and the attract mode.
# Related: src/gameplay/simulation/run_simulation.gd
class_name Autoplay
extends RefCounted

var _cue_beats: PackedFloat64Array = []
var _next_index: int = 0


func _init(chart: LevelChart, start_beat: float, missed_beats: PackedFloat64Array = []) -> void:
	for cue: ChartItems.ActionCue in chart.cues:
		if cue.beat >= start_beat and not missed_beats.has(cue.beat):
			_cue_beats.append(cue.beat)


## Feeds every cue up to `target_beat` into the simulation, then advances it.
func drive(simulation: RunSimulation, target_beat: float) -> void:
	while _next_index < _cue_beats.size() and _cue_beats[_next_index] <= target_beat:
		simulation.tap(_cue_beats[_next_index])
		_next_index += 1
	simulation.advance_to(target_beat)


## Runs a whole chart headlessly; returns the finished simulation.
static func run_full(chart: LevelChart, config: GameplayConfig, invincible: bool) -> RunSimulation:
	var simulation := RunSimulation.new(chart, config, -1.0)
	simulation.invincible = invincible
	var bot := Autoplay.new(chart, -1.0)
	bot.drive(simulation, chart.end_beat + 1.0)
	return simulation
