// Synthwave night sky: vertical gradient, stars, a ringed planet and a warm horizon glow.
// `energy` (0..1) follows the song section; `tint` shifts the palette per section.
// Everything is evaluated in the half-resolution pass (the sky is smooth; ~4x cheaper per pixel on phones).
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 zenith_color : source_color = vec3(0.02, 0.01, 0.07);
uniform vec3 mid_color : source_color = vec3(0.12, 0.04, 0.28);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.16, 0.6);
uniform vec3 planet_color : source_color = vec3(0.35, 0.45, 1.0);
uniform vec3 planet_direction = vec3(-0.55, 0.32, -0.77);
uniform float planet_size = 0.17;
uniform float energy = 0.5;
uniform vec3 tint : source_color = vec3(1.0);

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float stars(vec3 direction) {
	vec3 cell = floor(direction * 180.0);
	float h = hash(cell);
	vec3 center = (cell + 0.5 + (vec3(hash(cell + 1.0), hash(cell + 2.0), hash(cell + 3.0)) - 0.5) * 0.6) / 180.0;
	float d = length(direction - normalize(center)) * 180.0;
	// No TIME-based twinkle: using TIME would force a radiance cubemap update every frame.
	float brightness = 0.5 + 0.5 * hash(cell + 7.0);
	return step(0.965, h) * (1.0 - smoothstep(0.0, 0.35, d)) * brightness;
}

vec3 sky_color(vec3 dir, bool with_stars) {
	float height = dir.y;
	vec3 color = mix(horizon_color, mid_color, smoothstep(-0.05, 0.25, height));
	color = mix(color, zenith_color, smoothstep(0.2, 0.75, height));
	color = mix(color, horizon_color * 0.25, smoothstep(0.0, -0.4, height));
	color += horizon_color * exp(-abs(height) * 14.0) * (0.35 + energy * 0.5);
	if (with_stars) {
		color += vec3(0.9, 0.95, 1.0) * stars(dir) * smoothstep(0.0, 0.3, height);
	}

	vec3 planet_axis = normalize(planet_direction);
	float planet_angle = acos(clamp(dot(dir, planet_axis), -1.0, 1.0));
	float planet = 1.0 - smoothstep(planet_size - 0.004, planet_size, planet_angle);
	float rim = smoothstep(planet_size * 0.55, planet_size, planet_angle) * planet;
	vec3 to_dir = dir - planet_axis * dot(dir, planet_axis);
	float bands = 0.5 + 0.5 * sin(dot(to_dir, vec3(0.3, 1.0, 0.2)) * 60.0);
	vec3 planet_shade = planet_color * (0.25 + 0.15 * bands) + planet_color * rim * 0.9;
	color = mix(color, planet_shade, planet);
	color += planet_color * exp(-max(planet_angle - planet_size, 0.0) * 18.0) * 0.25 * (1.0 - planet);

	// Thin tilted ring around the planet.
	vec3 ring_normal = normalize(vec3(0.25, 1.0, 0.35));
	float ring_plane = abs(dot(dir - planet_axis, ring_normal));
	float ring_radius = length(dir - planet_axis);
	float ring = (1.0 - smoothstep(0.0, 0.006, ring_plane))
			* smoothstep(planet_size * 1.25, planet_size * 1.35, ring_radius)
			* (1.0 - smoothstep(planet_size * 1.9, planet_size * 2.0, ring_radius));
	ring *= 1.0 - planet * step(0.0, dot(dir - planet_axis, ring_normal));
	color += planet_color * ring * 0.8;

	return color * tint;
}


void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = sky_color(EYEDIR, false);
	} else if (AT_HALF_RES_PASS) {
		COLOR = sky_color(EYEDIR, true);
	} else {
		COLOR = HALF_RES_COLOR.rgb;
	}
}
