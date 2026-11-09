// Ghost Wrap — medium puff (shared by all elements; included by ghost_medium_mix/_add).
//
// A puff is NOT a picture of smoke. It is a soft window onto one continuous density field
// that lives in world space and drifts (field_flow). Overlapping puffs reveal the same
// structure, so many faint puffs merge into one volume instead of reading as separate balls.
//
// Each quad is stretched along the particle's velocity (the process material aligns the
// particle's Y axis to it) and turned around that axis to face the camera -> streaks, not dots.
// COLOR (the element's colour over life) multiplies the shading; values above 1 glow.

#include "res://shared/shaders/noise.gdshaderinc"
#include "res://experiments/06_ghost_wrap/ghost_billboard.gdshaderinc"

uniform vec3 lit_color : source_color = vec3(0.62, 0.7, 0.7);
uniform vec3 shadow_color : source_color = vec3(0.16, 0.2, 0.22);
uniform float opacity = 0.15;
uniform float field_scale = 2.2;    // density field frequency per metre
uniform vec3 field_flow = vec3(0.0, 0.35, 0.0); // m/s the field drifts through the world
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
	vec3 p = (w - field_flow * scaled_time) * field_scale;
	vec2 q = vec2(p.x + 0.6 * p.z, p.y);
	q += warp * (vec2(value_noise(q * 0.7 + 3.0), value_noise(q * 0.7 + 9.0)) - 0.5) * 2.0;
	return 0.6 * fbm(q) + 0.4 * fbm(vec2(p.z - 0.5 * p.x, p.y * 1.2) + 50.0);
}

void vertex() {
	mat4 world = velocity_billboard(MODEL_MATRIX, CAMERA_POSITION_WORLD);
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
