// Synthwave night sky: vertical gradient, stars, a ringed planet, a striped sun on the horizon (warm
// phases) and a horizon glow. `energy` (0..1) follows the song section; `tint` shifts the palette.
// Everything is evaluated in the half-resolution pass (the sky is smooth; ~4x cheaper per pixel on phones).
// The visible background reads the phase palette globals (`pal_sky_*`, blended per frame during a phase
// change) and brightens on the beat; the radiance cubemap reads the material uniforms, which
// EnvironmentDirector updates once per settled phase, so the radiance map is never re-rendered per frame.
shader_type sky;
render_mode use_half_res_pass;

uniform vec3 zenith_color : source_color = vec3(0.02, 0.01, 0.07);
uniform vec3 mid_color : source_color = vec3(0.12, 0.04, 0.28);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.16, 0.6);
uniform vec3 planet_color : source_color = vec3(0.35, 0.45, 1.0);
// x = planet, y = sun, z = stars, w = horizon glow.
uniform vec4 style = vec4(1.0, 0.0, 1.0, 1.0);
uniform vec3 planet_direction = vec3(-0.55, 0.32, -0.77);
uniform float planet_size = 0.17;
uniform vec3 sun_direction = vec3(0.25, 0.07, -0.96);
uniform float sun_size = 0.13;
uniform float energy = 0.5;
uniform vec3 tint : source_color = vec3(1.0);
// Horizon brightening per unit of `beat_pulse` (0 = off, for "reduce flashing"). Only the background pass
// reads the per-frame globals, so the radiance map is never re-rendered for them.
uniform float beat_brightness = 0.2;
global uniform float beat_pulse;
global uniform vec4 pal_sky_zenith;
global uniform vec4 pal_sky_mid;
global uniform vec4 pal_sky_horizon;
global uniform vec4 pal_sky_accent;
global uniform vec4 pal_sky_style;

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

// Retro sun: gradient disc sitting on the horizon, its lower half cut by widening horizontal stripes.
vec3 add_sun(vec3 color, vec3 dir, vec3 horizon, vec3 accent, float amount) {
	vec3 axis = normalize(sun_direction);
	float angle = acos(clamp(dot(dir, axis), -1.0, 1.0));
	float disc = 1.0 - smoothstep(sun_size - 0.004, sun_size, angle);
	float v = clamp((dir.y - axis.y) / sun_size, -1.0, 1.0);
	float stripe_width = mix(0.0, 0.55, smoothstep(0.25, -1.0, v));
	float stripes = step(stripe_width, fract(v * 7.0));
	float body = disc * stripes * step(0.0, dir.y);
	vec3 sun_shade = mix(horizon * 0.9, accent * 1.1, smoothstep(-1.0, 0.9, v));
	color = mix(color, sun_shade, body * amount);
	color += accent * exp(-max(angle - sun_size, 0.0) * 12.0) * 0.18 * (1.0 - disc) * amount;
	return color;
}

vec3 sky_color(vec3 dir, bool with_stars, float pulse, vec3 zenith, vec3 mid, vec3 horizon, vec3 accent,
		vec4 look) {
	float height = dir.y;
	vec3 color = mix(horizon, mid, smoothstep(-0.05, 0.25, height));
	color = mix(color, zenith, smoothstep(0.2, 0.75, height));
	color = mix(color, horizon * 0.25, smoothstep(0.0, -0.4, height));
	color += horizon * exp(-abs(height) * 14.0) * (0.35 + energy * 0.5) * look.w;
	// Beat pulse: strongest at the horizon, almost still overhead; stars and planet stay steady.
	color *= 1.0 + pulse * (1.0 - smoothstep(0.0, 0.6, abs(height)));
	if (with_stars) {
		color += vec3(0.9, 0.95, 1.0) * stars(dir) * smoothstep(0.0, 0.3, height) * look.z;
	}
	if (look.y > 0.0) {
		color = add_sun(color, dir, horizon, accent, look.y);
	}

	vec3 planet_axis = normalize(planet_direction);
	float planet_angle = acos(clamp(dot(dir, planet_axis), -1.0, 1.0));
	float planet = (1.0 - smoothstep(planet_size - 0.004, planet_size, planet_angle)) * look.x;
	float rim = smoothstep(planet_size * 0.55, planet_size, planet_angle) * planet;
	vec3 to_dir = dir - planet_axis * dot(dir, planet_axis);
	float bands = 0.5 + 0.5 * sin(dot(to_dir, vec3(0.3, 1.0, 0.2)) * 60.0);
	vec3 planet_shade = accent * (0.25 + 0.15 * bands) + accent * rim * 0.9;
	color = mix(color, planet_shade, planet);
	color += accent * exp(-max(planet_angle - planet_size, 0.0) * 18.0) * 0.25 * (1.0 - planet) * look.x;

	// Thin tilted ring around the planet.
	vec3 ring_normal = normalize(vec3(0.25, 1.0, 0.35));
	float ring_plane = abs(dot(dir - planet_axis, ring_normal));
	float ring_radius = length(dir - planet_axis);
	float ring = (1.0 - smoothstep(0.0, 0.006, ring_plane))
			* smoothstep(planet_size * 1.25, planet_size * 1.35, ring_radius)
			* (1.0 - smoothstep(planet_size * 1.9, planet_size * 2.0, ring_radius));
	ring *= 1.0 - planet * step(0.0, dot(dir - planet_axis, ring_normal));
	color += accent * ring * 0.8 * look.x;

	return color * tint;
}


void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = sky_color(EYEDIR, false, 0.0, zenith_color, mid_color, horizon_color, planet_color, style);
	} else if (AT_HALF_RES_PASS) {
		COLOR = sky_color(EYEDIR, true, beat_pulse * beat_brightness, pal_sky_zenith.rgb, pal_sky_mid.rgb,
				pal_sky_horizon.rgb, pal_sky_accent.rgb, pal_sky_style);
	} else {
		COLOR = HALF_RES_COLOR.rgb;
	}
}
