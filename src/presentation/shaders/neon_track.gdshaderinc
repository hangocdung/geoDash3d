// Body of the track shader (neon_track.gdshader / neon_track_detail.gdshader); see neon_track.gdshader for
// what it draws. Code between `#ifdef DETAIL_TEXTURES` exists only in the detail variant.

global uniform float beat_pulse;
// 1 when the glow post-process is off (low quality): shaders add cheap soft halos instead.
global uniform float soft_glow;
global uniform float run_beat;
global uniform float player_distance;
global uniform vec4 pal_track_base;
global uniform vec4 pal_track_grid;
global uniform vec4 pal_track_rail;
global uniform vec4 pal_track_streak;
global uniform vec4 pal_block_base;
global uniform vec4 pal_block_rail;
global uniform vec4 pal_scenery_b;
// Song position in seconds (SongClock): drives the LED equalizer.
global uniform float song_seconds;
#ifdef DETAIL_TEXTURES
global uniform float detail_textures;
#endif

uniform vec3 base_color : source_color = vec3(0.03, 0.025, 0.07);
uniform vec3 grid_color : source_color = vec3(0.25, 0.85, 1.0);
uniform vec3 rail_color : source_color = vec3(0.3, 0.95, 1.0);
// 0 = the colors above, 1 = road palette, 2 = raised-block palette.
uniform int palette_role = 0;
uniform float lanes = 3.0;
uniform float tile_length = 3.5;
uniform float grid_energy = 0.55;
uniform float rail_energy = 5.0;
uniform float pulse_gain = 1.4;
uniform vec3 streak_color : source_color = vec3(0.75, 0.97, 1.0);
uniform float streak_energy = 5.0;
// Units a streak's head runs back behind the player during one beat, and its tail length.
uniform float streak_reach = 24.0;
uniform float streak_length = 5.0;
#ifdef DETAIL_TEXTURES
// R = road plates, G = circuit traces, B = side panels, A = hex plates. One tile spans the track width (a plate
// per lane) and `tile_length` along the road; side panels repeat every `detail_side_length` units.
uniform sampler2D detail_map : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float detail_side_length = 2.4;
uniform float detail_gain = 1.0;
#endif

// LED equalizer on the road's camera-side face (COLOR.b = 1, road only): precomputed per song
// (tools/audio/build_spectrum.py), R = VU level, G = peak dot, `spectrum_row` frames per row block.
const int SPECTRUM_BANDS = 16;
uniform sampler2D spectrum : filter_nearest;
uniform int spectrum_frames = 0;
uniform int spectrum_row = 2048;
uniform float spectrum_fps = 30.0;
uniform float led_column_length = 0.55;
uniform float led_segments = 7.0;
uniform float led_energy = 2.2;

float grid_line(float coordinate, float half_width) {
	float distance_to_line = abs(fract(coordinate + 0.5) - 0.5);
	float aa = fwidth(coordinate) * 1.5;
	return 1.0 - smoothstep(half_width, half_width + aa, distance_to_line);
}

// x = thin wave front across the track at the streak head, y = fading tail back toward the player. The wave runs
// backward from the player so the road ahead (where the hazards are) stays free of glare.
vec2 beat_streak(float distance_along) {
	float phase = fract(run_beat);
	float behind = player_distance - distance_along;
	float behind_head = phase * streak_reach - behind;
	float alive = step(0.0, behind) * (1.0 - phase) * step(0.0, run_beat);
	float front = exp(-abs(behind_head) / 0.5);
	float tail = step(0.0, behind_head) * exp(-behind_head / streak_length);
	return vec2(front, tail) * alive;
}

// Columns along the road cycle through the bands mirrored (0..15..1) so neighbours flow; segments light up to
// the band level, low to high from the palette's grid color to its second scenery color, white peak dot. Far
// away, where a column gets thinner than ~2 px, the lamps fade into an even glow (no shimmer).
vec3 led_wall(vec2 uv, vec3 low_tint, vec3 high_tint) {
	float along = uv.y / led_column_length;
	float cycle = mod(floor(along), float(2 * SPECTRUM_BANDS - 2));
	int band = int(cycle < float(SPECTRUM_BANDS) ? cycle : float(2 * SPECTRUM_BANDS - 2) - cycle);
	int frame = clamp(int(song_seconds * spectrum_fps), 0, spectrum_frames - 1);
	int block = frame / spectrum_row;
	vec2 meter = texelFetch(spectrum, ivec2(frame - block * spectrum_row, block * SPECTRUM_BANDS + band), 0).rg;
	// UV.x runs 0 (road edge) .. 1 (bottom); the top tenth is the rail band.
	float height = clamp((1.0 - uv.x) / 0.9, 0.0, 1.0) * led_segments;
	float segment = floor(height);
	vec2 cell = vec2(fract(along), fract(height));
	float lamp = step(0.14, cell.x) * step(cell.x, 0.86) * step(0.18, cell.y) * step(cell.y, 0.82)
			* step(0.1, uv.x);
	float lit = step(segment + 0.5, meter.r * led_segments);
	float peak = step(abs(segment - floor(meter.g * led_segments - 0.001)), 0.5) * step(0.05, meter.g);
	vec3 color = mix(low_tint, high_tint, segment / led_segments);
	vec3 sharp = lamp * (color * (lit * led_energy + 0.05) + vec3(1.0) * peak * led_energy);
	vec3 glow = mix(low_tint, high_tint, 0.5) * meter.r * led_energy * 0.35;
	return mix(glow, sharp, 1.0 - smoothstep(0.25, 0.6, fwidth(along)));
}

