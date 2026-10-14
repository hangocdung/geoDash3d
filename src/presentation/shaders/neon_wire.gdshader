// Dark solid with glowing triangle edges. Procedural meshes put barycentric coordinates in
// COLOR.rgb (one vertex per corner = 1) so edges are where any coordinate approaches 0.
shader_type spatial;

global uniform float beat_pulse;
global uniform float soft_glow;
// Road-level position of the player: hazards brighten as it approaches (`proximity_gain` > 0).
global uniform vec3 player_position;

uniform vec3 body_color : source_color = vec3(0.04, 0.015, 0.06);
uniform vec3 edge_color : source_color = vec3(1.0, 0.25, 0.85);
uniform float edge_width = 1.2;
uniform float edge_energy = 5.0;
uniform float face_energy = 0.25;
uniform float pulse_gain = 0.8;
uniform float proximity_gain = 0.0;
uniform float proximity_near = 5.0;
uniform float proximity_far = 24.0;
instance uniform float flash = 0.0;

void fragment() {
	vec3 bary = COLOR.rgb;
	vec3 widths = fwidth(bary) * edge_width;
	vec3 edge_mask = 1.0 - smoothstep(widths * 0.5, widths * 1.5, bary);
	float edge = max(edge_mask.x, max(edge_mask.y, edge_mask.z));
	vec3 halo_mask = 1.0 - smoothstep(vec3(0.0), widths * 6.0, bary);
	edge += max(halo_mask.x, max(halo_mask.y, halo_mask.z)) * 0.3 * soft_glow;
	// Faces brighten toward the tip (top of the barycentric "a" corner) for a crystal look.
	float glow = face_energy * (0.4 + 0.6 * bary.x);
	float near = 1.0 - smoothstep(proximity_near, proximity_far, distance(NODE_POSITION_WORLD, player_position));
	float pulse = (1.0 + beat_pulse * pulse_gain + flash * 4.0) * (1.0 + proximity_gain * near);
	ALBEDO = body_color;
	ROUGHNESS = 0.15;
	METALLIC = 0.7;
	EMISSION = edge_color * (edge * edge_energy + glow) * pulse;
}
