extends Node3D
## Drum strike layer (Phase D): loose stone shards around the drum that the pulse
## physically kicks as its front passes over them.
##
## Simulated on the CPU on purpose: each shard rests until the ring's front reaches it,
## then hops outward, tumbles, bounces and settles. ~70 shards of simple ballistic motion
## is cheap in GDScript and much easier to direct than a physics engine.
##
## The field is persistent: it exists once, and every strike adds a *push* (that strike's
## pulse ring) with add_push(). Several pushes can travel at once — overlapping strikes
## each kick the stones. Shards stay where they land; reset() puts them back.

const SHARD_SHADER := preload("res://experiments/05_drum_strike/debris_shard.gdshader")
const SETTLE_SPEED := 1.0 # landing slower than this (m/s) stops instead of bouncing

@export_group("Field")
@export_range(1, 300) var shard_count := 70
@export_range(0.5, 10.0, 0.05, "suffix:m") var inner_radius := 1.7
@export_range(0.5, 12.0, 0.05, "suffix:m") var outer_radius := 5.5
@export_range(0.02, 0.5, 0.005, "suffix:m") var min_size := 0.05
@export_range(0.02, 0.5, 0.005, "suffix:m") var max_size := 0.2

@export_group("Push")
## For standalone use with play(): layer whose expanding front kicks the shards.
## Needs get_front_radius(). (DrumStrike passes each strike's ring to add_push() instead.)
@export var push_source: Node3D
## Front speed used when there is no active push source.
@export_range(0.5, 30.0, 0.5, "suffix:m/s") var fallback_front_speed := 8.0
## Launch speed of a shard at the inner edge of the field.
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var launch_speed := 3.2
## Distance over which the push fades (the wave's energy spreads as it grows).
@export_range(0.5, 20.0, 0.1, "suffix:m") var falloff_distance := 3.0
## Higher feels heavier and snappier; Earth is 9.8.
@export_range(1.0, 30.0, 0.5, "suffix:m/s²") var gravity := 14.0
## Fraction of vertical speed kept on each bounce.
@export_range(0.0, 0.9, 0.01) var bounce := 0.3

@export_group("Look")
@export var stone_color := Color(0.17, 0.16, 0.15)
@export var glow_color := Color(0.72, 0.86, 0.8)
## Brief glow where the pulse touches a shard. 0 = none.
@export_range(0.0, 8.0, 0.05) var glow_intensity := 0.6
@export_range(0.05, 3.0, 0.05, "suffix:s") var glow_time := 0.25

@export_group("Variation")
## Picks the scatter, shard shapes and launch jitter.
@export var noise_seed := 11

var _pushes: Array[Dictionary] = [] # active pushes, see add_push()
var _debug := false
var _strength := 1.0
var _seed_offset := 0
var _rng := RandomNumberGenerator.new()

# Per-shard state.
var _start_pos := PackedVector3Array()
var _start_rot: Array[Quaternion] = []
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _spin := PackedVector3Array() # angular velocity, rad/s around its own direction
var _rot: Array[Quaternion] = []
var _scale := PackedVector3Array()
var _ground := PackedFloat32Array() # resting height of each shard's centre
var _glow := PackedFloat32Array()
var _airborne := PackedByteArray()

var _multimesh := MultiMesh.new()
var _material := ShaderMaterial.new()
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	_material.shader = SHARD_SHADER
	var shard_mesh := _build_shard_mesh()
	shard_mesh.surface_set_material(0, _material)
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = shard_mesh
	var view := MultiMeshInstance3D.new()
	view.multimesh = _multimesh
	add_child(view)

	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.visible = false
	add_child(_debug_view)

	_rng.seed = noise_seed + 7
	_scatter()
	reset()


func play() -> void:
	add_push(push_source)


## Starts a push from `source`'s expanding front (get_front_radius()). With no source
## (e.g. the ring is muted), a front sweeps out at fallback_front_speed instead.
func add_push(source: Node3D) -> void:
	_apply_look()
	var hit := PackedByteArray()
	hit.resize(_pos.size())
	_pushes.append({
		"source": source,
		"fallback": source == null,
		"hit": hit,
		"elapsed": 0.0,
		"started": false,
		"strength": _strength,
	})


func reset() -> void:
	_pushes.clear()
	_restore()


func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)


## A different variation is a different scatter of shards.
func set_variation(index: int) -> void:
	if index * 101 != _seed_offset:
		_seed_offset = index * 101
		_scatter()
		_restore()


func set_debug(enabled: bool) -> void:
	_debug = enabled
	_debug_view.visible = enabled
	_debug_mesh.clear_surfaces()
	DebugDraw.circle(_debug_mesh, inner_radius, Color(0.6, 0.6, 0.6))
	DebugDraw.circle(_debug_mesh, outer_radius, Color(0.6, 0.6, 0.6))


func is_active() -> bool:
	return not _pushes.is_empty() or _airborne.has(1)


func get_debug_text() -> String:
	var airborne := 0
	for i in _pos.size():
		airborne += _airborne[i]
	return "%s: %d shards   airborne %d   pushes travelling %d" % [
		name, _pos.size(), airborne, _pushes.size()]


func _process(delta: float) -> void:
	for push in _pushes.duplicate():
		push.elapsed += delta
		var front := _push_front(push)
		if front >= 0.0:
			push.started = true
			var hit: PackedByteArray = push.hit
			for i in _pos.size():
				if not hit[i] and Vector2(_pos[i].x, _pos[i].z).length() <= front:
					hit[i] = 1
					_launch(i, push.strength)
			push.hit = hit
		if _push_done(push, front):
			_pushes.erase(push)
	_simulate(delta)


