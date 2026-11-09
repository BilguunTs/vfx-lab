extends Node3D
## Spirit Wisp — a small, shy spirit that lingers around this node's position, drifts closer
## out of curiosity, flinches away from a pulse and comes back cautiously.
##
## Self-contained. Call startle(from, strength) from anything; add_push(source) is the same for
## the drum strike's persistent-layer interface (source = the pulse ring: the wisp flinches
## when the ring's front reaches it, not at the moment of impact).
##
## Motion: a spring toward a target that drifts with smooth noise (wander), sometimes pulled
## toward `focus` (curiosity), pushed away by fear. Speed and pauses come from slow noise too,
## so it never moves at a constant rate. The trail is a camera-facing ribbon through the
## recent positions, rebuilt every frame.

const HEAD_SHADER := preload("res://experiments/08_spirit_wisp/wisp_head.gdshader")
const TRAIL_SHADER := preload("res://experiments/08_spirit_wisp/wisp_trail.gdshader")
const MAX_TRAIL_POINTS := 96

@export_group("Wander")
## Point it is drawn to, relative to this node (e.g. the drum head).
@export var focus := Vector3(0.0, 0.85, 0.0)
@export_range(0.3, 8.0, 0.05, "suffix:m") var wander_radius := 2.2
@export_range(0.1, 3.0, 0.05, "suffix:m") var min_height := 0.35
@export_range(0.2, 4.0, 0.05, "suffix:m") var max_height := 1.8
## How fast the wander target drifts.
@export_range(0.01, 1.0, 0.01) var wander_speed := 0.12
## Top speed when travelling calmly.
@export_range(0.05, 5.0, 0.05, "suffix:m/s") var cruise_speed := 0.8
## How quickly it eases toward its target speed: low = floaty, high = darting.
@export_range(0.2, 20.0, 0.1) var agility := 2.2
## Drag: high = settles, low = overshoots and loops.
@export_range(0.1, 10.0, 0.05) var drag := 1.6
## How much the wisp hesitates: slow noise that sometimes brings it nearly to a stop.
@export_range(0.0, 1.0, 0.01) var hesitation := 0.6
## How often (and how close) it drifts in to look at the focus. 0 = never.
@export_range(0.0, 1.0, 0.01) var curiosity := 0.5
## Closest it dares to come to the focus.
@export_range(0.1, 2.0, 0.01, "suffix:m") var personal_space := 0.55

@export_group("Startle")
## Speed of the flinch away from a pulse.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var startle_speed := 6.0
## Where it hides, as a distance from the focus.
@export_range(0.5, 15.0, 0.1, "suffix:m") var hide_distance := 4.5
## Seconds until it dares to come back (fear decays over this).
@export_range(0.2, 15.0, 0.1, "suffix:s") var recover_time := 3.5
## After a scare it stays wary this much longer: slower, keeps its distance, less curious.
@export_range(1.0, 6.0, 0.1) var wariness_length := 3.0
## Pulses farther than this barely scare it.
@export_range(0.5, 20.0, 0.1, "suffix:m") var startle_reach := 6.0
## Front speed used when the pulse source doesn't report its own front.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var fallback_front_speed := 9.0

@export_group("Look")
@export var color := Color(0.62, 0.9, 0.82)
@export_range(0.0, 8.0, 0.05) var brightness := 1.6
@export_range(0.02, 0.5, 0.005, "suffix:m") var head_size := 0.11
## Breathing pulse of the glow.
@export_range(0.0, 1.0, 0.01) var breathing := 0.35
## Dims while afraid (hiding).
@export_range(0.0, 1.0, 0.01) var fear_dim := 0.6
## A faint light on the ground beneath it: physical presence. 0 = off.
@export_range(0.0, 2.0, 0.01) var light_energy := 0.2

