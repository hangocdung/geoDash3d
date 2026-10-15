# Title screen: the level runs in attract mode (autoplay, no HUD) behind the menu (HomePage, MenuBackdrop). PLAY,
# PRACTICE and the debug build's RECORD (DEV) / AUTOPLAY (DEV) first pick a song (SongListPanel): selecting a song
# swaps the demo level to it (loaded in the background; AttractLoop limits its length), the list's big button starts
# it behind a LoadingCover (reusing the demo's loaded data); practice then picks a playback speed;
# autoplay plays the whole level by itself with the HUD on (checking a level, filming it).
# If level arguments were passed on the command line (--autoplay, --capture, …) it jumps straight
# into the level so tooling keeps working. SHOP opens the in-app purchases (ShopPanel).
# Related: src/ui/menu/home_page.gd, src/ui/scenes.gd, src/presentation/level/level_runner.gd
class_name MainMenu
extends Node

const PRACTICE_RATES: Array[float] = [1.0, 0.75, 0.5]

enum SongMode { PLAY, PRACTICE, RECORD, AUTOPLAY }

## Hidden while a full-screen page is open.
var _home: HomePage
var _settings: SettingsPanel
var _shop: ShopPanel
var _landscape_tip: LandscapeTip
var _practice_dialog: UiDialog
var _song_list: SongListPanel
## Home entry that opened the current page (focus returns to it).
var _panel_opener: StringName
var _root: Control
var _backdrop: MenuBackdrop
## The run waiting for its data behind the loading cover (null when none) and that data.
var _next_run: LaunchOptions
var _next_loader: LevelLoader
var _cover: LoadingCover


func _ready() -> void:
	DisplayOrientation.setup(get_window())
	DisplayOrientation.allow_rotation()
	# Before any shortcut into a level: purchases (remove_ads) first, then consent and the ad SDK; ads keep
	# preloading during play.
	Entitlements.apply()
	# A rewarded trial lasts until the player leaves the level (GD3-242).
	SongUnlocks.trial_path = ""
	Store.start(get_tree())
	Ads.start()
	if LaunchOptions.has_level_arguments():
		Scenes.go_to.call_deferred(get_tree(), Scenes.LEVEL)
		return
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	_backdrop.show_chart(Scenes.DEFAULT_CHART)
	_start_ads()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	_home = HomePage.new()
	_home.action_pressed.connect(_on_home_action)
	_root.add_child(_home)
	_home.set_now_playing("")
	_backdrop.level_shown.connect(_home.set_now_playing)
	_landscape_tip = LandscapeTip.new()
	_root.add_child(_landscape_tip)


func _on_home_action(action: StringName) -> void:
	match action:
		&"play":
			_on_play_pressed()
		&"practice":
			_open_songs(SongMode.PRACTICE)
		&"record":
			_open_songs(SongMode.RECORD)
		&"autoplay":
			_open_songs(SongMode.AUTOPLAY)
		&"calibrate":
			Scenes.go_to(get_tree(), Scenes.CALIBRATION)
		&"sync":
			Scenes.go_to(get_tree(), Scenes.METRONOME)
		&"settings":
			_open_settings()
		&"shop":
			_open_shop()


func _open_settings() -> void:
	_home.visible = false
	_settings = SettingsPanel.new()
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)


func _close_settings() -> void:
	_settings.queue_free()
	_settings = null
	_home.visible = true
	_home.focus(&"settings")


func _open_shop() -> void:
	_home.visible = false
	_landscape_tip.suppressed = true
	_shop = ShopPanel.new()
	_shop.closed.connect(func() -> void:
		_shop.queue_free()
		_shop = null
		_landscape_tip.suppressed = false
		_home.visible = true
		_home.focus(&"shop"))
	_root.add_child(_shop)


func _open_songs(mode: SongMode) -> void:
	_panel_opener = [&"play", &"practice", &"record", &"autoplay"][mode]
	_home.visible = false
	_song_list = SongListPanel.new()
	_song_list.heading = ["PLAY", "PRACTICE", "RECORD", "AUTOPLAY"][mode]
	_song_list.apply_locks = mode == SongMode.PLAY or mode == SongMode.PRACTICE
	_song_list.allow_trials = mode == SongMode.PLAY
	_song_list.selected_path = _backdrop.current_chart()
	_song_list.previewed.connect(_backdrop.show_chart)
	_backdrop.loading_changed.connect(_song_list.set_loading)
	_song_list.shop_requested.connect(func() -> void:
		_close_songs()
		_open_shop())
	_song_list.closed.connect(_close_songs)
	_song_list.chosen.connect(func(chart: String) -> void:
		if mode == SongMode.PRACTICE:
			_open_practice(chart)
		elif mode == SongMode.RECORD:
			Recorder.next_chart_path = chart
			Scenes.go_to(get_tree(), Scenes.RECORDER)
		elif mode == SongMode.AUTOPLAY:
			_start_level(LaunchOptions.autoplay_run(chart))
		else:
			_start_level(LaunchOptions.chart_run(chart)))
	_root.add_child(_song_list)
	_song_list.set_loading(_backdrop.is_loading())


