// Alpha-blended medium: smoke, water, wind. Covers what's behind it.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://experiments/06_ghost_wrap/ghost_medium.gdshaderinc"
