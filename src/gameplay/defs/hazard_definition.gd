# Collision volume of a hazard in path space: along-track half length and vertical extent.
# Hitboxes are intentionally a bit smaller than the visuals (forgiving collisions).
# Related: src/gameplay/simulation/hazard_checker.gd, src/presentation/obstacles/obstacle_view.gd
class_name HazardDefinition
extends Resource

@export var id: StringName = &""
@export var half_length: float = 0.3
@export var bottom: float = 0.0
@export var top: float = 0.85
## Visual footprint along the track (used by presentation, not by collision).
@export var visual_length: float = 1.0
@export var visual_height: float = 1.1
@export var color: Color = Color(1.0, 0.25, 0.85)
