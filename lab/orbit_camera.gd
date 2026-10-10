extends Camera3D
## Orbit camera: right/middle mouse drag to orbit, wheel to zoom.

@export var target := Vector3(0.0, 0.5, 0.0)
@export var home_distance := 13.0
@export var home_yaw := 30.0
@export var home_pitch := -30.0

var _yaw := 0.0
var _pitch := 0.0
var _distance := 0.0


func _ready() -> void:
	reset_view()


func reset_view() -> void:
	_yaw = home_yaw
	_pitch = home_pitch
	_distance = home_distance
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		_yaw -= motion.relative.x * 0.3
		_pitch = clampf(_pitch - motion.relative.y * 0.3, -88.0, -3.0)
		_update_transform()
		return
	var button := event as InputEventMouseButton
	if button and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.5, _distance * 0.9)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(40.0, _distance * 1.1)
		_update_transform()


func _update_transform() -> void:
	var orbit := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0))
	global_position = target + orbit * Vector3(0.0, 0.0, _distance)
	look_at(target)
