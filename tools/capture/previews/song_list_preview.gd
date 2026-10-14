# Dev preview: shows the SongListPanel alone so tools/capture/scene_shot.gd can screenshot it.
extends Control


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.05, 0.02, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := SongListPanel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
