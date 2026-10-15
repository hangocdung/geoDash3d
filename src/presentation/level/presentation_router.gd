# Routes RunSimulation signals and chart VFX cues to presentation nodes (player, camera, vfx,
# obstacles, environment, HUD) and sound effects. Owns no gameplay state; rebinds to each simulation.
# The landing drum is played ahead by the audio delay so it is heard on the landing beat (GD3-258).
# Related: src/presentation/level/level_runner.gd, src/gameplay/simulation/run_simulation.gd
class_name PresentationRouter
extends RefCounted

const GHOST_INTERVAL_SEC: float = 0.045
## Phase change: flash, shockwave in the new palette, FOV punch and a toast with the new speed.
const PHASE_FLASH: float = 1.0
const PHASE_FOV_KICK_DEG: float = 9.0
const PHASE_SHAKE: float = 0.25
## A landing this close to the one whose drum was played ahead is that landing (no second drum).
const LANDING_MATCH_BEATS: float = 0.03

var _runner: LevelRunner
var _context: LevelContext
var _simulation: RunSimulation
var _next_vfx_cue: int = 0
var _next_phase: int = 0
var _shields_shown: int = 0
var _ghost_timer: float = 0.0
## Off for the menu attract mode, so the backdrop stays quiet (sounds and vibrations).
var sfx_enabled: bool = true
var _hints: TutorialHints
## Audio output delay + calibration, in song seconds: sounds started now are heard this much later.
var _audio_delay_sec: float = 0.0
## Landing whose drum was already played ahead (NAN: none pending).
var _landing_sound_beat: float = NAN


func _init(runner: LevelRunner, context: LevelContext) -> void:
	_runner = runner
	_context = context
	var options: LaunchOptions = runner.options
	# Captures with autoplay are covered by `autoplay`; --capture-manual keeps hints to show them in screenshots.
	_hints = TutorialHints.new(runner.hud, context.chart, not (options.autoplay or options.attract_mode or options.video))


func bind(simulation: RunSimulation, start_beat: float) -> void:
	_simulation = simulation
	simulation.action_started.connect(_on_action_started)
	simulation.action_finished.connect(_on_action_finished)
	simulation.player_landed.connect(_on_player_landed)
	simulation.cue_judged.connect(_on_cue_judged)
	simulation.combo_changed.connect(_on_combo_changed)
	simulation.score_changed.connect(_runner.hud.set_score)
	simulation.shield_changed.connect(_on_shield_changed)
	simulation.shield_used.connect(_on_shield_used)
	simulation.flight_changed.connect(_on_flight_changed)
	_hints.bind(simulation, start_beat)
	_shields_shown = 0
	_landing_sound_beat = NAN
	_audio_delay_sec = maxf((AudioServer.get_output_latency() + _runner.song_clock.calibration_offset_sec)
			* _runner.song_clock.playback_rate, 0.0)
	_runner.hud.set_combo(0)
	_runner.hud.set_score(0)
	_runner.hud.set_shield(false, 0.0)
	_runner.player_view.set_shield(false)
	_next_vfx_cue = 0
	var cues: Array[ChartItems.VfxCue] = _context.chart.vfx_cues
	while _next_vfx_cue < cues.size() and cues[_next_vfx_cue].beat < start_beat:
		_next_vfx_cue += 1
	var phases: Array[ChartItems.Phase] = _context.chart.phases
	_next_phase = 1
	while _next_phase < phases.size() and phases[_next_phase].beat <= start_beat:
		_next_phase += 1


## Every running frame: phase changes, chart VFX cues and the landing drum played ahead.
func fire_vfx_cues(beat: float) -> void:
	_play_landing_ahead()
	var phases: Array[ChartItems.Phase] = _context.chart.phases
	while _next_phase < phases.size() and phases[_next_phase].beat <= beat:
		_on_phase_started(_next_phase, phases[_next_phase])
		_next_phase += 1
	var cues: Array[ChartItems.VfxCue] = _context.chart.vfx_cues
	while _next_vfx_cue < cues.size() and cues[_next_vfx_cue].beat <= beat:
		var cue: ChartItems.VfxCue = cues[_next_vfx_cue]
		_next_vfx_cue += 1
		_play(StringName("fx.%s" % cue.effect) if cue.effect != &"burst" else &"judge.perfect")
		if cue.effect == &"flash":
			_runner.environment_director.flash(0.8)
		else:
			_runner.vfx_director.play_cue(cue.effect, _runner.player_view.center_position(),
					_context.frame_at_beat(beat), PlayerView.PLAYER_COLOR)


func _on_phase_started(index: int, phase: ChartItems.Phase) -> void:
	var palette: ScenePalette = PaletteLibrary.get_palette(phase.palette)
	_play(&"fx.shockwave")
	_runner.environment_director.flash(PHASE_FLASH)
	_runner.camera_director.add_fov_kick(PHASE_FOV_KICK_DEG)
	_runner.camera_director.add_shake(PHASE_SHAKE)
	_runner.vfx_director.play_cue(&"shockwave", _runner.player_view.center_position(),
			_context.frame_at_beat(phase.beat), palette.track_rail)
	var first_speed: float = _context.chart.speed_at(_context.chart.phases[0].beat)
	var speed_ratio: float = _context.chart.speed_at(phase.beat) / maxf(first_speed, 0.001)
	var speed_note: String = Locale.t("  ·  SPEED ×%.2f") % speed_ratio if speed_ratio > 1.001 else ""
	_runner.hud.show_toast(Locale.t("PHASE %d") % (index + 1) + speed_note)


