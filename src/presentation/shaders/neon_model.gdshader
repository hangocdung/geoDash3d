// Single material for the Blender models (assets/blender/generate_models.py): the vertex color holds each face's
// role, black = dark metal body, red = primary neon glow, green = accent glow, so a model is one draw call.
// Glow pulses with the beat. `palette_role` 1 takes glow / accent from the phase palette's decor colors.
shader_type spatial;

global uniform float beat_pulse;
global uniform vec4 pal_decor_glow;
global uniform vec4 pal_decor_accent;

uniform vec3 body_color : source_color = vec3(0.035, 0.03, 0.08);
uniform vec3 glow_color : source_color = vec3(0.3, 0.9, 1.0);
uniform vec3 accent_color : source_color = vec3(1.0, 0.3, 0.85);
uniform float energy = 4.0;
uniform float pulse_gain = 0.8;
uniform int palette_role = 0;
instance uniform float flash = 0.0;

void fragment() {
	vec3 glow = palette_role == 1 ? pal_decor_glow.rgb : glow_color;
	vec3 accent = palette_role == 1 ? pal_decor_accent.rgb : accent_color;
	vec3 tint = glow * COLOR.r + accent * COLOR.g;
	float lit = clamp(COLOR.r + COLOR.g, 0.0, 1.0);
	ALBEDO = mix(body_color, tint * 0.2, lit);
	METALLIC = mix(0.7, 0.0, lit);
	ROUGHNESS = mix(0.28, 0.4, lit);
	EMISSION = tint * energy * (1.0 + beat_pulse * pulse_gain + flash * 3.0);
}