func _close_songs() -> void:
	_backdrop.loading_changed.disconnect(_song_list.set_loading)
	_song_list.queue_free()
	_song_list = null
	_home.visible = true
	_home.focus(_panel_opener)


## Practice speed picker over the song list.
func _open_practice(chart: String) -> void:
	_practice_dialog = UiDialog.create("PRACTICE", &"target",
			"Checkpoints every 16 beats.\nDying restarts from the last one.")
	var first: Button = null
	for rate: float in PRACTICE_RATES:
		var start_run := func() -> void:
			_practice_dialog.close()
			_start_level(LaunchOptions.practice_run(rate, chart))
		var button: Button = _practice_dialog.add_button(Locale.t("SPEED %d%%") % roundi(rate * 100.0), &"speed",
				first == null, start_run, &"ui.confirm")
		if first == null:
			first = button
	_practice_dialog.add_button("BACK", &"back", false, _close_practice, &"ui.back")
	_root.add_child(_practice_dialog)
	first.grab_focus()


## Back to the song list.
func _close_practice() -> void:
	_practice_dialog.close()
	_practice_dialog = null


## Starts `run` behind a LoadingCover: its data comes from the demo when it already has it, else loads on a thread
## while the cover animates; the level then shows the same cover while it builds its views.
func _start_level(run: LaunchOptions) -> void:
	if _next_run != null:
		return
	var loader: LevelLoader = _backdrop.loader_for(run.chart_path)
	if loader == null:
		loader = LevelLoader.new(run.chart_path, GameplayConfig.create_for_play(), UserSettings.quality_tier)
	_next_loader = loader.start()
	_next_run = run
	_backdrop.stop()
	_cover = LoadingCover.new(run.chart_path, _song_list.title_of(run.chart_path) if _song_list != null else "")
	_root.add_child(_cover)


func _process(_delta: float) -> void:
	if _next_run == null:
		return
	_cover.set_progress(_next_loader.progress * LevelBoot.LOADER_SHARE)
	if _next_loader.is_done():
		LaunchOptions.set_next_run(_next_run)
		LevelLoader.next_for_level = _next_loader
		Scenes.go_to(get_tree(), Scenes.LEVEL)
		set_process(false)


## The menu banner and an interstitial on coming back from a run (Ads decides
## whether enough play has passed). The attract level's music pauses while a full-screen ad is open.
func _start_ads() -> void:
	Ads.on_fullscreen = func(shown: bool) -> void:
		var level: LevelRunner = _backdrop.level if is_instance_valid(_backdrop) else null
		if level == null or level.state == LevelRunner.RunState.LOADING:
			return
		if shown:
			level.song_clock.pause()
		else:
			level.song_clock.resume(0.0)
	Ads.show_banner()
	Ads.maybe_show_interstitial()


func _exit_tree() -> void:
	Ads.hide_banner()
	Ads.on_fullscreen = Callable()


## PLAY. The very first time on a phone it first offers the 30-second audio calibration (GD3-250): phones report no
## output latency, and the in-game auto sync only corrects between runs.
func _on_play_pressed() -> void:
	if UserSettings.calibration_offered or not OS.has_feature("mobile"):
		_open_songs(SongMode.PLAY)
		return
	UserSettings.calibration_offered = true
	UserSettings.save_settings()
	var dialog: UiDialog = UiDialog.create("AUDIO SYNC", &"headphones",
			"Calibrate first (30 s)? Taps will match the music through your speakers or headphones.")
	var now: Button = dialog.add_button("CALIBRATE NOW", &"headphones", true,
			func() -> void: Scenes.go_to(get_tree(), Scenes.CALIBRATION), &"ui.confirm")
	dialog.add_button("LATER", &"chevron", false, func() -> void:
		dialog.close()
		_open_songs(SongMode.PLAY), &"ui.back")
	_root.add_child(dialog)
	now.grab_focus()
