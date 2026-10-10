// A circle of procedural glyphs on the ground around the drum.
// Like the energy ring, this shader has no clock: the script drives the ignition
// front, heat, dissolve and rotation every frame.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shared/shaders/noise.gdshaderinc"

uniform vec3 hot_color : source_color = vec3(1.0, 0.68, 0.38);
uniform vec3 cool_color : source_color = vec3(0.42, 0.1, 0.05);
uniform float intensity = 2.0;

uniform float front_radius = 100.0; // strokes inside this radius are lit
uniform float impact_flash = 1.5;   // extra brightness right behind the front
uniform float flare_length = 0.8;   // metres behind the front before the flare settles
uniform float heat = 1.0;     // 1 = just struck (hot colour), 0 = cooled
uniform float dissolve = 0.0; // 0..1, burns the seal away

uniform float inner_radius = 0.85;
uniform float outer_radius = 1.45;
uniform float glyph_count = 14.0;
uniform float stroke_width = 0.04;
uniform float rotation = 0.0;
uniform float noise_seed = 0.0;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Distance to one glyph: a spine pointing away from the centre plus up to four
// slanted side strokes. Strokes are picked by hashing the cell index, so every
// glyph differs but the whole seal is fixed for a given seed.
float glyph_distance(vec2 g, float cell, float half_w, float half_h) {
	float d = segment_distance(g, vec2(0.0, -half_h), vec2(0.0, half_h));
	for (int k = 0; k < 4; k++) {
		float pick = hash21(vec2(cell, float(k) + noise_seed * 13.0));
		if (pick < 0.3) {
			continue;
		}
		float y = mix(-half_h, half_h, (float(k) + 0.5) / 4.0);
		float side = pick < 0.65 ? -1.0 : 1.0;
		vec2 start = vec2(0.0, y);
		vec2 tip = vec2(side * half_w, y - 0.35 * half_w);
		d = min(d, segment_distance(g, start, tip));
		if (pick > 0.9) {
			d = min(d, segment_distance(g, start, vec2(-tip.x, tip.y)));
		}
	}
	return d;
}

void fragment() {
	float r = length(local_xz);
	float angle = atan(local_xz.y, local_xz.x) + rotation;
	float cell_angle = TAU / glyph_count;
	float fa = (angle + PI) / cell_angle;
	float cell = mod(floor(fa), glyph_count);
	float mid_r = 0.5 * (inner_radius + outer_radius);
	float band = outer_radius - inner_radius;

	// Glyph space in metres: x runs along the circle, y points outward.
	vec2 g = vec2((fract(fa) - 0.5) * cell_angle * r, r - mid_r);
	float d = glyph_distance(g, cell, 0.28 * cell_angle * mid_r, 0.4 * band);

	// Uneven stroke width, like a brush stroke or a cut of varying depth.
	float width = stroke_width * (0.6 + 0.8 * value_noise(local_xz * 9.0 + noise_seed * 3.1));
	// Anti-alias with the pixel footprint of the continuous radius. fwidth(d) would blow up
	// where d jumps between glyph cells and smear faint lines along the cell borders.
	float aa = fwidth(r);
	float glyph = 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, d);

	// Ignition: lit where the front has passed. A small per-glyph offset keeps the glyphs
	// from igniting in perfect lockstep.
	float jitter = (hash21(vec2(cell, 91.0 + noise_seed)) - 0.5) * 0.12;
	float glyph_behind = front_radius - (r + jitter);
	glyph *= smoothstep(0.0, 0.04, glyph_behind);

	// Two worn border circles, broken where angular noise is low.
	vec2 dir = local_xz / max(r, 1e-4);
	float wear = value_noise(dir * 4.0 + noise_seed * 7.7);
	float border_d = min(abs(r - (inner_radius - 0.06)), abs(r - (outer_radius + 0.06)));
	float border = 1.0 - smoothstep(width * 0.35 - aa, width * 0.35 + aa, border_d);
	float behind = front_radius - r;
	border *= smoothstep(0.3, 0.45, wear) * smoothstep(0.0, 0.04, behind);

	float shape = max(glyph, border);
	// Strokes flare as the front passes over them, then settle.
	float flare = 1.0 + impact_flash * exp(-max(behind, 0.0) / max(flare_length * 0.35, 1e-3));

	// Burn-away: a fixed noise field. Everything below the dissolve threshold is gone,
	// and a thin hot edge runs just ahead of it.
	float n = 0.7 * value_noise(local_xz * 5.0 + noise_seed * 1.7) + 0.3 * value_noise(local_xz * 13.0);
	float alive = smoothstep(dissolve, dissolve + 0.02, n);
	float burn_edge = (1.0 - smoothstep(0.0, 0.08, n - dissolve)) * step(0.001, dissolve);

	vec3 color = mix(cool_color, hot_color, heat);
	ALBEDO = shape * alive * intensity * flare * (color + hot_color * burn_edge * 1.5);
}
