// Draws one expanding ground ring on a flat quad.
// This shader has no notion of time or lifetime: the script drives radius,
// thickness and fade every frame. Keep it that way so timing stays in one place.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shared/shaders/noise.gdshaderinc"

uniform vec3 ring_color : source_color = vec3(0.72, 0.86, 0.8);
uniform float intensity = 2.5;
uniform float fade = 1.0;

uniform float radius = 1.0;
uniform float thickness = 0.2;
uniform float softness : hint_range(0.0, 1.0) = 0.7;

uniform float wake = 0.12;
uniform float wake_length = 0.4;

uniform float edge_noise = 0.06;
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.45;
uniform float noise_scale = 2.5;
uniform float noise_time = 0.0;
uniform float noise_seed = 0.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float dist = length(local_xz);
	// Sampling noise on a circle (direction * scale) makes it wrap seamlessly
	// around the ring, with no seam where the angle jumps from -PI to PI.
	vec2 dir = local_xz / max(dist, 1e-4);
	vec2 q = dir * noise_scale + vec2(noise_seed * 17.31, noise_time);
	float n = 0.65 * value_noise(q) + 0.35 * value_noise(q * 2.3 + 7.1);

	float r = radius + (n - 0.5) * 2.0 * edge_noise;
	float d = dist - r; // > 0 outside the front, < 0 behind it
	float half_band = max(thickness * 0.5, 1e-4);
	float band = 1.0 - smoothstep(half_band * (1.0 - softness), half_band, abs(d));

	// Wake: faint disturbed energy left behind the front, decaying toward the centre.
	// The leading edge stays crisp while the trailing side is soft, which reads as a
	// pressure wave rather than a drawn circle.
	float behind = max(-d, 0.0);
	float wake_mask = wake * exp(-behind / max(wake_length, 1e-3)) * (1.0 - smoothstep(-half_band, 0.0, d));

	float variation = mix(1.0 - brightness_variation, 1.0, value_noise(q * 1.7 + 31.7));

	ALBEDO = ring_color * intensity * fade * variation * (band + wake_mask);
}
