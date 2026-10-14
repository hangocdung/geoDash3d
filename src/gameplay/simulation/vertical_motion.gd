# The player's vertical state against the terrain: standing on the ground at some height, or flying a
# ballistic arc (a jump, orb or pad launch, or a fall after running off a ledge). Analytic in beats;
# contact is evaluated by RunSimulation on its fixed grid. Related: run_simulation.gd, track/terrain.gd
class_name VerticalMotion
extends RefCounted

## Every take-off, landing and restore (ReferenceRun records the perfect run's states from it).
signal changed(beat: float)

enum Contact {
	NONE,
	## Came down onto the ground (or onto a ledge within the snap distance).
	LANDED,
	## The ground under the player dropped away (ledge or gap): the caller starts a fall.
	LEFT_GROUND,
	## Ran into the side of higher ground.
	HIT_SIDE,
	## Fell below the death height.
	FELL,
}

## A height within this of the ground counts as touching it (float noise on exact landings).
const CONTACT_EPSILON: float = 0.000001

var airborne: bool = false
var ground_height: float = 0.0
## Beat the player left the ground (kept when an orb relaunches it in mid-air).
var take_off_beat: float = 0.0
## Current arc while airborne: height(t) = launch_height + launch_velocity·t − ½·gravity·t².
var launch_beat: float = 0.0
var launch_height: float = 0.0
var launch_velocity: float = 0.0
var gravity: float = 0.0
## Action that started the current arc, or null for a fall.
var launch_action: ActionDefinition = null
## Beat of the last landing (or of the run start).
var grounded_since: float = 0.0
## Beats from take-off to landing of the last completed flight.
var last_airtime: float = 0.0

var _last_height: float = 0.0
var _last_beat: float = 0.0


func reset(beat: float, height: float) -> void:
	airborne = false
	ground_height = height
	launch_action = null
	grounded_since = beat
	last_airtime = 0.0
	_last_height = height
	_last_beat = beat


func height_at(beat: float) -> float:
	if not airborne:
		return ground_height
	var t: float = beat - launch_beat
	return launch_height + launch_velocity * t - 0.5 * gravity * t * t


## Beats since leaving the ground, or -1 while grounded.
func air_beats_at(beat: float) -> float:
	return beat - take_off_beat if airborne else -1.0


## Starts an arc from the current height at `beat` (from the ground, or in mid-air for orbs).
func launch(action: ActionDefinition, beat: float, velocity: float, gravity_value: float) -> void:
	var height: float = height_at(beat)
	if not airborne:
		take_off_beat = beat
	airborne = true
	launch_action = action
	launch_beat = beat
	launch_height = height
	launch_velocity = velocity
	gravity = gravity_value
	_last_height = height
	_last_beat = beat
	changed.emit(beat)


## Evaluates ground contact at grid `beat`; `support` = highest ground under the player (Terrain.GAP if none).
func step(beat: float, support: float, snap: float, death_height: float) -> Contact:
	if not airborne:
		if support > ground_height + snap:
			return Contact.HIT_SIDE
		if support >= ground_height:
			ground_height = support
			return Contact.NONE
		return Contact.LEFT_GROUND
	var height: float = height_at(beat)
	# A launch on this very grid beat (a buffered tap performed as a dodge/flip ends) has not left yet.
	if height > support + CONTACT_EPSILON or beat <= launch_beat + CONTACT_EPSILON:
		_last_height = height
		_last_beat = beat
		return Contact.FELL if height < death_height else Contact.NONE
	# Coming down through the top (or reaching a ledge just above the feet) lands; anything else is a wall.
	if _last_height < support - snap:
		return Contact.HIT_SIDE
	land(_landing_beat(support, beat), support)
	return Contact.LANDED


func land(beat: float, height: float) -> void:
	last_airtime = beat - take_off_beat if airborne else 0.0
	airborne = false
	ground_height = height
	launch_action = null
	grounded_since = beat
	_last_height = height
	_last_beat = beat
	changed.emit(beat)


func snapshot() -> VerticalMotion:
	var copy := VerticalMotion.new()
	copy._copy_state(self)
	return copy


## Takes over `other`'s ground / arc as of `beat` (a shield puts the player back on the perfect run).
func restore(other: VerticalMotion, beat: float) -> void:
	_copy_state(other)
	_last_height = height_at(beat)
	_last_beat = beat
	changed.emit(beat)


func _copy_state(other: VerticalMotion) -> void:
	airborne = other.airborne
	ground_height = other.ground_height
	take_off_beat = other.take_off_beat
	launch_beat = other.launch_beat
	launch_height = other.launch_height
	launch_velocity = other.launch_velocity
	gravity = other.gravity
	launch_action = other.launch_action
	grounded_since = other.grounded_since
	last_airtime = other.last_airtime


## Exact beat where the descending arc meets `height`, kept within the grid step that detected it.
func _landing_beat(height: float, detected_beat: float) -> float:
	var discriminant: float = launch_velocity * launch_velocity + 2.0 * gravity * (launch_height - height)
	if gravity <= 0.0 or discriminant < 0.0:
		return detected_beat
	var t: float = (launch_velocity + sqrt(discriminant)) / gravity
	return clampf(launch_beat + t, _last_beat, detected_beat)
