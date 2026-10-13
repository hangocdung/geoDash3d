// Track surface: dark tiles with a glowing grid on top and bright neon rails along both edges.
// COLOR.r = 1 on the top face, 0 on side faces. UV.x across (top) / down (sides), UV.y = distance.
shader_type spatial;

global uniform float beat_pulse;

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
		float rail = 1.0 - smoothstep(0.0, 0.045, min(UV.x, 1.0 - UV.x));
		ALBEDO = base_color * (1.0 + grid);
		ROUGHNESS = 0.18;
		METALLIC = 0.5;
		emission = grid_color * grid * grid_energy * pulse + rail_color * rail * rail_energy * pulse;
	} else {
		float band = 1.0 - smoothstep(0.0, 0.07, UV.x);
		float panel = grid_line(UV.y / (tile_length * 2.0), 0.006) * 0.35;
		ALBEDO = base_color * 0.6;
		ROUGHNESS = 0.5;
		emission = rail_color * band * rail_energy * 0.45 * pulse + grid_color * panel * grid_energy;
	}
	EMISSION = emission;
}
