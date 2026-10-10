extends Node3D
## Experiment 04 â€” Energy Ring (drum strike, Phase A).
##
## A flat quad on the ground draws a ring with a shader. This script owns all
## timing: each frame it turns normalized time into radius, thickness and fade
## and pushes them to the shader. The shader never reads TIME, so a replay with
## the same seed is identical, and slow motion slows everything consistently.

const RING_SHADER := preload("res://experiments/04_energy_ring/energy_ring.gdshader")
const GROUND_OFFSET := 0.02

@export_group("Shape")
## Radius at the moment of the strike.
@export_range(0.0, 2.0, 0.01, "suffix:m") var start_radius := 0.3
## Radius when the ring has fully expanded.
@export_range(0.5, 15.0, 0.1, "suffix:m") var max_radius := 4.5
## Band width at the moment of the strike.
@export_range(0.01, 1.0, 0.005, "suffix:m") var thickness := 0.22
## Band width at the end, relative to the start. Below 1 the ring thins as its energy spreads.
@export_range(0.0, 2.0, 0.01) var thickness_end_scale := 0.3
## Radial wobble so the ring is not a perfect circle.
@export_range(0.0, 0.5, 0.005, "suffix:m") var edge_noise := 0.06

@export_group("Timing")
## Wait after play() before the ring appears. Lets layered rings share one trigger.
@export_range(0.0, 2.0, 0.01, "suffix:s") var start_delay := 0.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var lifetime := 1.4
## Expansion curve. Below 1 = explosive start that decelerates; 1 = linear.
@export_exp_easing var expansion_ease := 0.3
## Fade curve (brightness = 1 - ease(t)). Below 1 = drops fast then lingers; above 1 = holds then drops.
@export_exp_easing var fade_ease := 0.6

@export_group("Look")
@export var color := Color(0.72, 0.86, 0.8)
## Values above ~1 push the ring past the glow threshold.
@export_range(0.0, 8.0, 0.05) var intensity := 2.5
## 0 = hard edge, 1 = fully soft band.
@export_range(0.0, 1.0, 0.01) var softness := 0.7
## Faint energy trailing inside the ring.
@export_range(0.0, 1.0, 0.01) var wake := 0.12
@export_range(0.05, 3.0, 0.05, "suffix:m") var wake_length := 0.4
## Uneven brightness along the ring. 0 = uniform.
@export_range(0.0, 1.0, 0.01) var brightness_variation := 0.45

@export_group("Variation")
## Same seed = identical replay. Change it for a different wobble.
@export var noise_seed := 1
## Number of wobbles around the ring (roughly).
@export_range(0.5, 10.0, 0.1) var noise_scale := 2.5
## How fast the wobble crawls while the ring expands.
@export_range(0.0, 5.0, 0.05) var noise_speed := 0.8

var _elapsed := 0.0
var _playing := false
var _debug := false
var _radius := 0.0
var _band := 0.0
var _fade := 0.0
var _strength := 1.0
var _seed_offset := 0

var _plane := PlaneMesh.new()
var _material := ShaderMaterial.new()
var _ring: MeshInstance3D
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	_material.shader = RING_SHADER
	_ring = MeshInstance3D.new()
	_ring.mesh = _plane
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = GROUND_OFFSET
	add_child(_ring)

	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.visible = false
	add_child(_debug_view)

	reset()


func play() -> void:
	# Negative elapsed time = still waiting out the delay.
	_elapsed = -start_delay
	_playing = true
	# Size the quad to the largest the ring can get, so edits to max_radius are picked up on replay.
	var half_extent := maxf(start_radius, _max_radius()) + _thickness() + edge_noise + 0.1
	_plane.size = Vector2.ONE * half_extent * 2.0
	_ring.visible = _elapsed >= 0.0
	if _ring.visible:
		_apply(0.0)


## Scales the ring for a weaker or stronger strike; 1 = as authored. Brightness follows
## strength directly, size grows slower and duration barely changes: a big strike is mostly
## bigger and brighter, not slower. Applies from the next play().
func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)


## Offsets the noise seed: same ring, different wobble.
func set_variation(index: int) -> void:
	_seed_offset = index * 101


func is_active() -> bool:
	return _playing


func reset() -> void:
	_playing = false
	_elapsed = 0.0
	_ring.visible = false


func set_debug(enabled: bool) -> void:
	_debug = enabled
	_debug_view.visible = enabled


## Leading edge of the ring in metres, or -1 while it is idle or waiting out its delay.
## Lets other layers react to the wave (e.g. the rune seal ignites as the front passes).
func get_front_radius() -> float:
	if not _playing or _elapsed < 0.0:
		return -1.0
	return _radius + _band * 0.5


func get_debug_text() -> String:
	if not _playing:
		return "%s: idle" % name
	if _elapsed < 0.0:
		return "%s: waiting %.2fs" % [name, -_elapsed]
	return "%s: %.2fs / %.2fs (%d%%)   radius %.2fm   band %.3fm   fade %.2f" % [
		name, _elapsed, _lifetime(), int(100.0 * _elapsed / _lifetime()), _radius, _band, _fade]


func _process(delta: float) -> void:
	if _playing:
		_elapsed += delta
		if _elapsed >= _lifetime():
			reset()
		elif _elapsed >= 0.0:
			_ring.visible = true
			_apply(_elapsed / _lifetime())
	if _debug:
		_draw_debug()


func _apply(t: float) -> void:
	_radius = lerpf(start_radius, _max_radius(), ease(t, expansion_ease))
	_band = _thickness() * lerpf(1.0, thickness_end_scale, t)
	_fade = 1.0 - ease(t, fade_ease)

	_material.set_shader_parameter("radius", _radius)
	_material.set_shader_parameter("thickness", _band)
	_material.set_shader_parameter("fade", _fade)
	_material.set_shader_parameter("ring_color", color)
	_material.set_shader_parameter("intensity", intensity * _strength)
	_material.set_shader_parameter("softness", softness)
	_material.set_shader_parameter("wake", wake)
	_material.set_shader_parameter("wake_length", wake_length)
	_material.set_shader_parameter("edge_noise", edge_noise)
	_material.set_shader_parameter("brightness_variation", brightness_variation)
	_material.set_shader_parameter("noise_scale", noise_scale)
	_material.set_shader_parameter("noise_seed", float(noise_seed + _seed_offset))
	_material.set_shader_parameter("noise_time", _elapsed * noise_speed)


func _max_radius() -> float:
	return max_radius * pow(_strength, 0.6)


func _thickness() -> float:
	return thickness * pow(_strength, 0.5)


func _lifetime() -> float:
	return lifetime * pow(_strength, 0.3)


func _draw_debug() -> void:
	_debug_mesh.clear_surfaces()
	var guide := Color(0.5, 0.5, 0.5)
	DebugDraw.circle(_debug_mesh, start_radius, guide)
	DebugDraw.circle(_debug_mesh, _max_radius(), guide)
	if _playing and _elapsed >= 0.0:
		var live := Color(1.0, 0.85, 0.3)
		DebugDraw.circle(_debug_mesh, _radius - _band * 0.5, live)
		DebugDraw.circle(_debug_mesh, _radius + _band * 0.5, live)

