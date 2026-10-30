extends CharacterBody3D
## Arcade drivable vehicle: auto-rickshaw, hatchback, or delivery van.
## Front points toward -Z (Godot convention).

const KINDS := {
	"auto": {"max_speed": 26.0, "accel": 13.0, "turn": 1.9},
	"car": {"max_speed": 34.0, "accel": 16.0, "turn": 1.55},
	"van": {"max_speed": 21.0, "accel": 9.0, "turn": 1.3},
	"scooter": {"max_speed": 38.0, "accel": 18.0, "turn": 2.7},
}
## Cornering lean per kind (issue #154, free-roam feel): two- and
## three-wheelers tip INTO the turn, cars and vans roll to the outside.
## Radians of body roll at full steering lock and full speed.
const ROLL_LEAN := {
	"scooter": 0.10,
	"auto": 0.05,
	"car": -0.055,
	"van": -0.07,
}
const BRAKE_FACTOR := 2.4
const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")
const Exhaust := preload("res://scripts/exhaust.gd")

var driver_inside := false
## Traction 0..1 — monsoon wetness lowers it: wider turns, longer
## brake slides and momentum that keeps drifting through the turn.
var grip := 1.0

## Speed bumps crossed (issue #69) feed a scripted suspension jolt:
## the city is kinematic, so the physical effect lives here.
signal bump_hit(strength: float)

var _bumps: Array = []
var _jolt := 0.0
var _body_mesh: MeshInstance3D = null
var _prev_pos := Vector3.INF  # INF = skip the crossing test on first frame
## Whole-trip crash tally (issue #203 tip tiers): a hard slide contact
## while moving at speed counts once per ~second, so wall scrapes do not
## spam it. The taxi reads snapshots of this to grade rides.
var _crashes := 0
var _crash_cool := 0.0

var _spec: Dictionary = KINDS["auto"]
var _wheels: Array[MeshInstance3D] = []
var _steer_pivots: Array[Node3D] = []
var _steer_vis := 0.0
var _speed := 0.0
var _telem_accel := 0.0   # last pedal input, for the audio heartbeats (#213)
var _telem_steer := 0.0
var _telem_braking := false
var _pitch_vis := 0.0
var _roll_vis := 0.0
var _tyre_t := 0.0
var _rng := RandomNumberGenerator.new()
var _exhaust: Node3D = null
var _puff_t := 0.6


## Body kind ("auto"/"car"/"van"/"scooter") — public so systems like
## the taxi hustle can gate on riding the rickshaw.
var kind := "auto"


func setup(pos: Vector3, heading: float, kind := "auto") -> void:
	_spec = KINDS.get(kind, KINDS["auto"])
	self.kind = kind
	# Local transform: this node may not be in the tree yet when spawned.
	position = pos
	rotation.y = heading
	match kind:
		"car":
			_build_car()
		"van":
			_build_van()
		"scooter":
			_build_scooter()
		_:
			_build_auto()
	ShadowBlob.attach(self, 1.6, 0.07)
	# Idle exhaust (issue #166): the puff pool lives in world space so
	# smoke stays put while the vehicle drives away from it.
	_exhaust = Exhaust.new()
	_exhaust.top_level = true
	add_child(_exhaust)


func _build_auto() -> void:
	var b := MeshTools.new()
	Vehicles.build_rickshaw_body(b)
	_body_mesh = _body_node(b)
	add_child(_body_mesh)
	for spec in Vehicles.RICKSHAW_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.2, 2.2, 4.3), Vector3(0, 1.15, 0))


func _build_car() -> void:
	var b := MeshTools.new()
	Vehicles.build_hatchback_body(b, _random_paint())
	_body_mesh = _body_node(b)
	add_child(_body_mesh)
	for spec in Vehicles.HATCH_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.1, 1.95, 4.25), Vector3(0, 1.0, 0))


func _build_van() -> void:
	var b := MeshTools.new()
	Vehicles.build_van_body(b, _random_paint())
	_body_mesh = _body_node(b)
	add_child(_body_mesh)
	for spec in Vehicles.VAN_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.5, 3.0, 4.95), Vector3(0, 1.5, 0))


