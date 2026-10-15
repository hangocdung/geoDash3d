# Full-screen loading screen before a level: the song's cover and title, a spinner, a progress bar and LOADING.
# The menu shows one while LevelLoader works, then the level shows an identical one (same progress) while it builds
# its views over a few frames, and fades it out once the first frames have rendered, so the hand-over looks like
# one screen. Related: src/presentation/level/level_boot.gd, src/ui/menu/main_menu.gd, src/ui/loading/loading_spinner.gd
class_name LoadingCover
extends Control

const BACKGROUND: Color = Color(0.02, 0.0, 0.07)
const BAR_SIZE: Vector2 = Vector2(560, 10)
const COVER_SIZE: Vector2 = Vector2(360, 240)
const FADE_SEC: float = 0.35
## The bar eases toward the reported progress instead of jumping.
const BAR_EASE: float = 10.0

var _title: Label
var _fill: ColorRect
var _shown_progress: float = 0.0
var _target_progress: float = 0.0


## `chart_path` picks the cover art (assets/covers); `title` may come later (set_title) once the chart is loaded.
func _init(chart_path: String, title: String = "", start_progress: float = 0.0) -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_progress = start_progress
	_target_progress = start_progress
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	add_child(column)
	var art: Control = SongRow.cover_art(SongCatalog.song_id(chart_path))
	art.custom_minimum_size = COVER_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(art)
	_title = UiKit.label(title.to_upper(), "", HORIZONTAL_ALIGNMENT_CENTER)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.add_theme_font_override("font", UiTheme.heading_font())
	_title.add_theme_font_size_override("font_size", 40)
	column.add_child(_title)
	column.add_child(LoadingSpinner.new(72.0))
	var bar := ColorRect.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.color = Color(UiTheme.VIOLET, 0.25)
	column.add_child(bar)
	_fill = ColorRect.new()
	_fill.color = UiTheme.HOT
	_fill.size = Vector2(BAR_SIZE.x * _shown_progress, BAR_SIZE.y)
	bar.add_child(_fill)
	var caption: Label = UiKit.label("LOADING", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	caption.add_theme_font_size_override("font_size", 24)
	column.add_child(caption)


func set_title(title: String) -> void:
	_title.text = title.to_upper()


func has_title() -> bool:
	return not _title.text.is_empty()


## 0..1 (never moves back).
func set_progress(value: float) -> void:
	_target_progress = maxf(_target_progress, clampf(value, 0.0, 1.0))


func shown_progress() -> float:
	return _shown_progress


func _process(delta: float) -> void:
	_shown_progress = lerpf(_shown_progress, _target_progress, minf(delta * BAR_EASE, 1.0))
	_fill.size = Vector2(BAR_SIZE.x * _shown_progress, BAR_SIZE.y)


## Fades away and frees itself.
func dismiss() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_progress = 1.0
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	fade.tween_callback(queue_free)
