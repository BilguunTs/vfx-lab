extends Node3D
## Ghost Wrap — dissolves any set of meshes into a medium (smoke, fire, water, wind...).
## Self-contained: knows nothing about its owner.
##
## Place this node at the body's root (feet at its origin, +Y up) and list the meshes in
## `targets`. One value drives everything; whoever owns the node animates it:
##   intensity 0   = the model as authored (original materials, no particles)
##   intensity 0.5 = part solid, part medium
##   intensity 1   = no body left, only the medium in its shape (or a blob, if enabled)
##
## `element` (a GhostElement resource, see elements/) decides what the medium looks like and how
## it moves. Swap it at any time; empty = the default smoke.
##
## Transitions spread from `reveal_point` as a ragged sphere, in both directions:
##   leaving 0 (ghosting):  the area around the point dissolves first
##   leaving 1 (revealing): the area around the point turns solid first
## The direction and the point are latched when intensity leaves 0 or 1; reversing
## mid-transition runs the same front back, so nothing pops.
##
## Particles are emitted from the parts that are currently dissolved, extra at the moving edge.
## Surface samples are taken in rebuild() (called on ready). They don't follow skinned animation.

const BODY_SHADER := preload("res://experiments/06_ghost_wrap/ghost_body.gdshader")
const MEDIUM_MIX_SHADER := preload("res://experiments/06_ghost_wrap/ghost_medium_mix.gdshader")
const MEDIUM_ADD_SHADER := preload("res://experiments/06_ghost_wrap/ghost_medium_add.gdshader")
const EMISSION_POINTS := 512 # emission points, re-chosen as the front moves
const POOL_POINTS := 2048    # candidate surface samples they are chosen from
const SWIRL_RES := 16        # resolution of the blob's swirl vector field

## Meshes to dissolve.
@export var targets: Array[MeshInstance3D] = []
## 0 = the model, 1 = only the medium. Animate this from outside.
@export_range(0.0, 1.0, 0.001) var intensity := 0.0
## What the body dissolves into. Empty = default smoke.
@export var element: GhostElement
## Where transitions start. Read when intensity leaves 0 or 1.
## Empty = the bottom centre of the body (legs go first, like a ghost losing its feet).
@export var reveal_point: Node3D

@export_group("Dissolve")
@export var fade_enabled := true
## Width of the soft zone between solid and medium, as a fraction of the body's extent
## measured from the reveal point.
@export_range(0.01, 1.0, 0.01) var edge_band := 0.2
## How far noise pushes the edge in/out (same units). 0 = perfect sphere.
@export_range(0.0, 0.5, 0.01) var edge_noise := 0.1
## Noise frequency per metre. Higher = finer, more tattered edge.
@export_range(0.5, 20.0, 0.1) var edge_noise_scale := 5.0
## Opacity of the solid part while any transition is under way (1 = fully opaque).
@export_range(0.0, 1.0, 0.01) var body_opacity := 1.0
## How much colour the solid part loses at full intensity.
@export_range(0.0, 1.0, 0.01) var desaturate := 0.5

@export_group("Emission")
@export var particles_enabled := true
## How much more comes off the moving edge than off fully dissolved areas.
@export_range(0.0, 10.0, 0.1) var edge_smoke := 2.0
## Same seed = same emission pattern. Pool takes effect on rebuild().
@export var emission_seed := 1
## World height of the floor, for elements that collide with it (water).
@export var floor_height := 0.0

@export_group("Blob")
## Near full intensity, gather the medium into a sphere instead of the body's shape.
## How it behaves there (pull, swirl, drag) comes from the element.
@export var blob_enabled := false
## Where the blob forms. Empty = chest height (62 % of the body) above the body's centre.
@export var blob_center: Node3D
@export_range(0.05, 3.0, 0.01, "suffix:m") var blob_radius := 0.45
## Intensity where the medium starts moving from the body onto the sphere (done at 1).
@export_range(0.0, 0.99, 0.01) var blob_start := 0.7