func _build_scooter() -> void:
	## Issue #98: fast, nimble step-through — quickest top speed and the
	## sharpest steering of the fleet, sized for threading traffic.
	var b := MeshTools.new()
	Vehicles.build_scooter_body(b, _random_paint())
	_body_mesh = _body_node(b)
	add_child(_body_mesh)
	for spec in Vehicles.SCOOTER_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(1.2, 1.6, 2.7), Vector3(0, 0.8, 0))


func _random_paint() -> Color:
	return Vehicles.PAINTS[_rng.randi_range(0, Vehicles.PAINTS.size() - 1)]


func _body_node(b: MeshTools) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	return mi


func set_speed_bumps(bumps: Array) -> void:
	## Street furniture (issue #69) registers its raised crossings.
	_bumps = bumps


func hit_bump(strength: float) -> void:
	## Wheels just took a raised strip: the chassis dips and speed bleeds
	## off with the impact.
	_speed *= clampf(1.0 - 0.45 * strength, 0.3, 1.0)
	_jolt = clampf(_jolt + strength, 0.0, 1.2)


func _check_bumps() -> void:
	## A bump is hit when the chassis crosses its strip line while on
	## that road (inside the lane band); strength scales with speed.
	if _bumps.is_empty() or _prev_pos == Vector3.INF:
		return
	var p := global_position
	for bump: Dictionary in _bumps:
		var along_now: float = (p.x - bump.x) if bump.along_x else (p.z - bump.z)
		var along_prev: float = (_prev_pos.x - bump.x) if bump.along_x \
				else (_prev_pos.z - bump.z)
		var lateral: float = absf(p.z - bump.z) if bump.along_x \
				else absf(p.x - bump.x)
		if lateral < 5.6 and along_now * along_prev < 0.0 \
				and absf(_speed) > 1.0:
			var strength := clampf(absf(_speed) / 18.0, 0.25, 1.0)
			hit_bump(strength)
			bump_hit.emit(strength)
			return


func _physics_process(_delta: float) -> void:
	if not driver_inside:
		velocity = Vector3.ZERO
		return


func current_speed() -> float:
	return absf(_speed)


func engine_telemetry() -> Dictionary:
	## Engine voice pack (issue #213): one call hands the audio system
	## everything the hum, brake squeal and indicator tick need — speed
	## as a ratio of THIS kind's top speed, pedal state, the brake event
	## and steering input.
	return {
		"ratio": clampf(absf(_speed) / float(_spec["max_speed"]), 0.0, 1.0),
		"accel": _telem_accel,
		"steer": _telem_steer,
		"braking": _telem_braking,
	}


func crash_count() -> int:
	## Public snapshot for systems grading a ride (taxi tip tiers).
	return _crashes


func tyre_burst(duration := 7.0) -> void:
	## Spike-strip puncture (issue #188): top speed and pickup collapse
	## until the spare set goes on. Refreshes the timer if re-spiked.
	_tyre_t = maxf(_tyre_t, duration)


func tyre_burst_active() -> bool:
	return _tyre_t > 0.0


