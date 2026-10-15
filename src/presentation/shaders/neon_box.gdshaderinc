// Body of the box shader (neon_box.gdshader / neon_box_detail.gdshader); see neon_box.gdshader for what it
// draws. Code between `#ifdef DETAIL_TEXTURES` exists only in the detail variant.

global uniform float beat_pulse;
global uniform float soft_glow;
// Road-level position of the player: hazards brighten as it approaches (`proximity_gain` > 0).
global uniform vec3 player_position;
global uniform vec4 pal_scenery_a;
global uniform vec4 pal_scenery_b;
global uniform vec4 pal_pillar;
#ifdef DETAIL_TEXTURES
global uniform float detail_textures;
#endif

uniform vec3 body_color : source_color = vec3(0.02, 0.035, 0.08);
uniform vec3 edge_color : source_color = vec3(0.25, 0.95, 1.0);
uniform float edge_width = 0.07;
uniform float edge_energy = 4.0;
uniform float face_energy = 0.12;
uniform float pulse_gain = 0.0;
uniform bool draw_face = false;
uniform vec3 face_color : source_color = vec3(0.45, 1.0, 1.0);
uniform int palette_role = 0;
#ifdef DETAIL_TEXTURES
// R = lit windows, G = pillar ribs, B = facade structure; one tile covers `detail_tile` world units.
uniform sampler2D detail_map : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float detail_tile = 20.0;
uniform float window_energy = 1.1;
#endif
uniform float proximity_gain = 0.0;
uniform float proximity_near = 5.0;
uniform float proximity_far = 24.0;
instance uniform float flash = 0.0;

varying vec3 local_position;
varying vec3 axis_scale;

void vertex() {
	local_position = VERTEX;
	axis_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
}

float box_rect(vec2 p, vec2 center, vec2 half_size) {
	vec2 d = abs(p - center) - half_size;
	return 1.0 - smoothstep(0.0, 0.012, max(d.x, d.y));
}

void fragment() {
	vec3 to_face = (vec3(0.5) - abs(local_position)) * axis_scale;
	float nearest = min(to_face.x, min(to_face.y, to_face.z));
	float farthest = max(to_face.x, max(to_face.y, to_face.z));
	float edge_distance = to_face.x + to_face.y + to_face.z - nearest - farthest;
	float edge = 1.0 - smoothstep(edge_width * 0.55, edge_width, edge_distance);
	// Fake bloom: soft falloff away from the edge when the glow post-process is off.
	float halo = exp(-edge_distance / (edge_width * 1.6)) * 0.3 * soft_glow;
	float near = 1.0 - smoothstep(proximity_near, proximity_far, distance(NODE_POSITION_WORLD, player_position));
	float pulse = (1.0 + beat_pulse * pulse_gain + flash * 3.0) * (1.0 + proximity_gain * near);
	vec3 tint = edge_color * COLOR.rgb;
	if (palette_role == 1) {
		tint = mix(pal_scenery_a.rgb, pal_scenery_b.rgb, COLOR.g) * COLOR.r;
	} else if (palette_role == 2) {
		tint = pal_pillar.rgb;
	}

	vec3 emission = tint * (edge + halo) * edge_energy * pulse + tint * face_energy * (1.0 - edge);
	ALBEDO = body_color;
#ifdef DETAIL_TEXTURES
	if (palette_role > 0 && detail_textures > 0.5) {
		vec3 world_local = local_position * axis_scale;
		bool side_x = to_face.x <= min(to_face.y, to_face.z);
		bool side_z = !side_x && to_face.z <= to_face.y;
		vec2 face_uv = side_x ? world_local.zy : (side_z ? world_local.xy : world_local.xz);
		vec4 detail = texture(detail_map, face_uv / detail_tile);
		float inside = 1.0 - edge;
		if (palette_role == 1) {
			float walls = (side_x || side_z) ? 1.0 : 0.0;
			emission += tint * (detail.r * window_energy * walls + detail.b * face_energy * 1.5) * inside;
			ALBEDO *= 0.6 + detail.b;
		} else {
			emission += tint * detail.g * 0.08 * inside;
			ALBEDO *= 0.4 + detail.g;
		}
	}
#endif
	if (draw_face && local_position.z > 0.49) {
		// The face stays upright while the cube rolls: rotate it so its up follows world up projected on the face.
		vec2 up = (transpose(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0)).xy;
		up = length(up) > 0.001 ? normalize(up) : vec2(0.0, 1.0);
		vec2 face_uv = vec2(dot(local_position.xy, vec2(up.y, -up.x)), dot(local_position.xy, up));
		// Centered on the face: two eyes mirrored about the middle, the mouth under them.
		float eyes = box_rect(vec2(abs(face_uv.x), face_uv.y), vec2(0.15, 0.08), vec2(0.065, 0.1));
		float mouth = box_rect(face_uv, vec2(0.0, -0.17), vec2(0.13, 0.025));
		emission += face_color * (eyes + mouth * 0.6) * edge_energy;
	}
	ROUGHNESS = 0.3;
	METALLIC = 0.4;
	EMISSION = emission;
}
