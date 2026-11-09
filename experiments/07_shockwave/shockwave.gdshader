// Shockwave — an expanding sphere of compressed air that bends what's behind it outward.
//
// Nothing is drawn: the shader re-samples the already-rendered screen with an offset. The
// sphere's front faces cover the wave's area on screen; the offset is strongest near the
// silhouette (where we look through the most compressed air, tangent to the shell) and pushes
// pixels away from the sphere's centre. A smaller inward lobe behind the front is the rebound,
// so the air wobbles once instead of just bulging.
//
// Godot's screen texture only holds opaque geometry. Where the offset is zero the shader is
// fully transparent, so transparent effects behind the sphere still show; inside the wave band
// they are replaced by the (distorted) opaque scene.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform float amplitude = 0.025;  // max offset, in screen-UV units (fraction of the screen)
uniform float front_width = 0.35; // width of the push band, as a fraction of the rim (0..1)
uniform float rebound = 0.35;     // inward lobe behind the front, relative to the push
uniform float edge_light = 0.0;   // faint brightening at the front (already faded by the script)
uniform float chroma = 0.0;       // colour split along the offset (0 = none)
uniform bool debug_tint = false;  // colour the bend: orange = pushed out, blue = pulled back

float lobe(float x, float center, float width) {
	float d = (x - center) / width;
	return exp(-d * d * 4.0);
}

void fragment() {
	// 0 looking straight through the sphere's middle, 1 at its silhouette.
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = sqrt(rim); // spread the profile more evenly across the projected disc

	float push = lobe(rim, 1.0 - front_width * 0.5, front_width * 0.5);
	float back = lobe(rim, 1.0 - front_width * 1.4, front_width * 0.6);
	float profile = push - rebound * back;
	// Fade to zero exactly at the silhouette, so the wave has no hard outer outline.
	profile *= 1.0 - smoothstep(0.93, 1.0, rim);

	// Direction: away from the sphere's centre as seen on screen.
	vec4 c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
	vec2 center_uv = c.xy / c.w * 0.5 + 0.5;
	vec2 dir = SCREEN_UV - center_uv;
	dir = length(dir) > 1e-5 ? normalize(dir) : vec2(0.0);
	// Sampling *closer* to the centre makes the image appear pushed outward.
	vec2 offset = -dir * profile * amplitude;

	vec3 col;
	if (chroma > 0.0) {
		col.r = textureLod(screen_tex, SCREEN_UV + offset * (1.0 + chroma), 0.0).r;
		col.g = textureLod(screen_tex, SCREEN_UV + offset, 0.0).g;
		col.b = textureLod(screen_tex, SCREEN_UV + offset * (1.0 - chroma), 0.0).b;
	} else {
		col = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;
	}
	ALBEDO = col * (1.0 + edge_light * push);
	// Only cover the screen where we actually bend it.
	ALPHA = clamp(abs(profile) * 6.0, 0.0, 1.0) * step(1e-5, amplitude);
	if (debug_tint) {
		vec3 tint = profile > 0.0 ? vec3(1.0, 0.45, 0.1) : vec3(0.15, 0.45, 1.0);
		ALBEDO = mix(ALBEDO, tint, clamp(abs(profile), 0.0, 1.0) * 0.6);
	}
}
