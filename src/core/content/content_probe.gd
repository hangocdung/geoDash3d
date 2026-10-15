# Debug-only integration probe for USB Android builds and desktop HTTPS tests.
# Invoked by --content-probe; credentials are device-local, never exported.
class_name ContentProbe
extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var worker := ContentDownloader.new()
	add_child(worker)
	worker.progress.connect(func(text: String) -> void: print("CONTENT_PROBE ", text))
	await worker.refresh()
	var songs: Array = ContentCatalog.songs()
	if songs.is_empty():
		push_error("CONTENT_PROBE no songs")
		return
	worker.cache_limit = 0
	await worker.download(songs[0])
	if worker.busy:
		push_error("CONTENT_PROBE storage rejection failed")
		return
	print("CONTENT_PROBE storage_limit=ok")
	worker.cache_limit = ContentDownloader.CACHE_LIMIT
	for song: Dictionary in songs:
		await worker.download(song)
		if not ContentCatalog.installed(song):
			push_error("CONTENT_PROBE install failed: " + str(song["id"]))
			return
		var chart: LevelChart = ChartLoader.load_file(ContentCatalog.chart_path(song), GameplayConfig.create_default())
		if chart == null or ContentPaths.audio(chart.song_path) == null or SpectrumTexture.load_for_song(chart.song_path) == null:
			push_error("CONTENT_PROBE runtime asset loading failed")
			return
		print("CONTENT_PROBE installed=", song["id"], " revision=", chart.revision)
	var ratings: SongRatings = SongRatings.start(get_tree())
	await ratings.vote(str(songs[0]["id"]), 4)
	await ratings.refresh()
	print("CONTENT_PROBE rating=", ratings.vote_label(str(songs[0]["id"])))
	print("CONTENT_PROBE_OK charts=", songs.size())
	worker.queue_free()
