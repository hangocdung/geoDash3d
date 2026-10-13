# Small node pools so effects never instantiate (or compile shaders) mid-run.
# ParticlePool: round-robin one-shot GPUParticles3D. TimedPool: nodes animated by a callback.
# Related: src/presentation/vfx/vfx_director.gd
class_name EffectPools
extends RefCounted


class ParticlePool:
	var _items: Array[GPUParticles3D] = []
	var _next: int = 0

	func _init(parent: Node3D, count: int, factory: Callable) -> void:
		for index: int in count:
			var particles: GPUParticles3D = factory.call() as GPUParticles3D
			parent.add_child(particles)
			_items.append(particles)

	func emit_at(world_position: Vector3, color: Color) -> void:
		var particles: GPUParticles3D = _items[_next]
		_next = (_next + 1) % _items.size()
		var process: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		process.color = color
		particles.global_position = world_position
		particles.restart()
		particles.emitting = true


class TimedPool:
	var _items: Array[GeometryInstance3D] = []
	var _ages: PackedFloat32Array = []
	var _colors: Array[Color] = []
	var _animate: Callable
	var _next: int = 0

	## `animate(node, age, color) -> bool` returns false when the effect is finished.
	func _init(parent: Node3D, count: int, factory: Callable, animate: Callable) -> void:
		_animate = animate
		for index: int in count:
			var node: GeometryInstance3D = factory.call() as GeometryInstance3D
			node.visible = false
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node)
			_items.append(node)
			_ages.append(-1.0)
			_colors.append(Color.WHITE)

	func spawn(world_transform: Transform3D, color: Color) -> void:
		var index: int = _next
		_next = (_next + 1) % _items.size()
		_items[index].global_transform = world_transform
		_items[index].visible = true
		_ages[index] = 0.0
		_colors[index] = color
		_animate.call(_items[index], 0.0, color)

	func update(delta: float) -> void:
		for index: int in _items.size():
			if _ages[index] < 0.0:
				continue
			_ages[index] += delta
			var alive: bool = bool(_animate.call(_items[index], _ages[index], _colors[index]))
			if not alive:
				_ages[index] = -1.0
				_items[index].visible = false

	func clear() -> void:
		for index: int in _items.size():
			_ages[index] = -1.0
			_items[index].visible = false
