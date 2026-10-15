# End-to-end HTTPS smoke test for a debug device; uses its local staging credentials.
# Downloads packages, verifies runtime audio/LED loading and repairs a corrupted file.
extends SceneTree

var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var worker := ContentDownloader.new()
	root.add_child(worker)
	worker.progress.connect(func(text: String) -> void: print("ONLINE_PROGRESS ", text))
	worker.refresh()
	await worker.changed
	var songs: Array = ContentCatalog.songs()
	if songs.is_empty():
		push_error("ONLINE_CHECK no staging songs")
		quit(1)
		return
	for song: Dictionary in songs:
		worker.download(song)
		await worker.changed
		if not ContentCatalog.installed(song):
			push_error("ONLINE_CHECK package not installed: " + str(song["id"]))
			quit(1)
			return
		var chart: LevelChart = ChartLoader.load_file(ContentCatalog.chart_path(song), GameplayConfig.create_default())
		if chart == null or ContentPaths.audio(chart.song_path) == null or SpectrumTexture.load_for_song(chart.song_path) == null:
			push_error("ONLINE_CHECK runtime assets failed")
			quit(1)
			return
		print("ONLINE_PACKAGE_OK ", song["id"], " revision=", chart.revision)
	# A corrupted cached file must be re-fetched rather than blindly reused on retry.
	var first: Dictionary = songs[0]
	var target: Dictionary = first["files"][0]
	var path: String = ContentCatalog.directory(first).path_join(str(target["name"]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	worker.download(first)
	await worker.changed
	if not ContentCatalog.installed(first):
		push_error("ONLINE_CHECK repair failed")
		quit(1)
		return
	print("ONLINE_CHECK_OK packages=", songs.size(), " repair=ok")
	worker.queue_free()
	quit(0)
