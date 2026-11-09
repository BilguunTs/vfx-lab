// Ghost Wrap — velocity-aligned billboard for particles.
// The process material aligns each particle's Y axis to its velocity (particle_flag_align_y);
// this keeps that axis, scales by the particle size and turns the quad around it to face the
// camera. A quad taller than wide then reads as a streak along the motion.
mat4 velocity_billboard(mat4 model, vec3 camera_position) {
	vec3 pos = model[3].xyz;
	vec3 axis = model[1].xyz;
	float size = length(model[0].xyz);
	vec3 up = length(axis) > 1e-4 ? normalize(axis) : vec3(0.0, 1.0, 0.0);
	vec3 right = cross(up, normalize(camera_position - pos));
	right = length(right) > 1e-4 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	vec3 facing = cross(right, up);
	return mat4(vec4(right * size, 0.0), vec4(up * size, 0.0), vec4(facing * size, 0.0), vec4(pos, 1.0));
}
