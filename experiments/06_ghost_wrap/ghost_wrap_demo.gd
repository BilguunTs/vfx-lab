extends Node3D
## Experiment 06 demo: drives a GhostWrap on a stand-in figure for the lab.
## This script is the only place that knows about the figure; GhostWrap itself only sees its
## target meshes, `intensity` and `reveal_point`.
##
## Keys (on top of the lab's): SPACE toggles 0 <-> 1, Q / E step the target value down / up,
## P cycles the reveal point (children of Body/RevealPoints), B toggles the blob,
## N cycles the element (smoke, fire, water, wind).

const VALUE_STEP := 0.25

## Seconds for a full 0 -> 1 (or 1 -> 0) transition.
@export_range(0.1, 5.0, 0.05, "suffix:s") var ramp_time := 1.6
## The body lifts off the ground as it turns into a ghost.
@export_range(0.0, 1.0, 0.01, "suffix:m") var hover_height := 0.12
@export_range(0.0, 0.3, 0.005, "suffix:m") var hover_bob := 0.04
## Elements N cycles through. The first one is used on start.
@export var elements: Array[GhostElement] = []
## Walk a slow circle, to see the smoke trail behind a moving body.
@export var wander := false
@export_range(0.2, 5.0, 0.1, "suffix:m") var wander_radius := 1.5
@export_range(0.05, 3.0, 0.05, "suffix:m/s") var wander_speed := 0.35

var _value := 0.0 # linear, moves toward _target at 1 / ramp_time per second
var _target := 0.0
var _time := 0.0
var _angle := 0.0
var _reveal_index := 0
var _element_index := 0

@onready var _body: Node3D = $Body
@onready var _ghost: Node3D = $Body/GhostWrap
@onready var _reveal_points: Array[Node] = $Body/RevealPoints.get_children()


func _ready() -> void:
	_select_reveal(0)
	_select_element(0)


func play() -> void:
	_target = 0.0 if _target > 0.5 else 1.0


func reset() -> void:
	_target = 0.0
	_value = 0.0
	_time = 0.0
	_angle = 0.0
	_ghost.intensity = 0.0
	_body.position = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	_ghost.clear_smoke()


func set_debug(enabled: bool) -> void:
	_ghost.set_debug(enabled)


func get_debug_text() -> String:
	return _ghost.get_debug_text()


func get_layer_status() -> String:
	return "[1] Fade %s   [2] Particles %s      element: %s (N)   value %.2f -> %.2f (Q/E)   reveal point: %s (P)   blob %s (B)" % [
		"on" if _ghost.fade_enabled else "MUTED", "on" if _ghost.particles_enabled else "MUTED",
		_ghost.element.display_name if _ghost.element else "Smoke",
		_value, _target, _ghost.reveal_point.name if _ghost.reveal_point else "none",
		"on" if _ghost.blob_enabled else "off"]


func toggle_layer(index: int) -> void:
	match index:
		0: _ghost.fade_enabled = not _ghost.fade_enabled
		1: _ghost.particles_enabled = not _ghost.particles_enabled


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_Q:
			_target = clampf(snappedf(_target - VALUE_STEP, VALUE_STEP), 0.0, 1.0)
		KEY_E:
			_target = clampf(snappedf(_target + VALUE_STEP, VALUE_STEP), 0.0, 1.0)
		KEY_P:
			_select_reveal(_reveal_index + 1)
		KEY_B:
			_ghost.blob_enabled = not _ghost.blob_enabled
		KEY_N:
			_select_element(_element_index + 1)


func _select_element(index: int) -> void:
	if elements.is_empty():
		return
	_element_index = index % elements.size()
	_ghost.element = elements[_element_index]


func _select_reveal(index: int) -> void:
	if _reveal_points.is_empty():
		return
	_reveal_index = index % _reveal_points.size()
	_ghost.reveal_point = _reveal_points[_reveal_index]


func _process(delta: float) -> void:
	_time += delta
	_value = move_toward(_value, _target, delta / ramp_time)
	_ghost.intensity = _value

	var i := smoothstep(0.0, 1.0, _value)
	var pos := _body.position
	if wander:
		_angle += wander_speed / wander_radius * delta
		pos = Vector3(cos(_angle), 0.0, sin(_angle)) * wander_radius
		_body.rotation.y = -_angle # face along the path
	pos.y = i * (hover_height + sin(_time * 1.3) * hover_bob)
	_body.position = pos
