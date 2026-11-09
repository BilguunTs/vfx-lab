extends Node3D
## Shockwave — a one-shot ripple of air that bends the background outward from this node.
## Self-contained: call trigger(strength) (or play()) and it runs once. Knows nothing about
## drums; experiment 05 uses it as a layer of the strike.
##
## A sphere mesh grows from 0 to max_radius, decelerating like a real blast front, while the
## distortion strength decays. See shockwave.gdshader for how the bending works.

const SHADER := preload("res://experiments/07_shockwave/shockwave.gdshader")

## Wait after play() before the wave starts.
@export_range(0.0, 2.0, 0.01, "suffix:s") var start_delay := 0.0
@export_range(0.1, 10.0, 0.05, "suffix:m") var max_radius := 3.0
@export_range(0.05, 3.0, 0.01, "suffix:s") var lifetime := 0.45
## How the radius grows: high = bursts out fast, then crawls (a blast front decelerates).
@export_range(1.0, 8.0, 0.1) var expansion_sharpness := 3.0
## Peak bend, in fractions of the screen. 0.025 = 2.5 % of the screen width at the front.
@export_range(0.0, 0.2, 0.001) var amplitude := 0.04
## How fast the bend fades: higher = mostly at the start.
@export_range(0.2, 5.0, 0.05) var decay := 1.5
## Width of the push band, as a fraction of the wave's projected radius.
@export_range(0.05, 1.0, 0.01) var front_width := 0.35
## Inward lobe behind the front (the air springing back), relative to the push.
@export_range(0.0, 1.0, 0.01) var rebound := 0.35
## Faint brightening at the front.
@export_range(0.0, 0.5, 0.005) var edge_light := 0.1
## Colour split along the bend. Keep 0 for air; a little reads as "magical".
@export_range(0.0, 1.0, 0.01) var chroma := 0.0

var _elapsed := 0.0
var _playing := false
var _strength := 1.0
var _radius := 0.0
var _amp := 0.0
var _material := ShaderMaterial.new()
var _sphere: MeshInstance3D
var _debug := false
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	_material.shader = SHADER
	_sphere = MeshInstance3D.new()
	_sphere.mesh = mesh
	_sphere.material_override = _material
	_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sphere)
	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.visible = false
	add_child(_debug_view)
	reset()
	# Draw once, invisibly (amplitude 0 -> alpha 0), so the shader is compiled now rather
	# than stalling the frame of the first trigger.
	_material.set_shader_parameter("amplitude", 0.0)
	_sphere.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if not _playing:
		_sphere.visible = false


## Plays the wave once at the given strength (1 = as authored).
func trigger(strength := 1.0) -> void:
	set_strength(strength)
	play()


func play() -> void:
	_elapsed = -start_delay
	_playing = true
	_apply(0.0)


## Bend × s, size × s^0.6, duration × s^0.3: a harder hit is mostly bigger and stronger.
func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)


func set_variation(_index: int) -> void:
	pass # nothing random yet


func is_active() -> bool:
	return _playing


func reset() -> void:
	_playing = false
	_sphere.visible = false
	_debug_view.visible = false


func set_debug(enabled: bool) -> void:
	_debug = enabled
	_material.set_shader_parameter("debug_tint", enabled)


func get_debug_text() -> String:
	if not _playing:
		return "%s: idle" % name
	if _elapsed < 0.0:
		return "%s: waiting %.2fs" % [name, -_elapsed]
	return "%s: %.2fs / %.2fs   radius %.2fm   bend %.3f" % [name, _elapsed, _lifetime(), _radius, _amp]


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= _lifetime():
		reset()
		return
	_apply(maxf(_elapsed, 0.0) / _lifetime())


func _apply(t: float) -> void:
	var waiting := _elapsed < 0.0
	_sphere.visible = not waiting
	_radius = _max_radius() * (1.0 - pow(1.0 - t, expansion_sharpness))
	_amp = amplitude * _strength * pow(1.0 - t, decay)
	_sphere.scale = Vector3.ONE * maxf(_radius, 0.001)
	_material.set_shader_parameter("amplitude", _amp)
	_material.set_shader_parameter("front_width", front_width)
	_material.set_shader_parameter("rebound", rebound)
	_material.set_shader_parameter("edge_light", edge_light * _strength * pow(1.0 - t, decay))
	_material.set_shader_parameter("chroma", chroma)
	_debug_view.visible = _debug and not waiting
	if _debug_view.visible:
		_debug_mesh.clear_surfaces()
		_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_debug_mesh.surface_set_color(Color(0.6, 0.85, 1.0))
		for plane in [[Vector3.RIGHT, Vector3.UP], [Vector3.RIGHT, Vector3.BACK], [Vector3.UP, Vector3.BACK]]:
			for s in 48:
				var a0 := TAU * s / 48.0
				var a1 := TAU * (s + 1) / 48.0
				_debug_mesh.surface_add_vertex((plane[0] * cos(a0) + plane[1] * sin(a0)) * _radius)
				_debug_mesh.surface_add_vertex((plane[0] * cos(a1) + plane[1] * sin(a1)) * _radius)
		_debug_mesh.surface_end()


func _max_radius() -> float:
	return max_radius * pow(_strength, 0.6)


func _lifetime() -> float:
	return lifetime * pow(_strength, 0.3)
