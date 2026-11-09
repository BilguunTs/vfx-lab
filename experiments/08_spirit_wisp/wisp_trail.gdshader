// Spirit Wisp — the trail: a ribbon of fading light. UV.x is the distance along the trail from
// the head (metres), UV.y runs across; COLOR.a is life (1 at the head, 0 at the end).
// Soft across its width and broken up along its length by noise that drifts with time. The
// breakup is in metres, not in life, so a fast flight splits into separate wisps instead of
// drawing one long solid streak.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shared/shaders/noise.gdshaderinc"

uniform float intensity = 0.7;
uniform float scaled_time = 0.0;  // game time (follows Engine.time_scale)
uniform float breakup = 0.7;      // 0 = smooth ribbon, 1 = strongly broken into wisps
uniform float wisp_length = 0.07; // metres per wisp

void fragment() {
	float life = COLOR.a;
	float s = UV.x / wisp_length;
	// Wavering centre line: older parts drift sideways more.
	float drift = (value_noise(vec2(s * 0.7 - scaled_time * 1.3, 3.0)) - 0.5) * 0.7 * (1.0 - life);
	// Breakup: wisps separated by gaps, none right at the head so it stays attached.
	float n = value_noise(vec2(s - scaled_time * 1.5, 11.0));
	float gaps = smoothstep(0.35, 0.7, n);
	float keep = mix(1.0, gaps, breakup * smoothstep(0.0, 0.08, UV.x));
	// Width follows the same pattern: each wisp swells in its middle and tapers to its ends.
	float width = mix(0.0, 1.0, keep);
	float across = clamp(1.0 - abs((UV.y - drift) * 2.0 - 1.0) / width, 0.0, 1.0);
	float soft = across * across;
	ALBEDO = COLOR.rgb * soft * keep * life * life * intensity;
}
