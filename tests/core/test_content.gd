# Untrusted catalog parsing and old/new chart compatibility without network access.
# Related: ContentManifest, ContentPaths, ContentCatalog, ChartLoader.
extends TestCase


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
	var previous: Dictionary = ContentCatalog.manifest
	var was_loaded: bool = ContentCatalog.loaded
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
	ContentCatalog.manifest = previous
	ContentCatalog.loaded = was_loaded


func test_high_scores_do_not_mix_revisions() -> void:
	var previous: String = HighScores.path
	HighScores.path = "user://test_content_scores.cfg"
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
	DirAccess.remove_absolute(HighScores.path)
	HighScores.path = previous


func _catalog() -> Dictionary:
	var files: Array[Dictionary] = []
	for name: String in ["a.chart.json", "song.mp3", "song.spectrum.json", "cover.jpg"]:
		files.append({"name": name, "size": 4, "sha256": "a".repeat(64),
				"url": "https://cdn.sntgames.com/beatglide/prod/a/2/" + name})
	return {"schema_version": 1, "catalog_version": 1, "min_app_version": "1.0.0", "songs": [{
			"id": "a", "package_id": "a", "chart": "a.chart.json", "version": 2, "files": files,
			"license": {"status": "verified"}}]}
