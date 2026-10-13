// Additive hologram glyph on a quad: 0 = ring, 1 = up chevrons (jump), 2 = forward arrows (dash),
// 3 = shock ring driven by `progress`. Optional camera-facing billboard.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

global uniform float beat_pulse;

uniform int glyph = 0;
uniform bool billboard = false;
uniform vec3 glyph_color : source_color = vec3(1.0, 0.3, 0.9);
uniform float energy = 3.0;
instance uniform float flash = 0.0;
instance uniform float fade = 1.0;
instance uniform float progress = 0.0;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
				INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
				INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

float chevron(vec2 p, float y) {
	// "^" shape centered at height y, thickness 0.07.
	float d = abs(p.y - y - (0.22 - abs(p.x) * 0.9));
	return (1.0 - smoothstep(0.05, 0.08, d)) * step(abs(p.x), 0.3);
}

float arrow(vec2 p, float x) {
	float d = abs(p.x - x - (0.18 - abs(p.y) * 0.9));
	return (1.0 - smoothstep(0.05, 0.08, d)) * step(abs(p.y), 0.24);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.y = -p.y;
	float radius = length(p);
	float shape = 0.0;
	if (glyph == 0) {
		shape = 1.0 - smoothstep(0.02, 0.05, abs(radius - 0.4));
	} else if (glyph == 1) {
		shape = chevron(p, -0.18) + chevron(p, 0.02) * 0.8;
		shape += (1.0 - smoothstep(0.02, 0.04, abs(radius - 0.46))) * 0.6;
	} else if (glyph == 2) {
		shape = arrow(p, -0.2) + arrow(p, 0.02) * 0.8;
		shape += (1.0 - smoothstep(0.02, 0.04, abs(radius - 0.46))) * 0.6;
	} else {
		float ring_radius = mix(0.05, 0.48, progress);
		float width = mix(0.06, 0.01, progress);
		shape = (1.0 - smoothstep(width * 0.5, width, abs(radius - ring_radius))) * (1.0 - progress);
	}
	float halo = exp(-radius * 6.0) * 0.25 * (glyph == 3 ? 0.0 : 1.0);
	float pulse = 1.0 + beat_pulse * 0.6 + flash * 3.0;
	ALBEDO = glyph_color * (shape + halo) * energy * pulse * fade;
}
