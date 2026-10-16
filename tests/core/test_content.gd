# Untrusted catalog parsing and old/new chart compatibility without network access.
# Pending (listed, not downloaded) songs and new revisions never take unlocks away (GD3-300).
# Related: ContentManifest, ContentPaths, ContentCatalog, ChartLoader, SongUnlocks, RunRecords.
extends TestCase

const SCORES_PATH: String = "user://test_content_unlock_scores.cfg"
const ENTITLEMENTS_PATH: String = "user://test_content_entitlements.cfg"
const DIR: String = "res://assets/music/"

var _saved_scores: String
var _saved_entitlements: String
var _saved_manifest: Dictionary
var _saved_loaded: bool


func before_each() -> void:
	_saved_scores = HighScores.path
	_saved_entitlements = Entitlements.path
	_saved_manifest = ContentCatalog.manifest
	_saved_loaded = ContentCatalog.loaded
	HighScores.path = SCORES_PATH
	Entitlements.path = ENTITLEMENTS_PATH
	for path: String in [SCORES_PATH, ENTITLEMENTS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Entitlements.reset_cache()


func after_each() -> void:
	for path: String in [SCORES_PATH, ENTITLEMENTS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	HighScores.path = _saved_scores
	Entitlements.path = _saved_entitlements
	Entitlements.reset_cache()
	ContentCatalog.manifest = _saved_manifest
	ContentCatalog.loaded = _saved_loaded


func test_paths_reject_escape_and_keep_legacy() -> void:
	assert_eq(ContentPaths.resolve("res://assets/music/a.mp3", "<text>"), "res://assets/music/a.mp3")
	assert_eq(ContentPaths.resolve("song.mp3", "user://content/a/2/a.chart.json"), "user://content/a/2/song.mp3")
	for value: String in ["../song.mp3", "/tmp/song.mp3", "C:/song.mp3", "res://a.mp3", "a\\b", "https://x"]:
		assert_eq(ContentPaths.resolve(value, "user://content/a/2/a.chart.json"), "", value)


func test_manifest_rejects_bad_schema_version_hash_and_paths() -> void:
	assert_true(ContentManifest.parse("broken").is_empty())
	assert_true(ContentManifest.parse('{"schema_version":8,"songs":[]}').is_empty())
	assert_true(ContentManifest.parse('{"schema_version":1,"min_app_version":"9.0.0","songs":[]}').is_empty())
	var catalog: Dictionary = _catalog()
	assert_false(ContentManifest.parse(JSON.stringify(catalog)).is_empty())
	catalog["unknown_future_field"] = "ignored"
	assert_false(ContentManifest.parse(JSON.stringify(catalog)).is_empty())
	catalog["songs"][0]["files"][0]["name"] = "../escape"
	assert_true(ContentManifest.parse(JSON.stringify(catalog)).is_empty())


func test_downloaded_chart_revision_is_separate_from_format_version() -> void:
	var text: String = FileAccess.get_file_as_string("res://assets/music/pulse_drive.chart.json")
	var root: Dictionary = JSON.parse_string(text)
	root["song"] = "song.mp3"
	root["chart_revision"] = 2
	var chart: LevelChart = ChartLoader.parse_text(JSON.stringify(root), GameplayConfig.create_default(),
			"user://content/pulse_drive/2/pulse_drive.chart.json")
	assert_not_null(chart)
	assert_eq(chart.revision, 2)
	assert_eq(chart.song_path, "user://content/pulse_drive/2/song.mp3")
	var run: RunSimulation = Autoplay.run_full(chart, GameplayConfig.create_default(), false)
	assert_true(run.is_completed)
	assert_false(run.is_dead)


func test_new_remote_revision_keeps_shipped_until_installed() -> void:
	ContentCatalog.manifest = _catalog()
	ContentCatalog.loaded = true
	var bundled := SongCatalog.Entry.new()
	bundled.id = "a"
	bundled.path = "res://assets/music/a.chart.json"
	bundled.revision = 1
	var entries: Array[SongCatalog.Entry] = [bundled]
	var merged: Array[SongCatalog.Entry] = SongCatalog.merge_remote(entries)
	assert_eq(merged.size(), 1)
	assert_eq(merged[0].path, bundled.path)
	assert_eq(int(merged[0].remote["version"]), 2)
	ContentCatalog.manifest["songs"][0]["enabled"] = false
	assert_true(SongCatalog.merge_remote(entries).is_empty())


func test_high_scores_do_not_mix_revisions() -> void:
	var chart_path: String = "user://test_content.chart.json"
	var file := FileAccess.open(chart_path, FileAccess.WRITE)
	file.store_string('{"chart_revision":1}')
	file.close()
	HighScores.submit(chart_path, 100, 1.0, 10, true)
	file = FileAccess.open(chart_path, FileAccess.WRITE)
	file.store_string('{"chart_revision":2}')
	file.close()
	assert_eq(HighScores.best(chart_path).score, 0)
	HighScores.submit(chart_path, 50, 0.5, 5, false)
	assert_eq(HighScores.best(chart_path).score, 50)
	file = FileAccess.open(chart_path, FileAccess.WRITE)
	file.store_string('{"chart_revision":1}')
	file.close()
	assert_eq(HighScores.best(chart_path).score, 100)
	DirAccess.remove_absolute(chart_path)


## The todo case: every shipped song cleared, the manifest adds one song (difficulty 45) that is not downloaded.
func test_pending_remote_song_keeps_everything_unlocked() -> void:
	var shipped: int = SongCatalog.list_songs().size()
	ContentCatalog.manifest = {"schema_version": 1, "catalog_version": 1, "songs": [{"id": "new_song",
			"package_id": "new_song", "chart": "new_song.chart.json", "version": 1, "difficulty": 45.0,
			"title": "New Song", "files": [], "license": {"status": "verified"}}]}
	ContentCatalog.loaded = true
	var entries: Array[SongCatalog.Entry] = SongCatalog.list_songs()
	assert_eq(entries.size(), shipped + 1)
	var ordered: PackedStringArray = []
	for entry: SongCatalog.Entry in entries:
		ordered.append(entry.path)
		if entry.downloaded:
			HighScores.submit(entry.path, 100, 1.0, 10, true)
	var pending: Dictionary[String, bool] = SongCatalog.pending(entries)
	assert_eq(pending.size(), 1)
	var new_path: String = pending.keys()[0]
	var open: Dictionary[String, bool] = SongUnlocks.unlocked(ordered, pending)
	for path: String in ordered:
		assert_true(open.has(path), "%s stays open" % path)
	var index: int = ordered.find(new_path)
	assert_true(index > 0 and index < ordered.size() - 1, "difficulty 45 sits inside the list")
	var before: String = ordered[index - 1]
	var records := RunRecords.new(before, LaunchOptions.chart_run(before),
			ChartFixtures.make_chart([{"beat": 4, "type": "jump"}]), GameplayConfig.create_default())
	assert_eq(records.next_song(), ordered[index + 1], "NEXT SONG skips the song that is not downloaded")


func test_pending_song_is_skipped_by_requirement() -> void:
	var ordered: PackedStringArray = []
	for id: String in ["s1", "s2", "s3", "remote", "s4"]:
		ordered.append(DIR + id + ".chart.json")
	var pending: Dictionary[String, bool] = {DIR + "remote.chart.json": true}
	assert_eq(SongUnlocks.requirement(DIR + "s4.chart.json", ordered, pending), DIR + "s3.chart.json")
	assert_false(SongUnlocks.unlocked(ordered, pending).has(DIR + "s4.chart.json"))
	HighScores.submit(DIR + "s3.chart.json", 100, 0.8, 10, false)
	assert_true(SongUnlocks.unlocked(ordered, pending).has(DIR + "s4.chart.json"))


func test_unlocks_use_the_best_record_of_any_revision() -> void:
	var chart_path: String = "user://test_content_revision.chart.json"
	var file := FileAccess.open(chart_path, FileAccess.WRITE)
	file.store_string('{"chart_revision":1}')
	file.close()
	HighScores.submit(chart_path, 100, 1.0, 10, true)
	file = FileAccess.open(chart_path, FileAccess.WRITE)
	file.store_string('{"chart_revision":2}')
	file.close()
	var ordered: PackedStringArray = [DIR + "s1.chart.json", DIR + "s2.chart.json", chart_path,
			DIR + "s4.chart.json", DIR + "s4_led.chart.json"]
	assert_false(HighScores.best(chart_path).has_any(), "the shown record is per revision")
	assert_true(HighScores.best_any_revision(chart_path).completed)
	HighScores.submit(DIR + "s4.chart.json", 100, 1.0, 10, true)
	var open: Dictionary[String, bool] = SongUnlocks.unlocked(ordered)
	assert_true(open.has(DIR + "s4.chart.json"), "revision 2 keeps revision 1's clear for the chain")
	assert_true(open.has(DIR + "s4_led.chart.json"))
	DirAccess.remove_absolute(chart_path)


func _catalog() -> Dictionary:
	var files: Array[Dictionary] = []
	for name: String in ["a.chart.json", "song.mp3", "song.spectrum.json", "cover.jpg"]:
		files.append({"name": name, "size": 4, "sha256": "a".repeat(64),
				"url": "https://cdn.sntgames.com/beatglide/prod/a/2/" + name})
	return {"schema_version": 1, "catalog_version": 1, "min_app_version": "1.0.0", "songs": [{
			"id": "a", "package_id": "a", "chart": "a.chart.json", "version": 2, "files": files,
			"license": {"status": "verified"}}]}
