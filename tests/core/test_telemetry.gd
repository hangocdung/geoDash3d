# Telemetry: events fit Firebase Analytics' limits; one level_start / level_end per attempt with the run's numbers.
# Related: src/core/telemetry.gd, src/presentation/level/run_telemetry.gd
extends TestCase

const SCORES_PATH: String = "user://test_telemetry_scores.cfg"
const CHART_PATH: String = "res://assets/music/the_dawn_assembly.chart.json"


func before_each() -> void:
	Telemetry.send_enabled = false
	Telemetry.history.clear()
	HighScores.path = SCORES_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORES_PATH))


func test_validate_follows_firebase_rules() -> void:
	assert_eq(Telemetry.validate("level_end", {"song_id": "a", "score": 3, "pct": 1.5, "ok": true}), "")
	assert_ne(Telemetry.validate("level-end", {}), "", "dash in the name")
	assert_ne(Telemetry.validate("firebase_x", {}), "", "reserved prefix")
	assert_ne(Telemetry.validate("a".repeat(41), {}), "", "name too long")
	assert_ne(Telemetry.validate("e", {"text": "x".repeat(101)}), "", "text too long")
	assert_ne(Telemetry.validate("e", {"list": [1, 2]}), "", "arrays are not allowed")
	var many: Dictionary[String, Variant] = {}
	for index: int in 26:
		many["p%d" % index] = index
	assert_ne(Telemetry.validate("e", many), "", "26 params")


func test_one_start_and_end_per_attempt() -> void:
	var chart: LevelChart = _chart()
	var options := LaunchOptions.new()
	var telemetry := RunTelemetry.new(CHART_PATH, chart, options, true)
	var first := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	telemetry.bind(first, -1.0)
	first.tap(4.0)
	first.advance_to(6.0)
	var second := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	telemetry.bind(second, -1.0)
	for beat: float in [4.0, 8.0, 12.0, 16.0]:
		second.tap(beat)
	second.advance_to(30.0)
	var names: PackedStringArray = []
	for event: Dictionary in Telemetry.history:
		names.append(event["name"])
	assert_eq(",".join(names), "level_start,level_end,level_start,level_end,new_best,first_clear")
	var quit: Dictionary = Telemetry.history[1]["params"]
	assert_eq(quit["result"], "quit", "restarted mid-run")
	assert_eq(quit["perfect"], 1)
	var done: Dictionary = Telemetry.history[3]["params"]
	assert_eq(done["result"], "complete")
	assert_eq(done["perfect"], 4)
	assert_eq(done["attempt"], 2)
	assert_eq(done["song_id"], "the_dawn_assembly")
	assert_eq(done["progress_pct"], 100.0)


func test_death_reports_where_and_misses() -> void:
	var chart: LevelChart = _chart()
	var telemetry := RunTelemetry.new(CHART_PATH, chart, LaunchOptions.new(), false)
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	telemetry.bind(simulation, -1.0)
	simulation.tap(4.0)
	simulation.advance_to(30.0)
	var end: Dictionary = Telemetry.history[-1]["params"]
	assert_eq(Telemetry.history[-1]["name"], "level_end", "no new_best for runs that do not count")
	assert_eq(end["result"], "dead")
	assert_eq(end["miss_cues"], "8")
	assert_true(end.has("hazard_id") and end.has("death_cue"), str(end))


func test_autoplay_and_attract_stay_silent() -> void:
	var chart: LevelChart = _chart()
	var options := LaunchOptions.new()
	options.autoplay = true
	var telemetry := RunTelemetry.new(CHART_PATH, chart, options, false)
	telemetry.bind(RunSimulation.new(chart, GameplayConfig.create_default(), -1.0), -1.0)
	telemetry.leave()
	assert_eq(Telemetry.history.size(), 0)


func _chart() -> LevelChart:
	return ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "jump"},
			{"beat": 12, "type": "jump"}, {"beat": 16, "type": "jump"}], 120.0, 7.0, 24.0)