## Through a gold transform portal (gameplay v4): a shockwave ring, a FOV kick and a light shake.
func _on_flight_changed(_flying: bool, beat: float) -> void:
	_play(&"fx.shockwave", -6.0)
	_runner.camera_director.add_fov_kick(PHASE_FOV_KICK_DEG * 0.6)
	_runner.camera_director.add_shake(PHASE_SHAKE * 0.5)
	_runner.vfx_director.play_cue(&"shockwave", _runner.player_view.center_position(), _context.frame_at_beat(beat),
			GameplayConfig.FLY_COLOR)


## Afterimages while a dodge or flip is active.
func update_trails(action: ActionDefinition, delta: float) -> void:
	if action == null or action.kind == ActionDefinition.Kind.JUMP:
		return
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = GHOST_INTERVAL_SEC
		_runner.vfx_director.on_afterimage(_runner.player_view.body.global_transform, action.color)


func on_player_died(beat: float) -> void:
	_play(&"player.death")
	_vibrate(Haptics.Kind.DEATH)
	_runner.vfx_director.on_died(_runner.player_view.center_position(), _context.frame_at_beat(beat))
	_runner.player_view.on_died()
	_runner.camera_director.add_shake(0.75)
	_runner.environment_director.flash(1.2)


func _on_action_started(action: ActionDefinition, action_beat: float, _cue_index: int) -> void:
	_play(action.start_sound)
	match action.kind:
		ActionDefinition.Kind.JUMP:
			_runner.vfx_director.on_jump_started(_feet_at(action_beat), action.color)
		ActionDefinition.Kind.FLIP:
			_runner.camera_director.add_fov_kick(6.0)
			_ghost_timer = 0.0
		_:
			_ghost_timer = 0.0


func _on_action_finished(action: ActionDefinition, _end_beat: float) -> void:
	_runner.player_view.on_action_finished(action)


func _on_player_landed(beat: float, airtime_beats: float) -> void:
	_runner.player_view.on_landed(airtime_beats)
	if is_nan(_landing_sound_beat) or absf(beat - _landing_sound_beat) > LANDING_MATCH_BEATS:
		_play(&"player.land")
	_landing_sound_beat = NAN
	_runner.vfx_director.on_landed(_feet_at(beat), PlayerView.PLAYER_COLOR)
	_runner.camera_director.add_shake(0.12)


## Starts the landing drum once the predicted landing is within the audio delay, so it is heard on that beat;
## the landing itself then stays silent (a tap that changes the arc lands elsewhere and gets its own drum).
func _play_landing_ahead() -> void:
	var now: float = _simulation.current_beat
	if not sfx_enabled or _audio_delay_sec <= 0.0 or (not is_nan(_landing_sound_beat) and _landing_sound_beat >= now):
		return
	var chart: LevelChart = _context.chart
	var reach: float = chart.beat_at_time(chart.time_at(now) + _audio_delay_sec) - now
	var landing: float = LandingPredictor.landing_beat(_simulation, reach)
	if not is_nan(landing):
		_landing_sound_beat = landing
		_play(&"player.land")


## Track frame at the player's feet (terrain and jump height included; upside down under the track).
func _feet_at(beat: float) -> Transform3D:
	if _simulation.is_underside():
		return _context.underside_frame_at(beat, -_simulation.player_height_at(beat) - _context.config.underside_depth())
	return _context.frame_at_height(beat, _simulation.player_height_at(beat))


func _on_cue_judged(cue_index: int, grade: Judgement.Grade, _error_sec: float) -> void:
	_runner.hud.show_judgement(grade)
	if grade == Judgement.Grade.MISS:
		return
	_runner.obstacle_view.flash_cue(cue_index, 1.0 if grade == Judgement.Grade.PERFECT else 0.6)
	_runner.player_view.on_cue_hit(grade)
	if grade == Judgement.Grade.PERFECT:
		_play(&"judge.perfect")
		_vibrate(Haptics.Kind.PERFECT)
		_runner.vfx_director.on_perfect(_runner.player_view.center_position())
	elif grade == Judgement.Grade.GREAT:
		_play(&"judge.great")


func _on_combo_changed(combo: int) -> void:
	_runner.hud.set_combo(combo)
	_runner.hud.set_shield(_simulation.streak.shields > 0, _simulation.streak.charge())


func _on_shield_changed(shields: int) -> void:
	_runner.player_view.set_shield(shields > 0)
	_runner.hud.set_shield(shields > 0, _simulation.streak.charge())
	if shields > _shields_shown:
		_play(&"player.shield")
		_runner.vfx_director.on_perfect(_runner.player_view.center_position())
	_shields_shown = shields


func _on_shield_used(hazard_index: int, beat: float) -> void:
	_play(&"player.shield_break")
	_vibrate(Haptics.Kind.SHIELD_BREAK)
	_runner.vfx_director.on_shield_broken(_runner.player_view.center_position(), _context.frame_at_beat(beat),
			PlayerView.SHIELD_COLOR)
	if hazard_index >= 0:
		var hazard: HazardDefinition = _context.chart.hazards[hazard_index].hazard
		_runner.vfx_director.on_hazard_shattered(_runner.obstacle_view.shatter(hazard_index), hazard.color)
	_runner.camera_director.add_shake(0.45)
	_runner.environment_director.flash(0.5)


func on_hazard_landed(world_position: Vector3, hazard: HazardDefinition) -> void:
	_play(hazard.landing_sound, -5.0)
	_runner.vfx_director.on_hazard_landed(world_position, hazard)
	if hazard.entrance == HazardDefinition.Entrance.DROP:
		_runner.camera_director.add_shake(0.06)


func _play(sound_id: StringName, volume_offset_db: float = 0.0) -> void:
	if sfx_enabled and not sound_id.is_empty():
		Sfx.play(sound_id, volume_offset_db)


func _vibrate(kind: Haptics.Kind) -> void:
	if sfx_enabled:
		Haptics.pulse(kind)
