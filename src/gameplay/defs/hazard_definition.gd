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
	## Low laser fence between two emitter posts (jumped like a spike).
	LASER,
	## Axe swinging under a gantry: it sweeps the road exactly when the player gets there (jump it).
	PENDULUM,
	## Spiked mine floating just above the road, bobbing with the beat (jump it).
	MINE,
	## Hydraulic press over the road, pumping on the beat but never below its hitbox (stay on the ground).
	CRUSHER,
	## Two-lane laser grid instead of a solid wall (dodge into the free lane).
	LASER_WALL,
	## Ring standing across the road with an energy field (flip under the track).
	RING_GATE,
	## Spiked mace swinging along the track from a tall gantry (roll under the track).
	MACE_SWEEP,
	## Gameplay v4: spike row pumping up and down on every beat, fully up when the player arrives (jump it).
	PISTON,
	## Gameplay v4: spiked ball rolling down the road at the player, meeting it at the hazard beat (jump it).
	ROLLING_BALL,
}
enum Entrance {
	## Grows out of the track surface.
	RISE,
	## Falls from the sky and slams onto the track.
	DROP,
	## Unfolds sideways across the track.
	UNFOLD,
	## Gameplay v4: pops out of nothing with an elastic overshoot.
	BEAT_POP,
	## Gameplay v4: spins down from above.
	SPIRAL,
	## Gameplay v4: slides in from beside the road (walls close their lane).
	SWEEP,
}
enum Face { FOLLOW_RUN, TOP, UNDERSIDE }

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
## Flight hazard (gameplay v4): floats in a fly section at `bottom`..`top` above the road, not on the ground.
@export var airborne: bool = false
@export var color: Color = Color(1.0, 0.25, 0.85)
## Which face of the road the hazard stands on (GD3-112). FOLLOW_RUN: under the track inside an underside run
## (LevelChart.underside_ranges), on top elsewhere. Gates are pinned: the flip_down's gate stays on top even
## though it lands after the player went under, the flip_up's gate (gate_under) always hangs underneath.
@export var face: Face = Face.FOLLOW_RUN
## Sound played when the entrance lands (see tools/audio/sfx_spec.py).
@export var landing_sound: StringName = &""


## Beat on which the entrance animation lands (snapped down to a whole beat so it hits the music).
func appear_beat(hazard_beat: float) -> float:
	return floorf(hazard_beat - lead_beats)
