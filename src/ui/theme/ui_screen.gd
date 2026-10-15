# Base of the full-screen menu pages (settings, song list, shop): a dim backdrop, safe-area margins, the header
# (BACK + icon + title + subtitle) and a body. Subclasses fill `body` in _build_body() and adapt to rotation in
# _layout(portrait), called once built and whenever the screen turns between landscape and portrait.
# Related: src/ui/theme/ui_kit.gd, src/ui/menu/settings_panel.gd, src/ui/menu/song_list_panel.gd
class_name UiScreen
extends Control

signal closed

var body: VBoxContainer
## The dim backdrop; pages that show the level behind them (song list demo) restyle it.
var shade: ColorRect
var _margin: MarginContainer
var _portrait: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.05, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	_margin.add_child(column)
	column.add_child(UiKit.header(_title(), _subtitle(), _icon(), _close))
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	_build_body()
	_portrait = UiKit.is_portrait(self)
	_apply_margins()
	_layout(_portrait)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _title() -> String:
	return ""


func _subtitle() -> String:
	return ""


func _icon() -> StringName:
	return &"info"


func _build_body() -> void:
	pass


func _layout(_is_portrait: bool) -> void:
	pass


## BACK. Subclasses that save state first override this and call super.
func _close() -> void:
	closed.emit()


func _on_viewport_resized() -> void:
	_apply_margins()
	var portrait: bool = UiKit.is_portrait(self)
	if portrait != _portrait:
		_portrait = portrait
		_layout(portrait)


func _apply_margins() -> void:
	var margins: Vector4 = UiKit.safe_margins(self)
	_margin.add_theme_constant_override("margin_left", int(margins.x))
	_margin.add_theme_constant_override("margin_top", int(margins.y))
	_margin.add_theme_constant_override("margin_right", int(margins.z))
	_margin.add_theme_constant_override("margin_bottom", int(margins.w))
