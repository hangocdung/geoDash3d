# Music-driven decor from Blender models: a portal ring at every section start (the player runs
# through it as the music changes) and spiked maces hanging in the background that swing with the bar.
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
const PORTAL_COLOR: Color = Color(0.45, 0.4, 1.0)
const PORTAL_ACCENT: Color = Color(0.3, 0.9, 1.0)
const MACE_GLOW: Color = Color(0.4, 0.5, 1.0)
const MACE_EYE: Color = Color(0.3, 0.65, 1.0)

var _maces: Array[Node3D] = []
var _mace_rest: Array[Transform3D] = []
var _mace_phase: PackedFloat32Array = []


func setup(context: LevelContext) -> void:
	for section: ChartItems.Section in context.chart.sections:
		if section.beat <= 0.0 or section.beat >= context.chart.end_beat:
			continue
		var portal: Node3D = NeonModel.instantiate(PORTAL_SCENE, PORTAL_COLOR, PORTAL_ACCENT, 3.0)
		portal.transform = context.surface_frame_at_beat(section.beat) * Transform3D(Basis(), Vector3(0, PORTAL_HEIGHT, 0))
		add_child(portal)
	var beat: float = MACE_SPACING_BEATS * 0.5
	var index: int = 0
	while beat < context.chart.end_beat + 8.0:
		var mace: Node3D = NeonModel.instantiate(MACE_SCENE, MACE_GLOW, MACE_EYE, 3.5)
		var rest: Transform3D = context.frame_at_beat(beat) * Transform3D(Basis(),
				Vector3(0, MACE_PIVOT_HEIGHT - float(index % 3), MACE_LATERAL - float(index % 2) * 4.0))
		add_child(mace)
		_maces.append(mace)
		_mace_rest.append(rest)
		_mace_phase.append(PI * float(index % 2))
		beat += MACE_SPACING_BEATS
		index += 1
	update_view(0.0)


## Maces swing one full cycle every two bars, alternating phase between neighbours.
func update_view(beat: float) -> void:
	for index: int in _maces.size():
		var angle: float = deg_to_rad(MACE_SWING_DEG) * sin(beat * PI / 4.0 + _mace_phase[index])
		_maces[index].transform = _mace_rest[index] * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
