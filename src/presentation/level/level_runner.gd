# Level orchestrator: loads the chart, owns the RunSimulation, feeds it song time and taps,
# routes simulation signals to presentation nodes and handles start / death / restart / complete.
# Related: src/gameplay/simulation/run_simulation.gd, src/presentation/level/level.tscn
class_name LevelRunner
extends Node3D

enum RunState { LOADING, WAITING, RUNNING, PAUSED, DEAD, COMPLETE }

const COUNT_IN_BEATS: float = 4.0
const RESTART_DELAY_SEC: float = 0.9
const SCENERY_SEED: int = 1337
const GHOST_INTERVAL_SEC: float = 0.045

@export_file("*.json") var chart_path: String = "res://assets/music/the_dawn_assembly.chart.json"
@export var gameplay_config: GameplayConfig

var chart: LevelChart
var simulation: RunSimulation
var options: LaunchOptions
var state: RunState = RunState.LOADING
var start_beat: float = -COUNT_IN_BEATS

var _context: LevelContext
var _stream: AudioStream
var _autoplay: Autoplay
var _pending_tap_times: PackedFloat64Array = []
var _attempt: int = 0
var _death_beat: float = 0.0
var _restart_timer: float = 0.0
var _next_vfx_cue: int = 0
var _ghost_timer: float = 0.0

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
	options = LaunchOptions.from_command_line()
	var config: GameplayConfig = gameplay_config if gameplay_config != null else GameplayConfig.create_default()
	var path: String = options.chart_path if not options.chart_path.is_empty() else chart_path
	chart = ChartLoader.load_file(path, config)
	if chart == null:
		hud.show_message("Cannot load chart:\n%s" % path)
		return
	_stream = load(chart.song_path) as AudioStream
	if _stream == null:
		hud.show_message("Cannot load song:\n%s" % chart.song_path)
		return
	_context = LevelContext.new(chart, config, TrackPath.build(chart), UserSettings.quality_tier)
	environment_director.setup(_context)
	track_view.setup(_context)
	scenery_view.setup(_context, SCENERY_SEED)
	obstacle_view.setup(_context)
	player_view.setup(_context)
	camera_director.setup(_context)
	vfx_director.setup(_context)
	song_clock.drive_mode = SongClock.DriveMode.FRAME_DELTA if options.frame_delta_clock \
			else SongClock.DriveMode.AUDIO_SYNC
	song_clock.calibration_offset_sec = UserSettings.audio_offset_sec
	song_clock.song_finished.connect(_on_song_finished)
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
	simulation.action_started.connect(_on_action_started)
	simulation.action_finished.connect(_on_action_finished)
	simulation.cue_judged.connect(_on_cue_judged)
	simulation.player_died.connect(_on_player_died)
	simulation.run_completed.connect(_on_run_completed)
	_autoplay = Autoplay.new(chart, start_beat) if options.autoplay else null
	_pending_tap_times.clear()
	_next_vfx_cue = 0
	while _next_vfx_cue < chart.vfx_cues.size() and chart.vfx_cues[_next_vfx_cue].beat < start_beat:
		_next_vfx_cue += 1
	for view: Node in [player_view, obstacle_view, camera_director, vfx_director, environment_director]:
		view.call(&"reset_view")
	_update_presentation(start_beat, 0.0)


func begin_run() -> void:
	_attempt += 1
	hud.show_message("")
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
			_fire_vfx_cues(beat)
			if options.debug_clock and Engine.get_process_frames() % 30 == 0:
				print("CLOCK t=%.3f drift_ms=%.2f latency_ms=%.1f fps=%d" % [song_clock.frame_time(),
						song_clock.audio_drift() * 1000.0, AudioServer.get_output_latency() * 1000.0,
						Engine.get_frames_per_second()])
			_update_presentation(beat if state != RunState.DEAD else _death_beat, delta)
		RunState.DEAD:
			_update_presentation(_death_beat, delta)
			_restart_timer -= delta
			if _restart_timer <= 0.0:
				restart()
		RunState.WAITING, RunState.PAUSED:
			_update_presentation(simulation.current_beat, delta)


