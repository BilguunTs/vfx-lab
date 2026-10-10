extends Node3D
## A procedural stand-in for a shaman's frame drum on a tripod, with a beater that
## strikes it. Gives the effect a visible cause and an anticipation phase:
##   windup (slow, anticipation) -> swing (fast) -> impact -> rebound.
## On impact it emits `impacted`, tips back on a damped spring and sends a ripple of
## light across the skin. The lab plays the effect layers on `impacted`.

signal impacted

const SKIN_SHADER := preload("res://experiments/05_drum_strike/drum_skin.gdshader")
## Strikes requested mid-swing are queued, up to this many.
const MAX_QUEUED := 3

enum Phase { REST, WINDUP, SWING, REBOUND }

@export_group("Shape")
@export_range(0.15, 1.0, 0.01, "suffix:m") var drum_radius := 0.36
## Height of the drum's centre above the ground.
@export_range(0.3, 2.0, 0.01, "suffix:m") var drum_height := 0.85
@export var wood_color := Color(0.2, 0.13, 0.08)
@export var hide_color := Color(0.6, 0.5, 0.36)

@export_group("Beater")
## Off: the beater swings straight from rest, with no windup. Compare both.
@export var anticipation := true
@export_range(0.0, 90.0, 1.0, "suffix:°") var rest_angle := 30.0
@export_range(0.0, 120.0, 1.0, "suffix:°") var windup_angle := 80.0
@export_range(0.01, 1.0, 0.01, "suffix:s") var windup_time := 0.25
@export_range(0.01, 0.5, 0.005, "suffix:s") var swing_time := 0.07
@export_range(0.05, 2.0, 0.01, "suffix:s") var rebound_time := 0.45

@export_group("Recoil")
## Tilt speed given to the drum on impact, in rad/s at strength 1.
@export_range(0.0, 5.0, 0.05) var recoil := 1.2
## Wobble frequency of the drum on its stand.
@export_range(0.5, 10.0, 0.1, "suffix:Hz") var recoil_frequency := 3.0
## 0 = wobbles forever, 1 = no wobble.
@export_range(0.0, 1.0, 0.01) var recoil_damping := 0.25

var _phase := Phase.REST
var _phase_time := 0.0
var _from_angle := 0.0
var _angle := 0.0
var _strength := 1.0
var _tilt := 0.0
var _tilt_velocity := 0.0
var _ripple_time := 100.0
var _queued := 0

var _body_pivot: Node3D # tilts on recoil; sits where the drum rests on the stand
var _beater_pivot: Node3D # the (invisible) hand holding the beater
var _skin_material := ShaderMaterial.new()


func _ready() -> void:
	_build()
	reset()


## Starts a strike: windup (if anticipation), swing, then `impacted` at contact.
## Strikes requested while the beater is already on its way are queued: each starts the
## moment the previous one lands, the beater going straight from the skin into the next
## windup — a drumming rhythm instead of a restarted swing.
func strike(strength := 1.0) -> void:
	_strength = strength
	if _phase == Phase.WINDUP or _phase == Phase.SWING:
		_queued = mini(_queued + 1, MAX_QUEUED)
		return
	_begin_strike()


func reset() -> void:
	_queued = 0
	_set_phase(Phase.REST)
	_angle = rest_angle
	_tilt = 0.0
	_tilt_velocity = 0.0
	_ripple_time = 100.0
	_update_pose()


func get_debug_text() -> String:
	return "%s: %s   beater %.0f°   tilt %.1f°   queued %d   anticipation %s" % [
		name, Phase.keys()[_phase], _angle, rad_to_deg(_tilt), _queued, "on" if anticipation else "off"]


func _process(delta: float) -> void:
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			var t := minf(_phase_time / windup_time, 1.0)
			# Slow in, slow out: the beater gathers, then hangs for an instant at the top.
			_angle = lerpf(_from_angle, _windup_target(), smoothstep(0.0, 1.0, t))
			if t >= 1.0:
				_from_angle = _angle
				_set_phase(Phase.SWING)
		Phase.SWING:
			var t := minf(_phase_time / swing_time, 1.0)
			# Accelerates into the skin.
			_angle = lerpf(_from_angle, 0.0, pow(t, 2.5))
			if t >= 1.0:
				_angle = 0.0
				_impact()
				if _queued > 0:
					_queued -= 1
					_begin_strike()
				else:
					_set_phase(Phase.REBOUND)
		Phase.REBOUND:
			var t := minf(_phase_time / rebound_time, 1.0)
			_angle = lerpf(0.0, rest_angle, 1.0 - pow(1.0 - t, 3.0))
			if t >= 1.0:
				_set_phase(Phase.REST)

	# Damped spring: the drum tips back on its stand and settles.
	var omega := TAU * recoil_frequency
	var accel := -omega * omega * _tilt - 2.0 * recoil_damping * omega * _tilt_velocity
	_tilt_velocity += accel * delta
	_tilt += _tilt_velocity * delta
	_ripple_time += delta
	_update_pose()


