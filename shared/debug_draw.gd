class_name DebugDraw
## Helpers for debug overlays: unlit, vertex-coloured lines drawn on top of everything.


## A MeshInstance3D that shows `mesh` as debug lines (hidden from shadows, ignores depth).
static func make_view(mesh: Mesh) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view


## Appends a horizontal circle (as its own line-strip surface) to `mesh`.
static func circle(mesh: ImmediateMesh, radius: float, color: Color, height := 0.03, segments := 96) -> void:
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_set_color(color)
	for i in segments + 1:
		var a := TAU * i / segments
		mesh.surface_add_vertex(Vector3(cos(a) * radius, height, sin(a) * radius))
	mesh.surface_end()
