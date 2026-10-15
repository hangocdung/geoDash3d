# Combo counts PERFECT hits only (GREAT/GOOD break it), score = grade points x combo bonus, high scores per chart, and which runs count.
# Related: src/gameplay/simulation/score_keeper.gd, src/core/high_scores.gd, src/presentation/level/run_records.gd
extends TestCase

const SCORES_PATH: String = "user://test_scores.cfg"


func _simulate(taps: Array[float]) -> RunSimulation:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"},
			{"beat": 8, "type": "jump", "hazard": "none"}, {"beat": 12, "type": "jump", "hazard": "none"},
			{"beat": 16, "type": "jump", "hazard": "none"}], 120.0, 7.0, 24.0)
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(20.0)
	return simulation


func test_combo_counts_perfect_hits_only() -> void:
	# 0.12 beat late at 120 BPM = 60 ms: GREAT. A non-PERFECT hit breaks the combo like a miss.
	var simulation: RunSimulation = _simulate([4.0, 8.12, 12.0, 16.0])
	assert_eq(simulation.grade_counts[Judgement.Grade.GREAT], 1)
	assert_eq(simulation.streak.combo, 2, "the GREAT at 8 reset the combo")
	assert_eq(simulation.streak.max_combo, 2)
	var missed: RunSimulation = _simulate([4.0, 12.0, 16.0])
	assert_eq(missed.streak.combo, 2, "the miss at 8 reset the combo")


func test_score_adds_grade_points_with_combo_bonus() -> void:
	var config: GameplayConfig = GameplayConfig.create_default()
	assert_eq(ScoreKeeper.points_for(Judgement.Grade.PERFECT, 1, config), 303)
	assert_eq(ScoreKeeper.points_for(Judgement.Grade.GREAT, 0, config), 150)
	assert_eq(ScoreKeeper.points_for(Judgement.Grade.PERFECT, 500, config), 600, "bonus capped at combo 100")
	var simulation: RunSimulation = _simulate([4.0, 8.12, 12.0, 16.0])
	assert_eq(simulation.score.score, 303 + 150 + 303 + 306, "the GREAT scores at combo 0, then it restarts")
	assert_eq(_simulate([4.0, 8.0, 12.0, 16.0]).score.score, ScoreKeeper.max_score(4, config))


func test_high_scores_keep_the_best_of_each_field() -> void:
	HighScores.path = SCORES_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORES_PATH))
	var chart: String = "res://assets/music/some_song.chart.json"
	assert_false(HighScores.best(chart).has_any())
	HighScores.submit(chart, 5000, 0.4, 12, false)
	var previous: HighScores.Record = HighScores.submit(chart, 3000, 0.7, 20, false)
	assert_eq(previous.score, 5000)
	var record: HighScores.Record = HighScores.best(chart)
	assert_eq(record.score, 5000, "a lower score does not replace the best")
	assert_almost_eq(record.progress, 0.7)
	assert_eq(record.max_combo, 20)
	assert_false(record.completed)
	HighScores.submit(chart, 9000, 1.0, 30, true)
	assert_true(HighScores.best(chart).completed)
	assert_false(HighScores.best("res://assets/music/other.chart.json").has_any(), "records are per chart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORES_PATH))
	HighScores.path = HighScores.DEFAULT_PATH


func test_only_normal_runs_are_recorded() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var config: GameplayConfig = GameplayConfig.create_default()
	var path: String = "res://assets/music/pulse_drive.chart.json"
	assert_true(RunRecords.new(path, LaunchOptions.chart_run(path), chart, config).counts())
	assert_false(RunRecords.new(path, LaunchOptions.autoplay_run(path), chart, config).counts())
	assert_false(RunRecords.new(path, LaunchOptions.practice_run(1.0, path), chart, config).counts())
	assert_false(RunRecords.new(path, LaunchOptions.attract(), chart, config).counts())
	assert_eq(RunRecords.grouped(1234567), "1,234,567")