void fragment() {
	float pulse = 1.0 + beat_pulse * pulse_gain;
	vec3 base_tint = base_color;
	vec3 grid_tint = grid_color;
	vec3 rail_tint = rail_color;
	vec3 streak_tint = streak_color;
	if (palette_role > 0) {
		base_tint = palette_role == 1 ? pal_track_base.rgb : pal_block_base.rgb;
		grid_tint = pal_track_grid.rgb;
		rail_tint = palette_role == 1 ? pal_track_rail.rgb : pal_block_rail.rgb;
		streak_tint = pal_track_streak.rgb;
	}
	bool top = COLOR.r > 0.5;
#ifdef DETAIL_TEXTURES
	// `detail_textures` stays a runtime switch for A/B measurements (--perf=nodetail).
	bool detailed = detail_textures > 0.5;
	vec4 detail = vec4(0.5);
	if (detailed) {
		// Sampled once, outside the face branches (mip selection needs uniform control flow).
		detail = texture(detail_map, top ? vec2(UV.x, UV.y / tile_length) : vec2(UV.y / detail_side_length, UV.x * 0.5));
	}
#endif
	vec3 emission;
	if (top) {
		float grid = max(grid_line(UV.x * lanes, 0.012), grid_line(UV.y / tile_length, 0.01));
		float edge_distance = min(UV.x, 1.0 - UV.x);
		float rail = 1.0 - smoothstep(0.0, 0.045, edge_distance);
		rail += exp(-edge_distance * 22.0) * 0.35 * soft_glow;
		grid += max(grid_line(UV.x * lanes, 0.06), grid_line(UV.y / tile_length, 0.05)) * 0.25 * soft_glow;
		ALBEDO = base_tint * (1.0 + grid);
		ROUGHNESS = 0.18;
		METALLIC = 0.5;
		emission = grid_tint * grid * grid_energy * pulse + rail_tint * rail * rail_energy * pulse;
		float lane_lines = grid_line(UV.x * lanes, 0.025);
		vec2 streak = beat_streak(UV.y);
		emission += streak_tint * streak_energy * (0.6 + beat_pulse)
				* (streak.x * 0.45 + streak.y * (lane_lines + 0.08));
#ifdef DETAIL_TEXTURES
		if (detailed) {
			float plates = palette_role == 2 ? detail.a : detail.r;
			float groove = 1.0 - smoothstep(0.1, 0.32, plates);
			ALBEDO *= 0.55 + 0.9 * plates;
			ROUGHNESS = mix(0.16, 0.6, groove);
			emission += grid_tint * (plates * 0.05 + groove * 0.1) * grid_energy * detail_gain;
			// Road: circuit traces light up with the beat. Blocks: their hex seams glow in the rail color.
			emission += palette_role == 2 ? rail_tint * groove * 0.05 * pulse * detail_gain
					: grid_tint * detail.g * 0.5 * grid_energy * pulse * detail_gain;
		}
#endif
	} else {
		float band = 1.0 - smoothstep(0.0, 0.07, UV.x);
		ALBEDO = base_tint * 0.6;
		ROUGHNESS = 0.5;
		if (COLOR.g > 0.5) {
			// End cap: outline the whole face so a wall ahead reads from far away.
			float side_edge = 1.0 - smoothstep(0.0, 0.04, min(UV.y, 1.0 - UV.y));
			emission = rail_tint * max(band, side_edge) * rail_energy * 0.45 * pulse;
		} else {
			float panel = grid_line(UV.y / (tile_length * 2.0), 0.006) * 0.35;
			emission = rail_tint * band * rail_energy * 0.45 * pulse + grid_tint * panel * grid_energy;
			if (palette_role == 1 && COLOR.b > 0.5 && spectrum_frames > 0) {
				emission += led_wall(UV, grid_tint, pal_scenery_b.rgb);
			}
#ifdef DETAIL_TEXTURES
			if (detailed) {
				ALBEDO *= 0.5 + detail.b;
				emission += rail_tint * (detail.b * 0.03 + smoothstep(0.75, 0.95, detail.b) * 0.12) * detail_gain;
			}
#endif
		}
	}
	EMISSION = emission;
}
