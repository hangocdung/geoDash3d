# Level orchestrator: loads the chart, owns the RunSimulation, feeds it song time and taps, and runs
# the state machine (waiting / running / paused / dead / complete / attract). Effects are routed by
# PresentationRouter. Related: src/gameplay/simulation/run_simulation.gd, src/presentation/level/level.tscn
class_name LevelRunner
extends Node3D

enum RunState { LOADING, WAITING, RUNNING, PAUSED, DEAD, COMPLETE }

const COUNT_IN_BEATS: float = 4.0
const RESTART_DELAY_SEC: float = 0.9
const SCENERY_SEED: int = 1337
const ATTRACT_VOLUME_OFFSET_DB: float = -4.0

@export_file("*.json") var chart_path: String = Scenes.DEFAULT_CHART
@export var gameplay_config: GameplayConfig

## Set before adding to the tree to bypass command-line parsing (menu attract mode).
var preset_options: LaunchOptions
var chart: LevelChart
var simulation: RunSimulation
var options: LaunchOptions
var state: RunState = RunState.LOADING
var start_beat: float = -COUNT_IN_BEATS

var _context: LevelContext
var _router: PresentationRouter
var _stream: AudioStream
var _autoplay: Autoplay
var _pending_tap_times: PackedFloat64Array = []
var _attempt: int = 0
var _death_beat: float = 0.0
var _restart_timer: float = 0.0

@onready var song_clock: SongClock = $SongClock
@onready var environment_director: EnvironmentDirector = $EnvironmentDirector
@onready var track_view: TrackView = $TrackView
@onready var scenery_view: SceneryView = $SceneryView
@onready var obstacle_view: ObstacleView = $ObstacleView
@onready var player_view: PlayerView = $PlayerView
@onready var camera_director: CameraDirector = $CameraDirector
@onready var vfx_director: VfxDirector = $VfxDirector
@onready var hud: Hud = $Hud
@onready var capture: CaptureController = $CaptureController


func _ready() -> void:
	options = preset_options if preset_options != null else LaunchOptions.from_command_line()
	var config: GameplayConfig = gameplay_config if gameplay_config != null else GameplayConfig.create_default()
	var path: String = options.chart_path if not options.chart_path.is_empty() else chart_path
	chart = ChartLoader.load_file(path, config)
	_stream = load(chart.song_path) as AudioStream if chart != null else null
	if _stream == null:
		hud.show_message("Cannot load chart or song:\n%s" % path)
		return
	_context = LevelContext.new(chart, config, TrackPath.build(chart), UserSettings.quality_tier)
	for view: Node in [environment_director, track_view, obstacle_view, player_view, camera_director, vfx_director]:
		view.call(&"setup", _context)
	scenery_view.setup(_context, SCENERY_SEED)
	_router = PresentationRouter.new(self, _context)
	song_clock.drive_mode = SongClock.DriveMode.FRAME_DELTA if options.frame_delta_clock \
			else SongClock.DriveMode.AUDIO_SYNC
	song_clock.calibration_offset_sec = UserSettings.audio_offset_sec
	song_clock.song_finished.connect(_on_song_finished)
	UserSettings.changed.connect(_apply_volume)
	_apply_volume()
	_connect_hud()
	if not is_nan(options.start_beat):
		start_beat = chart.safe_start_beat(options.start_beat)
	if options.is_capture_run():
		capture.begin(self, options)
		return
	prepare_run()
	if options.skip_start_screen:
		begin_run()
	else:
		state = RunState.WAITING
		hud.show_message("%s\nTAP TO START" % chart.title.to_upper())


## Fresh simulation at `start_beat`; views are reset and posed but the clock is not started.
func prepare_run() -> void:
	simulation = RunSimulation.new(chart, _context.config, start_beat)
	simulation.invincible = options.invincible
	simulation.player_died.connect(_on_player_died)
	simulation.run_completed.connect(_on_run_completed)
	_router.bind(simulation, start_beat)
	_autoplay = Autoplay.new(chart, start_beat) if options.autoplay else null
	_pending_tap_times.clear()
	for view: Node in [player_view, obstacle_view, camera_director, vfx_director, environment_director]:
		view.call(&"reset_view")
	hud.run_menu.close()
	_update_presentation(start_beat, 0.0)