## Front radius of a push this frame, or -1 while it hasn't started / has finished.
func _push_front(push: Dictionary) -> float:
	if push.fallback:
		return push.elapsed * fallback_front_speed
	var source = push.source
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return -1.0
	return source.get_front_radius()


func _push_done(push: Dictionary, front: float) -> bool:
	if push.fallback:
		return front > outer_radius + 0.5
	if not is_instance_valid(push.source):
		return true
	# A ring reports -1 both before its delay and after it ends; only the latter is "done".
	return push.started and front < 0.0


func _launch(i: int, strength: float) -> void:
	_airborne[i] = 1
	_glow[i] = 1.0
	var p := _pos[i]
	var distance := Vector2(p.x, p.z).length()
	var outward := Vector3(p.x, 0.0, p.z) / maxf(distance, 0.001)
	outward = outward.rotated(Vector3.UP, _rng.randf_range(-0.3, 0.3))
	# The push weakens with distance; small shards fly further than big ones.
	var energy := exp(-maxf(distance - inner_radius, 0.0) / falloff_distance) * pow(strength, 0.7)
	var size_t := inverse_lerp(min_size, max_size, _scale[i].x)
	var speed := launch_speed * energy * lerpf(1.3, 0.7, clampf(size_t, 0.0, 1.0))
	_vel[i] = outward * speed * _rng.randf_range(0.6, 1.0) + Vector3.UP * speed * _rng.randf_range(0.7, 1.2)
	var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	_spin[i] = axis.normalized() * speed * _rng.randf_range(4.0, 10.0)


func _simulate(delta: float) -> void:
	for i in _pos.size():
		if _glow[i] > 0.0:
			_glow[i] = maxf(_glow[i] - delta / glow_time, 0.0)
		if _airborne[i]:
			_vel[i].y -= gravity * delta
			_pos[i] += _vel[i] * delta
			var w := _spin[i]
			if w.length_squared() > 0.0:
				_rot[i] = (Quaternion(w.normalized(), w.length() * delta) * _rot[i]).normalized()
			if _pos[i].y <= _ground[i] and _vel[i].y < 0.0:
				_pos[i].y = _ground[i]
				if -_vel[i].y > SETTLE_SPEED:
					_vel[i] = Vector3(_vel[i].x * 0.5, -_vel[i].y * bounce, _vel[i].z * 0.5)
					_spin[i] *= 0.5
				else:
					_vel[i] = Vector3.ZERO
					_spin[i] = Vector3.ZERO
					_airborne[i] = 0
		_write_instance(i)


func _write_instance(i: int) -> void:
	var basis := Basis(_rot[i]) * Basis.from_scale(_scale[i])
	_multimesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
	_multimesh.set_instance_custom_data(i, Color(_glow[i], 0.0, 0.0, 0.0))


## Lays out the shards: random positions in the ring between inner and outer radius
## (uniform by area), random size, flattened proportions, random yaw and slight tilt.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + _seed_offset
	var n := shard_count
	_multimesh.instance_count = n
	_start_pos.resize(n)
	_start_rot.resize(n)
	_scale.resize(n)
	_ground.resize(n)
	for i in n:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner_radius * inner_radius, outer_radius * outer_radius))
		var size := lerpf(min_size, max_size, pow(rng.randf(), 2.0)) # mostly small, a few big
		_scale[i] = Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.4, 0.8), size * rng.randf_range(0.8, 1.4))
		_ground[i] = _scale[i].y * 0.35
		_start_pos[i] = Vector3(cos(angle) * r, _ground[i], sin(angle) * r)
		var yaw := Quaternion(Vector3.UP, rng.randf() * TAU)
		var tilt := Quaternion(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
		_start_rot[i] = yaw * tilt


func _restore() -> void:
	var n := _start_pos.size()
	_pos = _start_pos.duplicate()
	_rot = _start_rot.duplicate()
	_vel.resize(n)
	_vel.fill(Vector3.ZERO)
	_spin.resize(n)
	_spin.fill(Vector3.ZERO)
	_glow.resize(n)
	_glow.fill(0.0)
	_airborne.resize(n)
	_airborne.fill(0)
	for i in n:
		_write_instance(i)


func _apply_look() -> void:
	_material.set_shader_parameter("stone_color", stone_color)
	_material.set_shader_parameter("glow_color", glow_color)
	_material.set_shader_parameter("glow_intensity", glow_intensity)


## One low-poly shard: a jittered double pyramid (5 sides) with flat-shaded faces.
## Unit size; each instance is scaled non-uniformly for variety.
func _build_shard_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var top := Vector3(rng.randf_range(-0.1, 0.1), 0.5, rng.randf_range(-0.1, 0.1))
	var bottom := Vector3(rng.randf_range(-0.1, 0.1), -0.5, rng.randf_range(-0.1, 0.1))
	var ring: Array[Vector3] = []
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(0.35, 0.55)
		ring.append(Vector3(cos(a) * r, rng.randf_range(-0.12, 0.12), sin(a) * r))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := ring[k]
		var b := ring[(k + 1) % 5]
		_add_face(st, top, a, b)
		_add_face(st, bottom, b, a)
	return st.commit()


## Adds a flat triangle facing away from the shard centre. Godot treats clockwise
## triangles (seen from the front) as front faces, so the winding is fixed up here.
func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0) > 0.0:
		var tmp := b
		b = c
		c = tmp
	else:
		normal = -normal
	st.set_normal(normal)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