func drive(delta: float) -> void:
	## Called by Main while this vehicle is the active one.
	var accel := 0.0
	var steer := 0.0
	if Input.is_action_pressed("move_forward"):
		accel = 1.0
	if Input.is_action_pressed("move_back"):
		accel = -1.0
	if Input.is_action_pressed("move_left"):
		steer = 1.0
	if Input.is_action_pressed("move_right"):
		steer = -1.0

	# Pedal feel (issue #154): holding the opposite direction BRAKES at
	# a sharper rate than acceleration builds; releasing just coasts.
	# Shredded tyres (spike strip) cap speed and pickup until they are
	# swapped — the chase keeps moving, just horribly.
	var max_speed := float(_spec["max_speed"])
	var accel_rate := float(_spec["accel"])
	if _tyre_t > 0.0:
		_tyre_t = maxf(_tyre_t - delta, 0.0)
		max_speed *= 0.45
		accel_rate *= 0.6
	var braking := accel != 0.0 and absf(_speed) > 0.5 and signf(accel) != signf(_speed)
	_telem_accel = accel
	_telem_steer = steer
	_telem_braking = braking
	if braking:
		_speed += accel * accel_rate * BRAKE_FACTOR * delta
	elif not is_zero_approx(accel):
		_speed += accel * accel_rate * delta
	else:
		_speed *= pow(lerpf(0.65, 0.35, grip), delta)
	_speed = clampf(_speed, -8.0, max_speed)

	if absf(_speed) > 0.5:
		rotate_y(steer * float(_spec["turn"]) * lerpf(0.6, 1.0, grip) * delta * _speed / float(_spec["max_speed"]))
		var fwd := -global_transform.basis.z * _speed
		if grip >= 0.999:
			velocity = fwd
		else:
			# Hydroplaning lite: heading swings over before momentum follows.
			var follow: float = clampf(lerpf(2.2, 12.0, grip) * delta, 0.0, 1.0)
			velocity = velocity.lerp(fwd, follow)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

	# Crash tally (issue #203): contact while still travelling at speed,
	# rate-limited so a grind along one wall is one knock, not thirty.
	if _crash_cool > 0.0:
		_crash_cool = maxf(_crash_cool - delta, 0.0)
	elif get_slide_collision_count() > 0 and absf(_speed) > 6.0:
		_crashes += 1
		_crash_cool = 0.9

	# Speed bumps (issue #69): kinematic crossing test, then the
	# suspension settles — body dips and noses down as the jolt decays.
	_check_bumps()
	_jolt = maxf(_jolt - 2.6 * delta, 0.0)
	# Weight transfer (issue #154): brake dive, throttle squat and
	# cornering roll ride on top of the bump jolt — the chassis now
	# breathes with every pedal input instead of sitting level.
	var ratio := clampf(absf(_speed) / float(_spec["max_speed"]), 0.0, 1.0)
	var pitch_target := 0.0
	if braking:
		pitch_target = 0.05 * maxf(ratio, 0.4)
	elif accel > 0.0:
		pitch_target = -0.022 * ratio
	var roll_target := steer * ratio * float(ROLL_LEAN.get(kind, 0.0))
	_pitch_vis = lerpf(_pitch_vis, pitch_target, clampf(8.0 * delta, 0.0, 1.0))
	_roll_vis = lerpf(_roll_vis, roll_target, clampf(6.0 * delta, 0.0, 1.0))
	if _body_mesh != null:
		_body_mesh.position.y = -0.10 * _jolt
		_body_mesh.rotation.x = -0.12 * _jolt + _pitch_vis
		_body_mesh.rotation.z = _roll_vis
	_prev_pos = global_position

	# Front wheels visibly steer with input; all wheels spin with speed.
	_steer_vis = lerpf(_steer_vis, steer * 0.42, clampf(10.0 * delta, 0.0, 1.0))
	for p in _steer_pivots:
		p.rotation.y = _steer_vis
	for w in _wheels:
		w.rotation.x += _speed * delta * 2.0

	# Idle exhaust (issue #166): a soft puff every beat while parked with
	# the engine on; any speed at all clears the pipe.
	if absf(_speed) < 0.6:
		_puff_t += delta
		if _puff_t >= 0.8:
			_puff_t = 0.0
			var off: Vector3 = Vehicles.EXHAUST_POS.get(kind, Vector3.ZERO)
			_exhaust.spawn(global_transform * off,
					Vector3(0.1, 0.5, 0.0) + global_transform.basis.z * 0.35,
					0.12 if kind == "scooter" else 0.22)
	else:
		_puff_t = 0.6  # first puff after a stop comes quickly


func _add_wheel(spec: Dictionary) -> void:
	var pivot := Node3D.new()
	pivot.position = spec["pos"]
	add_child(pivot)
	var w := MeshInstance3D.new()
	w.mesh = Vehicles.wheel_mesh(spec)
	w.rotation.z = PI / 2.0
	pivot.add_child(w)
	_wheels.append(w)
	if spec["steer"]:
		_steer_pivots.append(pivot)


func _add_collision(size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	add_child(col)
