// Translucent energy wall (dash hazard): scrolling scanlines, bright frame, additive.
// UV.x across the wall; QuadMesh UV.y runs top (0) to bottom (1), so height = 1 - UV.y.
// `circular`: a round field (ring gate) with a bright rim instead of the rectangular frame.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

global uniform float beat_pulse;

uniform vec3 wall_color : source_color = vec3(1.0, 0.75, 0.2);
uniform float energy = 2.2;
uniform float line_density = 18.0;
uniform float scroll_speed = 1.5;
uniform bool circular = false;
instance uniform float flash = 0.0;

void fragment() {
	float height = 1.0 - UV.y;
	float scan = 0.5 + 0.5 * sin((height * line_density - TIME * scroll_speed) * 6.2831);
	scan = pow(scan, 6.0);
	float frame = 1.0 - smoothstep(0.0, 0.06, min(min(UV.x, 1.0 - UV.x), 1.0 - height));
	float base = 0.12 + 0.25 * (1.0 - height);
	float inside = 1.0;
	if (circular) {
		float radius = length(UV - vec2(0.5)) * 2.0;
		inside = 1.0 - smoothstep(0.96, 1.0, radius);
		frame = (1.0 - smoothstep(0.0, 0.08, abs(radius - 0.93))) * inside;
	}
	float intensity = (base + scan * 0.55 + frame * 1.6) * inside * (1.0 + beat_pulse * 0.8 + flash * 3.0);
	ALBEDO = wall_color * intensity * energy;
}
