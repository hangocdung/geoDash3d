# Applies the neon look to models exported by assets/blender/generate_models.py, using the material
# naming contract: "Body" → dark metal, "Glow" → primary neon, "GlowAlt" → accent neon.
# Related: src/presentation/shaders/neon_glow.gdshader, src/presentation/track/decor_view.gd
class_name NeonModel
extends RefCounted

const GLOW_SHADER: Shader = preload("res://src/presentation/shaders/neon_glow.gdshader")


## Instantiates `scene` and overrides its surface materials. Returns the instance root.
static func instantiate(scene: PackedScene, glow_color: Color, accent_color: Color, energy: float = 4.0) -> Node3D:
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		push_error("NeonModel: scene root is not a Node3D")
		return Node3D.new()
	var materials: Dictionary[String, Material] = {
		"Body": _body_material(),
		"Glow": _glow_material(glow_color, energy),
		"GlowAlt": _glow_material(accent_color, energy),
	}
	_apply(root, materials)
	return root


static func _apply(node: Node, materials: Dictionary[String, Material]) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.mesh.surface_get_material(surface)
			var material_name: String = source.resource_name if source != null else ""
			if materials.has(material_name):
				mesh_instance.set_surface_override_material(surface, materials[material_name])
			else:
				push_warning("NeonModel: unknown material '%s' on %s" % [material_name, mesh_instance.name])
	for child: Node in node.get_children():
		_apply(child, materials)


static func _body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.03, 0.08)
	material.metallic = 0.7
	material.roughness = 0.28
	return material


static func _glow_material(color: Color, energy: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter("glow_color", color)
	material.set_shader_parameter("energy", energy)
	return material
