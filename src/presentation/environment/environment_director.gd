# Owns WorldEnvironment, sky and key light. Each frame it publishes the global shader parameters
# (`beat_pulse`, `run_beat`, `player_distance`, `player_position`: all functions of the beat) and eases
# glow/fog/background energy toward the current section's energy. "Reduce flashing" turns off the sky's
# beat pulse and scales the neon beat pulses and flashes down.
# The sky material is never changed per frame: that would re-render its radiance map every frame.
# Related: src/presentation/shaders/neon_sky.gdshader, tools/setup/configure_project.gd (shader globals)
class_name EnvironmentDirector
extends Node3D

const SKY_SHADER: Shader = preload("res://src/presentation/shaders/neon_sky.gdshader")
const BEAT_PULSE_PARAMETER: StringName = &"beat_pulse"
const SOFT_GLOW_PARAMETER: StringName = &"soft_glow"
const RUN_BEAT_PARAMETER: StringName = &"run_beat"
const PLAYER_DISTANCE_PARAMETER: StringName = &"player_distance"
const PLAYER_POSITION_PARAMETER: StringName = &"player_position"
const PULSE_SHARPNESS: float = 7.0
const ENERGY_EASE_PER_SEC: float = 1.5
## Sky horizon brightening per unit of beat pulse, and the pulse/flash scale under "reduce flashing".
const SKY_BEAT_BRIGHTNESS: float = 0.2
const REDUCED_FLASH_SCALE: float = 0.35
const CALM_FOG: Color = Color(0.08, 0.05, 0.2)
const HOT_FOG: Color = Color(0.17, 0.04, 0.2)

var environment: Environment
var _sky_material: ShaderMaterial
## Last value given to the sky's `beat_brightness` (-1 = not set yet).
var _sky_beat_brightness: float = -1.0
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
	_apply_flash_setting()
	UserSettings.changed.connect(_apply_flash_setting)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.24, 0.6)
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	apply_quality(context.quality)
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
	var flash_scale: float = REDUCED_FLASH_SCALE if UserSettings.reduce_flashing else 1.0
	RenderingServer.global_shader_parameter_set(BEAT_PULSE_PARAMETER, (_beat_pulse(beat) + _flash) * flash_scale)
	# Track position of the player (road level): rail streaks and the hazards' approach glow use it.
	RenderingServer.global_shader_parameter_set(RUN_BEAT_PARAMETER, beat)
	RenderingServer.global_shader_parameter_set(PLAYER_DISTANCE_PARAMETER, _context.chart.distance_at(beat))
	RenderingServer.global_shader_parameter_set(PLAYER_POSITION_PARAMETER, _context.frame_at_beat(beat).origin)
	environment.background_energy_multiplier = lerpf(0.85, 1.15, _energy) * (1.0 + _flash * 0.6 * flash_scale)
	environment.glow_intensity = lerpf(0.75, 1.15, _energy) + _flash * 0.6 * flash_scale
	environment.fog_light_color = CALM_FOG.lerp(HOT_FOG, _energy)


## Changes the sky material only when the setting changes (each change re-renders the radiance map once).
func _apply_flash_setting() -> void:
	var brightness: float = 0.0 if UserSettings.reduce_flashing else SKY_BEAT_BRIGHTNESS
	if brightness != _sky_beat_brightness:
		_sky_beat_brightness = brightness
		_sky_material.set_shader_parameter("beat_brightness", brightness)


func _beat_pulse(beat: float) -> float:
	if beat < 0.0:
		return 0.0
	var phase: float = beat - floorf(beat)
	var accent: float = 1.0 if int(floorf(beat)) % 4 == 0 else 0.55
	return exp(-phase * PULSE_SHARPNESS) * accent * lerpf(0.35, 1.0, _energy)


## Glow post-process on/off per tier; without it shaders draw soft halos (`soft_glow` global).
func apply_quality(quality: QualityTier.Tier) -> void:
	var glow: bool = QualityTier.uses_glow(quality)
	environment.glow_enabled = glow
	RenderingServer.global_shader_parameter_set(SOFT_GLOW_PARAMETER, 0.0 if glow else 1.0)
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
