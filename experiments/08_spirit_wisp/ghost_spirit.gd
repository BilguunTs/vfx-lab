extends "res://experiments/08_spirit_wisp/spirit_wisp.gd"
## Ghost Spirit — a spirit wisp whose body is a half-dissolved figure (Ghost Wrap) instead of a
## glow. Same motion, fear and wariness as the wisp; this only replaces the look:
##   - the figure glides along the wisp's path, close to the ground, facing the focus (watching);
##   - fear drives the Ghost Wrap value: resting half smoke, a startle dissolves it fully
##     (feet first, head last), and it re-forms from the head down as the fear fades.
## The wisp's glow, trail and light are hidden. Smoke trails come from Ghost Wrap itself.

## The figure to move (its origin at the feet).
@export var body: Node3D
## The figure's Ghost Wrap. Its reveal point should be the head: re-forming then starts there.
@export var ghost: Node
## Ghost value at rest: 0 = solid figure, 1 = only smoke.
@export_range(0.0, 1.0, 0.01) var rest_ghost := 0.65
## How fast it dissolves when startled (value per second).
@export_range(0.1, 10.0, 0.05) var dissolve_rate := 3.0
## Fastest it may re-form (value per second); fear decides when it starts.
@export_range(0.02, 2.0, 0.01) var reform_rate := 0.18
## Height the figure floats above the ground, and its slow bob.
@export_range(0.0, 1.0, 0.01, "suffix:m") var hover := 0.06
@export_range(0.0, 0.3, 0.005, "suffix:m") var bob := 0.03
## How quickly it turns to face the focus.
@export_range(0.1, 10.0, 0.1) var turn_rate := 1.5

var _ghost_value := 1.0
var _yaw := 0.0


func _ready() -> void:
	super()
	_head.visible = false
	_trail_view.visible = false
	_light.visible = false


func reset() -> void:
	super()
	# Start as smoke and gather into the figure: re-forming from the head on every reset.
	_ghost_value = 1.0
	if ghost:
		ghost.intensity = 1.0
		ghost.clear_smoke()


func get_debug_text() -> String:
	return super() + "   ghost %.2f" % _ghost_value


func _update_trail(_delta: float) -> void:
	pass # the smoke is the trail


## Replaces the glow: places the figure and turns fear into the ghost value.
func _update_look() -> void:
	var delta := get_process_delta_time()
	if body:
		var ground := global_position.y
		var p := Vector3(_pos.x, ground + hover + bob * sin(_time * 1.3 + float(noise_seed)), _pos.z)
		body.global_position = p
		var look := global_position + focus - p
		if Vector2(look.x, look.z).length() > 0.05:
			var want := atan2(look.x, look.z)
			_yaw = lerp_angle(_yaw, want, clampf(delta * turn_rate, 0.0, 1.0))
		body.global_rotation = Vector3(0.0, _yaw, 0.0)

	var target := lerpf(rest_ghost, 1.0, smoothstep(0.0, 0.25, _fear))
	if target > _ghost_value:
		_ghost_value = move_toward(_ghost_value, target, dissolve_rate * delta)
	else:
		_ghost_value = move_toward(_ghost_value, target, reform_rate * delta)
	if ghost:
		ghost.intensity = _ghost_value
