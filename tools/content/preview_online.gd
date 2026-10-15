# Captures the real song list and a completed-run rating card for visual review.
# Related: SongListPanel, RunMenu, scene_shot.gd.
extends SceneTree

var _frames: int = 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	DisplayOrientation.setup(root)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var songs: Control = load("res://src/ui/menu/song_list_panel.gd").new()
	songs.apply_locks = false
	screen.add_child(songs)
	if OS.get_cmdline_user_args().has("--rating"):
		songs.visible = false
		var results: Control = load("res://src/ui/hud/run_menu.gd").new()
		screen.add_child(results)
		results.open_results("LEVEL COMPLETE\nSCORE 24,500 · 96.0%\nPERFECT 148 · MAX COMBO 148", "S", true)
		SongRatings.start(self)._state.erase_section_key("prompted", "preview_song")
		results.offer_song_rating("preview_song")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 120:
		var name: String = "rating" if OS.get_cmdline_user_args().has("--rating") else "song-list"
		root.get_texture().get_image().save_png("res://tools/capture/out/online-" + name + ".png")
		quit()
	return false
