# Plain data records produced by ChartLoader. All positions are in beats; distances along the
# track are derived later through LevelChart.distance_at().
# Related: src/gameplay/chart/level_chart.gd, src/gameplay/chart/chart_loader.gd
class_name ChartItems
extends RefCounted


## A moment where a tap performs `action`.
class ActionCue:
	var beat: float
	var action: ActionDefinition
	## False when the chart said "hazard": "none" (terrain jumps: the ground itself is the obstacle).
	var has_hazard: bool = false

	func _init(cue_beat: float, cue_action: ActionDefinition) -> void:
		beat = cue_beat
		action = cue_action


class HazardPlacement:
	var beat: float
	var hazard: HazardDefinition
	## Distance along the track of the hazard center (filled by LevelChart).
	var distance: float = 0.0
	## Ground height under the hazard (filled by LevelChart); its hitbox sits on top of it.
	var base_height: float = 0.0
	## Hangs under the track (filled by LevelChart): its hitbox mirrors below the road's underside.
	var underside: bool = false

	func _init(hazard_beat: float, hazard_definition: HazardDefinition) -> void:
		beat = hazard_beat
		hazard = hazard_definition


## Ground height from `beat` until the next segment (Terrain.GAP = no ground).
class TerrainSegment:
	var beat: float
	var height: float

	func _init(segment_beat: float, segment_height: float) -> void:
		beat = segment_beat
		height = segment_height


## Jump pad on the ground: launches the player (no tap) when it runs over it.
class PadPlacement:
	var beat: float
	## Filled by LevelChart: distance along the track and ground height under the pad.
	var distance: float = 0.0
	var base_height: float = 0.0

	func _init(pad_beat: float) -> void:
		beat = pad_beat


class CameraCue:
	var beat: float
	var shot: StringName
	var blend_beats: float

	func _init(cue_beat: float, shot_name: StringName, blend: float) -> void:
		beat = cue_beat
		shot = shot_name
		blend_beats = blend


class VfxCue:
	var beat: float
	var effect: StringName

	func _init(cue_beat: float, effect_name: StringName) -> void:
		beat = cue_beat
		effect = effect_name


class Section:
	var beat: float
	var name: StringName
	## 0..1 intensity used by presentation (glow strength, particle density, palette energy).
	var energy: float

	func _init(section_beat: float, section_name: StringName, section_energy: float) -> void:
		beat = section_beat
		name = section_name
		energy = section_energy


## Gameplay phase: from `beat` on the level wears `palette` (presentation look; the speed ladder lives in
## the chart's `speed` keys). Phases start on bar lines so the change lands on the music.
class Phase:
	var beat: float
	var palette: StringName

	func _init(phase_beat: float, palette_name: StringName) -> void:
		beat = phase_beat
		palette = palette_name


## Track shape from `beat` until the next segment (see docs/chart_format.md and TrackPath).
class TrackSegment:
	enum Shape { STRAIGHT, TURN, SLOPE, HELIX, LOOP, ROLL, WAVE }

	var beat: float
	var shape: Shape
	## TURN / HELIX: total yaw change in degrees (positive = left).
	var angle_deg: float = 0.0
	## SLOPE / HELIX: total height change in units.
	var rise: float = 0.0
	## TURN: lean into the turn by up to this many degrees (0 = flat).
	var bank_deg: float = 0.0
	## ROLL: total roll around the direction of travel in degrees (positive = clockwise seen from behind).
	var roll_deg: float = 0.0
	## LOOP: sideways shift over the loop in units (positive = right), so it never runs into itself.
	var lateral: float = 0.0
	## WAVE: height of each hill and number of hills.
	var amplitude: float = 0.0
	var count: int = 1

	func _init(segment_beat: float, segment_shape: Shape) -> void:
		beat = segment_beat
		shape = segment_shape
