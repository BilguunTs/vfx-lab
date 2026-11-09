// Lab test pattern: a grid of lines over a faint checker, for judging distortion effects.
// A bend is invisible on a flat colour and obvious on straight lines. Toggled with G in the lab.
shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color = vec3(0.13, 0.14, 0.15);
uniform vec3 line_color : source_color = vec3(0.5, 0.53, 0.55);
uniform float cell = 0.25;        // metres between lines
uniform float line_width = 0.08;  // fraction of a cell
// 0: lay the grid out in world XZ (floor). Otherwise: UV × this size in metres (a quad).
uniform vec2 quad_size = vec2(0.0);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (quad_size.x > 0.0 ? UV * quad_size : v_world.xz) / cell;
	vec2 d = abs(fract(p + 0.5) - 0.5);           // distance to the nearest line, in cells
	vec2 aa = fwidth(p);
	vec2 l = 1.0 - smoothstep(line_width * 0.5 - aa, line_width * 0.5 + aa, d);
	float line = max(l.x, l.y);
	vec2 c = floor(p);
	float checker = mod(c.x + c.y, 2.0);
	ALBEDO = mix(base_color * (0.8 + 0.4 * checker), line_color, line);
}
