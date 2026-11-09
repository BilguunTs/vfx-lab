// Ghost Wrap — body material. Replaces a mesh's material while a transition is under way.
// Keeps the original colour. The body dissolves along a ragged sphere (the "front") centred on
// the reveal origin: in ghosting mode the ghost is inside the front, in revealing mode the
// solid body is. Noise flowing upward tatters the edge; a faint rim keeps the silhouette.
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
uniform float edge_flow = 0.25;       // m/s, upward

uniform float body_opacity = 1.0;
uniform float desaturate = 0.5;
uniform vec3 glow_color : source_color = vec3(0.55, 0.8, 0.75);
uniform float rim_strength = 0.35;
uniform float edge_glow = 0.2;

varying vec3 body_pos;

void vertex() {
	body_pos = (world_to_body * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo.rgb * texture(albedo_tex, UV).rgb;

	// Two noise layers on crossed axes, so the edge is ragged from every side and flows upward.
	vec3 p = body_pos * edge_noise_scale;
	float flow = scaled_time * edge_flow * edge_noise_scale;
	float n = 0.6 * value_noise(vec2(p.x + 0.7 * p.z, p.y - flow))
			+ 0.4 * value_noise(vec2(p.z - 0.6 * p.x, 1.3 * p.y - flow) * 1.9 + 13.0);

	float d = distance(body_pos, reveal_origin) / reveal_reach + (n - 0.5) * 2.0 * edge_noise;
	float s = smoothstep(front - edge_band, front, d);
	float vis = ghost_inside ? s : 1.0 - s;

	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, vec3(luma), desaturate * intensity);
	ROUGHNESS = roughness;

	// Glow fades in over the first 10 % of a transition, so leaving 0 doesn't pop.
	float presence = smoothstep(0.0, 0.1, intensity);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	float edge = vis * (1.0 - vis) * 4.0 * edge_glow; // peaks mid-dissolve
	EMISSION = glow_color * (rim + edge) * presence;

	ALPHA = vis * mix(1.0, body_opacity, presence) * albedo.a;
}
