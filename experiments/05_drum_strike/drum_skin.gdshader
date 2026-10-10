// Drum skin: mottled hide with a faint painted mark, plus a ripple of light that
// spreads from the beater's contact point on impact. The script drives ripple_time.
shader_type spatial;

#include "res://shared/shaders/noise.gdshaderinc"

uniform vec3 hide_color : source_color = vec3(0.6, 0.5, 0.36);
uniform vec3 paint_color : source_color = vec3(0.4, 0.13, 0.07);
uniform vec3 glow_color : source_color = vec3(0.72, 0.86, 0.8);
uniform float radius = 0.36;
uniform vec2 impact_point = vec2(0.0, 0.0); // in the skin plane, metres from centre
uniform float ripple_time = 100.0;          // seconds since impact
uniform float ripple_strength = 0.0;
uniform float ripple_speed = 1.4;           // m/s across the skin

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local.xz; // the skin is a cylinder cap; its face lies in local xz
	float r = length(p) / radius;

	// Hide: mottled, darker and more worn toward the rim.
	float mottle = 0.6 * value_noise(p * 14.0) + 0.4 * value_noise(p * 40.0 + 9.0);
	vec3 color = hide_color * (0.75 + 0.35 * mottle) * mix(1.0, 0.65, smoothstep(0.7, 1.0, r));

	// Painted mark: a broken circle and a vertical axis line, faded like old pigment.
	float paint_wear = smoothstep(0.35, 0.6, value_noise(p * 22.0 + 3.0));
	float circle = 1.0 - smoothstep(0.012, 0.02, abs(length(p) - radius * 0.62));
	float axis = (1.0 - smoothstep(0.008, 0.016, abs(p.x))) * step(abs(p.y), radius * 0.62);
	color = mix(color, paint_color, max(circle, axis) * paint_wear * 0.8);

	// Ripple: a thin ring travelling out from the contact point, fading fast.
	float d = length(p - impact_point);
	float front = ripple_time * ripple_speed;
	float ring = exp(-pow((d - front) / 0.03, 2.0));
	float glow = ripple_strength * ring * exp(-ripple_time * 5.0) * step(r, 1.0);

	ALBEDO = color;
	ROUGHNESS = 0.85;
	EMISSION = glow_color * glow * 1.5;
}
