@tool
extends Node3D
## Scatters low-poly stones and a few boulders on the lab ground (deterministic: same seed,
## same layout). Static set dressing beyond the drum's debris field, so the ground has
## silhouettes and depth cues at a distance. Each rock shape is a sphere with its vertices
## pushed in and out, squashed and flat-shaded; a few shapes are reused through MultiMeshes.

@export var noise_seed := 3:
	set(v):
		noise_seed = v
		_rebuild()
@export_range(0, 1000) var stone_count := 160:
	set(v):
		stone_count = v
		_rebuild()
@export_range(0, 50) var boulder_count := 7:
	set(v):
		boulder_count = v
		_rebuild()
## Keeps stones out of the debris field and away from the drum.
@export_range(0.0, 20.0, 0.1, "suffix:m") var inner_radius := 5.5:
	set(v):
		inner_radius = v
		_rebuild()
@export_range(1.0, 60.0, 0.5, "suffix:m") var outer_radius := 18.0:
	set(v):
		outer_radius = v
		_rebuild()
@export var stone_color := Color(0.2, 0.19, 0.18):
	set(v):
		stone_color = v
		_rebuild()

const SHAPES := 4


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0

	var transforms: Array[Array] = []
	var colors: Array[Array] = []
	for i in SHAPES:
		transforms.append([])
		colors.append([])
	# Small stones: loosely clustered (stones gather; uniform scatter looks artificial).
	var clusters: Array[Vector2] = []
	for i in 12:
		clusters.append(_random_ring_point(rng, inner_radius, outer_radius))
	for i in stone_count:
		var p: Vector2
		if rng.randf() < 0.6:
			p = clusters[rng.randi() % clusters.size()] + Vector2(rng.randfn(0.0, 1.2), rng.randfn(0.0, 1.2))
		else:
			p = _random_ring_point(rng, inner_radius, outer_radius)
		if p.length() < inner_radius:
			continue
		var size := rng.randf_range(0.04, 0.16) * (1.0 + 2.0 * pow(rng.randf(), 6.0))
		_place(rng, transforms, colors, p, size)
	for i in boulder_count:
		var p := _random_ring_point(rng, inner_radius + 1.5, outer_radius)
		_place(rng, transforms, colors, p, rng.randf_range(0.35, 0.9))

	for shape in SHAPES:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _rock_mesh(noise_seed * 31 + shape)
		multimesh.instance_count = transforms[shape].size()
		for i in multimesh.instance_count:
			multimesh.set_instance_transform(i, transforms[shape][i])
			multimesh.set_instance_color(i, colors[shape][i])
		var view := MultiMeshInstance3D.new()
		view.multimesh = multimesh
		view.material_override = material
		add_child(view)


func _place(rng: RandomNumberGenerator, transforms: Array[Array], colors: Array[Array], p: Vector2, size: float) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU)
	basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
	basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.45, 0.8), rng.randf_range(0.8, 1.3)) * size)
	# Half buried: rocks sit in the ground, they don't rest on it.
	var origin := Vector3(p.x, -size * rng.randf_range(0.1, 0.35), p.y)
	var shape := rng.randi() % SHAPES
	transforms[shape].append(Transform3D(basis, origin))
	colors[shape].append(stone_color * rng.randf_range(0.75, 1.25))


## Uniform by area within the ring.
func _random_ring_point(rng: RandomNumberGenerator, r0: float, r1: float) -> Vector2:
	var r := sqrt(rng.randf_range(r0 * r0, r1 * r1))
	return Vector2.from_angle(rng.randf() * TAU) * r


func _rock_mesh(shape_seed: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Displacement keyed on the rounded position, so seam duplicates move together.
	for i in vertices.size():
		var v := vertices[i]
		var key := hash([shape_seed, roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)])
		var k := float(absi(key) % 10007) / 10007.0
		v *= 0.75 + 0.5 * k
		v.y = maxf(v.y, -0.15) # flat-ish underside
		vertices[i] = v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # flat shading: faceted, low-poly
	for index in indices:
		st.add_vertex(vertices[index])
	st.generate_normals()
	return st.commit()
