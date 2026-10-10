extends Node3D
## Effect layer wrapping a GPUParticles3D child named "Particles".
##
## One-shot particles fire once as a burst. Continuous particles emit for
## emit_duration while the emission rate tapers off, so the layer ends gradually
## instead of stopping dead. All particle behaviour lives in the scene's resources
## (select Particles and expand its Process Material); this script only handles
## triggering, delay, determinism and the debug view.

## Wait after play() before emitting.
@export_range(0.0, 5.0, 0.01, "suffix:s") var start_delay := 0.0
## Continuous particles only: how long to keep emitting.
@export_range(0.1, 10.0, 0.05, "suffix:s") var emit_duration := 1.5
## Continuous particles only: emission rate over emit_duration is 1 - ease(t).
## Below 1 = drops early; above 1 = holds, then drops.
@export_exp_easing var emit_taper := 1.0
## Same seed = identical particles on every replay.
@export var burst_seed := 1
@export var debug_marker_color := Color(1.0, 0.5, 0.15)

@export_group("Strength")
## Particle speed scales by strength^power. 0 = speed unaffected by strength.
@export_range(0.0, 2.0, 0.05) var strength_speed_power := 0.7
## Weaker strikes emit fewer particles. Never more than the authored amount.
@export var strength_affects_amount := true

const SPEED_PROPERTIES := [
	"initial_velocity_min", "initial_velocity_max", "radial_velocity_min", "radial_velocity_max"]

var _elapsed := 0.0
var _playing := false
var _emitted := false
var _draw_mesh: Mesh
var _debug_mesh := QuadMesh.new()
var _strength := 1.0
var _seed_offset := 0
var _process_material: ParticleProcessMaterial
var _base_speeds := {}

@onready var _particles: GPUParticles3D = $Particles


func _ready() -> void:
	# Debug view: small opaque unlit markers, so each particle's path and spread is readable.
	var debug_material := StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	debug_material.billboard_keep_scale = true
	debug_material.albedo_color = debug_marker_color
	_debug_mesh.size = Vector2.ONE * 0.08
	_debug_mesh.material = debug_material
	_draw_mesh = _particles.draw_pass_1
	# Own copy of the process material, so strength can scale speeds from the authored values.
	_process_material = _particles.process_material.duplicate()
	_particles.process_material = _process_material
	for property in SPEED_PROPERTIES:
		_base_speeds[property] = _process_material.get(property)
	reset()


func play() -> void:
	_elapsed = -start_delay
	_playing = true
	_emitted = false
	if _elapsed >= 0.0:
		_start()


## Scales speed (and, below 1, particle count) for a weaker or stronger strike.
## Applies from the next play().
func set_strength(value: float) -> void:
	_strength = maxf(value, 0.05)
	var k := pow(_strength, strength_speed_power)
	for property in _base_speeds:
		_process_material.set(property, _base_speeds[property] * k)


## Offsets the seed: same behaviour, different individual particles.
func set_variation(index: int) -> void:
	_seed_offset = index * 101


func is_active() -> bool:
	return _playing


func reset() -> void:
	_playing = false
	_emitted = false
	_particles.emitting = false
	_particles.visible = false


func set_debug(enabled: bool) -> void:
	_particles.draw_pass_1 = _debug_mesh if enabled else _draw_mesh


func get_debug_text() -> String:
	if not _playing:
		return "%s: idle" % name
	if not _emitted:
		return "%s: waiting %.2fs" % [name, -_elapsed]
	var rate := "" if _particles.one_shot else "   rate %d%%" % int(100.0 * _particles.amount_ratio * float(_particles.emitting))
	return "%s: %.2fs / %.2fs   %d particles%s   seed %d" % [
		name, _elapsed, _total_time(), int(_particles.amount * _amount_scale()), rate, burst_seed + _seed_offset]


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if not _emitted:
		if _elapsed < 0.0:
			return
		_start()
	if not _particles.one_shot:
		var t := _elapsed / emit_duration
		if t >= 1.0:
			_particles.emitting = false
		else:
			_particles.amount_ratio = (1.0 - ease(t, emit_taper)) * _amount_scale()
	# After the last particle could have died, the layer is done.
	if _elapsed >= _total_time():
		_playing = false


func _amount_scale() -> float:
	return minf(_strength, 1.0) if strength_affects_amount else 1.0


func _total_time() -> float:
	return (0.0 if _particles.one_shot else emit_duration) + _particles.lifetime


func _start() -> void:
	_emitted = true
	_particles.seed = burst_seed + _seed_offset
	_particles.amount_ratio = _amount_scale()
	_particles.visible = true
	_particles.restart(true)
	_particles.emitting = true