var _surfaces: Array[Dictionary] = [] # {mesh, surface, original, ghost}
var _swapped := false
var _bounds := AABB()              # body space
var _pool_pos := PackedVector3Array()
var _pool_nrm := PackedVector3Array()
var _emit_pos := PackedVector3Array() # currently chosen emission points (for debug)
var _emit_nrm := PackedVector3Array()
var _ghost_inside := true          # true: medium grows from the point; false: solid grows from it
var _rest := 0                     # 0 or 1 while resting at that value, -1 mid-transition
var _origin := Vector3.ZERO        # latched reveal origin, body space
var _origin_name := "body base"
var _origin_reach := 1.0           # distance from origin to the farthest part of the body
var _last_emission_key := Vector2(NAN, NAN) # (front, blob) the emission points were chosen for
var _time := 0.0                   # game time for shaders (TIME ignores Engine.time_scale)
var _default_element := GhostElement.new()
var _built_element: GhostElement   # element the particles were built for
var _particles: GPUParticles3D
var _process_mat: ParticleProcessMaterial
var _medium_material: ShaderMaterial
var _attractor: GPUParticlesAttractorSphere3D
var _swirl: GPUParticlesAttractorVectorField3D
var _floor: GPUParticlesCollisionBox3D
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
	_build_helpers()
	rebuild()


## Re-measures the targets, rebuilds ghost materials and particles. Call after changing targets.
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
	_build_particles()
	_latch_origin()


## Removes all particles immediately.
func clear_smoke() -> void:
	if _particles:
		_particles.restart()


func set_debug(enabled: bool) -> void:
	_debug_view.visible = enabled


func get_debug_text() -> String:
	var el := _element()
	return "GhostWrap: %s   intensity %.2f   %s from %s   front %.2f   blob %.2f   particles %d/%d" % [
		el.display_name, intensity, "ghosting" if _ghost_inside else "revealing", _origin_name,
		_front(), _blob_amount(), int(el.amount * _particles.amount_ratio) if _particles else 0, el.amount]


func _element() -> GhostElement:
	return element if element else _default_element


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

	if _element() != _built_element:
		_build_particles() # amount, lifetime and blend mode need a new particle system

	var fade_on := fade_enabled and intensity > 0.0005
	if fade_on != _swapped:
		if fade_on:
			_apply_materials()
		else:
			_restore_materials()
	if _swapped:
		_update_materials()
	_update_emission()
	_update_particles()
	if _debug_view.visible:
		_draw_debug()


## Radius of the dissolve front, in units of _origin_reach. Matches the body shader.
## Ghosting: medium inside the front, which grows from the origin. Revealing: solid inside it.
func _front() -> float:
	var span := 1.0 + edge_noise + edge_band
	if _ghost_inside:
		return lerpf(-edge_noise, span, intensity)
	return lerpf(span, -edge_noise, intensity)


## Visibility (1 = solid) at normalised distance d from the origin, without noise.
func _visibility(d: float, front: float) -> float:
	var s := smoothstep(front - edge_band, front, d)
	return s if _ghost_inside else 1.0 - s


## 0 = medium in the body's shape, 1 = medium gathered into the blob sphere.
func _blob_amount() -> float:
	return smoothstep(blob_start, 1.0, intensity) if blob_enabled else 0.0


## Blob centre in body space.
func _blob_center_local() -> Vector3:
	if blob_center and is_instance_valid(blob_center):
		return global_transform.affine_inverse() * blob_center.global_position
	var c := _bounds.get_center()
	return Vector3(c.x, _bounds.position.y + _bounds.size.y * 0.62, c.z)


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
	var el := _element()
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
		m.set_shader_parameter("edge_flow", el.edge_flow)
		m.set_shader_parameter("body_opacity", body_opacity)
		m.set_shader_parameter("desaturate", desaturate)
		m.set_shader_parameter("glow_color", el.glow_color)
		m.set_shader_parameter("rim_strength", el.rim_strength)
		m.set_shader_parameter("edge_glow", el.edge_glow)
		m.set_shader_parameter("scorch_color", el.scorch_color)
		m.set_shader_parameter("scorch_width", el.scorch_width)


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
## emit, the moving edge emits extra, solid areas emit nothing. With the blob forming, each
## point slides from the body surface toward its own point inside the blob sphere.
func _update_emission() -> void:
	if not _particles or _pool_pos.is_empty():
		return
	var front := _front()
	var blob := _blob_amount()
	var key := Vector2(front, blob)
	if absf(key.x - _last_emission_key.x) < 0.002 and absf(key.y - _last_emission_key.y) < 0.002:
		return
	_last_emission_key = key
	var center := _blob_center_local()

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
		# Always draw the sphere direction, so the selection stays identical with the blob off.
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if blob > 0.0:
			p = p.lerp(center + dir * blob_radius * sqrt(rng.randf()), blob)
			n = n.lerp(dir, blob).normalized()
		_emit_pos[i] = p
		_emit_nrm[i] = n
		_point_image.set_pixel(i, 0, Color(p.x, p.y, p.z))
		_normal_image.set_pixel(i, 0, Color(n.x, n.y, n.z))
	_point_texture.update(_point_image)
	_normal_texture.update(_normal_image)


