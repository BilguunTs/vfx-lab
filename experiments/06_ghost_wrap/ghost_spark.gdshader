// Ghost Wrap — accent particle (sparks, embers): a tiny additive light streak.
// Bright narrow core with a soft halo, stretched along the motion, with per-particle flicker.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://experiments/06_ghost_wrap/ghost_billboard.gdshaderinc"

uniform float flicker = 0.3;
uniform float scaled_time = 0.0; // game time (follows Engine.time_scale)

varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * velocity_billboard(MODEL_MATRIX, CAMERA_POSITION_WORLD);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_seed = fract(float(INSTANCE_ID) * 0.6180339);
}

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c);
	float core = 1.0 - smoothstep(0.0, 0.35, r);
	float halo = 1.0 - smoothstep(0.0, 1.0, r);
	float light = core + 0.35 * halo * halo;
	// Two incommensurate sines per particle: an irregular twinkle, not a regular pulse.
	float t = scaled_time * (9.0 + 7.0 * v_seed) + v_seed * 40.0;
	float tw = 0.5 + 0.25 * sin(t) + 0.25 * sin(t * 2.37 + 1.3);
	light *= mix(1.0, tw, flicker);
	ALBEDO = COLOR.rgb * light;
	ALPHA = COLOR.a;
}
