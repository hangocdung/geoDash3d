# A hazard's collision box in path space (along × lateral × vertical) plus how it looks and how it
# enters on the beat. Hitboxes are slightly smaller than visuals (forgiving collisions).
# Related: src/gameplay/simulation/hazard_checker.gd, src/presentation/obstacles/obstacle_factory.gd
class_name HazardDefinition
extends Resource

enum Visual {
	SPIKE,
	WALL,
	GATE,
	## Spinning saw blade, half sunk into the ground (turns with the beat).
	SAW,
	## Slab hanging over the road with spikes pointing down: pass under it on the ground.
	CEILING,
}
enum Entrance {
	## Grows out of the track surface.
	RISE,
	## Falls from the sky and slams onto the track.
	DROP,
	## Unfolds sideways across the track.
	UNFOLD,
}

@export var id: StringName = &""
@export var visual: Visual = Visual.SPIKE
@export var entrance: Entrance = Entrance.RISE
## The entrance lands on the whole beat at least this many beats before the player reaches it.
@export var lead_beats: float = 2.0
@export var half_length: float = 0.3
@export var lateral_center: float = 0.0
@export var lateral_half_width: float = 0.4
@export var bottom: float = 0.0
@export var top: float = 0.85
@export var visual_length: float = 1.0
@export var visual_width: float = 1.0
@export var visual_height: float = 1.1
## SPIKE: number of spikes in a row along the track (each `visual_length` / `repeat` long).
@export var repeat: int = 1
@export var color: Color = Color(1.0, 0.25, 0.85)
## Sound played when the entrance lands (see tools/audio/sfx_spec.py).
@export var landing_sound: StringName = &""


## Beat on which the entrance animation lands (snapped down to a whole beat so it hits the music).
func appear_beat(hazard_beat: float) -> float:
	return floorf(hazard_beat - lead_beats)
