# The level demo behind the menu (attract mode). show_chart() loads another song on a LevelLoader thread while the
# current demo keeps playing, then fades a dark veil in, swaps the level (its views build behind the veil over a few
# frames) and fades back out, so choosing a song never freezes the page. Also runs the quality auto tuner.
# Related: src/ui/menu/main_menu.gd, src/presentation/level/level_loader.gd, src/presentation/level/level_boot.gd
class_name MenuBackdrop
extends Node

## The new demo is on screen.
signal level_shown(title: String)
## A song is loading (the song list shows a spinner).
signal loading_changed(loading: bool)

const LEVEL_SCENE: PackedScene = preload("res://src/presentation/level/level.tscn")
## Above the level (and its hidden HUD), below the menu pages (layer 10).
const VEIL_LAYER: int = 5
const VEIL_COLOR: Color = Color(0.02, 0.0, 0.07)
const VEIL_FADE_SEC: float = 0.22

var level: LevelRunner
var _wanted: String = ""
var _pending: LevelLoader
## Superseded loads still running: WorkerThreadPool tasks must be waited on, so they are polled until done.
var _stale: Array[LevelLoader] = []
var _swapping: bool = false
var _veil: ColorRect
var _tuner: QualityAutoTuner


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = VEIL_LAYER
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = VEIL_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)
	_tuner = QualityAutoTuner.new()
	_tuner.name = "QualityAutoTuner"
	add_child(_tuner)


## The demo of `chart_path` (nothing to do when it already plays or loads it).
func show_chart(chart_path: String) -> void:
	if chart_path == _wanted:
		return
	_wanted = chart_path
	if _pending != null:
		_stale.append(_pending)
		_pending = null
	if level != null and level.loader.matches(chart_path, UserSettings.quality_tier):
		loading_changed.emit(_swapping)
		return
	_pending = LevelLoader.new(chart_path, GameplayConfig.create_for_play(), UserSettings.quality_tier).start()
	loading_changed.emit(true)


func is_loading() -> bool:
	return _pending != null or _swapping


func current_chart() -> String:
	return level.loader.chart_path if level != null else _wanted


## Data already loaded (or loading) for `chart_path`, so starting that song does not load it twice.
func loader_for(chart_path: String) -> LevelLoader:
	for candidate: LevelLoader in [_pending, level.loader if level != null else null]:
		if candidate != null and candidate.matches(chart_path, UserSettings.quality_tier):
			return candidate
	return null


## Before leaving for a run: silence the demo and stop swapping.
func stop() -> void:
	set_process(false)
	if level != null:
		level.song_clock.stop()


func _process(_delta: float) -> void:
	_stale = _stale.filter(func(loader: LevelLoader) -> bool: return not loader.is_done())
	if _pending != null and not _swapping and _pending.is_done():
		var next: LevelLoader = _pending
		_pending = null
		if next.failed():
			loading_changed.emit(false)
		else:
			_swap(next)


func _swap(next: LevelLoader) -> void:
	_swapping = true
	if level != null:
		await _fade_veil(1.0)
		level.song_clock.stop()
		remove_child(level)
		level.queue_free()
	level = LEVEL_SCENE.instantiate() as LevelRunner
	level.preset_options = LaunchOptions.attract()
	level.preset_options.chart_path = next.chart_path
	level.preset_loader = next
	add_child(level)
	move_child(level, 0)
	_tuner.setup(level)
	await level.loaded
	_swapping = false
	loading_changed.emit(_pending != null)
	level_shown.emit(level.chart.title)
	_fade_veil(0.0)


func _fade_veil(alpha: float) -> Signal:
	var tween: Tween = create_tween()
	tween.tween_property(_veil, "color:a", alpha, VEIL_FADE_SEC)
	return tween.finished
