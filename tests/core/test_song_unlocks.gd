# Song unlock rules (GD3-242): 3 free songs, the next opens on a clear or 80 %, variants and the bonus song open on
# their base song's clear, the IAP opens everything, a trial opens one song. Related: src/core/song_unlocks.gd
extends TestCase

const SCORES_PATH: String = "user://test_unlock_scores.cfg"
const ENTITLEMENTS_PATH: String = "user://test_unlock_entitlements.cfg"
const DIR: String = "res://assets/music/"

var _saved_scores: String
var _saved_entitlements: String


func before_each() -> void:
	_saved_scores = HighScores.path
	_saved_entitlements = Entitlements.path
	HighScores.path = SCORES_PATH
	Entitlements.path = ENTITLEMENTS_PATH
	for path: String in [SCORES_PATH, ENTITLEMENTS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Entitlements.reset_cache()
	SongUnlocks.trial_path = ""


func after_each() -> void:
	for path: String in [SCORES_PATH, ENTITLEMENTS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	HighScores.path = _saved_scores
	Entitlements.path = _saved_entitlements
	Entitlements.reset_cache()
	SongUnlocks.trial_path = ""


func test_first_three_are_free() -> void:
	assert_eq(_open(), "s1,s2,s3")


func test_clear_or_80_percent_opens_the_next() -> void:
	_record("s3", 0.79, false)
	assert_eq(_open(), "s1,s2,s3", "79 % is not enough")
	_record("s3", 0.8, false)
	assert_eq(_open(), "s1,s2,s3,s4")
	_record("s4", 1.0, true)
	assert_eq(_open(), "s1,s2,s3,s4,s4_led,fault_line", "a clear also opens s4's EXPERT variant")


func test_progress_on_a_locked_song_does_not_skip_ahead() -> void:
	_record("s4", 1.0, true)
	assert_eq(_open(), "s1,s2,s3", "s4 was played on a trial while locked: fault_line stays closed")


func test_variant_and_bonus_need_a_clear_of_their_base() -> void:
	for id: String in ["s3", "s4"]:
		_record(id, 1.0, true)
	_record("fault_line", 0.9, false)
	assert_false(_open().contains("the_dawn_assembly"), "bonus needs a clear, 90 % is not enough")
	_record("fault_line", 1.0, true)
	assert_true(_open().contains(",the_dawn_assembly"))
	assert_false(_open().contains("the_dawn_assembly_led"))
	_record("the_dawn_assembly", 1.0, true)
	assert_true(_open().contains("the_dawn_assembly_led"))
	assert_true(_open().contains("s4_led"), "s4 is open and cleared")


func test_unlock_all_purchase_opens_everything() -> void:
	Entitlements.grant(Entitlements.UNLOCK_ALL_SONGS)
	assert_eq(_open().split(",").size(), _ordered().size())


func test_trial_opens_one_song_and_requirement_names_the_song_before() -> void:
	var ordered: PackedStringArray = _ordered()
	SongUnlocks.trial_path = DIR + "fault_line.chart.json"
	assert_true(SongUnlocks.is_unlocked(DIR + "fault_line.chart.json", ordered))
	assert_false(SongUnlocks.is_unlocked(DIR + "s4.chart.json", ordered))
	assert_eq(SongUnlocks.requirement(DIR + "s4.chart.json", ordered), DIR + "s3.chart.json")
	assert_eq(SongUnlocks.requirement(DIR + "the_dawn_assembly.chart.json", ordered), DIR + "fault_line.chart.json")
	assert_true(SongUnlocks.needs_clear(DIR + "s4_led.chart.json"))
	assert_false(SongUnlocks.needs_clear(DIR + "s4.chart.json"))


func _ordered() -> PackedStringArray:
	var paths: PackedStringArray = []
	for id: String in ["s1", "s2", "s3", "s4", "s4_led", "fault_line", "the_dawn_assembly", "the_dawn_assembly_led"]:
		paths.append(DIR + id + ".chart.json")
	return paths


func _open() -> String:
	var open: Dictionary[String, bool] = SongUnlocks.unlocked(_ordered())
	var ids: PackedStringArray = []
	for path: String in _ordered():
		if open.has(path):
			ids.append(SongCatalog.song_id(path))
	return ",".join(ids)


func _record(id: String, progress: float, completed: bool) -> void:
	HighScores.submit(DIR + id + ".chart.json", 100, progress, 1, completed)
