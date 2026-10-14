# Owns WorldEnvironment, sky and key light. Each frame it publishes the global shader parameters
# (`beat_pulse`, `run_beat`, `player_distance`, `player_position`: all functions of the beat) and eases
# glow/fog/background energy toward the current section's energy. The sky's beat pulse is off on LOW and
# with "reduce flashing", which also scales the neon beat pulses and flashes down.
# Phase palettes (PhasePalettes, a function of the beat) go out as `pal_*` globals only when they change;
# the sky material itself changes once per settled phase: changing it per frame would re-render its
# radiance map every frame. On LOW the phase change is instant (one sky change instead of a blend).
# Related: src/presentation/shaders/neon_sky.gdshader, tools/setup/configure_project.gd (shader globals),
# phase_palettes.gd
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
## Beats a phase change blends over (MEDIUM/HIGH).
const PHASE_TRANSITION_BEATS: float = 1.0
const PALETTE_GLOBALS: Dictionary[StringName, StringName] = {
	&"pal_sky_zenith": &"sky_zenith", &"pal_sky_mid": &"sky_mid", &"pal_sky_horizon": &"sky_horizon",
	&"pal_sky_accent": &"sky_accent", &"pal_sky_style": &"sky_style", &"pal_track_base": &"track_base",
	&"pal_track_grid": &"track_grid", &"pal_track_rail": &"track_rail", &"pal_track_streak": &"track_streak",
	&"pal_block_base": &"block_base", &"pal_block_rail": &"block_rail", &"pal_scenery_a": &"scenery_a",
	&"pal_scenery_b": &"scenery_b", &"pal_pillar": &"pillar", &"pal_decor_glow": &"decor_glow",
	&"pal_decor_accent": &"decor_accent",
}

var environment: Environment
## Palette in effect this frame (blended during a phase change).
var palette: ScenePalette
var _phases: PhasePalettes
var _palette_index: int = -1
var _palette_weight: float = -1.0
## Phase whose palette the sky material (radiance) currently shows.
var _sky_phase: int = -1
var _light: DirectionalLight3D
var _sky_material: ShaderMaterial
## Last value given to the sky's `beat_brightness` (-1 = not set yet).
var _sky_beat_brightness: float = -1.0
var _context: LevelContext
var _quality: QualityTier.Tier = QualityTier.Tier.HIGH
var _energy: float = 0.3
var _flash: float = 0.0


func setup(context: LevelContext) -> void:
	_context = context
	_phases = PhasePalettes.from_chart(context.chart, PHASE_TRANSITION_BEATS)
	palette = _phases.settled_palette(0)
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	# apply_quality() below sets the sky pulse for the tier; later setting changes re-apply it.
	UserSettings.changed.connect(_apply_flash_setting)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
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
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	_light.light_energy = 0.7
	_light.shadow_enabled = false
	add_child(_light)
	_update_palette(0.0)


func flash(amount: float) -> void:
	_flash = clampf(_flash + amount, 0.0, 1.5)


func reset_view() -> void:
	_flash = 0.0
	_palette_index = -1


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
	_update_palette(beat)
	environment.fog_light_color = palette.fog_calm.lerp(palette.fog_hot, _energy)


## Publishes the phase palette when it changes; the sky material follows once the phase has settled.
func _update_palette(beat: float) -> void:
	var index: int = _phases.index_at(beat)
	var weight: float = _phases.blend_at(beat)
	if index == _palette_index and weight == _palette_weight:
		return
	_palette_index = index
	_palette_weight = weight
	palette = _phases.palette_at(beat)
	for parameter: StringName in PALETTE_GLOBALS:
		var value: Variant = palette.get(PALETTE_GLOBALS[parameter])
		if value is Color:
			# vec4 globals hold linear colors, like `source_color` uniforms.
			var linear: Color = (value as Color).srgb_to_linear()
			value = Vector4(linear.r, linear.g, linear.b, linear.a)
		RenderingServer.global_shader_parameter_set(parameter, value)
	environment.ambient_light_color = palette.ambient
	_light.light_color = palette.light
	if weight >= 1.0 and _sky_phase != index:
		_sky_phase = index
		var settled: ScenePalette = _phases.settled_palette(index)
		_sky_material.set_shader_parameter("zenith_color", settled.sky_zenith)
		_sky_material.set_shader_parameter("mid_color", settled.sky_mid)
		_sky_material.set_shader_parameter("horizon_color", settled.sky_horizon)
		_sky_material.set_shader_parameter("planet_color", settled.sky_accent)
		_sky_material.set_shader_parameter("style", settled.sky_style)


## Changes the sky material only when the setting changes (each change re-renders the radiance map once).
func _apply_flash_setting() -> void:
	var calm: bool = UserSettings.reduce_flashing or not QualityTier.uses_sky_pulse(_quality)
	var brightness: float = 0.0 if calm else SKY_BEAT_BRIGHTNESS
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
	_quality = quality
	if _phases != null:
		_phases.transition_beats = PHASE_TRANSITION_BEATS if QualityTier.blends_phase_changes(quality) else 0.0
	_apply_flash_setting()
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
