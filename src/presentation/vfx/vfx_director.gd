# Event-driven effects with pooled nodes: takeoff/landing bursts, landing rings, dash afterimages,
# perfect sparkles, death shatter, shield effects and chart VFX cues, plus ambient motes and speed lines
# (MEDIUM/HIGH; denser in high-energy sections). Never touches gameplay state.
# Related: src/presentation/vfx/trail_particles.gd, src/presentation/vfx/effect_pools.gd
class_name VfxDirector
extends Node3D

const GLYPH_SHADER: Shader = preload("res://src/presentation/shaders/glyph.gdshader")
const RING_LIFETIME: float = 0.45
const GHOST_LIFETIME: float = 0.28
const PERFECT_COLOR: Color = Color(1.0, 0.95, 0.55)
const DEATH_COLOR: Color = Color(0.35, 0.95, 1.0)
const SPEED_LINE_COLOR: Color = Color(0.7, 0.85, 1.0)
## Speed-line emitter in the player's track frame: ahead, a little up, on the background side (-Z), so the
## streaks never cross the road between the camera and the player.
const SPEED_LINES_OFFSET: Transform3D = Transform3D(Basis(), Vector3(12.0, 3.0, -8.0))

var _bursts_small: EffectPools.ParticlePool
var _bursts_sparkle: EffectPools.ParticlePool
var _bursts_death: EffectPools.ParticlePool
var _rings: EffectPools.TimedPool
var _ghosts: EffectPools.TimedPool
var _motes: GPUParticles3D
## Null on LOW.
var _speed_lines: GPUParticles3D
var _context: LevelContext
var _quality_scale: float = 1.0


func setup(context: LevelContext) -> void:
	_quality_scale = QualityTier.particle_scale(context.quality)
	_bursts_small = EffectPools.ParticlePool.new(self, 4, func() -> GPUParticles3D:
		return TrailParticles.create_burst(Color(1.0, 0.4, 0.9), int(18 * _quality_scale), 4.0, 0.16, 0.5))
	_bursts_sparkle = EffectPools.ParticlePool.new(self, 3, func() -> GPUParticles3D:
		return TrailParticles.create_burst(PERFECT_COLOR, int(14 * _quality_scale), 5.5, 0.1, 0.4))
	_bursts_death = EffectPools.ParticlePool.new(self, 1, func() -> GPUParticles3D:
		return TrailParticles.create_burst(DEATH_COLOR, int(48 * _quality_scale), 12.0, 0.2, 1.1))
	_rings = EffectPools.TimedPool.new(self, 6, _create_ring, _animate_ring)
	_ghosts = EffectPools.TimedPool.new(self, 6, _create_ghost, _animate_ghost)
	_motes = _create_motes(context.quality)
	add_child(_motes)
	_context = context
	var speed_lines: int = QualityTier.speed_line_count(context.quality)
	if speed_lines > 0:
		_speed_lines = TrailParticles.create_speed_lines(SPEED_LINE_COLOR, speed_lines)
		add_child(_speed_lines)


func _process(delta: float) -> void:
	_rings.update(delta)
	_ghosts.update(delta)


func follow_camera(camera_position: Vector3, beat: float) -> void:
	_motes.global_position = camera_position
	if _speed_lines == null:
		return
	_speed_lines.global_transform = _context.frame_at_beat(beat) * SPEED_LINES_OFFSET
	var section: ChartItems.Section = _context.chart.section_at(beat)
	_speed_lines.amount_ratio = lerpf(0.3, 1.0, section.energy if section != null else 0.3)


## Ambient motes take the phase palette's color (only touched when it changes).
func set_palette(palette: ScenePalette) -> void:
	var process: ParticleProcessMaterial = _motes.process_material as ParticleProcessMaterial
	if process.color != palette.motes:
		process.color = palette.motes


func reset_view() -> void:
	_rings.clear()
	_ghosts.clear()
	if _speed_lines != null:
		_speed_lines.emitting = true


## Fires every pooled effect once far ahead of the camera (inside the fog) so their shader pipelines
## compile during the count-in instead of hitching the first time they are needed (GD3-051).
func prewarm(camera: Camera3D) -> void:
	var far_point: Vector3 = camera.global_position - camera.global_basis.z * 160.0
	_bursts_small.emit_at(far_point, Color.WHITE)
	_bursts_sparkle.emit_at(far_point, Color.WHITE)
	_bursts_death.emit_at(far_point, Color.WHITE)
	_rings.spawn(Transform3D(Basis(), far_point), Color.WHITE)
	_ghosts.spawn(Transform3D(Basis(), far_point), Color.WHITE)


