// Flight corridor spikes (gameplay v4), drawn as one MultiMesh: neon_wire's dark crystal with glowing edges, plus
// the entrance in the vertex shader. INSTANCE_CUSTOM.x = beat the spike rises; it grows out of its plate over
// `rise_beats` (MEDIUM/HIGH: overshoot and a quarter twist), so the corridor builds up ahead of the player in a wave
// with no per-frame CPU work. Pure function of the global run_beat: exact when seeking and restarting.
// Related: src/presentation/track/corridor_view.gd, src/presentation/shaders/neon_wire.gdshader
shader_type spatial;

global uniform float beat_pulse;
global uniform float soft_glow;
global uniform float run_beat;

uniform vec3 body_color : source_color = vec3(0.05, 0.035, 0.01);
uniform vec3 edge_color : source_color = vec3(1.0, 0.79, 0.24);
uniform float edge_width = 1.2;
uniform float edge_energy = 2.0;
uniform float face_energy = 0.1;
uniform float pulse_gain = 0.5;
uniform float rise_beats = 0.5;
// 0 = plain rise (LOW), 1 = overshoot + twist.
uniform int entrance_style = 1;
// Settings > Reduce flashing lowers the rising flash.
uniform float flash_gain = 1.0;

varying float rise;

void vertex() {
	float t = clamp((run_beat - INSTANCE_CUSTOM.x) / rise_beats, 0.0, 1.0);
	float grow = t;
	if (entrance_style == 1) {
		// Back-out ease: a little over full height, then settle.
		float s = t - 1.0;
		grow = 1.0 + 2.2 * s * s * s + 1.2 * s * s;
		float twist = (1.0 - t) * 1.5708;
		VERTEX.xz = mat2(vec2(cos(twist), -sin(twist)), vec2(sin(twist), cos(twist))) * VERTEX.xz;
	}
	VERTEX.y *= grow;
	VERTEX.xz *= mix(0.3, 1.0, t);
	rise = t;
}

void fragment() {
	vec3 bary = COLOR.rgb;
	vec3 widths = fwidth(bary) * edge_width;
	vec3 edge_mask = 1.0 - smoothstep(widths * 0.5, widths * 1.5, bary);
	float edge = max(edge_mask.x, max(edge_mask.y, edge_mask.z));
	vec3 halo_mask = 1.0 - smoothstep(vec3(0.0), widths * 6.0, bary);
	edge += max(halo_mask.x, max(halo_mask.y, halo_mask.z)) * 0.3 * soft_glow;
	float glow = face_energy * (0.4 + 0.6 * bary.x);
	// A flash while rising draws the eye to the wave front.
	float entering = (1.0 - rise) * step(0.001, rise) * 2.0 * flash_gain;
	ALBEDO = body_color;
	ROUGHNESS = 0.2;
	METALLIC = 0.6;
	EMISSION = edge_color * (edge * edge_energy + glow + entering) * (1.0 + beat_pulse * pulse_gain);
}