## Nodes that don't depend on the element: emission textures, blob attractors, floor collider.
func _build_helpers() -> void:
	_point_image = Image.create(EMISSION_POINTS, 1, false, Image.FORMAT_RGBF)
	_normal_image = Image.create(EMISSION_POINTS, 1, false, Image.FORMAT_RGBF)
	_point_texture = ImageTexture.create_from_image(_point_image)
	_normal_texture = ImageTexture.create_from_image(_normal_image)

	# Pulls puffs toward the blob centre.
	_attractor = GPUParticlesAttractorSphere3D.new()
	_attractor.name = "BlobAttractor"
	_attractor.directionality = 0.0
	_attractor.attenuation = 0.6
	_attractor.strength = 0.0
	add_child(_attractor)

	# Turns them around the blob's vertical axis (a whirlwind), drifting slightly inward.
	# Vector field textures store each vector as v * 0.5 + 0.5, with +Y pointing down in texture space.
	var layers: Array[Image] = []
	for z in SWIRL_RES:
		var layer := Image.create(SWIRL_RES, SWIRL_RES, false, Image.FORMAT_RGBF)
		for y in SWIRL_RES:
			for x in SWIRL_RES:
				var p := Vector3(x, y, z) / float(SWIRL_RES - 1) * 2.0 - Vector3.ONE # -1..1
				var flat := Vector3(p.x, 0.0, p.z)
				var v := Vector3.ZERO
				if flat.length() > 0.001:
					v = Vector3.UP.cross(flat).normalized() - flat * 0.3
					v *= clampf(flat.length() * 2.0, 0.0, 1.0)
				v.y = -v.y # texture space
				v = v.limit_length(1.0)
				layer.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5))
		layers.append(layer)
	var field := ImageTexture3D.new()
	field.create(Image.FORMAT_RGBF, SWIRL_RES, SWIRL_RES, SWIRL_RES, false, layers)
	_swirl = GPUParticlesAttractorVectorField3D.new()
	_swirl.name = "BlobSwirl"
	_swirl.texture = field
	_swirl.strength = 0.0
	add_child(_swirl)

	# A wide box whose top is the floor; follows the body sideways (top_level, world space).
	_floor = GPUParticlesCollisionBox3D.new()
	_floor.name = "FloorCollision"
	_floor.top_level = true
	_floor.size = Vector3(16.0, 1.0, 16.0)
	add_child(_floor)


## The particle system for the current element. Rebuilt when the element changes.
func _build_particles() -> void:
	var el := _element()
	_built_element = el
	_last_emission_key = Vector2(NAN, NAN)
	if _particles:
		_particles.queue_free()
		_particles = null
	if _pool_pos.is_empty():
		return

	_process_mat = ParticleProcessMaterial.new()
	_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	_process_mat.emission_point_texture = _point_texture
	_process_mat.emission_normal_texture = _normal_texture
	_process_mat.emission_point_count = EMISSION_POINTS
	# The particle's Y axis follows its velocity; the shader stretches the quad along it.
	_process_mat.particle_flag_align_y = true
	_process_mat.scale_min = 0.7
	_process_mat.scale_max = 1.0
	# Growth over life (smoke: entrainment, ~4x; droplets: barely).
	_process_mat.scale_curve = _curve_texture([Vector2(0.0, el.birth_scale), Vector2(1.0, 1.0)], 1.2)
	var ramp := el.color_over_life
	if not ramp:
		ramp = Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.5, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	ramp_texture.use_hdr = true
	_process_mat.color_ramp = ramp_texture
	# Laminar -> turbulent: smooth near the body, churning later.
	_process_mat.turbulence_enabled = true
	_process_mat.turbulence_noise_strength = 1.0
	_process_mat.turbulence_noise_speed = Vector3(0.0, 0.25, 0.0)
	_process_mat.turbulence_influence_over_life = _curve_texture([Vector2(0.0, 0.1), Vector2(0.5, 1.0), Vector2(1.0, 1.0)])
	if el.collide_with_floor:
		_process_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		_process_mat.collision_bounce = el.bounce
		_process_mat.collision_friction = el.friction

	_medium_material = ShaderMaterial.new()
	_medium_material.shader = MEDIUM_ADD_SHADER if el.additive else MEDIUM_MIX_SHADER
	var quad := QuadMesh.new()
	quad.material = _medium_material

	_particles = GPUParticles3D.new()
	_particles.name = "Medium"
	_particles.amount = el.amount
	_particles.lifetime = el.lifetime
	_particles.local_coords = false
	_particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	_particles.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, _bounds.size.y + 5.0, 8.0))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.collision_base_size = el.size * el.birth_scale * 0.5
	_particles.process_material = _process_mat
	_particles.draw_pass_1 = quad
	_particles.amount_ratio = 0.0
	add_child(_particles)
	_update_particles()


