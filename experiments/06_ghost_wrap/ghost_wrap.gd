extends Node3D
## Ghost Wrap — dissolves any set of meshes into smoke. Self-contained: knows nothing about its owner.
##
## Place this node at the body's root (feet at its origin, +Y up) and list the meshes in
## `targets`. One value drives everything; whoever owns the node animates it:
##   intensity 0   = the model as authored (original materials, no smoke)
##   intensity 0.5 = part solid, part smoke
##   intensity 1   = no body left, only smoke in its shape
##
## Transitions spread from `reveal_point` as a ragged sphere, in both directions:
##   leaving 0 (ghosting):  the area around the point dissolves first
##   leaving 1 (revealing): the area around the point turns solid first
## The direction and the point are latched when intensity leaves 0 or 1; reversing
## mid-transition runs the same front back, so nothing pops.
##
## Smoke is emitted from the parts that are currently dissolved, extra at the moving edge.
## Surface samples are taken in rebuild() (called on ready). They don't follow skinned animation.

const BODY_SHADER := preload("res://experiments/06_ghost_wrap/ghost_body.gdshader")
const SMOKE_SHADER := preload("res://experiments/06_ghost_wrap/ghost_smoke.gdshader")
const EMISSION_POINTS := 512 # smoke emission points, re-chosen as the front moves
const POOL_POINTS := 2048    # candidate surface samples they are chosen from

## Meshes to dissolve.
@export var targets: Array[MeshInstance3D] = []
## 0 = the model, 1 = only smoke. Animate this from outside.
@export_range(0.0, 1.0, 0.001) var intensity := 0.0
## Where transitions start. Read when intensity leaves 0 or 1.
## Empty = the bottom centre of the body (legs go first, like a ghost losing its feet).
@export var reveal_point: Node3D

@export_group("Dissolve")
@export var fade_enabled := true
## Width of the soft zone between solid and smoke, as a fraction of the body's extent
## measured from the reveal point.
@export_range(0.01, 1.0, 0.01) var edge_band := 0.2
## How far noise pushes the edge in/out (same units). 0 = perfect sphere.
@export_range(0.0, 0.5, 0.01) var edge_noise := 0.1
## Noise frequency per metre. Higher = finer, more tattered edge.
@export_range(0.5, 20.0, 0.1) var edge_noise_scale := 5.0
## How fast the edge pattern flows upward.
@export_range(0.0, 2.0, 0.01, "suffix:m/s") var edge_flow := 0.25
## Opacity of the solid part while any transition is under way (1 = fully opaque).
@export_range(0.0, 1.0, 0.01) var body_opacity := 1.0
## How much colour the solid part loses at full intensity.
@export_range(0.0, 1.0, 0.01) var desaturate := 0.5
@export var glow_color := Color(0.55, 0.8, 0.75)
## Fresnel rim along the silhouette.
@export_range(0.0, 2.0, 0.01) var rim_strength := 0.35
## Glow along the dissolving edge.
@export_range(0.0, 2.0, 0.01) var edge_glow := 0.2

@export_group("Smoke")
@export var smoke_enabled := true
## Particles alive at full intensity. Takes effect on rebuild().
@export_range(8, 2000, 1) var smoke_amount := 360
## Takes effect on rebuild().
@export_range(0.2, 8.0, 0.1, "suffix:s") var smoke_lifetime := 3.0
## Colour of thin / lit smoke.
@export var smoke_lit_color := Color(0.62, 0.7, 0.7)
## Colour of dense smoke in its own shadow.
@export var smoke_shadow_color := Color(0.16, 0.2, 0.22)
## Opacity of a single puff. Keep it low: smoke is many faint layers, not a few opaque ones.
@export_range(0.0, 1.0, 0.01) var smoke_opacity := 0.3
## Width of a puff at the end of its life (it is born at a quarter of this and grows).
@export_range(0.05, 3.0, 0.01, "suffix:m") var smoke_size := 0.9
## Height / width of a puff, stretched along its motion. 1 = round.
@export_range(1.0, 4.0, 0.05) var smoke_stretch := 1.7
## Buoyancy: upward acceleration.
@export_range(-1.0, 2.0, 0.01, "suffix:m/s²") var smoke_rise := 0.45
## Initial push away from the surface.
@export_range(0.0, 2.0, 0.01, "suffix:m/s") var smoke_push := 0.15
## Curling. Weak at birth (smooth, laminar), full strength later (turbulent). 0 = straight paths.
@export_range(0.0, 1.0, 0.01) var smoke_turbulence := 0.35
## How much more smoke comes off the moving edge than off fully dissolved areas.
@export_range(0.0, 10.0, 0.1) var edge_smoke := 2.0
## Same seed = same emission pattern. Pool takes effect on rebuild().
@export var emission_seed := 1

