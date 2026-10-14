# Named phase palettes referenced by charts (`"phases": [{"beat", "palette"}]`). The road, scenery and decor
# stay in cool hues so the reserved gameplay colors (pink jump, orange dodge, lime flip) always stand out;
# only the sky may turn warm (sunset, ember). `indigo` is the original look, used by charts without phases.
# Related: scene_palette.gd, phase_palettes.gd, docs/chart_format.md
class_name PaletteLibrary
extends RefCounted

const DEFAULT: StringName = &"indigo"

# Per palette: sky zenith, mid, horizon, accent (planet / sun), sky style (planet, sun, stars, horizon glow),
# fog calm, fog hot, ambient, light, road base, grid, rail, streak, block base, block rail,
# scenery a, scenery b, pillar, decor glow, decor accent, motes.
const _DATA: Dictionary[StringName, Array] = {
	&"indigo": [Color(0.02, 0.01, 0.07), Color(0.12, 0.04, 0.28), Color(0.55, 0.16, 0.6), Color(0.35, 0.45, 1.0),
		Vector4(1.0, 0.0, 1.0, 1.0), Color(0.08, 0.05, 0.2), Color(0.17, 0.04, 0.2), Color(0.32, 0.24, 0.6),
		Color(0.75, 0.65, 1.0), Color(0.03, 0.025, 0.07), Color(0.25, 0.85, 1.0), Color(0.3, 0.95, 1.0),
		Color(0.75, 0.97, 1.0), Color(0.05, 0.045, 0.12), Color(0.45, 0.75, 1.0), Color(0.25, 0.75, 1.0),
		Color(0.55, 0.4, 0.98), Color(0.55, 0.35, 1.0), Color(0.45, 0.4, 1.0), Color(0.3, 0.9, 1.0),
		Color(0.5, 0.45, 0.9)],
	&"ocean": [Color(0.0, 0.015, 0.05), Color(0.0, 0.07, 0.18), Color(0.05, 0.42, 0.62), Color(0.45, 0.9, 1.0),
		Vector4(1.0, 0.0, 0.6, 1.2), Color(0.02, 0.07, 0.15), Color(0.03, 0.11, 0.2), Color(0.18, 0.32, 0.55),
		Color(0.6, 0.8, 1.0), Color(0.01, 0.025, 0.05), Color(0.1, 0.55, 1.0), Color(0.2, 0.75, 1.0),
		Color(0.65, 0.9, 1.0), Color(0.02, 0.05, 0.1), Color(0.3, 0.9, 0.95), Color(0.1, 0.5, 1.0),
		Color(0.2, 0.9, 0.95), Color(0.2, 0.5, 1.0), Color(0.2, 0.55, 1.0), Color(0.35, 1.0, 0.95),
		Color(0.3, 0.65, 0.9)],
	&"sunset": [Color(0.04, 0.01, 0.1), Color(0.22, 0.03, 0.24), Color(0.72, 0.26, 0.24), Color(1.0, 0.72, 0.32),
		Vector4(0.0, 1.0, 0.35, 1.0), Color(0.18, 0.05, 0.16), Color(0.26, 0.06, 0.15), Color(0.45, 0.25, 0.5),
		Color(1.0, 0.75, 0.8), Color(0.04, 0.015, 0.07), Color(0.55, 0.4, 1.0), Color(0.45, 0.7, 1.0),
		Color(0.85, 0.85, 1.0), Color(0.07, 0.03, 0.12), Color(0.65, 0.55, 1.0), Color(0.45, 0.3, 1.0),
		Color(0.25, 0.55, 1.0), Color(0.5, 0.3, 0.95), Color(0.6, 0.35, 1.0), Color(0.4, 0.75, 1.0),
		Color(0.8, 0.55, 0.8)],
	&"aurora": [Color(0.0, 0.025, 0.045), Color(0.01, 0.1, 0.13), Color(0.08, 0.62, 0.55), Color(0.62, 0.42, 1.0),
		Vector4(0.8, 0.0, 1.2, 1.1), Color(0.02, 0.08, 0.1), Color(0.04, 0.12, 0.14), Color(0.15, 0.38, 0.42),
		Color(0.6, 1.0, 0.95), Color(0.01, 0.03, 0.04), Color(0.1, 0.9, 0.8), Color(0.3, 1.0, 0.92),
		Color(0.7, 1.0, 0.97), Color(0.02, 0.06, 0.07), Color(0.45, 0.6, 1.0), Color(0.1, 0.8, 0.75),
		Color(0.45, 0.4, 1.0), Color(0.15, 0.75, 0.75), Color(0.2, 0.9, 0.8), Color(0.6, 0.45, 1.0),
		Color(0.35, 0.85, 0.8)],
	&"ultraviolet": [Color(0.03, 0.0, 0.08), Color(0.16, 0.02, 0.38), Color(0.48, 0.2, 1.0), Color(0.85, 0.55, 1.0),
		Vector4(1.0, 0.0, 1.0, 1.3), Color(0.09, 0.03, 0.22), Color(0.13, 0.04, 0.3), Color(0.35, 0.2, 0.65),
		Color(0.8, 0.6, 1.0), Color(0.035, 0.01, 0.08), Color(0.6, 0.35, 1.0), Color(0.72, 0.5, 1.0),
		Color(0.9, 0.82, 1.0), Color(0.07, 0.03, 0.14), Color(0.4, 0.6, 1.0), Color(0.5, 0.25, 1.0),
		Color(0.3, 0.5, 1.0), Color(0.6, 0.3, 1.0), Color(0.65, 0.35, 1.0), Color(0.35, 0.6, 1.0),
		Color(0.6, 0.4, 0.95)],
	&"ember": [Color(0.03, 0.0, 0.03), Color(0.13, 0.01, 0.06), Color(0.56, 0.11, 0.09), Color(1.0, 0.42, 0.16),
		Vector4(0.0, 1.0, 0.5, 1.0), Color(0.12, 0.02, 0.06), Color(0.18, 0.03, 0.07), Color(0.45, 0.2, 0.3),
		Color(1.0, 0.6, 0.55), Color(0.03, 0.01, 0.03), Color(0.4, 0.6, 1.0), Color(0.55, 0.8, 1.0),
		Color(0.9, 0.95, 1.0), Color(0.05, 0.02, 0.05), Color(0.7, 0.75, 1.0), Color(0.35, 0.4, 1.0),
		Color(0.6, 0.35, 0.9), Color(0.45, 0.35, 0.9), Color(0.5, 0.5, 1.0), Color(0.85, 0.85, 1.0),
		Color(0.9, 0.45, 0.4)],
	&"glacier": [Color(0.03, 0.07, 0.15), Color(0.1, 0.24, 0.42), Color(0.55, 0.8, 0.95), Color(0.95, 0.98, 1.0),
		Vector4(1.0, 0.0, 0.2, 0.9), Color(0.12, 0.2, 0.3), Color(0.16, 0.25, 0.36), Color(0.4, 0.5, 0.65),
		Color(0.85, 0.95, 1.0), Color(0.03, 0.05, 0.08), Color(0.6, 0.85, 1.0), Color(0.8, 0.95, 1.0),
		Color(0.95, 1.0, 1.0), Color(0.06, 0.09, 0.13), Color(0.45, 0.8, 1.0), Color(0.55, 0.8, 1.0),
		Color(0.3, 0.55, 0.95), Color(0.5, 0.75, 1.0), Color(0.6, 0.85, 1.0), Color(0.95, 0.98, 1.0),
		Color(0.8, 0.9, 1.0)],
	&"void": [Color(0.0, 0.0, 0.0), Color(0.005, 0.005, 0.012), Color(0.2, 0.21, 0.26), Color(0.95, 0.95, 1.0),
		Vector4(1.0, 0.0, 1.3, 0.6), Color(0.02, 0.02, 0.03), Color(0.04, 0.04, 0.05), Color(0.25, 0.25, 0.3),
		Color(0.9, 0.9, 1.0), Color(0.0, 0.0, 0.005), Color(0.75, 0.8, 0.95), Color(1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0), Color(0.02, 0.02, 0.03), Color(0.75, 0.85, 1.0), Color(0.7, 0.75, 0.9),
		Color(0.35, 0.4, 0.55), Color(0.6, 0.6, 0.7), Color(0.85, 0.85, 1.0), Color(1.0, 1.0, 1.0),
		Color(0.8, 0.8, 0.9)],
}
const _FIELDS: Array[StringName] = [&"sky_zenith", &"sky_mid", &"sky_horizon", &"sky_accent", &"sky_style",
	&"fog_calm", &"fog_hot", &"ambient", &"light", &"track_base", &"track_grid", &"track_rail", &"track_streak",
	&"block_base", &"block_rail", &"scenery_a", &"scenery_b", &"pillar", &"decor_glow", &"decor_accent", &"motes"]


static func has_palette(palette_name: StringName) -> bool:
	return _DATA.has(palette_name)


static func names() -> Array[StringName]:
	return _DATA.keys()


## Fresh palette by name; unknown names report an error and fall back to the default look.
static func get_palette(palette_name: StringName) -> ScenePalette:
	if not _DATA.has(palette_name):
		push_error("PaletteLibrary: unknown palette '%s', using '%s'" % [palette_name, DEFAULT])
		palette_name = DEFAULT
	var values: Array = _DATA[palette_name]
	var palette := ScenePalette.new()
	for index: int in _FIELDS.size():
		palette.set(_FIELDS[index], values[index])
	return palette
