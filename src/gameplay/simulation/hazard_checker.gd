# Path-space collision between the player box and hazard boxes (distance × height).
# Assumes the player only moves forward, so a cursor skips hazards already behind.
# Related: src/gameplay/simulation/run_simulation.gd, src/gameplay/defs/hazard_definition.gd
class_name HazardChecker
extends RefCounted

const NO_HAZARD: int = -1

var _hazards: Array[ChartItems.HazardPlacement]
var _cursor: int = 0


func _init(hazards_sorted_by_distance: Array[ChartItems.HazardPlacement]) -> void:
	_hazards = hazards_sorted_by_distance


## Returns the index of the first hazard overlapping the player box, or NO_HAZARD.
## `ignored` lists hazard indices that already hit (invincible practice runs).
func find_collision(player_distance: float, half_length: float, bottom: float, top: float,
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
		if top < hazard.bottom or bottom > hazard.top:
			continue
		if active_action != null and active_action.is_immune_to(hazard.id):
			continue
		if ignored.has(index):
			continue
		return index
	return NO_HAZARD
