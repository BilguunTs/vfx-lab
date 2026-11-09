// Lab ground: packed earth, procedural, no textures.
//
// Detail at several scales so the ground reads at any distance and gives distortion effects
// (the shockwave) something to bend: big damp/dry patches, mid mottling, scattered pebbles and
// fine grit. A shallow bump from the same height field catches the low sun. Fine detail fades
// out with distance (fwidth) instead of shimmering.
//
// Storytelling: a trampled ring around the origin — darker, smoother, fewer pebbles — as if
// people have circled this spot for a long time. worn_strength = 0 removes it.
shader_type spatial;
render_mode diffuse_lambert;

#include "res://shared/shaders/noise.gdshaderinc"

uniform vec3 earth_dark : source_color = vec3(0.28, 0.265, 0.24);
uniform vec3 earth_light : source_color = vec3(0.43, 0.405, 0.37);
uniform vec3 pebble_color : source_color = vec3(0.55, 0.53, 0.5);
uniform float patch_scale = 0.22;      // big damp/dry patches per metre
uniform float mottle_scale = 1.7;
uniform float pebble_cell = 0.12;      // metres per pebble cell
uniform float pebble_density = 0.1;    // share of cells holding a pebble
uniform float grit_strength = 0.12;
uniform float bump_strength = 0.6;
// Dry-earth cracks: a cell network of thin dark lines, only in the drier patches.
uniform vec3 crack_color : source_color = vec3(0.1, 0.09, 0.08);
uniform float crack_cell = 0.45;       // metres between cracks
uniform float crack_width = 0.035;     // fraction of a cell
uniform float crack_amount = 0.75;     // 0 = none, 1 = cracks wherever the ground is dry

uniform vec2 worn_center = vec2(0.0);
uniform float worn_radius = 2.4;
uniform float worn_width = 1.1;
uniform float worn_strength = 0.4;

varying vec3 v_world;

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

// 0..1 pebble coverage: one round pebble at a jittered spot in some cells.
float pebbles(vec2 p, float density) {
	vec2 g = p / pebble_cell;
	vec2 cell = floor(g);
	float present = step(1.0 - density, hash21(cell + 311.0));
	vec2 centre = vec2(hash21(cell + 17.0), hash21(cell + 53.0)) * 0.6 + 0.2;
	float radius = 0.1 + 0.25 * pow(hash21(cell + 91.0), 2.0);
	vec2 q = fract(g) - centre;
	// Lumpy outline: stretch along a random direction, wobble the edge.
	float a = hash21(cell + 5.0) * 6.2832;
	q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * q * vec2(1.0, 1.5);
	float d = length(q) * (0.85 + 0.3 * value_noise(g * 9.0 + cell));
	return present * (1.0 - smoothstep(radius * 0.7, radius, d));
}

// Distance to the nearest cell border of a jittered grid (Voronoi F2 - F1, approximated).
float crack_lines(vec2 p) {
	vec2 g = p / crack_cell;
	g += (vec2(value_noise(g * 1.3), value_noise(g * 1.3 + 7.7)) - 0.5) * 0.35; // wander
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 pt = o + vec2(hash21(cell + o + 101.0), hash21(cell + o + 211.0)) * 0.8 + 0.1;
			float d = length(pt - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1; // 0 on a border
}

float worn(vec2 p) {
	float r = length(p - worn_center);
	float d = (r - worn_radius) / worn_width;
	// Slightly irregular edge: nobody walks a perfect circle.
	float wobble = value_noise(p * 0.9) * 0.6 - 0.3;
	return worn_strength * exp(-(d + wobble) * (d + wobble) * 2.0);
}

float height(vec2 p, float detail, float wear) {
	float h = fbm(p * mottle_scale) * 0.6;
	h += pebbles(p, pebble_density * (1.0 - wear * 1.5)) * 0.5 * detail;
	h += value_noise(p * 30.0) * 0.15 * detail;
	return h * (1.0 - wear);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	// 1 up close, 0 where a pebble cell is smaller than ~2 pixels.
	float detail = 1.0 - smoothstep(0.25, 0.6, fwidth(p.x) / pebble_cell);
	float wear = worn(p);

	float patches = smoothstep(0.3, 0.7, fbm(p * patch_scale));
	float mottle = fbm(p * mottle_scale);
	vec3 col = mix(earth_dark, earth_light, patches * 0.6 + mottle * 0.4);
	col *= 1.0 + (value_noise(p * 30.0) - 0.5) * 2.0 * grit_strength * detail;
	float pebble = pebbles(p, pebble_density * (1.0 - wear * 1.5)) * detail;
	// Pebbles both lighter and darker than the earth, never all white dots.
	float pebble_tone = hash21(floor(p / pebble_cell) + 7.0);
	col = mix(col, pebble_color * mix(0.45, 1.1, pebble_tone), pebble * 0.85);

	// Cracks where it's dry (light patches), broken up by noise so they don't tile the world.
	float dry = smoothstep(0.35, 0.75, patches + (value_noise(p * 0.7) - 0.5) * 0.5);
	float cracked = crack_amount * dry * (1.0 - wear) * smoothstep(0.35, 0.6, value_noise(p * 1.1 + 31.0));
	float cd = crack_lines(p);
	float aa = fwidth(cd);
	float crack = (1.0 - smoothstep(crack_width - aa, crack_width + aa, cd)) * cracked;
	crack *= 1.0 - smoothstep(0.4, 1.0, fwidth(p.x) / (crack_cell * crack_width) * 0.5); // fade far away
	col = mix(col, crack_color, crack * 0.85);
	col *= 1.0 - wear * 0.35;
	ALBEDO = col;
	ROUGHNESS = mix(1.0, 0.85, wear);
	SPECULAR = 0.25;

	// Bump from the same height field (finite differences in world space).
	float e = 0.01;
	float h0 = height(p, detail, wear);
	float hx = height(p + vec2(e, 0.0), detail, wear);
	float hz = height(p + vec2(0.0, e), detail, wear);
	vec3 n = normalize(vec3(-(hx - h0) / e * 0.05 * bump_strength, 1.0, -(hz - h0) / e * 0.05 * bump_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
