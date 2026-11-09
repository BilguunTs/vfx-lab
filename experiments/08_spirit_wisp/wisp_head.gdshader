// Spirit Wisp — the head: a camera-facing soft glow. A small hot core inside a wide, faint
// halo; the halo is what makes it read as light in air rather than a dot.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.62, 0.9, 0.82);
uniform float intensity = 1.6;

void vertex() {
	// Billboard, keeping the node's scale.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * size, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * size, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * size, 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = exp(-r * r * 30.0);
	float halo = exp(-r * r * 4.0) * (1.0 - smoothstep(0.7, 1.0, r));
	// Core goes towards white: very bright light desaturates.
	vec3 c = color * (halo * 0.35 + core) + vec3(core * 0.5);
	ALBEDO = c * intensity;
}