func _begin_strike() -> void:
	_from_angle = _angle
	_set_phase(Phase.WINDUP if anticipation else Phase.SWING)


func _impact() -> void:
	_tilt_velocity += recoil * _strength
	_ripple_time = 0.0
	_skin_material.set_shader_parameter("ripple_strength", _strength)
	impacted.emit()


func _windup_target() -> float:
	# A harder strike is drawn back further.
	return minf(windup_angle * pow(_strength, 0.3), 120.0)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _update_pose() -> void:
	# The beater points from the hand toward the skin; positive angles lift it away.
	_beater_pivot.rotation.x = deg_to_rad(_angle)
	# Negative tilt = top of the drum moves away from the beater.
	_body_pivot.rotation.x = -_tilt
	_skin_material.set_shader_parameter("ripple_time", _ripple_time)


# --- Construction -------------------------------------------------------------
# Drum-local axes: the skin faces +Z, up is +Y. The beater strikes from the +Z side.

func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = wood_color
	wood.roughness = 0.9
	var hide := StandardMaterial3D.new()
	hide.albedo_color = hide_color.darkened(0.3)
	hide.roughness = 0.9

	var bottom := drum_height - drum_radius
	_body_pivot = Node3D.new()
	_body_pivot.position.y = bottom
	add_child(_body_pivot)
	var body := Node3D.new()
	body.position.y = drum_radius
	_body_pivot.add_child(body)

	# Rim: a torus stretched along its axis into a shallow frame, low-poly on purpose.
	var rim := TorusMesh.new()
	rim.inner_radius = drum_radius - 0.01
	rim.outer_radius = drum_radius + 0.035
	rim.rings = 24
	rim.ring_segments = 6
	var rim_view := _add_mesh(body, rim, wood)
	rim_view.rotation.x = PI / 2.0
	rim_view.scale = Vector3(1.0, 2.6, 1.0)

	# Skin: a thin disc at the front of the rim.
	_skin_material.shader = SKIN_SHADER
	_skin_material.set_shader_parameter("hide_color", hide_color)
	_skin_material.set_shader_parameter("radius", drum_radius)
	var skin := CylinderMesh.new()
	skin.top_radius = drum_radius
	skin.bottom_radius = drum_radius
	skin.height = 0.012
	skin.radial_segments = 32
	skin.rings = 1
	var skin_view := _add_mesh(body, skin, _skin_material)
	skin_view.rotation.x = PI / 2.0
	skin_view.position.z = 0.03

	# Cross-shaped handle behind the skin.
	for angle in [PI / 4.0, -PI / 4.0]:
		var bar := BoxMesh.new()
		bar.size = Vector3(drum_radius * 1.8, 0.022, 0.022)
		var bar_view := _add_mesh(body, bar, wood)
		bar_view.position.z = -0.03
		bar_view.rotation.z = angle

	# Tripod stand: three legs from the ground to just under the drum.
	var top := Vector3(0.0, bottom + 0.02, 0.0)
	for k in 3:
		var a := TAU * k / 3.0 + PI / 2.0
		_add_stick(self, Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), top, 0.015, wood)

	# Beater: held by an invisible hand in front of the skin, slightly off-centre
	# (real strikes rarely land dead centre).
	var head_reach := 0.4
	var contact := Vector2(0.12, 0.06)
	_beater_pivot = Node3D.new()
	_beater_pivot.position = Vector3(contact.x, drum_height + contact.y, 0.085 + head_reach)
	add_child(_beater_pivot)
	_add_stick(_beater_pivot, Vector3.ZERO, Vector3(0.0, 0.0, -head_reach + 0.04), 0.011, wood)
	var head := SphereMesh.new()
	head.radius = 0.045
	head.height = 0.09
	head.radial_segments = 8
	head.rings = 4
	var head_view := _add_mesh(_beater_pivot, head, hide)
	head_view.position.z = -head_reach
	head_view.scale = Vector3(1.0, 1.0, 0.75)

	# The skin disc is rotated +90° about X, so drum-up (+Y) is the skin mesh's -Z.
	_skin_material.set_shader_parameter("impact_point", Vector2(contact.x, -contact.y))


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	parent.add_child(view)
	return view


## A thin cylinder from `a` to `b` (in `parent` space).
func _add_stick(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var stick := CylinderMesh.new()
	stick.top_radius = radius
	stick.bottom_radius = radius
	stick.height = a.distance_to(b)
	stick.radial_segments = 6
	stick.rings = 1
	var view := _add_mesh(parent, stick, material)
	var direction := (b - a).normalized()
	view.basis = Basis(Quaternion(Vector3.UP, direction))
	view.position = (a + b) * 0.5
