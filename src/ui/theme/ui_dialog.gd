# Modal dialog: dims the screen and shows a centred glowing card with an icon + title, an optional message and a
# column of buttons (practice speed, first-run calibration offer). Build with UiDialog.create(), then add_button().
# Related: src/ui/theme/ui_kit.gd, src/ui/menu/main_menu.gd
class_name UiDialog
extends Control

const WIDTH: float = 760.0

var buttons: VBoxContainer
var _card: VBoxContainer


static func create(title: String, icon: StringName, message: String = "") -> UiDialog:
	var dialog := UiDialog.new()
	dialog.theme = UiTheme.get_theme()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.05, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Dialog"
	center.add_child(panel)
	dialog._card = VBoxContainer.new()
	dialog._card.custom_minimum_size = Vector2(WIDTH, 0)
	dialog._card.add_theme_constant_override("separation", 22)
	panel.add_child(dialog._card)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 18)
	heading.add_child(UiKit.icon_rect(icon, 52, UiTheme.HOT))
	heading.add_child(UiKit.label(title, "SectionTitle"))
	dialog._card.add_child(heading)
	if not message.is_empty():
		var text: Label = UiKit.label(message, "", HORIZONTAL_ALIGNMENT_CENTER)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 26)
		text.add_theme_color_override("font_color", UiTheme.MUTED)
		dialog._card.add_child(text)
	dialog.buttons = VBoxContainer.new()
	dialog.buttons.add_theme_constant_override("separation", 14)
	dialog._card.add_child(dialog.buttons)
	return dialog


## Full-width button in the dialog; the first primary one is what Enter / A activates by default.
func add_button(text: String, icon: StringName, primary: bool, action: Callable,
		sound_id: StringName = &"ui.tap") -> Button:
	var result: Button = UiKit.button(text, icon, "PrimaryButton" if primary else "", false, Vector2(0, 72), sound_id)
	result.pressed.connect(action)
	buttons.add_child(result)
	return result


func close() -> void:
	queue_free()
