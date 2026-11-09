extends Node3D
## Stage 1 sandbox: plays the effect under EffectSlot with replay/reset/debug controls.
## An effect only needs play() and reset(); set_debug(bool), get_debug_text(),
## get_layer_status() and toggle_layer(index) are optional, as are `strength` and `variation` properties.
## An optional `striker` (strike(strength), reset(), `impacted` signal) gives the effect a cause:
## SPACE swings it, and the effect plays at the moment of impact.

const SLOW_MOTION := 0.2
const STRENGTH_STEP := 0.25
const TEST_PATTERN := preload("res://lab/test_pattern.gdshader")
const TuningPanel := preload("res://lab/tuning_panel.gd")
const BACKDROP_SIZE := Vector2(16.0, 8.0)
const BACKDROP_DISTANCE := 5.0
const CONTROLS := "SPACE strike   R reset   D debug   G test grid   TAB tune   T slow-mo   L loop   -/= strength   V variation   A anticipation   RMB drag orbit   wheel zoom   ESC quit"

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
var _test_grid := false
var _floor_material: Material
var _grid_floor := ShaderMaterial.new()
var _backdrop: MeshInstance3D
var _tuning_panel: Control

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

	_build_test_grid()
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
		KEY_G:
			_set_test_grid(not _test_grid)
		KEY_TAB:
			_toggle_tuning()
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
	if _test_grid:
		_place_backdrop()
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


## Tuning panel (effects with get_tunable_layers()): sliders for a layer's exported values.
## Built on first use; releasing a slider strikes so the change is seen at once.
func _toggle_tuning() -> void:
	if not _effect.has_method("get_tunable_layers"):
		return
	if not _tuning_panel:
		_tuning_panel = TuningPanel.new()
		_tuning_panel.effect = _effect
		_tuning_panel.committed.connect(_strike)
		_tuning_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_tuning_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
		$HUD.add_child(_tuning_panel)
		return
	_tuning_panel.visible = not _tuning_panel.visible


## Test grid: swaps the floor for a line grid and puts a gridded wall behind the scene, so
## distortion effects (the shockwave) have straight lines to bend. Plain flat colours hide them.
func _set_test_grid(enabled: bool) -> void:
	_test_grid = enabled
	$Floor.set_surface_override_material(0, _grid_floor if enabled else _floor_material)
	_backdrop.visible = enabled
	if enabled:
		_place_backdrop()


func _build_test_grid() -> void:
	_floor_material = $Floor.get_surface_override_material(0)
	_grid_floor.shader = TEST_PATTERN
	var wall_material := ShaderMaterial.new()
	wall_material.shader = TEST_PATTERN
	wall_material.set_shader_parameter("quad_size", BACKDROP_SIZE)
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	quad.material = wall_material
	_backdrop = MeshInstance3D.new()
	_backdrop.mesh = quad
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_backdrop.visible = false
	add_child(_backdrop)


## Keeps the wall upright on the far side of the scene from the camera, facing it.
func _place_backdrop() -> void:
	var away: Vector3 = -_camera.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	_backdrop.global_position = away * BACKDROP_DISTANCE + Vector3.UP * (BACKDROP_SIZE.y * 0.5)
	_backdrop.look_at(_backdrop.global_position + away, Vector3.UP)
	_backdrop.rotate_object_local(Vector3.UP, PI) # QuadMesh faces +Z; look_at points -Z


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