@export_group("Trail")
@export_range(0.05, 4.0, 0.05, "suffix:s") var trail_time := 1.1
@export_range(0.005, 0.3, 0.005, "suffix:m") var trail_width := 0.06
@export_range(0.0, 3.0, 0.05) var trail_brightness := 0.7
## 0 = smooth ribbon, 1 = broken into wisps toward the tail.
@export_range(0.0, 1.0, 0.01) var trail_breakup := 1.0

@export_group("Variation")
@export var noise_seed := 5

var _pos := Vector3.ZERO      # world space
var _vel := Vector3.ZERO
var _fear := 0.0              # 0..1: fleeing / hiding
var _wary := 0.0              # 0..1: decays slower than fear; a cautious return
var _flee_dir := Vector3.RIGHT
var _time := 0.0
var _curious := 0.0           # 0..1, smoothed
var _strength := 1.0
var _seed_offset := 0
var _pending: Array[Dictionary] = [] # pulses on their way: {source, origin, elapsed, strength}
var _trail: Array[Dictionary] = []   # {pos, age}
var _target := Vector3.ZERO
var _noise := FastNoiseLite.new()

var _head: MeshInstance3D
var _head_material := ShaderMaterial.new()
var _trail_mesh := ImmediateMesh.new()
var _trail_view: MeshInstance3D
var _trail_material := ShaderMaterial.new()
var _light: OmniLight3D
var _debug := false
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0

	_head_material.shader = HEAD_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_head = MeshInstance3D.new()
	_head.mesh = quad
	_head.material_override = _head_material
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.top_level = true
	add_child(_head)

	_trail_material.shader = TRAIL_SHADER
	_trail_view = MeshInstance3D.new()
	_trail_view.mesh = _trail_mesh
	_trail_view.material_override = _trail_material
	_trail_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_view.top_level = true
	_trail_view.extra_cull_margin = 16384.0 # rebuilt every frame; never cull on stale bounds
	add_child(_trail_view)

	_light = OmniLight3D.new()
	_light.omni_range = 1.6
	_light.omni_attenuation = 2.0
	_light.shadow_enabled = false
	_light.top_level = true
	add_child(_light)

	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.top_level = true
	_debug_view.visible = false
	add_child(_debug_view)
	reset()


## Scares the wisp away from `from` (world position). Strength 1 = a normal strike.
func startle(from: Vector3, strength := 1.0) -> void:
	var away := _pos - from
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(cos(_time * 7.0), 0.0, sin(_time * 7.0))
	away = away.normalized()
	var reach := clampf(1.0 - from.distance_to(_pos) / startle_reach, 0.15, 1.0)
	var amount := clampf(strength, 0.0, 2.0) * reach
	_flee_dir = away
	_vel += (away + Vector3.UP * 0.35).normalized() * startle_speed * amount
	_fear = clampf(maxf(_fear, amount), 0.0, 1.0)
	_wary = maxf(_wary, _fear)


## Drum strike interface: `source` is the pulse (a node, optionally with get_front_radius()).
## The flinch waits for the front to reach the wisp.
func add_push(source: Node3D) -> void:
	var origin := source.global_position if source else global_position
	_pending.append({source = source, origin = origin, elapsed = 0.0, strength = _strength})


func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)


func set_variation(index: int) -> void:
	_seed_offset = index * 101
	_noise.seed = noise_seed + _seed_offset


func reset() -> void:
	_noise.seed = noise_seed + _seed_offset
	_time = 0.0
	_fear = 0.0
	_wary = 0.0
	_curious = 0.0
	_pending.clear()
	_trail.clear()
	_pos = global_position + focus + Vector3(wander_radius * 0.6, 0.0, 0.0)
	_vel = Vector3.ZERO
	_target = _pos


func is_active() -> bool:
	return true


func set_debug(enabled: bool) -> void:
	_debug = enabled
	_debug_view.visible = enabled


