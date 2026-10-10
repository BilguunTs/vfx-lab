// Dark stone shards. INSTANCE_CUSTOM.x carries a per-shard glow (0..1) that the
// script sets to 1 when the pulse touches the shard and lets decay.
shader_type spatial;

uniform vec3 stone_color : source_color = vec3(0.17, 0.16, 0.15);
uniform vec3 glow_color : source_color = vec3(0.72, 0.86, 0.8);
uniform float glow_intensity = 0.6;

varying float glow;

void vertex() {
	glow = INSTANCE_CUSTOM.x;
}

void fragment() {
	ALBEDO = stone_color;
	ROUGHNESS = 0.9;
	EMISSION = glow_color * glow_intensity * glow * glow;
}
