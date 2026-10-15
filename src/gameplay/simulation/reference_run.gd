# Annotates a loaded chart with what a perfect (autoplay) run does: the player's height at every cue
# (cue rings and jump orbs are drawn there), the beat ranges it spends in the air (safe start points) and
# its vertical states (a shield puts a falling player back onto them).
# Related: autoplay.gd, src/gameplay/chart/level_chart.gd, src/gameplay/chart/chart_loader.gd
class_name ReferenceRun
extends RefCounted

## Same as the level's count-in, so the reference starts where real runs start.
const START_BEAT: float = -4.0


static func annotate(chart: LevelChart, config: GameplayConfig) -> void:
	if _is_flat(chart):
		# Every cue is tapped standing on the road, and the cue-based safe start already covers each jump.
		chart.cue_heights.resize(chart.cues.size())
		chart.cue_heights.fill(0.0)
		chart.airborne_ranges = PackedVector2Array()
		chart.reference_beats = PackedFloat64Array()
		chart.reference_motions = []
		return
	var simulation := RunSimulation.new(chart, config, START_BEAT)
	simulation.invincible = true
	var ranges: Array[Vector2] = []
	simulation.player_landed.connect(func(beat: float, airtime: float) -> void:
		ranges.append(Vector2(beat - airtime, beat)))
	# The lambdas must not capture `simulation` (a reference cycle through its own signal would leak it).
	var beats: Array[float] = [START_BEAT]
	var motions: Array[VerticalMotion] = [simulation.motion_snapshot()]
	simulation.motion_changed.connect(func(beat: float, motion: VerticalMotion) -> void:
		beats.append(beat)
		motions.append(motion))
	var bot := Autoplay.new(chart, START_BEAT)
	chart.cue_heights.resize(chart.cues.size())
	for index: int in chart.cues.size():
		var cue_beat: float = chart.cues[index].beat
		if cue_beat < START_BEAT:
			chart.cue_heights[index] = 0.0
			continue
		bot.drive(simulation, cue_beat)
		chart.cue_heights[index] = simulation.player_height_at(cue_beat)
	bot.drive(simulation, chart.end_beat + 1.0)
	chart.airborne_ranges = PackedVector2Array(ranges)
	chart.reference_beats = PackedFloat64Array(beats)
	chart.reference_motions = motions


## No terrain, pads, orbs or flight: the pre-v3 kind of chart, which needs no simulation pass.
static func _is_flat(chart: LevelChart) -> bool:
	if not chart.terrain.is_flat() or not chart.pads.is_empty() or not chart.fly_ranges.is_empty():
		return false
	for cue: ChartItems.ActionCue in chart.cues:
		if cue.action.air_allowed:
			return false
	return true