func get_debug_text() -> String:
	return "%s: speed %.2f m/s   fear %.2f   wary %.2f   curious %.2f   %.1fm from focus   pulses pending %d" % [
		name, _vel.length(), _fear, _wary, _curious, _pos.distance_to(global_position + focus), _pending.size()]


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_update_pending(delta)
	_update_motion(delta)
	_update_trail(delta)
	_update_look()
	if _debug:
		_draw_debug()


func _update_pending(delta: float) -> void:
	for pulse in _pending.duplicate():
		pulse.elapsed += delta
		var source: Node3D = pulse.source if is_instance_valid(pulse.source) else null
		var front := -1.0
		if source and source.has_method("get_front_radius"):
			front = source.get_front_radius()
		if front < 0.0:
			front = pulse.elapsed * fallback_front_speed
		var offset: Vector3 = _pos - pulse.origin
		offset.y = 0.0
		if front >= offset.length() or pulse.elapsed > 2.0:
			startle(pulse.origin, pulse.strength)
			_pending.erase(pulse)


func _update_motion(delta: float) -> void:
	var home := global_position + focus
	var t := _time * wander_speed

	# Wander: a target drifting through the space around the focus.
	var n := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0), _noise.get_noise_2d(t, 200.0))
	var wander := home + Vector3(n.x, 0.0, n.z) * wander_radius * 1.6
	wander.y = lerpf(min_height, max_height, n.y * 0.5 + 0.5) + global_position.y

	# Curiosity: now and then it comes in close to look.
	var want_close := smoothstep(1.0 - curiosity, 1.0, _noise.get_noise_2d(t * 0.6, 300.0) * 0.5 + 0.5 + curiosity * 0.25)
	_curious = move_toward(_curious, want_close * (1.0 - _wary), delta * 0.5)
	var to_wisp := _pos - home
	var side := to_wisp.normalized() if to_wisp.length() > 0.01 else Vector3.RIGHT
	var peek := home + side * (personal_space + 0.15)
	var target := wander.lerp(peek, _curious)
	# While wary it keeps to the outer part of its range.
	var from_home := target - home
	from_home.y = 0.0
	var keep_out := wander_radius * 0.8 * _wary
	if from_home.length() < keep_out:
		target += (from_home.normalized() if from_home.length() > 0.01 else side) * (keep_out - from_home.length())

	# Fear: hide out along the flee direction, coming back as fear decays.
	var hide_point := home + _flee_dir * hide_distance
	hide_point.y = global_position.y + min_height + 0.2
	target = target.lerp(hide_point, smoothstep(0.0, 0.6, _fear))
	_target = target

	# Hesitation: slow noise that sometimes nearly stops it.
	var pace := 1.0 - hesitation * smoothstep(0.1, 0.7, _noise.get_noise_2d(t * 2.5, 400.0) * 0.5 + 0.5)
	pace = maxf(pace, _fear) # fleeing is never hesitant
	# Cautious return: wobbles sideways while still a little afraid.
	var wobble := Vector3(_noise.get_noise_2d(_time * 3.0, 500.0), _noise.get_noise_2d(_time * 3.0, 600.0) * 0.5, _noise.get_noise_2d(_time * 3.0, 700.0))

	# Steer toward a desired velocity rather than spring to the target: a far target must not
	# mean a fast wisp. Slower while wary.
	var to_target := target - _pos
	var speed_limit := cruise_speed * pace * (1.0 - 0.6 * _wary)
	if _fear > 0.3:
		speed_limit = maxf(speed_limit, cruise_speed * 2.0) # retreating to hide is brisk
	var desired := to_target.normalized() * minf(to_target.length() * 1.5, speed_limit) if to_target.length() > 1e-4 else Vector3.ZERO
	var caution := 4.0 * _wary * (1.0 - _wary)
	var accel := (desired - _vel) * agility - _vel * drag * 0.2 + wobble * (0.5 + caution * 2.0)
	# Personal space: pushed away from the focus if it comes too close.
	var d := to_wisp.length()
	if d < personal_space:
		accel += side * (personal_space - d) * 30.0
	_vel += accel * delta
	_pos += _vel * delta
	_pos.y = maxf(_pos.y, global_position.y + 0.12)

	_fear = maxf(_fear - delta / recover_time, 0.0)
	_wary = maxf(_wary - delta / (recover_time * wariness_length), _fear)


