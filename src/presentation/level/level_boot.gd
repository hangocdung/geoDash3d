# Starts a level without freezing the screen: waits for the LevelLoader thread, then sets the views up one step per
# frame on the main thread, behind a LoadingCover (normal runs) that fades once the first frames after the start
# have rendered (shader compilation). The menu demo and capture runs boot the same way without a cover.
# Related: src/presentation/level/level_runner.gd, src/presentation/level/level_loader.gd, src/ui/loading/loading_cover.gd
class_name LevelBoot
extends RefCounted

## Share of the loading bar taken by the loader thread; the view steps fill the rest.
const LOADER_SHARE: float = 0.7
const STEP_COUNT: int = 6
## Frames rendered behind the cover after the run starts, before it fades (first-use shader compilation).
const SETTLE_FRAMES: int = 4
const SCENERY_SEED: int = 1337
const COVER_LAYER: int = 50

var loader: LevelLoader
var _runner: LevelRunner
var _cover: LoadingCover
var _step: int = 0
var _settle_frames: int = SETTLE_FRAMES


## `preset` (menu demo) or the menu's handed-over data (LevelLoader.next_for_level) when it fits `path` and the
## current quality tier, else a new loader.
static func pick_loader(preset: LevelLoader, path: String, config: GameplayConfig) -> LevelLoader:
	var tier: QualityTier.Tier = UserSettings.quality_tier
	var preloaded: LevelLoader = preset if preset != null else LevelLoader.next_for_level
	LevelLoader.next_for_level = null
	if preloaded != null and preloaded.matches(path, tier):
		return preloaded
	return LevelLoader.new(path, config if config != null else GameplayConfig.create_for_play(), tier)


func _init(runner: LevelRunner, level_loader: LevelLoader, show_cover: bool) -> void:
	_runner = runner
	loader = level_loader.start()
	# Views that animate in _process wait until they are set up.
	for view: Node in _views():
		view.process_mode = Node.PROCESS_MODE_DISABLED
	if not show_cover:
		return
	var layer := CanvasLayer.new()
	layer.layer = COVER_LAYER
	runner.add_child(layer)
	var done: bool = loader.is_done()
	_cover = LoadingCover.new(loader.chart_path, loader.chart.title if done and loader.chart != null else "",
			LOADER_SHARE * (1.0 if done else loader.progress))
	layer.add_child(_cover)


## One step per frame; true once the views are set up (or loading failed: loader.failed()).
func step() -> bool:
	if not loader.is_done():
		_report(loader.progress * LOADER_SHARE)
		return false
	if loader.failed():
		abort()
		_runner.hud.show_message(Locale.t("Cannot load chart or song:\n%s") % loader.chart_path)
		return true
	var context: LevelContext = loader.context
	if _cover != null and not _cover.has_title():
		_cover.set_title(loader.chart.title)
	match _step:
		0:
			QualityTier.apply_to_viewport(_runner.get_viewport(), context.quality)
			_runner.environment_director.setup(context)
		1:
			_runner.track_view.setup(context, loader.track_geometry)
		2:
			_runner.decor_view.setup(context)
		3:
			_runner.obstacle_view.corridor_data = loader.corridor_data
			_runner.obstacle_view.setup(context)
		4:
			for view: Node in [_runner.player_view, _runner.camera_director, _runner.vfx_director]:
				view.call(&"setup", context)
		5:
			_runner.scenery_view.setup(context, SCENERY_SEED)
	_step += 1
	_report(LOADER_SHARE + (1.0 - LOADER_SHARE) * float(_step) / float(STEP_COUNT))
	if _step < STEP_COUNT:
		return false
	for view: Node in _views():
		view.process_mode = Node.PROCESS_MODE_INHERIT
	return true


## Called each frame once the level is running or waiting; true when the cover is gone (the boot can be dropped).
func settle() -> bool:
	if _cover == null:
		return true
	_settle_frames -= 1
	if _settle_frames > 0:
		return false
	_cover.dismiss()
	_cover = null
	return true


## Loading failed: the level shows the error message, so the cover goes at once.
func abort() -> void:
	if _cover != null:
		_cover.queue_free()
		_cover = null


func _views() -> Array[Node]:
	return [_runner.environment_director, _runner.track_view, _runner.decor_view, _runner.obstacle_view,
			_runner.player_view, _runner.camera_director, _runner.vfx_director, _runner.scenery_view]


func _report(value: float) -> void:
	if _cover != null:
		_cover.set_progress(value)
