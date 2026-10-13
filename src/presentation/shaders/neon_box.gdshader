// Box with glowing edges of constant world width (works for scaled MultiMesh instances).
// Mesh must be a unit cube (±0.5). Instance/vertex COLOR tints the edge color.
// Optional face (two eyes) on the local +Z side for the player cube.
shader_type spatial;

global uniform float beat_pulse;

uniform vec3 body_color : source_color = vec3(0.02, 0.035, 0.08);
uniform vec3 edge_color : source_color = vec3(0.25, 0.95, 1.0);
uniform float edge_width = 0.07;
uniform float edge_energy = 4.0;
uniform float face_energy = 0.12;
uniform float pulse_gain = 0.0;
uniform bool draw_face = false;
uniform vec3 face_color : source_color = vec3(0.45, 1.0, 1.0);
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
	float pulse = 1.0 + beat_pulse * pulse_gain + flash * 3.0;
	vec3 tint = edge_color * COLOR.rgb;

	vec3 emission = tint * edge * edge_energy * pulse + tint * face_energy * (1.0 - edge);
	if (draw_face && local_position.z > 0.49) {
		vec2 face_uv = local_position.xy;
		float eyes = box_rect(face_uv, vec2(-0.06, 0.08), vec2(0.07, 0.1))
				+ box_rect(face_uv, vec2(0.2, 0.08), vec2(0.07, 0.1));
		float mouth = box_rect(face_uv, vec2(0.07, -0.18), vec2(0.16, 0.025));
		emission += face_color * (eyes + mouth * 0.6) * edge_energy;
	}
	ALBEDO = body_color;
	ROUGHNESS = 0.3;
	METALLIC = 0.4;
	EMISSION = emission;
}
