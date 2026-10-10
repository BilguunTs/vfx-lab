// Shared procedural noise. Include with:
//   #include "res://shared/shaders/noise.gdshaderinc"

// Integer hash in [0, 1]. Float hashes (fract/sin tricks) amplify rounding error, so the
// same lattice point can hash differently from neighbouring cells -> visible seams.
float hash21(vec2 p) {
	uvec2 q = uvec2(ivec2(p));
	uint h = (q.x * 1597334677u) ^ (q.y * 3812015801u);
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	return float(h) * (1.0 / 4294967295.0);
}

// Smooth value noise in [0, 1].
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
