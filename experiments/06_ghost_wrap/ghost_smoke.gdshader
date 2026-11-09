// Ghost Wrap — smoke puff.
//
// A puff is NOT a picture of smoke. It is a soft window onto one continuous density field
// that lives in world space and scrolls upward. Overlapping puffs reveal the same structure,
// so many faint puffs merge into one volume instead of reading as separate balls.
//
// Each quad is stretched along the particle's velocity (the process material aligns the
// particle's Y axis to it) and turned around that axis to face the camera -> streaks, not dots.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shared/shaders/noise.gdshaderinc"

uniform vec3 lit_color : source_color = vec3(0.62, 0.7, 0.7);
uniform vec3 shadow_color : source_color = vec3(0.16, 0.2, 0.22);
uniform float opacity = 0.15;
uniform float field_scale = 2.2;    // density field frequency per metre
uniform float field_rise = 0.35;    // m/s the field scrolls upward
uniform float warp = 0.6;           // curling distortion of the field
uniform float thin_start = 0.2;     // density threshold at birth ...
uniform float thin_end = 0.55;      // ... and at death: the puff disperses into wisps
uniform float softness = 0.35;
uniform float shade_contrast = 3.0; // fake self-shadowing strength
uniform float proximity_fade = 0.3; // m: soft contact with floor / body
uniform float scaled_time = 0.0;    // game time (follows Engine.time_scale)
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

varying vec3 v_world;
varying float v_life;

float fbm(vec2 p) {
	return 0.55 * value_noise(p) + 0.3 * value_noise(p * 2.03 + 17.0) + 0.15 * value_noise(p * 4.01 + 31.0);
}

// Density of the shared field at a world position. Two projections so it varies on every axis.
float field(vec3 w) {
	vec3 p = w * field_scale;
	p.y -= scaled_time * field_rise * field_scale;
	vec2 q = vec2(p.x + 0.6 * p.z, p.y);
	q += warp * (vec2(value_noise(q * 0.7 + 3.0), value_noise(q * 0.7 + 9.0)) - 0.5) * 2.0;
	return 0.6 * fbm(q) + 0.4 * fbm(vec2(p.z - 0.5 * p.x, p.y * 1.2) + 50.0);
}

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 up = length(axis) > 1e-4 ? normalize(axis) : vec3(0.0, 1.0, 0.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - pos);
	vec3 right = cross(up, to_cam);
	right = length(right) > 1e-4 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	vec3 facing = cross(right, up);
	mat4 world = mat4(vec4(right * size, 0.0), vec4(up * size, 0.0), vec4(facing * size, 0.0), vec4(pos, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_world = (world * vec4(VERTEX, 1.0)).xyz;
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	// Very soft elliptical window (the quad is taller than wide).
	float r = length((UV - 0.5) * 2.0);
	float window = 1.0 - smoothstep(0.0, 1.0, r);
	window *= window;

	float d = field(v_world);
	float threshold = mix(thin_start, thin_end, v_life);
	float density = window * smoothstep(threshold, threshold + softness, d);

	// Fake self-shadowing: if the field gets denser just below this point, light from above
	// reaches it easily (lit top edge); if denser just above, it sits in shadow.
	float d_above = field(v_world + vec3(0.0, 0.12, 0.0));
	float lit = clamp(0.5 + (d - d_above) * shade_contrast, 0.0, 1.0);
	// Thin smoke scatters light: thin parts of the *field* lean toward the lit colour.
	// (Not the puff's own window: that gives every puff a bright rim -> reads as bubbles.)
	lit = mix(lit, 1.0, 1.0 - smoothstep(threshold, threshold + 0.4, d));

	float alpha = density * opacity * COLOR.a;

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	scene.xyz /= scene.w;
	alpha *= clamp(1.0 - smoothstep(scene.z + proximity_fade, scene.z, VERTEX.z), 0.0, 1.0);

	ALBEDO = mix(shadow_color, lit_color, lit) * COLOR.rgb;
	ALPHA = alpha;
}
