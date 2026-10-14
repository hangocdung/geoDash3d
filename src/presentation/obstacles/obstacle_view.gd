# Owns obstacle, jump pad and cue-marker nodes. Obstacles stay hidden until their entrance, which lands on
# a whole beat (HazardDefinition.appear_beat) and emits `hazard_landed` for VFX/SFX. Pose = f(beat), so
# seeking and restarts are exact. Related: obstacle_factory.gd, obstacle_entrance.gd, level_runner.gd
class_name ObstacleView
extends Node3D

signal hazard_landed(world_position: Vector3, hazard: HazardDefinition)

const VISIBILITY_RANGE: float = 240.0
const FLASH_DECAY_PER_SEC: float = 4.0
## Saw blades turn this many times per beat (rolling toward the player).
const SPIN_TURNS_PER_BEAT: float = 0.5


class Obstacle:
	var root: Node3D
	var rest: Transform3D
	var hazard: HazardDefinition
	var appear_beat: float
	var landed: bool = false
	var settled: bool = false
	## Saw blade turned with the beat (null for other hazards).
	var spinner: Node3D = null
	## Shattered by a shield: stays hidden until the next run.
	var broken: bool = false


var _obstacles: Array[Obstacle] = []
## Per cue (same index as chart.cues): its marker nodes.
var _cue_markers: Array[Array] = []
var _cue_flash: PackedFloat32Array = []


func setup(context: LevelContext) -> void:
	var factory := ObstacleFactory.new()
	for placement: ChartItems.HazardPlacement in context.chart.hazards:
		var obstacle := Obstacle.new()
		obstacle.hazard = placement.hazard
		obstacle.rest = context.track.transform_at(placement.distance) * Transform3D(Basis(),
				Vector3(0, placement.base_height, 0))
		obstacle.appear_beat = placement.hazard.appear_beat(placement.beat)
		obstacle.root = factory.build_hazard(placement.hazard)
		obstacle.root.visible = false
		obstacle.spinner = obstacle.root.find_child(ObstacleFactory.SPINNER_NAME, true, false) as Node3D
		_set_visibility_range(obstacle.root)
		add_child(obstacle.root)
		_obstacles.append(obstacle)
	for pad: ChartItems.PadPlacement in context.chart.pads:
		var pad_node: Node3D = factory.build_pad(context.config.pad_launch.color, context.config.pad_half_length)
		pad_node.transform = context.track.transform_at(pad.distance) * Transform3D(Basis(), Vector3(0, pad.base_height, 0))
		_set_visibility_range(pad_node)
		add_child(pad_node)
	for index: int in context.chart.cues.size():
		var markers: Array[GeometryInstance3D] = factory.build_cue_markers(context.chart.cues[index],
				context.chart.cue_heights[index], context)
		for marker: GeometryInstance3D in markers:
			marker.visibility_range_end = VISIBILITY_RANGE
			add_child(marker)
		_cue_markers.append(markers)
	_cue_flash.resize(_cue_markers.size())
	_cue_flash.fill(0.0)


## Call when a run (re)starts: entrances before `beat` count as already landed (no VFX/SFX burst).
func rewind_to(beat: float) -> void:
	for obstacle: Obstacle in _obstacles:
		obstacle.landed = beat >= obstacle.appear_beat
		obstacle.settled = false
		obstacle.broken = false
	update_view(beat)


func update_view(beat: float) -> void:
	for obstacle: Obstacle in _obstacles:
		if obstacle.broken:
			obstacle.root.visible = false
			continue
		var since_landing: float = beat - obstacle.appear_beat
		if since_landing < -ObstacleEntrance.lead_in(obstacle.hazard.entrance):
			obstacle.root.visible = false
			obstacle.settled = false
			continue
		obstacle.root.visible = true
		if obstacle.spinner != null:
			obstacle.spinner.rotation.z = beat * SPIN_TURNS_PER_BEAT * TAU
		if not obstacle.landed and since_landing >= 0.0:
			obstacle.landed = true
			hazard_landed.emit(obstacle.rest.origin, obstacle.hazard)
		if since_landing > ObstacleEntrance.SETTLE_BEATS:
			if not obstacle.settled:
				obstacle.root.transform = obstacle.rest
				obstacle.settled = true
			continue
		obstacle.settled = false
		obstacle.root.transform = obstacle.rest * ObstacleEntrance.pose(obstacle.hazard.entrance, since_landing,
				obstacle.hazard.visual_height)


## Hides a hazard a shield destroyed (same index as chart.hazards); returns where it stood.
func shatter(hazard_index: int) -> Vector3:
	var obstacle: Obstacle = _obstacles[hazard_index]
	obstacle.broken = true
	obstacle.root.visible = false
	return obstacle.rest.origin


func flash_cue(cue_index: int, strength: float) -> void:
	if cue_index >= 0 and cue_index < _cue_flash.size():
		_cue_flash[cue_index] = maxf(_cue_flash[cue_index], strength)


func reset_view() -> void:
	_cue_flash.fill(0.0)
	for index: int in _cue_markers.size():
		_set_flash(index, 0.0)


func _process(delta: float) -> void:
	for index: int in _cue_flash.size():
		if _cue_flash[index] <= 0.0:
			continue
		_cue_flash[index] = maxf(_cue_flash[index] - delta * FLASH_DECAY_PER_SEC, 0.0)
		_set_flash(index, _cue_flash[index])


func _set_flash(cue_index: int, value: float) -> void:
	for marker: GeometryInstance3D in _cue_markers[cue_index]:
		marker.set_instance_shader_parameter("flash", value)


static func _set_visibility_range(node: Node) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.visibility_range_end = VISIBILITY_RANGE
	for child: Node in node.get_children():
		_set_visibility_range(child)
