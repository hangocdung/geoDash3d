// Track surface: dark tiles with a glowing grid on top and bright neon rails along both edges.
// COLOR.r = 1 on the top face, 0 on side faces; COLOR.g = 1 on end caps (step risers, gap edges).
// UV.x across (top) / down (sides, caps); UV.y = distance (top, sides) / 0..1 across (caps).
shader_type spatial;

global uniform float beat_pulse;
// 1 when the glow post-process is off (low quality): shaders add cheap soft halos instead.
global uniform float soft_glow;

uniform vec3 base_color : source_color = vec3(0.03, 0.025, 0.07);
uniform vec3 grid_color : source_color = vec3(0.25, 0.85, 1.0);
uniform vec3 rail_color : source_color = vec3(0.3, 0.95, 1.0);
uniform float lanes = 3.0;
uniform float tile_length = 3.5;
uniform float grid_energy = 0.55;
uniform float rail_energy = 5.0;
uniform float pulse_gain = 1.4;

float grid_line(float coordinate, float half_width) {
	float distance_to_line = abs(fract(coordinate + 0.5) - 0.5);
	float aa = fwidth(coordinate) * 1.5;
	return 1.0 - smoothstep(half_width, half_width + aa, distance_to_line);
}

void fragment() {
	float pulse = 1.0 + beat_pulse * pulse_gain;
	vec3 emission;
	if (COLOR.r > 0.5) {
		float grid = max(grid_line(UV.x * lanes, 0.012), grid_line(UV.y / tile_length, 0.01));
		float edge_distance = min(UV.x, 1.0 - UV.x);
		float rail = 1.0 - smoothstep(0.0, 0.045, edge_distance);
		rail += exp(-edge_distance * 22.0) * 0.35 * soft_glow;
		grid += max(grid_line(UV.x * lanes, 0.06), grid_line(UV.y / tile_length, 0.05)) * 0.25 * soft_glow;
		ALBEDO = base_color * (1.0 + grid);
		ROUGHNESS = 0.18;
		METALLIC = 0.5;
		emission = grid_color * grid * grid_energy * pulse + rail_color * rail * rail_energy * pulse;
	} else {
		float band = 1.0 - smoothstep(0.0, 0.07, UV.x);
		ALBEDO = base_color * 0.6;
		ROUGHNESS = 0.5;
		if (COLOR.g > 0.5) {
			// End cap: outline the whole face so a wall ahead reads from far away.
			float side_edge = 1.0 - smoothstep(0.0, 0.04, min(UV.y, 1.0 - UV.y));
			emission = rail_color * max(band, side_edge) * rail_energy * 0.45 * pulse;
		} else {
			float panel = grid_line(UV.y / (tile_length * 2.0), 0.006) * 0.35;
			emission = rail_color * band * rail_energy * 0.45 * pulse + grid_color * panel * grid_energy;
		}
	}
	EMISSION = emission;
}
