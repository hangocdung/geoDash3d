// Additive hologram glyph on a quad: 0 = ring, 1 = up chevrons (jump), 2 = forward arrows,
// 3 = shock ring driven by `progress`, 4 = sideways arrows (dodge), 5 = circular arrow (flip),
// 6 = jump orb (bright core inside two rings), 7 = dive orb (down chevrons inside a ring),
// 8 = big orb (up chevrons inside a double ring), 10 = beat ring under the player (a steady ring plus a wave
// that leaves it on every beat).
// Optional camera-facing billboard.
// Cue markers set `approach_scale` > 1: the quad is that much bigger than the glyph and an approach ring
// shrinks onto the glyph, touching it exactly on `cue_beat` (pure function of the song beat). They also pulse
// harder with the beat (`beat_gain`) and flash on the tap moment.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

global uniform float beat_pulse;
global uniform float run_beat;

uniform int glyph = 0;
uniform bool billboard = false;
uniform vec3 glyph_color : source_color = vec3(1.0, 0.3, 0.9);
uniform float energy = 3.0;
uniform float beat_gain = 0.6;
uniform float approach_scale = 1.0;
uniform float approach_beats = 2.0;
// Glyph-space radius the approach ring lands on (0.4 = ring glyph, 0.46 = orbs' outer ring).
uniform float approach_target = 0.42;
instance uniform float cue_beat = -1000.0;
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

float circle_arrow(vec2 p) {
	// Ring with a gap on the lower right; an arrow head at the gap's lower end points clockwise.
	const float RADIUS = 0.24;
	const float HEAD_ANGLE = -1.1;
	float angle = atan(p.y, p.x);
	float on_ring = 1.0 - smoothstep(0.035, 0.06, abs(length(p) - RADIUS));
	float in_gap = step(HEAD_ANGLE, angle) * step(angle, -0.2);
	vec2 tangent = vec2(sin(HEAD_ANGLE), -cos(HEAD_ANGLE));
	vec2 normal = vec2(-tangent.y, tangent.x);
	vec2 q = p - vec2(cos(HEAD_ANGLE), sin(HEAD_ANGLE)) * RADIUS;
	vec2 local = vec2(dot(q, tangent), dot(q, normal));
	float head = (1.0 - smoothstep(0.04, 0.07, abs(local.x - (0.1 - abs(local.y) * 0.9)))) * step(abs(local.y), 0.13);
	return max(on_ring * (1.0 - in_gap), head);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * approach_scale;
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
	} else if (glyph == 4) {
		float shaft = (1.0 - smoothstep(0.03, 0.05, abs(p.y))) * step(abs(p.x), 0.22);
		shape = shaft + arrow(p, 0.1) + arrow(vec2(-p.x, p.y), 0.1);
		shape += (1.0 - smoothstep(0.02, 0.04, abs(radius - 0.46))) * 0.6;
	} else if (glyph == 5) {
		shape = circle_arrow(p);
		shape += (1.0 - smoothstep(0.02, 0.04, abs(radius - 0.46))) * 0.6;
	} else if (glyph == 6) {
		float core = 1.0 - smoothstep(0.1, 0.17, radius);
		float ring = 1.0 - smoothstep(0.025, 0.055, abs(radius - 0.33));
		float outer = (1.0 - smoothstep(0.015, 0.03, abs(radius - 0.46))) * 0.5;
		shape = core * 1.5 + ring + outer;
	} else if (glyph == 7 || glyph == 8) {
		float ring = 1.0 - smoothstep(0.025, 0.055, abs(radius - 0.36));
		float outer = (1.0 - smoothstep(0.015, 0.03, abs(radius - 0.46))) * (glyph == 8 ? 1.0 : 0.5);
		float inner = glyph == 8 ? (1.0 - smoothstep(0.015, 0.03, abs(radius - 0.41))) * 0.7 : 0.0;
		// Chevrons scaled to fit inside the ring; flipped vertically for the dive orb.
		vec2 q = (glyph == 7 ? vec2(p.x, -p.y) : p) * 1.5;
		float arrows = chevron(q, -0.2) + chevron(q, 0.02);
		shape = ring + outer + inner + arrows * 1.3;
	} else if (glyph == 10) {
		float steady = 1.0 - smoothstep(0.015, 0.035, abs(radius - 0.3));
		float phase = fract(run_beat);
		float wave = (1.0 - smoothstep(0.01, 0.03, abs(radius - mix(0.3, 0.48, phase)))) * (1.0 - phase);
		shape = steady * 0.8 + wave * 1.2 * step(0.0, run_beat);
	} else {
		float ring_radius = mix(0.05, 0.48, progress);
		float width = mix(0.06, 0.01, progress);
		shape = (1.0 - smoothstep(width * 0.5, width, abs(radius - ring_radius))) * (1.0 - progress);
	}
	float approach_glow = 0.0;
	if (approach_scale > 1.0) {
		float lead = cue_beat - run_beat;
		float t = lead / approach_beats;
		float approach_radius = mix(approach_target, 0.5 * approach_scale - 0.04, clamp(t, 0.0, 1.0));
		float approach = 1.0 - smoothstep(0.02, 0.045, abs(radius - approach_radius));
		float visible = step(0.0, t) * (1.0 - smoothstep(0.8, 1.0, t));
		shape += approach * visible * (0.45 + 0.9 * (1.0 - t));
		// The moment to tap: the glyph lights up as the approach ring lands on it.
		approach_glow = exp(-abs(lead) * 18.0);
	}
	float halo = exp(-radius * 6.0) * 0.25 * ((glyph == 3 || glyph == 10) ? 0.0 : 1.0);
	float pulse = 1.0 + beat_pulse * beat_gain + flash * 3.0 + approach_glow * 1.5;
	ALBEDO = glyph_color * (shape + halo) * energy * pulse * fade;
}
