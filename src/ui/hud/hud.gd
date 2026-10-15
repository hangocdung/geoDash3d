# In-run overlay: progress bar with percentage, score, judgement popups, combo counter, shield charge meter,
# attempt counter, centered message, a touch-friendly pause button and the pause/complete RunMenu.
# Respects the mobile safe area.
# Related: src/presentation/level/level_runner.gd, src/ui/hud/run_menu.gd
class_name Hud
extends CanvasLayer

signal pause_pressed

const BAR_WIDTH: float = 760.0
const BAR_HEIGHT: float = 16.0
const POPUP_LIFETIME: float = 0.55
## The combo shows from this many hits on.
const COMBO_MIN_SHOWN: int = 2
const SHIELD_BAR_WIDTH: float = 170.0
const SHIELD_COLOR: Color = Color(0.6, 0.75, 1.0)
const SHIELD_DIM: Color = Color(0.45, 0.5, 0.7, 0.75)
const GRADE_COLORS: Dictionary[int, Color] = {
	Judgement.Grade.PERFECT: Color(1.0, 0.95, 0.5),
	Judgement.Grade.GREAT: Color(0.45, 1.0, 0.9),
	Judgement.Grade.GOOD: Color(0.6, 0.7, 1.0),
	Judgement.Grade.MISS: Color(1.0, 0.3, 0.45),
}

var _bar_fill: ColorRect
var _percent_label: Label
var _judgement_label: Label
var _message_label: Label
var _attempt_label: Label
var _popup_age: float = INF
var _attempt_fade: float = 0.0
var run_menu: RunMenu
var _pause_button: Button
var _mode_label: Label
var _score_label: Label
var _combo_label: Label
var _combo_age: float = INF
var _shield_label: Label
var _shield_fill: ColorRect
var _root: Control


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root
	_apply_safe_area(root)
	_build_progress(root)
	_judgement_label = _make_label(root, 56, Control.PRESET_CENTER_TOP, Vector2(0, 110))
	_combo_label = _make_label(root, 34, Control.PRESET_CENTER_TOP, Vector2(0, 182))
	_message_label = _make_label(root, 64, Control.PRESET_CENTER, Vector2(0, -40))
	_attempt_label = _make_label(root, 40, Control.PRESET_CENTER_TOP, Vector2(0, 260))
	_pause_button = UiTheme.make_button("II", 84.0)
	_pause_button.theme = UiTheme.get_theme()
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.position = Vector2(28, 22)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	root.add_child(_pause_button)
	_mode_label = _make_label(root, 28, Control.PRESET_TOP_LEFT, Vector2(130, 34))
	_mode_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.45))
	# Starts right of the pause button and grows rightward (centred text would spill over the button).
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mode_label.grow_horizontal = Control.GROW_DIRECTION_END
	_build_shield_meter(root)
	_score_label = _make_label(root, 36, Control.PRESET_TOP_RIGHT, Vector2(-32, 62))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	set_score(0)
	run_menu = RunMenu.new()
	add_child(run_menu)


## Diagnostic spectrum + cue lane along the bottom (Settings > Music meter).
func enable_music_meter(chart: LevelChart, clock: SongClock) -> void:
	var meter := MusicMeter.new()
	meter.setup(chart, clock, AudioBuses.music_spectrum())
	_root.add_child(meter)


## Hides everything (menu attract mode).
func set_overlay_enabled(enabled: bool) -> void:
	visible = enabled


func _process(delta: float) -> void:
	_popup_age += delta
	var popup_t: float = clampf(_popup_age / POPUP_LIFETIME, 0.0, 1.0)
	_judgement_label.modulate.a = 1.0 - popup_t * popup_t
	_judgement_label.scale = Vector2.ONE * lerpf(1.25, 1.0, minf(popup_t * 4.0, 1.0))
	_combo_age += delta
	_combo_label.scale = Vector2.ONE * lerpf(1.18, 1.0, clampf(_combo_age * 8.0, 0.0, 1.0))
	_attempt_fade = maxf(_attempt_fade - delta * 0.6, 0.0)
	_attempt_label.modulate.a = clampf(_attempt_fade, 0.0, 1.0)


func set_progress(progress: float) -> void:
	_bar_fill.size.x = BAR_WIDTH * clampf(progress, 0.0, 1.0)
	_percent_label.text = "%d%%" % int(floorf(progress * 100.0))


func show_judgement(grade: Judgement.Grade) -> void:
	_judgement_label.text = Judgement.label(grade)
	_judgement_label.add_theme_color_override("font_color", GRADE_COLORS[grade])
	_judgement_label.pivot_offset = _judgement_label.size * 0.5
	_popup_age = 0.0


func set_combo(combo: int) -> void:
	_combo_label.visible = combo >= COMBO_MIN_SHOWN
	_combo_label.text = "%d COMBO" % combo
	_combo_label.pivot_offset = _combo_label.size * 0.5
	_combo_age = 0.0 if combo > 0 else INF


func set_score(score: int) -> void:
	_score_label.text = RunRecords.grouped(score)


## `charge` = 0..1 progress toward the next shield; `ready` = a shield is held.
func set_shield(ready: bool, charge: float) -> void:
	_shield_label.text = "SHIELD READY" if ready else "SHIELD"
	_shield_label.add_theme_color_override("font_color", SHIELD_COLOR if ready else SHIELD_DIM)
	_shield_fill.size.x = (SHIELD_BAR_WIDTH - 4.0) * clampf(1.0 if ready else charge, 0.0, 1.0)
	_shield_fill.color = SHIELD_COLOR if ready else SHIELD_DIM


## Short centered notice that fades out (attempts, checkpoints).
func show_toast(text: String) -> void:
	_attempt_label.text = text
	_attempt_fade = 1.6


## Persistent mode tag next to the pause button (e.g. PRACTICE 75%).
func show_mode(text: String) -> void:
	_mode_label.text = text


func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()


func _build_progress(root: Control) -> void:
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.position = Vector2(-BAR_WIDTH * 0.5, 36.0)
	frame.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.12, 0.7)
	style.border_color = Color(0.85, 0.9, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.3, 0.9, 1.0)
	_bar_fill.position = Vector2(3, 3)
	_bar_fill.size = Vector2(0, BAR_HEIGHT - 6.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_bar_fill)
	_percent_label = _make_label(root, 34, Control.PRESET_CENTER_TOP, Vector2(BAR_WIDTH * 0.5 + 70.0, 20.0))


## Small meter under the pause button: fills with the combo, glows when a shield is ready.
func _build_shield_meter(root: Control) -> void:
	_shield_label = _make_label(root, 22, Control.PRESET_TOP_LEFT, Vector2(30, 112))
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_shield_label.grow_horizontal = Control.GROW_DIRECTION_END
	var frame := ColorRect.new()
	frame.color = Color(0.05, 0.03, 0.12, 0.7)
	frame.position = Vector2(30, 146)
	frame.size = Vector2(SHIELD_BAR_WIDTH, 10)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_shield_fill = ColorRect.new()
	_shield_fill.position = Vector2(2, 2)
	_shield_fill.size = Vector2(0, 6)
	_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_shield_fill)
	set_shield(false, 0.0)


func _make_label(root: Control, font_size: int, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position += offset
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.12, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label


func _apply_safe_area(root: Control) -> void:
	if not OS.has_feature("mobile"):
		return
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return
	var scale_factor: float = get_viewport().get_visible_rect().size.x / float(screen.x)
	root.offset_left = float(safe.position.x) * scale_factor
	root.offset_right = -float(screen.x - safe.end.x) * scale_factor
	root.offset_top = float(safe.position.y) * scale_factor