var _surfaces: Array[Dictionary] = [] # {mesh, surface, original, ghost}
var _swapped := false
var _bounds := AABB()              # body space
var _pool_pos := PackedVector3Array()
var _pool_nrm := PackedVector3Array()
var _emit_pos := PackedVector3Array() # currently chosen emission points (for debug)
var _emit_nrm := PackedVector3Array()
var _ghost_inside := true          # true: ghost grows from the point; false: solid grows from it
var _rest := 0                     # 0 or 1 while resting at that value, -1 mid-transition
var _origin := Vector3.ZERO        # latched reveal origin, body space
var _origin_name := "body base"
var _origin_reach := 1.0           # distance from origin to the farthest part of the body
var _last_front := NAN
var _time := 0.0                   # game time for shaders (TIME ignores Engine.time_scale)
var _particles: GPUParticles3D
var _process_mat: ParticleProcessMaterial
var _smoke_material: ShaderMaterial
var _point_image: Image
var _normal_image: Image
var _point_texture: ImageTexture
var _normal_texture: ImageTexture
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.visible = false
	add_child(_debug_view)
	rebuild()


## Re-measures the targets, rebuilds ghost materials and smoke. Call after changing targets.
func rebuild() -> void:
	_restore_materials()
	_surfaces.clear()
	for target in targets:
		if not target or not target.mesh:
			continue
		for s in target.mesh.get_surface_count():
			_surfaces.append({
				mesh = target, surface = s,
				original = target.get_surface_override_material(s),
				ghost = _make_ghost_material(target.get_active_material(s)),
			})
	_sample_surfaces()
	_build_smoke()
	_latch_origin()
	_last_front = NAN


## Removes all smoke immediately.
func clear_smoke() -> void:
	if _particles:
		_particles.restart()


func set_debug(enabled: bool) -> void:
	_debug_view.visible = enabled


func get_debug_text() -> String:
	return "GhostWrap: intensity %.2f   %s from %s   front %.2f   smoke rate %d/%d   %d emission points" % [
		intensity, "ghosting" if _ghost_inside else "revealing", _origin_name, _front(),
		int(smoke_amount * _particles.amount_ratio) if _particles else 0, smoke_amount, _emit_pos.size()]


func _process(delta: float) -> void:
	_time += delta
	# Leaving a rest state starts a transition: it runs from the reveal point as it is *now*,
	# ghosting when leaving 0, revealing when leaving 1. Mid-transition both stay fixed.
	if intensity <= 0.0005:
		_rest = 0
	elif intensity >= 0.9995:
		_rest = 1
	elif _rest != -1:
		_ghost_inside = _rest == 0
		_latch_origin()
		_rest = -1

	var fade_on := fade_enabled and intensity > 0.0005
	if fade_on != _swapped:
		if fade_on:
			_apply_materials()
		else:
			_restore_materials()
	if _swapped:
		_update_materials()
	_update_emission()
	_update_smoke()
	if _debug_view.visible:
		_draw_debug()


## Radius of the dissolve front, in units of _origin_reach. Matches the body shader.
## Ghosting: ghost inside the front, which grows from the origin. Revealing: solid inside it.
func _front() -> float:
	var span := 1.0 + edge_noise + edge_band
	if _ghost_inside:
		return lerpf(-edge_noise, span, intensity)
	return lerpf(span, -edge_noise, intensity)


## Visibility (1 = solid) at normalised distance d from the origin, without noise.
func _visibility(d: float, front: float) -> float:
	var s := smoothstep(front - edge_band, front, d)
	return s if _ghost_inside else 1.0 - s


func _latch_origin() -> void:
	if reveal_point and is_instance_valid(reveal_point):
		_origin = global_transform.affine_inverse() * reveal_point.global_position
		_origin_name = reveal_point.name
	else:
		_origin = Vector3(_bounds.get_center().x, _bounds.position.y, _bounds.get_center().z)
		_origin_name = "body base"
	_origin_reach = 0.01
	for i in 8:
		_origin_reach = maxf(_origin_reach, _origin.distance_to(_bounds.get_endpoint(i)))


