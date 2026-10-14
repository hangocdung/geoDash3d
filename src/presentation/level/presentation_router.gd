# Routes RunSimulation signals and chart VFX cues to presentation nodes (player, camera, vfx,
# obstacles, environment, HUD) and sound effects. Owns no gameplay state; rebinds to each simulation.
# Related: src/presentation/level/level_runner.gd, src/gameplay/simulation/run_simulation.gd
class_name PresentationRouter
extends RefCounted

const GHOST_INTERVAL_SEC: float = 0.045

var _runner: LevelRunner
var _context: LevelContext
var _simulation: RunSimulation
var _next_vfx_cue: int = 0
var _ghost_timer: float = 0.0
## Off for the menu attract mode, so the backdrop stays quiet.
var sfx_enabled: bool = true


func _init(runner: LevelRunner, context: LevelContext) -> void:
	_runner = runner
	_context = context


func bind(simulation: RunSimulation, start_beat: float) -> void:
	_simulation = simulation
	simulation.action_started.connect(_on_action_started)
	simulation.action_finished.connect(_on_action_finished)
	simulation.player_landed.connect(_on_player_landed)
	simulation.cue_judged.connect(_on_cue_judged)
	_next_vfx_cue = 0
	var cues: Array[ChartItems.VfxCue] = _context.chart.vfx_cues
	while _next_vfx_cue < cues.size() and cues[_next_vfx_cue].beat < start_beat:
		_next_vfx_cue += 1


func fire_vfx_cues(beat: float) -> void:
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
	_play(&"player.land")
	_runner.vfx_director.on_landed(_feet_at(beat), PlayerView.PLAYER_COLOR)
	_runner.camera_director.add_shake(0.12)


## Track frame at the player's feet (terrain and jump height included).
func _feet_at(beat: float) -> Transform3D:
	return _context.frame_at_height(beat, _simulation.player_height_at(beat))


func _on_cue_judged(cue_index: int, grade: Judgement.Grade, _error_sec: float) -> void:
	_runner.hud.show_judgement(grade)
	if grade == Judgement.Grade.MISS:
		return
	_runner.obstacle_view.flash_cue(cue_index, 1.0 if grade == Judgement.Grade.PERFECT else 0.6)
	_runner.player_view.on_cue_hit(grade)
	if grade == Judgement.Grade.PERFECT:
		_play(&"judge.perfect")
		_runner.vfx_director.on_perfect(_runner.player_view.center_position())
	elif grade == Judgement.Grade.GREAT:
		_play(&"judge.great")


func on_hazard_landed(world_position: Vector3, hazard: HazardDefinition) -> void:
	_play(hazard.landing_sound, -5.0)
	_runner.vfx_director.on_hazard_landed(world_position, hazard)
	if hazard.entrance == HazardDefinition.Entrance.DROP:
		_runner.camera_director.add_shake(0.06)


func _play(sound_id: StringName, volume_offset_db: float = 0.0) -> void:
	if sfx_enabled and not sound_id.is_empty():
		Sfx.play(sound_id, volume_offset_db)
