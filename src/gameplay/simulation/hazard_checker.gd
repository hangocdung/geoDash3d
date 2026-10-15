# Path-space collision between the player box and hazard boxes (distance × lateral × height).
# Assumes the player only moves forward, so a cursor skips hazards already behind.
# Related: src/gameplay/simulation/run_simulation.gd, src/gameplay/defs/hazard_definition.gd
class_name HazardChecker
extends RefCounted

const NO_HAZARD: int = -1

var _hazards: Array[ChartItems.HazardPlacement]
var _cursor: int = 0
## Underside hazards hang below the road's underside: their boxes mirror below this depth.
var _track_thickness: float = 0.0


func _init(hazards_sorted_by_distance: Array[ChartItems.HazardPlacement], track_thickness: float = 0.0) -> void:
	_hazards = hazards_sorted_by_distance
	_track_thickness = track_thickness


## Returns the index of the first hazard overlapping the player box, or NO_HAZARD.
## `lateral_range` = (min, max) of the player across the track; `vertical_range` = (bottom, top) above the
## road surface (hazard boxes stand on the ground under them: HazardPlacement.base_height).
## `ignored` lists hazard indices that already hit (invincible practice runs).
func find_collision(player_distance: float, half_length: float, lateral_range: Vector2, vertical_range: Vector2,
		active_action: ActionDefinition, ignored: PackedInt32Array) -> int:
	var player_back: float = player_distance - half_length
	var player_front: float = player_distance + half_length
	while _cursor < _hazards.size():
		var behind: ChartItems.HazardPlacement = _hazards[_cursor]
		if behind.distance + behind.hazard.half_length >= player_back:
			break
		_cursor += 1
	for index: int in range(_cursor, _hazards.size()):
		var placement: ChartItems.HazardPlacement = _hazards[index]
		var hazard: HazardDefinition = placement.hazard
		if placement.distance - hazard.half_length > player_front:
			break
		if placement.distance + hazard.half_length < player_back:
			continue
		var box_bottom: float = placement.base_height + hazard.bottom
		var box_top: float = placement.base_height + hazard.top
		if placement.underside:
			box_bottom = -_track_thickness - hazard.top
			box_top = -_track_thickness - hazard.bottom
		if vertical_range.y < box_bottom or vertical_range.x > box_top:
			continue
		var hazard_left: float = hazard.lateral_center - hazard.lateral_half_width
		var hazard_right: float = hazard.lateral_center + hazard.lateral_half_width
		if lateral_range.y < hazard_left or lateral_range.x > hazard_right:
			continue
		if active_action != null and active_action.is_immune_to(hazard.id):
			continue
		if ignored.has(index):
			continue
		return index
	return NO_HAZARD