func _make_ghost_material(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	if source is BaseMaterial3D:
		material.set_shader_parameter("albedo", source.albedo_color)
		material.set_shader_parameter("roughness", source.roughness)
		if source.albedo_texture:
			material.set_shader_parameter("albedo_tex", source.albedo_texture)
	return material


func _apply_materials() -> void:
	for entry in _surfaces:
		entry.mesh.set_surface_override_material(entry.surface, entry.ghost)
	_swapped = true


func _restore_materials() -> void:
	if not _swapped:
		return
	for entry in _surfaces:
		if is_instance_valid(entry.mesh):
			entry.mesh.set_surface_override_material(entry.surface, entry.original)
	_swapped = false


func _update_materials() -> void:
	var world_to_body := global_transform.affine_inverse()
	var front := _front()
	for entry in _surfaces:
		var m: ShaderMaterial = entry.ghost
		m.set_shader_parameter("world_to_body", world_to_body)
		m.set_shader_parameter("scaled_time", _time)
		m.set_shader_parameter("intensity", intensity)
		m.set_shader_parameter("reveal_origin", _origin)
		m.set_shader_parameter("reveal_reach", _origin_reach)
		m.set_shader_parameter("front", front)
		m.set_shader_parameter("ghost_inside", _ghost_inside)
		m.set_shader_parameter("edge_band", edge_band)
		m.set_shader_parameter("edge_noise", edge_noise)
		m.set_shader_parameter("edge_noise_scale", edge_noise_scale)
		m.set_shader_parameter("edge_flow", edge_flow)
		m.set_shader_parameter("body_opacity", body_opacity)
		m.set_shader_parameter("desaturate", desaturate)
		m.set_shader_parameter("glow_color", glow_color)
		m.set_shader_parameter("rim_strength", rim_strength)
		m.set_shader_parameter("edge_glow", edge_glow)


## Samples POOL_POINTS area-weighted points on the targets' triangles (in this node's space)
## and measures the body's bounds.
func _sample_surfaces() -> void:
	var corners := PackedVector3Array() # 3 per triangle
	var corner_normals := PackedVector3Array()
	var to_body := global_transform.affine_inverse()
	for target in targets:
		if not target or not target.mesh:
			continue
		var xf := to_body * target.global_transform
		for s in target.mesh.get_surface_count():
			var arrays := target.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if indices else verts.size()
			for i in count:
				var v: int = indices[i] if indices else i
				corners.append(xf * verts[v])
				corner_normals.append((xf.basis * normals[v]).normalized() if normals.size() > v else Vector3.UP)

	_pool_pos.clear()
	_pool_nrm.clear()
	if corners.is_empty():
		_bounds = AABB(Vector3.ZERO, Vector3.ONE)
		return
	_bounds = AABB(corners[0], Vector3.ZERO)
	for c in corners:
		_bounds = _bounds.expand(c)

	var cumulative := PackedFloat32Array()
	var total := 0.0
	for t in corners.size() / 3:
		var a := corners[t * 3]
		total += (corners[t * 3 + 1] - a).cross(corners[t * 3 + 2] - a).length() * 0.5
		cumulative.append(total)

	var rng := RandomNumberGenerator.new()
	rng.seed = emission_seed
	for i in POOL_POINTS:
		var t := mini(cumulative.bsearch(rng.randf() * total), cumulative.size() - 1)
		var u := rng.randf()
		var v := rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var a := corners[t * 3]
		_pool_pos.append(a + (corners[t * 3 + 1] - a) * u + (corners[t * 3 + 2] - a) * v)
		var na := corner_normals[t * 3]
		_pool_nrm.append((na + (corner_normals[t * 3 + 1] - na) * u + (corner_normals[t * 3 + 2] - na) * v).normalized())


## Re-chooses the emission points from the pool whenever the front moves: dissolved areas
## emit, the moving edge emits extra, solid areas emit nothing.
func _update_emission() -> void:
	if not _particles or _pool_pos.is_empty():
		return
	var front := _front()
	if absf(front - _last_front) < 0.002:
		return
	_last_front = front

	var cumulative := PackedFloat32Array()
	cumulative.resize(_pool_pos.size())
	var total := 0.0
	for i in _pool_pos.size():
		var vis := _visibility(_pool_pos[i].distance_to(_origin) / _origin_reach, front)
		total += (1.0 - vis) + edge_smoke * 4.0 * vis * (1.0 - vis)
		cumulative[i] = total
	if total <= 0.0001:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = emission_seed
	_emit_pos.resize(EMISSION_POINTS)
	_emit_nrm.resize(EMISSION_POINTS)
	for i in EMISSION_POINTS:
		var k := mini(cumulative.bsearch(rng.randf() * total), _pool_pos.size() - 1)
		var p := _pool_pos[k]
		var n := _pool_nrm[k]
		_emit_pos[i] = p
		_emit_nrm[i] = n
		_point_image.set_pixel(i, 0, Color(p.x, p.y, p.z))
		_normal_image.set_pixel(i, 0, Color(n.x, n.y, n.z))
	_point_texture.update(_point_image)
	_normal_texture.update(_normal_image)


func _build_smoke() -> void:
	if _particles:
		_particles.queue_free()
		_particles = null
	if _pool_pos.is_empty():
		return

	_point_image = Image.create(EMISSION_POINTS, 1, false, Image.FORMAT_RGBF)
	_normal_image = Image.create(EMISSION_POINTS, 1, false, Image.FORMAT_RGBF)
	_point_texture = ImageTexture.create_from_image(_point_image)
	_normal_texture = ImageTexture.create_from_image(_normal_image)

	_process_mat = ParticleProcessMaterial.new()
	_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	_process_mat.emission_point_texture = _point_texture
	_process_mat.emission_normal_texture = _normal_texture
	_process_mat.emission_point_count = EMISSION_POINTS
	_process_mat.spread = 25.0
	_process_mat.damping_min = 0.3
	_process_mat.damping_max = 0.6
	# The particle's Y axis follows its velocity; the shader stretches the quad along it.
	_process_mat.particle_flag_align_y = true
	_process_mat.scale_min = 0.7
	_process_mat.scale_max = 1.0
	# Entrainment: a plume widens as it rises. Born at 25 % size, grows ~4x.
	_process_mat.scale_curve = _curve_texture([Vector2(0.0, 0.25), Vector2(1.0, 1.0)], 1.2)
	# Opacity over life: quick appear, long dispersal. (The shader also thins the density.)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_process_mat.color_ramp = fade_texture
	# Laminar -> turbulent: smooth near the body, churning higher up.
	_process_mat.turbulence_enabled = true
	_process_mat.turbulence_noise_strength = 1.0
	_process_mat.turbulence_noise_scale = 2.0
	_process_mat.turbulence_noise_speed = Vector3(0.0, 0.25, 0.0)
	_process_mat.turbulence_influence_over_life = _curve_texture([Vector2(0.0, 0.1), Vector2(0.5, 1.0), Vector2(1.0, 1.0)])

	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = SMOKE_SHADER
	var quad := QuadMesh.new()
	quad.material = _smoke_material

	_particles = GPUParticles3D.new()
	_particles.name = "Smoke"
	_particles.amount = smoke_amount
	_particles.lifetime = smoke_lifetime
	_particles.local_coords = false
	_particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_particles.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, _bounds.size.y + 4.0, 6.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.process_material = _process_mat
	_particles.draw_pass_1 = quad
	_particles.amount_ratio = 0.0
	add_child(_particles)
	_update_smoke()


func _update_smoke() -> void:
	if not _particles:
		return
	_particles.emitting = smoke_enabled
	_particles.amount_ratio = intensity
	_process_mat.initial_velocity_min = smoke_push * 0.4
	_process_mat.initial_velocity_max = smoke_push
	_process_mat.gravity = Vector3(0.0, smoke_rise, 0.0)
	_process_mat.turbulence_influence_min = smoke_turbulence * 0.5
	_process_mat.turbulence_influence_max = smoke_turbulence
	(_particles.draw_pass_1 as QuadMesh).size = Vector2(smoke_size, smoke_size * smoke_stretch)
	_smoke_material.set_shader_parameter("lit_color", smoke_lit_color)
	_smoke_material.set_shader_parameter("shadow_color", smoke_shadow_color)
	_smoke_material.set_shader_parameter("opacity", smoke_opacity)
	_smoke_material.set_shader_parameter("scaled_time", _time)


func _curve_texture(points: Array[Vector2], end_tangent := 0.0) -> CurveTexture:
	var curve := Curve.new()
	for p in points:
		curve.add_point(p)
	if end_tangent != 0.0:
		curve.set_point_left_tangent(curve.point_count - 1, end_tangent)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


## Debug: current emission points with push direction (cyan), the reveal origin (white cross),
## and the dissolve front as three great circles (yellow).
func _draw_debug() -> void:
	_debug_mesh.clear_surfaces()
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_debug_mesh.surface_set_color(Color(0.4, 1.0, 0.85))
	if intensity > 0.0005:
		for i in _emit_pos.size():
			_debug_mesh.surface_add_vertex(_emit_pos[i])
			_debug_mesh.surface_add_vertex(_emit_pos[i] + _emit_nrm[i] * 0.08)
	_debug_mesh.surface_set_color(Color.WHITE)
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_debug_mesh.surface_add_vertex(_origin - axis * 0.1)
		_debug_mesh.surface_add_vertex(_origin + axis * 0.1)
	var radius := maxf(_front() - edge_band * 0.5, 0.0) * _origin_reach
	if radius > 0.0:
		_debug_mesh.surface_set_color(Color(1.0, 0.85, 0.3))
		var planes := [[Vector3.RIGHT, Vector3.UP], [Vector3.RIGHT, Vector3.BACK], [Vector3.UP, Vector3.BACK]]
		for plane in planes:
			for s in 48:
				var a0 := TAU * s / 48.0
				var a1 := TAU * (s + 1) / 48.0
				_debug_mesh.surface_add_vertex(_origin + (plane[0] * cos(a0) + plane[1] * sin(a0)) * radius)
				_debug_mesh.surface_add_vertex(_origin + (plane[0] * cos(a1) + plane[1] * sin(a1)) * radius)
	_debug_mesh.surface_end()
