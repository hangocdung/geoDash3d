# Dev preview of one UI state for tools/capture/scene_shot.gd: `-- --preview=<state>` with settings:<tab>,
# run:paused, run:results, dialog:practice or dialog:calibrate. Related: tools/capture/screens.sh
extends Control

const RESULTS_TEXT: String = "LEVEL COMPLETE\nSCORE 25,681  ·  94.2%\nNEW BEST!\nPERFECT 88   GREAT 12   GOOD 3   MISS 1\nMAX COMBO 64"


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.05, 0.02, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var state: String = "settings:general"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			state = argument.trim_prefix("--preview=")
	var parts: PackedStringArray = state.split(":")
	match parts[0]:
		"settings":
			var panel := SettingsPanel.new()
			add_child(panel)
			panel.open_tab(StringName(parts[1]))
		"run":
			var menu := RunMenu.new()
			add_child(menu)
			if parts[1] == "results":
				menu.open_results(RESULTS_TEXT, "A", true)
			else:
				menu.open("PAUSED", true)
		"dialog":
			var dialog: UiDialog
			if parts[1] == "practice":
				dialog = UiDialog.create("PRACTICE", &"target", "Checkpoints every 16 beats.\nDying restarts from the last one.")
				for rate: int in [100, 75, 50]:
					dialog.add_button(Locale.t("SPEED %d%%") % rate, &"speed", rate == 100, func() -> void: pass)
				dialog.add_button("BACK", &"back", false, func() -> void: pass)
			else:
				dialog = UiDialog.create("AUDIO SYNC", &"headphones",
						"Calibrate first (30 s)? Taps will match the music through your speakers or headphones.")
				dialog.add_button("CALIBRATE NOW", &"headphones", true, func() -> void: pass)
				dialog.add_button("LATER", &"chevron", false, func() -> void: pass)
			add_child(dialog)
