# Owns WorldEnvironment, sky and key light. Each frame it publishes the global `beat_pulse`
# shader parameter and eases glow/fog/background energy toward the current section's energy.
# The sky material is never changed per frame: that would re-render its radiance map every frame.
# Related: src/presentation/shaders/neon_sky.gdshader, tools/setup/configure_project.gd (shader globals)
class_name EnvironmentDirector
extends Node3D

const SKY_SHADER: Shader = preload("res://src/presentation/shaders/neon_sky.gdshader")
const BEAT_PULSE_PARAMETER: StringName = &"beat_pulse"
const PULSE_SHARPNESS: float = 7.0
const ENERGY_EASE_PER_SEC: float = 1.5
const CALM_FOG: Color = Color(0.08, 0.05, 0.2)
const HOT_FOG: Color = Color(0.17, 0.04, 0.2)

var environment: Environment
var _sky_material: ShaderMaterial
var _context: LevelContext
var _energy: float = 0.3
var _flash: float = 0.0


func setup(context: LevelContext) -> void:
	_context = context
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.24, 0.6)
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	_configure_glow(context.quality)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.0
	environment.fog_height = -6.0
	environment.fog_height_density = 0.035
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	light.light_color = Color(0.75, 0.65, 1.0)
	light.light_energy = 0.7
	light.shadow_enabled = false
	add_child(light)


func flash(amount: float) -> void:
	_flash = clampf(_flash + amount, 0.0, 1.5)


func reset_view() -> void:
	_flash = 0.0


func update_environment(beat: float, delta: float) -> void:
	var section: ChartItems.Section = _context.chart.section_at(beat)
	var target_energy: float = section.energy if section != null else 0.3
	_energy = move_toward(_energy, target_energy, delta * ENERGY_EASE_PER_SEC)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	RenderingServer.global_shader_parameter_set(BEAT_PULSE_PARAMETER, _beat_pulse(beat) + _flash)
	environment.background_energy_multiplier = lerpf(0.85, 1.15, _energy) * (1.0 + _flash * 0.6)
	environment.glow_intensity = lerpf(0.75, 1.15, _energy) + _flash * 0.6
	environment.fog_light_color = CALM_FOG.lerp(HOT_FOG, _energy)


func _beat_pulse(beat: float) -> float:
	if beat < 0.0:
		return 0.0
	var phase: float = beat - floorf(beat)
	var accent: float = 1.0 if int(floorf(beat)) % 4 == 0 else 0.55
	return exp(-phase * PULSE_SHARPNESS) * accent * lerpf(0.35, 1.0, _energy)


func _configure_glow(quality: QualityTier.Tier) -> void:
	environment.glow_enabled = true
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	environment.glow_hdr_threshold = 0.9
	environment.glow_bloom = 0.04
	environment.glow_strength = 1.0
	var levels: Array[float] = [0.0, 1.0, 0.8, 0.6, 0.35, 0.0, 0.0]
	if quality == QualityTier.Tier.MEDIUM:
		levels = [0.0, 1.0, 0.8, 0.6, 0.0, 0.0, 0.0]
	elif quality == QualityTier.Tier.LOW:
		levels = [0.0, 0.0, 1.0, 0.6, 0.0, 0.0, 0.0]
	for index: int in levels.size():
		environment.set_glow_level(index, levels[index])
