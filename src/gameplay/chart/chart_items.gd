# Plain data records produced by ChartLoader. All positions are in beats; distances along the
# track are derived later through LevelChart.distance_at().
# Related: src/gameplay/chart/level_chart.gd, src/gameplay/chart/chart_loader.gd
class_name ChartItems
extends RefCounted


## A moment where a tap performs `action`.
class ActionCue:
	var beat: float
	var action: ActionDefinition

	func _init(cue_beat: float, cue_action: ActionDefinition) -> void:
		beat = cue_beat
		action = cue_action


class HazardPlacement:
	var beat: float
	var hazard: HazardDefinition
	## Distance along the track of the hazard center (filled by LevelChart).
	var distance: float = 0.0

	func _init(hazard_beat: float, hazard_definition: HazardDefinition) -> void:
		beat = hazard_beat
		hazard = hazard_definition


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


class TrackSegment:
	enum Shape { STRAIGHT, TURN, SLOPE }

	var beat: float
	var shape: Shape
	## TURN: total yaw change in degrees (positive = left).
	var angle_deg: float = 0.0
	## SLOPE: total height change in units.
	var rise: float = 0.0

	func _init(segment_beat: float, segment_shape: Shape) -> void:
		beat = segment_beat
		shape = segment_shape
