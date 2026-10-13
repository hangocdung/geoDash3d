# Factory for particle systems used by the player and effects: a world-space pixel trail and
# one-shot cube bursts. Materials are unshaded emissive so they bloom on every renderer.
# Related: src/presentation/player/player_view.gd, src/presentation/vfx/vfx_director.gd
class_name TrailParticles
extends RefCounted


static func create(color: Color, amount_scale: float, cube_size: float = 0.14) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Trail"
	particles.amount = maxi(8, int(70.0 * amount_scale))
	particles.lifetime = 0.55
	particles.local_coords = false
	particles.fixed_fps = 0
	particles.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.05, 0.4, 0.4)
	process.direction = Vector3(-1, 0.4, 0)
	process.spread = 30.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 1.6
	process.gravity = Vector3(0, -1.5, 0)
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.scale_curve = _shrink_curve()
	process.color_ramp = _fade_ramp(color)
	particles.process_material = process
	particles.draw_pass_1 = _cube_mesh(cube_size, 2.5)
	return particles


static func create_burst(color: Color, amount: int, speed: float, size: float, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = maxi(4, amount)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0, -9.0, 0)
	process.damping_min = 1.0
	process.damping_max = 3.0
	process.angular_velocity_min = -360.0
	process.angular_velocity_max = 360.0
	process.scale_min = 0.5
	process.scale_max = 1.2
	process.scale_curve = _shrink_curve()
	# White ramp: the tint comes from `process.color`, which pools change per emission.
	process.color_ramp = _fade_ramp(Color.WHITE)
	process.color = color
	particles.process_material = process
	particles.draw_pass_1 = _cube_mesh(size, 1.6)
	return particles


static func _cube_mesh(size: float, brightness: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(brightness, brightness, brightness)
	mesh.material = material
	return mesh


static func _shrink_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _fade_ramp(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 1.0))
	gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