func _update_trail(delta: float) -> void:
	for point in _trail:
		point.age += delta
	while _trail.size() > 0 and _trail.front().age > trail_time:
		_trail.pop_front()
	_trail.append({pos = _pos, age = 0.0})
	if _trail.size() > MAX_TRAIL_POINTS:
		_trail.pop_front()

	_trail_mesh.clear_surfaces()
	if _trail.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var eye := camera.global_position
	# Distance from the head along the trail, for the shader's breakup (measured in metres).
	var along := PackedFloat32Array()
	along.resize(_trail.size())
	var run := 0.0
	for i in range(_trail.size() - 1, -1, -1):
		if i < _trail.size() - 1:
			run += (_trail[i].pos as Vector3).distance_to(_trail[i + 1].pos)
		along[i] = run
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail.size():
		var p: Vector3 = _trail[i].pos
		var a: Vector3 = _trail[maxi(i - 1, 0)].pos
		var b: Vector3 = _trail[mini(i + 1, _trail.size() - 1)].pos
		var tangent := b - a
		var side := tangent.cross(eye - p)
		side = side.normalized() if side.length() > 1e-6 else Vector3.UP
		var life := 1.0 - float(_trail[i].age) / trail_time # 1 at the head, 0 at the tail end
		var width := trail_width * (0.25 + 0.75 * life)
		var c := Color(color.r, color.g, color.b, life)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_set_uv(Vector2(along[i], 0.0))
		_trail_mesh.surface_add_vertex(p - side * width)
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_set_uv(Vector2(along[i], 1.0))
		_trail_mesh.surface_add_vertex(p + side * width)
	_trail_mesh.surface_end()


func _update_look() -> void:
	var breath := 1.0 + breathing * 0.5 * (sin(_time * 1.7) + 0.4 * sin(_time * 4.3 + 1.0))
	var glow := brightness * breath * (1.0 - fear_dim * _fear)
	_head.global_position = _pos
	_head.scale = Vector3.ONE * head_size * (0.9 + 0.2 * breath)
	_head_material.set_shader_parameter("color", color)
	_head_material.set_shader_parameter("intensity", glow)
	_trail_material.set_shader_parameter("intensity", trail_brightness * glow / maxf(brightness, 0.01))
	_trail_material.set_shader_parameter("scaled_time", _time)
	_trail_material.set_shader_parameter("breakup", trail_breakup)
	_light.visible = light_energy > 0.0
	_light.global_position = _pos
	_light.light_color = color
	_light.light_energy = light_energy * glow / maxf(brightness, 0.01)


func _draw_debug() -> void:
	var home := global_position + focus
	_debug_mesh.clear_surfaces()
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_debug_mesh.surface_set_color(Color(0.9, 0.9, 0.3))
	_debug_mesh.surface_add_vertex(_pos)
	_debug_mesh.surface_add_vertex(_target)
	_debug_mesh.surface_set_color(Color(1.0, 0.3, 0.3).lerp(Color(0.3, 1.0, 0.6), 1.0 - _fear))
	_debug_mesh.surface_add_vertex(_pos)
	_debug_mesh.surface_add_vertex(_pos + _vel * 0.3)
	_debug_mesh.surface_end()
	# Wander area on the ground, around the focus.
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_debug_mesh.surface_set_color(Color(0.5, 0.6, 0.6))
	for i in 65:
		var a := TAU * i / 64.0
		_debug_mesh.surface_add_vertex(Vector3(home.x + cos(a) * wander_radius, global_position.y + 0.03, home.z + sin(a) * wander_radius))
	_debug_mesh.surface_end()
