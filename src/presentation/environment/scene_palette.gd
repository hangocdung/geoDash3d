# One phase's look: sky, fog, light and the colors of every palette-driven material (road, raised blocks,
# pillars, scenery, decor, motes). Hazards and the player keep their reserved gameplay colors.
# Related: palette_library.gd, phase_palettes.gd, environment_director.gd
class_name ScenePalette
extends RefCounted

var sky_zenith: Color
var sky_mid: Color
var sky_horizon: Color
## Planet / sun color.
var sky_accent: Color
## x = planet, y = striped sun on the horizon, z = stars, w = horizon glow (all 0..~1.5).
var sky_style: Vector4 = Vector4(1.0, 0.0, 1.0, 1.0)
var fog_calm: Color
var fog_hot: Color
var ambient: Color
var light: Color
var track_base: Color
var track_grid: Color
var track_rail: Color
var track_streak: Color
var block_base: Color
var block_rail: Color
var scenery_a: Color
var scenery_b: Color
var pillar: Color
var decor_glow: Color
var decor_accent: Color
var motes: Color


## Copy blended toward `other` by `weight` (0 = self, 1 = other).
func blended(other: ScenePalette, weight: float) -> ScenePalette:
	var result := ScenePalette.new()
	for property: StringName in color_properties():
		result.set(property, (get(property) as Color).lerp(other.get(property) as Color, weight))
	result.sky_style = sky_style.lerp(other.sky_style, weight)
	return result


static func color_properties() -> Array[StringName]:
	return [&"sky_zenith", &"sky_mid", &"sky_horizon", &"sky_accent", &"fog_calm", &"fog_hot", &"ambient", &"light",
			&"track_base", &"track_grid", &"track_rail", &"track_streak", &"block_base", &"block_rail", &"scenery_a",
			&"scenery_b", &"pillar", &"decor_glow", &"decor_accent", &"motes"]
