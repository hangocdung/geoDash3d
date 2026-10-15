# Read-only bundle handed to every presentation node at setup time.
# Related: src/presentation/level/level_runner.gd
class_name LevelContext
extends RefCounted

var chart: LevelChart
var config: GameplayConfig
var track: TrackPath
var quality: QualityTier.Tier = QualityTier.Tier.HIGH


func _init(level_chart: LevelChart, gameplay_config: GameplayConfig, track_path: TrackPath,
		quality_tier: QualityTier.Tier) -> void:
	chart = level_chart
	config = gameplay_config
	track = track_path
	quality = quality_tier


## World transform of the track frame at `beat`.
func frame_at_beat(beat: float) -> Transform3D:
	return track.transform_at(chart.distance_at(beat))


## Track frame at `beat` raised by `height` (along the frame's up axis).
func frame_at_height(beat: float, height: float) -> Transform3D:
	return frame_at_beat(beat) * Transform3D(Basis(), Vector3(0.0, height, 0.0))


## Track frame on the road's underside at `beat`, upside down (its up axis points away from the road) and
## `depth` below it: what frame_at_height is on top of the road, for underside runs (GD3-112).
func underside_frame_at(beat: float, depth: float = 0.0) -> Transform3D:
	return frame_at_beat(beat) * underside_flip() * Transform3D(Basis(), Vector3(0.0, depth, 0.0))


## Turns something placed on the road upside down under it (half a turn around the track's length axis).
func underside_flip() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, -config.track_thickness, 0.0))


## Track frame at `beat` raised onto the ground (terrain) at that point.
func surface_frame_at_beat(beat: float) -> Transform3D:
	return frame_at_height(beat, chart.surface_height_at(beat))