func on_jump_started(feet: Transform3D, color: Color) -> void:
	_bursts_small.emit_at(feet.origin, color)


func on_landed(feet: Transform3D, color: Color) -> void:
	_rings.spawn(feet * Transform3D(Basis().scaled(Vector3.ONE * 3.2), Vector3(0, 0.05, 0)), color)


func on_afterimage(body_transform: Transform3D, color: Color) -> void:
	_ghosts.spawn(body_transform, color)


## Entrance landing of an obstacle: dust ring sized by the entrance style, plus a burst for drops.
func on_hazard_landed(world_position: Vector3, hazard: HazardDefinition) -> void:
	var size: float = 1.8
	match hazard.entrance:
		HazardDefinition.Entrance.DROP:
			size = 4.5
			_bursts_small.emit_at(world_position + Vector3.UP * 0.3, hazard.color)
		HazardDefinition.Entrance.UNFOLD:
			size = 5.5
	_rings.spawn(Transform3D(Basis().scaled(Vector3.ONE * size), world_position + Vector3.UP * 0.06), hazard.color)


func on_shield_broken(center: Vector3, frame: Transform3D, color: Color) -> void:
	_bursts_sparkle.emit_at(center, color)
	var upright := Transform3D(frame.basis * Basis(Vector3.RIGHT, PI * 0.5), center)
	_rings.spawn(upright.scaled_local(Vector3.ONE * 5.0), color)


## A hazard destroyed by a shield breaks into shards in its own color.
func on_hazard_shattered(world_position: Vector3, color: Color) -> void:
	_bursts_death.emit_at(world_position + Vector3.UP * 0.4, color)


func on_perfect(center: Vector3) -> void:
	_bursts_sparkle.emit_at(center, PERFECT_COLOR)


func on_died(center: Vector3, frame: Transform3D) -> void:
	if _speed_lines != null:
		_speed_lines.emitting = false
	_bursts_death.emit_at(center, DEATH_COLOR)
	var upright := Transform3D(frame.basis * Basis(Vector3.RIGHT, PI * 0.5), center)
	_rings.spawn(upright.scaled_local(Vector3.ONE * 7.0), DEATH_COLOR)


## Chart VFX cue (`{"type": "vfx", "name": ...}`) at the player position.
func play_cue(effect: StringName, center: Vector3, frame: Transform3D, color: Color) -> void:
	match effect:
		&"shockwave":
			var upright := Transform3D(frame.basis * Basis(Vector3.RIGHT, PI * 0.5), center)
			_rings.spawn(upright.scaled_local(Vector3.ONE * 16.0), color)
		&"burst":
			_bursts_sparkle.emit_at(center, color)
			_bursts_small.emit_at(center, color)
		_:
			push_warning("VfxDirector: unknown vfx cue '%s'" % effect)


func _create_ring() -> GeometryInstance3D:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	ring.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = GLYPH_SHADER
	material.set_shader_parameter("glyph", 3)
	material.set_shader_parameter("energy", 4.0)
	ring.material_override = material
	return ring


func _animate_ring(node: GeometryInstance3D, age: float, color: Color) -> bool:
	var progress: float = age / RING_LIFETIME
	var material: ShaderMaterial = (node as MeshInstance3D).material_override as ShaderMaterial
	material.set_shader_parameter("glyph_color", color)
	node.set_instance_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	return progress < 1.0


func _create_ghost() -> GeometryInstance3D:
	var ghost := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * PlayerView.CUBE_SIZE
	ghost.mesh = cube
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = material
	return ghost


func _animate_ghost(node: GeometryInstance3D, age: float, color: Color) -> bool:
	var fade: float = 1.0 - age / GHOST_LIFETIME
	var material: StandardMaterial3D = (node as MeshInstance3D).material_override as StandardMaterial3D
	material.albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.35 * fade)
	return fade > 0.0


func _create_motes(quality: QualityTier.Tier) -> GPUParticles3D:
	# White ramp: the tint is `process.color`, set from the phase palette.
	var motes: GPUParticles3D = TrailParticles.create(Color.WHITE, QualityTier.particle_scale(quality), 0.06)
	motes.name = "Motes"
	motes.amount = int(90 * QualityTier.particle_scale(quality))
	motes.lifetime = 4.0
	motes.preprocess = 4.0
	var process: ParticleProcessMaterial = motes.process_material as ParticleProcessMaterial
	process.emission_box_extents = Vector3(30, 12, 30)
	process.direction = Vector3(0, 1, 0)
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.gravity = Vector3.ZERO
	return motes
