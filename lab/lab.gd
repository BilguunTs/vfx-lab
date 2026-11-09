extends Node3D
## Stage 1 sandbox: plays the effect under EffectSlot with replay/reset/debug controls.
## An effect only needs play() and reset(); set_debug(bool), get_debug_text(),
## get_layer_status() and toggle_layer(index) are optional, as are `strength` and `variation` properties.
## An optional `striker` (strike(strength), reset(), `impacted` signal) gives the effect a cause:
## SPACE swings it, and the effect plays at the moment of impact.

const SLOW_MOTION := 0.2
const STRENGTH_STEP := 0.25
const CONTROLS := "SPACE strike   R reset   D debug   T slow-mo   L loop   -/= strength   V variation   A anticipation   RMB drag orbit   wheel zoom   ESC quit"

@export var play_on_start := true
## Seconds between strikes while looping.
@export_range(0.2, 10.0, 0.1, "suffix:s") var loop_interval := 2.5
## Optional node that delivers the strike (e.g. the drum stand-in). Empty = effect plays instantly.
@export var striker: Node3D
## Optional: replaces whatever sits under EffectSlot. Lets an experiment reuse the lab through
## an inherited scene (see experiments/06_ghost_wrap/ghost_wrap_lab.tscn).
@export var effect_scene: PackedScene

var _debug := false
var _looping := false
var _loop_timer := 0.0
var _debug_view: MeshInstance3D
var _effect: Node

@onready var _camera := $Camera
@onready var _info: Label = $HUD/Info


func _ready() -> void:
	var slot := $EffectSlot
	if effect_scene:
		for child in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
		slot.add_child(effect_scene.instantiate())
	_effect = slot.get_child(0)
	if striker and not striker.visible:
		striker = null

	_debug_view = _build_debug_guides()
	add_child(_debug_view)
	_set_debug(false)
	if striker:
		striker.impacted.connect(_effect.play)
	if play_on_start:
		_strike()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_strike()
		KEY_R:
			_reset()
		KEY_D:
			_set_debug(not _debug)
		KEY_T:
			Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else SLOW_MOTION
		KEY_L:
			_looping = not _looping
			if _looping:
				_strike()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_change_strength(-STRENGTH_STEP)
		KEY_EQUAL, KEY_KP_ADD:
			_change_strength(STRENGTH_STEP)
		KEY_A:
			if striker and "anticipation" in striker:
				striker.anticipation = not striker.anticipation
				_strike()
		KEY_V:
			if "variation" in _effect:
				_effect.variation += 1
				_strike()
		KEY_ESCAPE:
			get_tree().quit()
		_ when key.keycode >= KEY_1 and key.keycode <= KEY_9:
			if _effect.has_method("toggle_layer"):
				_effect.toggle_layer(key.keycode - KEY_1)


func _process(delta: float) -> void:
	if _looping:
		_loop_timer += delta
		if _loop_timer >= loop_interval:
			_strike()
	_update_hud()


func _strike() -> void:
	_loop_timer = 0.0
	if striker:
		striker.strike(_effect.strength if "strength" in _effect else 1.0)
	else:
		_effect.play()


## Changes strength and strikes immediately, so the difference is seen right away.
func _change_strength(delta: float) -> void:
	if not "strength" in _effect:
		return
	_effect.strength = clampf(_effect.strength + delta, STRENGTH_STEP, 2.0)
	_strike()


func _reset() -> void:
	_looping = false
	Engine.time_scale = 1.0
	_effect.reset()
	if striker:
		striker.reset()
	_camera.reset_view()


func _set_debug(enabled: bool) -> void:
	_debug = enabled
	_debug_view.visible = enabled
	if _effect.has_method("set_debug"):
		_effect.set_debug(enabled)


func _update_hud() -> void:
	var lines := PackedStringArray([CONTROLS])
	lines.append("time scale %.2f   loop %s   debug %s" % [
		Engine.time_scale, "on" if _looping else "off", "on" if _debug else "off"])
	if "strength" in _effect:
		lines.append("strength %.2f   variation %d" % [_effect.strength, _effect.variation])
	if _effect.has_method("get_layer_status"):
		lines.append("layers (1-9 mute):   " + _effect.get_layer_status())
	if _debug and striker and striker.has_method("get_debug_text"):
		lines.append(striker.get_debug_text())
	if _debug and _effect.has_method("get_debug_text"):
		lines.append(_effect.get_debug_text())
	_info.text = "\n".join(lines)


## Origin axes (X red, Y green, Z blue, 1 m each) and a 1 m floor grid for judging scale.
func _build_debug_guides() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var grid := Color(0.3, 0.3, 0.3)
	var extent := 8
	for i in range(-extent, extent + 1):
		mesh.surface_set_color(grid)
		mesh.surface_add_vertex(Vector3(i, 0.01, -extent))
		mesh.surface_add_vertex(Vector3(i, 0.01, extent))
		mesh.surface_add_vertex(Vector3(-extent, 0.01, i))
		mesh.surface_add_vertex(Vector3(extent, 0.01, i))
	for axis in [[Vector3.RIGHT, Color.RED], [Vector3.UP, Color.GREEN], [Vector3.BACK, Color.BLUE]]:
		mesh.surface_set_color(axis[1])
		mesh.surface_add_vertex(Vector3(0.0, 0.02, 0.0))
		mesh.surface_add_vertex(axis[0] + Vector3(0.0, 0.02, 0.0))
	mesh.surface_end()
	return DebugDraw.make_view(mesh)