func _update_particles() -> void:
	if not _particles:
		return
	var el := _element()
	var blob := _blob_amount()
	_particles.emitting = particles_enabled
	_particles.amount_ratio = intensity
	# Blob puffs are born inside the sphere: no outward push, so the pull and swirl alone set
	# their motion (otherwise stretched media draw radial petals before the swirl takes over).
	_process_mat.initial_velocity_min = el.push * 0.4 * (1.0 - blob)
	_process_mat.initial_velocity_max = el.push * (1.0 - blob)
	_process_mat.spread = el.spread
	_process_mat.gravity = el.gravity.lerp(el.blob_gravity, blob)
	_process_mat.turbulence_noise_scale = el.turbulence_scale
	_process_mat.turbulence_influence_min = el.turbulence * 0.5
	_process_mat.turbulence_influence_max = el.turbulence
	# In the blob, puffs swing through the centre: velocity stretch would turn every swing into a
	# radial streak, and low drag keeps them overshooting. Round puffs (element's blob_stretch)
	# + high drag = a churning orb.
	_process_mat.damping_min = lerpf(el.damping * 0.7, el.blob_damping * 0.75, blob * blob)
	_process_mat.damping_max = lerpf(el.damping, el.blob_damping, blob * blob)
	var size := el.size * lerpf(1.0, el.blob_puff_scale, blob)
	(_particles.draw_pass_1 as QuadMesh).size = Vector2(size, size * lerpf(el.stretch, el.blob_stretch, blob))

	var m := _medium_material
	m.set_shader_parameter("lit_color", el.lit_color)
	m.set_shader_parameter("shadow_color", el.shadow_color)
	m.set_shader_parameter("opacity", el.opacity)
	m.set_shader_parameter("field_scale", el.field_scale)
	m.set_shader_parameter("field_flow", el.field_flow)
	m.set_shader_parameter("warp", el.warp)
	m.set_shader_parameter("thin_start", el.thin_start)
	m.set_shader_parameter("thin_end", el.thin_end)
	m.set_shader_parameter("softness", el.softness)
	m.set_shader_parameter("shade_contrast", el.shade_contrast)
	m.set_shader_parameter("scaled_time", _time)

	var center := _blob_center_local()
	_attractor.position = center
	_attractor.radius = blob_radius * 3.0
	_attractor.strength = el.blob_pull * blob
	_swirl.position = center
	_swirl.size = Vector3.ONE * blob_radius * 4.0
	_swirl.strength = el.blob_swirl * blob
	var g := global_position
	_floor.global_position = Vector3(g.x, floor_height - _floor.size.y * 0.5, g.z)


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
## the dissolve front as three great circles (yellow), and the blob sphere (violet) when forming.
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
		_draw_sphere(_origin, radius, Color(1.0, 0.85, 0.3))
	if _blob_amount() > 0.0:
		_draw_sphere(_blob_center_local(), blob_radius, Color(0.75, 0.55, 1.0))
	_debug_mesh.surface_end()


func _draw_sphere(center: Vector3, radius: float, color: Color) -> void:
	_debug_mesh.surface_set_color(color)
	for plane in [[Vector3.RIGHT, Vector3.UP], [Vector3.RIGHT, Vector3.BACK], [Vector3.UP, Vector3.BACK]]:
		for s in 48:
			var a0 := TAU * s / 48.0
			var a1 := TAU * (s + 1) / 48.0
			_debug_mesh.surface_add_vertex(center + (plane[0] * cos(a0) + plane[1] * sin(a0)) * radius)
			_debug_mesh.surface_add_vertex(center + (plane[0] * cos(a1) + plane[1] * sin(a1)) * radius)
