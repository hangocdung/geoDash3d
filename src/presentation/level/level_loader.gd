# Loads a level's data on a WorkerThreadPool thread so the screen keeps animating: the chart (parse, validation,
# reference run), the song stream, the TrackPath and the track mesh arrays (TrackView.Geometry). Everything it
# builds is read-only afterwards, so the menu demo's loader can be handed to the level the player starts.
# Related: src/presentation/level/level_boot.gd, src/presentation/level/level_runner.gd, src/ui/menu/menu_backdrop.gd
class_name LevelLoader
extends RefCounted

var chart_path: String
var quality: QualityTier.Tier
## Results (main thread: read only once is_done() is true). `context` is null when loading failed.
var chart: LevelChart
var stream: AudioStream
var context: LevelContext
var track_geometry: TrackView.Geometry
## 0..1, written by the worker as it goes (a rough guide for loading bars).
var progress: float = 0.0

## Handed from the menu to the next level scene (consumed once by LevelBoot.pick_loader), like
## LaunchOptions.set_next_run. Kept out of LaunchOptions so that stays free of gameplay dependencies (tool scripts).
static var next_for_level: LevelLoader

var _config: GameplayConfig
var _task_id: int = -1
var _started: bool = false


## `config` is created on the main thread (it reads RemoteSettings).
func _init(path: String, config: GameplayConfig, quality_tier: QualityTier.Tier) -> void:
	chart_path = path
	quality = quality_tier
	_config = config


## Queues the work (once).
func start() -> LevelLoader:
	if not _started:
		_started = true
		_task_id = WorkerThreadPool.add_task(_work, false, "LevelLoader %s" % chart_path.get_file())
	return self


## True once the worker has finished (it also releases the task, as WorkerThreadPool requires).
func is_done() -> bool:
	if not _started:
		return false
	if _task_id >= 0:
		if not WorkerThreadPool.is_task_completed(_task_id):
			return false
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
	return true


func failed() -> bool:
	return context == null


## Same data a new level for `path` at `quality_tier` would load.
func matches(path: String, quality_tier: QualityTier.Tier) -> bool:
	return chart_path == path and quality == quality_tier


func _work() -> void:
	chart = ChartLoader.load_file(chart_path, _config)
	progress = 0.55
	if chart == null:
		progress = 1.0
		return
	stream = ContentPaths.audio(chart.song_path)
	if stream == null:
		push_error("LevelLoader: cannot load song '%s'" % chart.song_path)
		progress = 1.0
		return
	progress = 0.6
	var song_end_beat: float = chart.beat_at_time(stream.get_length())
	var flatten: bool = not QualityTier.uses_spectacle_track(quality)
	var built := LevelContext.new(chart, _config, TrackPath.build(chart, song_end_beat, flatten), quality)
	progress = 0.7
	track_geometry = TrackView.build_geometry(built)
	context = built
	progress = 1.0
