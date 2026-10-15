# Music-driven decor from Blender models: a portal ring at every section start (the player runs
# through it as the music changes, under the track during underside runs; a bigger one in the new palette's
# colors where a phase starts; gold transform portals at both ends of a flight section, gameplay v4) and
# spiked maces hanging in the background that swing with the bar. Colors follow the phase palette.
# Pose is a pure function of the beat. Related: neon_model.gd, assets/blender/generate_models.py
class_name DecorView
extends Node3D

const PORTAL_SCENE: PackedScene = preload("res://assets/models/portal_ring.glb")
const MACE_SCENE: PackedScene = preload("res://assets/models/spiked_mace.glb")
const PORTAL_HEIGHT: float = 1.2
const MACE_SPACING_BEATS: float = 12.0
const MACE_LATERAL: float = -11.0
const MACE_PIVOT_HEIGHT: float = 10.5
const MACE_SWING_DEG: float = 32.0
## Phase portals: bigger rings (lifted by the same scale so they stay centred on the player).
const PHASE_PORTAL_SCALE: float = 1.7
const PHASE_PORTAL_ENERGY: float = 4.5

var _maces: Array[Node3D] = []
var _mace_rest: Array[Transform3D] = []
var _mace_phase: PackedFloat32Array = []


func setup(context: LevelContext) -> void:
	var phase_beats: Dictionary[float, StringName] = {}
	for phase: ChartItems.Phase in context.chart.phases:
		if phase.beat > 0.0 and phase.beat < context.chart.end_beat:
			phase_beats[phase.beat] = phase.palette
			_add_phase_portal(context, phase.beat, PaletteLibrary.get_palette(phase.palette))
	for section: ChartItems.Section in context.chart.sections:
		if section.beat <= 0.0 or section.beat >= context.chart.end_beat or phase_beats.has(section.beat):
			continue
		var portal: Node3D = NeonModel.instantiate_palette(PORTAL_SCENE, 3.0)
		portal.transform = _ground_frame(context, section.beat) * Transform3D(Basis(), Vector3(0, PORTAL_HEIGHT, 0))
		add_child(portal)
	for section: Vector2 in context.chart.fly_ranges:
		for portal_beat: float in [section.x, section.y]:
			_add_portal(context, portal_beat, GameplayConfig.FLY_COLOR, GameplayConfig.FLY_COLOR.lightened(0.4))
	var beat: float = MACE_SPACING_BEATS * 0.5
	var index: int = 0
	while beat < context.chart.end_beat + 8.0:
		# Maces hang from world up: none over loops, rolls or steep banks.
		if not context.track.is_upright_at(context.chart.distance_at(beat)):
			beat += MACE_SPACING_BEATS
			index += 1
			continue
		var mace: Node3D = NeonModel.instantiate_palette(MACE_SCENE, 3.5)
		var rest: Transform3D = context.frame_at_beat(beat) * Transform3D(Basis(),
				Vector3(0, MACE_PIVOT_HEIGHT - float(index % 3), MACE_LATERAL - float(index % 2) * 4.0))
		add_child(mace)
		_maces.append(mace)
		_mace_rest.append(rest)
		_mace_phase.append(PI * float(index % 2))
		beat += MACE_SPACING_BEATS
		index += 1
	update_view(0.0)


## Bigger ring in the colors of the palette the player is about to enter.
func _add_phase_portal(context: LevelContext, beat: float, palette: ScenePalette) -> void:
	_add_portal(context, beat, palette.track_rail, palette.decor_accent)


func _add_portal(context: LevelContext, beat: float, main_color: Color, accent: Color) -> void:
	var portal: Node3D = NeonModel.instantiate(PORTAL_SCENE, main_color, accent, PHASE_PORTAL_ENERGY)
	portal.transform = _ground_frame(context, beat) * Transform3D(Basis().scaled(Vector3.ONE * PHASE_PORTAL_SCALE),
			Vector3(0, PORTAL_HEIGHT * PHASE_PORTAL_SCALE, 0))
	add_child(portal)


## Where the player runs at `beat`: the road's surface, or its underside during an underside run.
static func _ground_frame(context: LevelContext, beat: float) -> Transform3D:
	if context.chart.is_underside_at(beat):
		return context.underside_frame_at(beat)
	return context.surface_frame_at_beat(beat)


## Maces swing one full cycle every two bars, alternating phase between neighbours.
func update_view(beat: float) -> void:
	for index: int in _maces.size():
		var angle: float = deg_to_rad(MACE_SWING_DEG) * sin(beat * PI / 4.0 + _mace_phase[index])
		_maces[index].transform = _mace_rest[index] * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
