// Emissive neon strip for imported models ("Glow" / "GlowAlt" materials). Pulses with the beat.
shader_type spatial;

global uniform float beat_pulse;

uniform vec3 glow_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float energy = 4.0;
uniform float pulse_gain = 0.8;
instance uniform float flash = 0.0;

void fragment() {
	ALBEDO = glow_color * 0.2;
	ROUGHNESS = 0.4;
	EMISSION = glow_color * energy * (1.0 + beat_pulse * pulse_gain + flash * 3.0);
}