func begin_run() -> void:
	_attempt += 1
	hud.show_message("")
	if not options.attract_mode:
		hud.show_attempt(_attempt)
	var start_time: float = chart.time_at(start_beat)
	var audio_start: float = maxf(start_time, 0.0)
	song_clock.start(_stream, audio_start, audio_start - start_time)
	state = RunState.RUNNING


func restart() -> void:
	song_clock.stop()
	prepare_run()
	begin_run()


func current_beat() -> float:
	return chart.beat_at_time(song_clock.frame_time())


func _process(delta: float) -> void:
	match state:
		RunState.RUNNING, RunState.COMPLETE:
			var beat: float = current_beat()
			for tap_time: float in _pending_tap_times:
				simulation.tap(chart.beat_at_time(tap_time))
			_pending_tap_times.clear()
			if _autoplay != null:
				_autoplay.drive(simulation, beat)
			else:
				simulation.advance_to(beat)
			_router.fire_vfx_cues(beat)
			if options.debug_clock and Engine.get_process_frames() % 30 == 0:
				print("CLOCK t=%.3f drift_ms=%.2f latency_ms=%.1f fps=%d" % [song_clock.frame_time(),
						song_clock.audio_drift() * 1000.0, AudioServer.get_output_latency() * 1000.0,
						Engine.get_frames_per_second()])
			_update_presentation(beat if state != RunState.DEAD else _death_beat, delta)
			if state == RunState.RUNNING:
				_router.update_trails(simulation.active_action(), delta)
		RunState.DEAD:
			_update_presentation(_death_beat, delta)
			_restart_timer -= delta
			if _restart_timer <= 0.0:
				restart()
		RunState.WAITING, RunState.PAUSED:
			_update_presentation(simulation.current_beat, delta)


func _unhandled_input(event: InputEvent) -> void:
	if state == RunState.LOADING or capture.is_active() or options.attract_mode:
		return
	if event.is_action_pressed(&"restart"):
		restart()
	elif event.is_action_pressed(&"pause"):
		_toggle_pause()
	elif event.is_action_pressed(&"tap", false, true):
		match state:
			RunState.WAITING:
				begin_run()
			RunState.RUNNING:
				if _autoplay == null:
					_pending_tap_times.append(song_clock.now())
			RunState.COMPLETE:
				if simulation.current_beat > chart.end_beat + 2.0:
					restart()


func _toggle_pause() -> void:
	if state == RunState.RUNNING:
		song_clock.pause()
		state = RunState.PAUSED
		hud.run_menu.open("PAUSED", true)
	elif state == RunState.PAUSED:
		hud.run_menu.close()
		song_clock.resume(0.0)
		state = RunState.RUNNING


func _connect_hud() -> void:
	hud.set_overlay_enabled(not options.attract_mode)
	hud.pause_pressed.connect(_toggle_pause)
	hud.run_menu.resume_pressed.connect(_toggle_pause)
	hud.run_menu.restart_pressed.connect(restart)
	hud.run_menu.menu_pressed.connect(func() -> void:
		song_clock.stop()
		Scenes.go_to(get_tree(), Scenes.MAIN_MENU))


func _apply_volume() -> void:
	var offset: float = ATTRACT_VOLUME_OFFSET_DB if options.attract_mode else 0.0
	song_clock.audio_player.volume_db = UserSettings.music_volume_db + offset


func _update_presentation(beat: float, delta: float) -> void:
	player_view.update_pose(beat, simulation, delta)
	camera_director.update_camera(beat, simulation.player_height_at(beat), delta)
	environment_director.update_environment(beat, delta)
	vfx_director.follow_camera(camera_director.camera.global_position)
	hud.set_progress(chart.progress_at(beat))


func _on_player_died(_hazard_index: int, beat: float) -> void:
	state = RunState.DEAD
	_death_beat = beat
	_restart_timer = RESTART_DELAY_SEC
	song_clock.stop()
	_router.on_player_died(beat)


func _on_run_completed(_beat: float) -> void:
	state = RunState.COMPLETE
	if options.attract_mode:
		return
	var counts: PackedInt32Array = simulation.grade_counts
	hud.run_menu.open("LEVEL COMPLETE\nPERFECT %d   GREAT %d   GOOD %d   MISS %d" % [counts[0], counts[1],
			counts[2], counts[3]], false)


func _on_song_finished() -> void:
	if options.attract_mode:
		restart()
