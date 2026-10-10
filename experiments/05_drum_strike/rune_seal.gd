extends Node3D
## Drum strike layer (Phase C): a seal of procedural glyphs that ignites on the
## strike, cools from ember to dark red, then burns away.
##
## Same split as the energy ring: this script owns timing and pushes uniforms;
## rune_seal.gdshader only draws the seal for given front / heat / dissolve values.
##
## Ignition follows a front radius: glyph strokes light up where the front has passed and
## flare just behind it. With an ignition_source (the pulse ring) the wave writes the runes
## into the ground; without one, the front sweeps across the seal on its own.

const SEAL_SHADER := preload("res://experiments/05_drum_strike/rune_seal.gdshader")
const GROUND_OFFSET := 0.015

@export_group("Shape")
@export_range(0.2, 4.0, 0.01, "suffix:m") var inner_radius := 0.85
@export_range(0.3, 5.0, 0.01, "suffix:m") var outer_radius := 1.45
@export_range(3, 32) var glyph_count := 14
@export_range(0.005, 0.15, 0.001, "suffix:m") var stroke_width := 0.04

@export_group("Timing")
## Layer whose expanding front ignites the seal. Needs get_front_radius(). If empty or
## muted, the seal ignites on its own over ignite_time.
@export var ignition_source: Node3D
@export_range(0.0, 2.0, 0.01, "suffix:s") var start_delay := 0.0
## Fallback only: time for the front to sweep across the seal without an ignition source.
@export_range(0.01, 1.0, 0.01, "suffix:s") var ignite_time := 0.15
## Time from hot (hot_color) to cooled (cool_color).
@export_range(0.05, 4.0, 0.05, "suffix:s") var cool_time := 0.9
## When the burn-away starts; it ends at lifetime.
@export_range(0.0, 5.0, 0.05, "suffix:s") var dissolve_start := 0.9
@export_range(0.2, 6.0, 0.05, "suffix:s") var lifetime := 2.4
## Slow drift of the whole seal, in degrees per second. Small values feel alive; large ones feel mechanical.
@export_range(-90.0, 90.0, 0.5, "suffix:°/s") var rotation_speed := 3.0

@export_group("Look")
@export var hot_color := Color(1.0, 0.68, 0.38)
@export var cool_color := Color(0.42, 0.1, 0.05)
@export_range(0.0, 8.0, 0.05) var intensity := 1.6
## Extra brightness of strokes the front has just passed.
@export_range(0.0, 5.0, 0.05) var impact_flash := 1.5
## How far behind the front the flare reaches before it settles.
@export_range(0.05, 3.0, 0.05, "suffix:m") var flare_length := 0.8

@export_group("Variation")
## Picks the glyph shapes, ignition order, wear and burn pattern.
@export var noise_seed := 3

var _elapsed := 0.0
var _playing := false
var _debug := false
var _front := 0.0
var _heat := 0.0
var _dissolve := 0.0
var _strength := 1.0
var _seed_offset := 0

var _plane := PlaneMesh.new()
var _material := ShaderMaterial.new()
var _seal: MeshInstance3D
var _debug_mesh := ImmediateMesh.new()
var _debug_view: MeshInstance3D


func _ready() -> void:
	_material.shader = SEAL_SHADER
	_seal = MeshInstance3D.new()
	_seal.mesh = _plane
	_seal.material_override = _material
	_seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seal.position.y = GROUND_OFFSET
	add_child(_seal)

	_debug_view = DebugDraw.make_view(_debug_mesh)
	_debug_view.visible = false
	add_child(_debug_view)

	reset()


func play() -> void:
	_elapsed = -start_delay
	_playing = true
	_front = 0.0
	_plane.size = Vector2.ONE * (outer_radius + 0.2) * 2.0
	_seal.visible = _elapsed >= 0.0
	if _seal.visible:
		_apply()


## Weaker strikes ignite the seal dimly and briefly; stronger ones burn hotter, flare
## further behind the front and smoulder longer. Applies from the next play().
func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)


## Offsets the seed: a different set of glyphs, wear and burn pattern.
func set_variation(index: int) -> void:
	_seed_offset = index * 101


func is_active() -> bool:
	return _playing


func reset() -> void:
	_playing = false
	_elapsed = 0.0
	_seal.visible = false


func set_debug(enabled: bool) -> void:
	_debug = enabled
	_debug_view.visible = enabled


func get_debug_text() -> String:
	if not _playing:
		return "%s: idle" % name
	if _elapsed < 0.0:
		return "%s: waiting %.2fs" % [name, -_elapsed]
	return "%s: %.2fs / %.2fs   front %.2fm (%s)   heat %.2f   dissolve %.2f" % [
		name, _elapsed, _lifetime(), _front, "source" if _source_active() else "timed", _heat, _dissolve]


func _process(delta: float) -> void:
	if _playing:
		_elapsed += delta
		if _elapsed >= _lifetime():
			reset()
		elif _elapsed >= 0.0:
			_seal.visible = true
			_apply()
	if _debug:
		_draw_debug()


func _apply() -> void:
	_front = maxf(_front, _current_front())
	# Cools fast at first, then lingers in the dark-red range.
	_heat = 1.0 - ease(clampf(_elapsed / (cool_time * sqrt(_strength)), 0.0, 1.0), 0.5)
	# Burn-away accelerates toward the end.
	var burn_start := dissolve_start * pow(_strength, 0.3)
	var burn_t := clampf((_elapsed - burn_start) / maxf(_lifetime() - burn_start, 0.01), 0.0, 1.0)
	_dissolve = ease(burn_t, 1.6)

	_material.set_shader_parameter("front_radius", _front)
	_material.set_shader_parameter("impact_flash", impact_flash * _strength)
	_material.set_shader_parameter("flare_length", flare_length * _strength)
	_material.set_shader_parameter("heat", _heat)
	_material.set_shader_parameter("dissolve", _dissolve)
	_material.set_shader_parameter("intensity", intensity * _strength)
	_material.set_shader_parameter("hot_color", hot_color)
	_material.set_shader_parameter("cool_color", cool_color)
	_material.set_shader_parameter("inner_radius", inner_radius)
	_material.set_shader_parameter("outer_radius", outer_radius)
	_material.set_shader_parameter("glyph_count", float(glyph_count))
	_material.set_shader_parameter("stroke_width", stroke_width)
	_material.set_shader_parameter("rotation", deg_to_rad(rotation_speed * _elapsed))
	_material.set_shader_parameter("noise_seed", float(noise_seed + _seed_offset))


func _lifetime() -> float:
	return lifetime * pow(_strength, 0.3)


func _draw_debug() -> void:
	_debug_mesh.clear_surfaces()
	var guide := Color(1.0, 0.6, 0.3)
	DebugDraw.circle(_debug_mesh, inner_radius, guide)
	DebugDraw.circle(_debug_mesh, outer_radius, guide)
	if _playing and _front > 0.0 and _front < outer_radius + flare_length:
		DebugDraw.circle(_debug_mesh, _front, Color(1.0, 0.25, 0.1))


func _source_active() -> bool:
	return ignition_source != null and ignition_source.is_visible_in_tree() 			and ignition_source.has_method("get_front_radius")


## Front radius this frame. It only ever grows (see _apply), so the seal stays lit after the
## ring has faded. While the source waits out its own delay it reports -1: no ignition yet.
func _current_front() -> float:
	if _source_active():
		return ignition_source.get_front_radius()
	var sweep := inner_radius - 0.1 + (outer_radius - inner_radius + 0.2) * _elapsed / ignite_time
	return sweep
