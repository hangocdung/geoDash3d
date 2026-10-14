# Applies the neon look to models exported by assets/blender/generate_models.py: every surface gets one
# neon_model ShaderMaterial, which reads each face's role (body / glow / accent) from the vertex color, so a
# model is a single draw call. Materials are shared: create one per look and reuse it across instances.
# Related: src/presentation/shaders/neon_model.gdshader, src/presentation/track/decor_view.gd, obstacle_models.gd
class_name NeonModel
extends RefCounted

const MODEL_SHADER: Shader = preload("res://src/presentation/shaders/neon_model.gdshader")

## Palette-driven materials by energy (decor shares them).
static var _palette_materials: Dictionary[float, ShaderMaterial] = {}


static func create_material(glow_color: Color, accent_color: Color, energy: float = 4.0,
		pulse_gain: float = 0.8) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MODEL_SHADER
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("accent_color", accent_color)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("pulse_gain", pulse_gain)
	return material


## Instantiates `scene` with its own material in fixed colors. Returns the instance root.
static func instantiate(scene: PackedScene, glow_color: Color, accent_color: Color, energy: float = 4.0) -> Node3D:
	return instantiate_shared(scene, create_material(glow_color, accent_color, energy))


## Glow / accent follow the phase palette's decor colors (material shared by every such instance).
static func instantiate_palette(scene: PackedScene, energy: float = 4.0) -> Node3D:
	if not _palette_materials.has(energy):
		var material: ShaderMaterial = create_material(Color.WHITE, Color.WHITE, energy)
		material.set_shader_parameter("palette_role", 1)
		_palette_materials[energy] = material
	return instantiate_shared(scene, _palette_materials[energy])


## Instantiates `scene` with a caller-owned material on every surface.
static func instantiate_shared(scene: PackedScene, material: Material) -> Node3D:
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		push_error("NeonModel: scene root is not a Node3D")
		return Node3D.new()
	_apply(root, material)
	return root


static func _apply(node: Node, material: Material) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.material_override = material
	for child: Node in node.get_children():
		_apply(child, material)