func _unhandled_input(event: InputEvent) -> void:
	if state == RunState.LOADING or capture.is_active():
		return
	if event.is_action_pressed(&"restart"):
		restart()
	elif event.is_action_pressed(&"pause"):
		_toggle_pause()
	elif event.is_action_pressed(&"tap", false, true):
		match state:
			RunState.WAITING:
				begin_run()
			RunState.PAUSED:
				_toggle_pause()
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
		hud.show_message("PAUSED\nTAP TO RESUME")
	elif state == RunState.PAUSED:
		hud.show_message("")
		song_clock.resume(0.0)
		state = RunState.RUNNING


func _update_presentation(beat: float, delta: float) -> void:
	player_view.update_pose(beat, simulation, delta)
	camera_director.update_camera(beat, simulation.player_height_at(beat), delta)
	environment_director.update_environment(beat, delta)
	vfx_director.follow_camera(camera_director.camera.global_position)
	hud.set_progress(chart.progress_at(beat))
	var action: ActionDefinition = simulation.active_action()
	if action != null and action.lunge_distance > 0.0 and state == RunState.RUNNING:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = GHOST_INTERVAL_SEC
			vfx_director.on_dash_ghost(player_view.body.global_transform, action.color)


func _fire_vfx_cues(beat: float) -> void:
	while _next_vfx_cue < chart.vfx_cues.size() and chart.vfx_cues[_next_vfx_cue].beat <= beat:
		var cue: ChartItems.VfxCue = chart.vfx_cues[_next_vfx_cue]
		_next_vfx_cue += 1
		if cue.effect == &"flash":
			environment_director.flash(0.8)
		else:
			vfx_director.play_cue(cue.effect, player_view.center_position(), _context.frame_at_beat(beat),
					PlayerView.PLAYER_COLOR)


func _on_action_started(action: ActionDefinition, action_beat: float, _cue_index: int) -> void:
	if action.jump_height > 0.0:
		vfx_director.on_jump_started(_context.frame_at_beat(action_beat), action.color)
	if action.lunge_distance > 0.0:
		camera_director.add_fov_kick(9.0)
		_ghost_timer = 0.0


func _on_action_finished(action: ActionDefinition, end_beat: float) -> void:
	player_view.on_action_finished(action)
	if action.jump_height > 0.0:
		vfx_director.on_landed(_context.frame_at_beat(end_beat), PlayerView.PLAYER_COLOR)
		camera_director.add_shake(0.12)


func _on_cue_judged(cue_index: int, grade: Judgement.Grade, _error_sec: float) -> void:
	hud.show_judgement(grade)
	if grade == Judgement.Grade.MISS:
		return
	obstacle_view.flash_cue(cue_index, 1.0 if grade == Judgement.Grade.PERFECT else 0.6)
	player_view.on_cue_hit(grade)
	if grade == Judgement.Grade.PERFECT:
		vfx_director.on_perfect(player_view.center_position())


func _on_player_died(_hazard_index: int, beat: float) -> void:
	state = RunState.DEAD
	_death_beat = beat
	_restart_timer = RESTART_DELAY_SEC
	song_clock.stop()
	vfx_director.on_died(player_view.center_position(), _context.frame_at_beat(beat))
	player_view.on_died()
	camera_director.add_shake(0.75)
	environment_director.flash(1.2)


func _on_run_completed(_beat: float) -> void:
	state = RunState.COMPLETE
	var counts: PackedInt32Array = simulation.grade_counts
	hud.show_message("LEVEL COMPLETE\nPERFECT %d   GREAT %d   GOOD %d   MISS %d" % [counts[0], counts[1], counts[2], counts[3]])


func _on_song_finished() -> void:
	if state == RunState.COMPLETE:
		hud.show_message("LEVEL COMPLETE\nTAP TO PLAY AGAIN")
