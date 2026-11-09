// Additive medium: fire. Adds light, never darkens what's behind it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://experiments/06_ghost_wrap/ghost_medium.gdshaderinc"
