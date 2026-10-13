# Shares ShaderMaterials between obstacle instances (one material per look, not per node).
# Related: src/presentation/obstacles/obstacle_factory.gd
class_name MaterialCache
extends RefCounted

var _materials: Dictionary[StringName, ShaderMaterial] = {}


func get_material(key: StringName, shader: Shader, parameters: Dictionary) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = shader
	for parameter_name: String in parameters:
		material.set_shader_parameter(parameter_name, parameters[parameter_name])
	_materials[key] = material
	return material
