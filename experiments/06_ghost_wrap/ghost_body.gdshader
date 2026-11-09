// Ghost Wrap — body material. Replaces a mesh's material while a transition is under way.
// Keeps the original colour. The body dissolves along a ragged sphere (the "front") centred on
// the reveal origin: in ghosting mode the medium is inside the front, in revealing mode the
// solid body is. Drifting noise tatters the edge; the element can scorch the body just ahead
// of it (char for fire, wet darkening for water); a faint rim keeps the silhouette.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back;

#include "res://shared/shaders/noise.gdshaderinc"

// Copied from the original material.
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness = 1.0;

uniform mat4 world_to_body;         // world -> GhostWrap node
uniform float scaled_time = 0.0;    // game time (follows Engine.time_scale)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Dissolve front, computed by ghost_wrap.gd (distances in units of reveal_reach).
uniform vec3 reveal_origin;         // body space
uniform float reveal_reach = 1.0;   // distance from origin to the farthest part of the body
uniform float front = 0.0;
uniform bool ghost_inside = true;
uniform float edge_band = 0.2;
uniform float edge_noise = 0.1;
uniform float edge_noise_scale = 5.0; // per metre
uniform vec3 edge_flow = vec3(0.0, 0.25, 0.0); // m/s

uniform float body_opacity = 1.0;
uniform float desaturate = 0.5;
uniform vec3 glow_color : source_color = vec3(0.55, 0.8, 0.75);
uniform float rim_strength = 0.35;
uniform float edge_glow = 0.2;
uniform vec4 scorch_color : source_color = vec4(0.0);
uniform float scorch_width = 0.0;

varying vec3 body_pos;

void vertex() {
	body_pos = (world_to_body * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo.rgb * texture(albedo_tex, UV).rgb;

	// Two noise layers on crossed axes, so the edge is ragged from every side; it drifts with edge_flow.
	vec3 p = (body_pos - edge_flow * scaled_time) * edge_noise_scale;
	float n = 0.6 * value_noise(vec2(p.x + 0.7 * p.z, p.y))
			+ 0.4 * value_noise(vec2(p.z - 0.6 * p.x, 1.3 * p.y) * 1.9 + 13.0);

	float d = distance(body_pos, reveal_origin) / reveal_reach + (n - 0.5) * 2.0 * edge_noise;
	float s = smoothstep(front - edge_band, front, d);
	float vis = ghost_inside ? s : 1.0 - s;
	// How far into the solid side of the band this point is (<= 0 inside the band itself).
	float into_solid = ghost_inside ? d - front : (front - edge_band) - d;

	// Glow and scorch fade in over the first 10 % of a transition, so leaving 0 doesn't pop.
	float presence = smoothstep(0.0, 0.1, intensity);
	float scorch = (1.0 - smoothstep(0.0, max(scorch_width, 1e-4), into_solid)) * scorch_color.a * presence;

	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(mix(base, vec3(luma), desaturate * intensity), scorch_color.rgb, scorch);
	ROUGHNESS = roughness;

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	float edge = vis * (1.0 - vis) * 4.0 * edge_glow; // peaks mid-dissolve
	EMISSION = glow_color * (rim + edge) * presence;

	ALPHA = vis * mix(1.0, body_opacity, presence) * albedo.a;
}
