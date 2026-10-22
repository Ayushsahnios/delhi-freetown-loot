extends CharacterBody3D
## Arcade drivable vehicle: auto-rickshaw, hatchback, or delivery van.
## Front points toward -Z (Godot convention).

const KINDS := {
	"auto": {"max_speed": 26.0, "accel": 13.0, "turn": 1.9},
	"car": {"max_speed": 34.0, "accel": 16.0, "turn": 1.55},
	"van": {"max_speed": 21.0, "accel": 9.0, "turn": 1.3},
}
const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

var driver_inside := false
## Traction 0..1 — monsoon wetness lowers it: wider turns, longer
## brake slides and momentum that keeps drifting through the turn.
var grip := 1.0

var _spec: Dictionary = KINDS["auto"]
var _wheels: Array[MeshInstance3D] = []
var _steer_pivots: Array[Node3D] = []
var _steer_vis := 0.0
var _speed := 0.0
var _rng := RandomNumberGenerator.new()


func setup(pos: Vector3, heading: float, kind := "auto") -> void:
	_spec = KINDS.get(kind, KINDS["auto"])
	# Local transform: this node may not be in the tree yet when spawned.
	position = pos
	rotation.y = heading
	match kind:
		"car":
			_build_car()
		"van":
			_build_van()
		_:
			_build_auto()


func _build_auto() -> void:
	var b := MeshTools.new()
	Vehicles.build_rickshaw_body(b)
	add_child(_body_node(b))
	for spec in Vehicles.RICKSHAW_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.2, 2.2, 4.3), Vector3(0, 1.15, 0))


func _build_car() -> void:
	var b := MeshTools.new()
	Vehicles.build_hatchback_body(b, _random_paint())
	add_child(_body_node(b))
	for spec in Vehicles.HATCH_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.1, 1.95, 4.25), Vector3(0, 1.0, 0))


func _build_van() -> void:
	var b := MeshTools.new()
	Vehicles.build_van_body(b, _random_paint())
	add_child(_body_node(b))
	for spec in Vehicles.VAN_WHEELS:
		_add_wheel(spec)
	_add_collision(Vector3(2.5, 3.0, 4.95), Vector3(0, 1.5, 0))


func _random_paint() -> Color:
	return Vehicles.PAINTS[_rng.randi_range(0, Vehicles.PAINTS.size() - 1)]


func _body_node(b: MeshTools) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	return mi


func _physics_process(_delta: float) -> void:
	if not driver_inside:
		velocity = Vector3.ZERO
		return


func current_speed() -> float:
	return absf(_speed)


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

	_speed += accel * float(_spec["accel"]) * delta
	if is_zero_approx(accel):
		_speed *= pow(lerpf(0.65, 0.35, grip), delta)
	_speed = clampf(_speed, -8.0, float(_spec["max_speed"]))

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

	# Front wheels visibly steer with input; all wheels spin with speed.
	_steer_vis = lerpf(_steer_vis, steer * 0.42, clampf(10.0 * delta, 0.0, 1.0))
	for p in _steer_pivots:
		p.rotation.y = _steer_vis
	for w in _wheels:
		w.rotation.x += _speed * delta * 2.0


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
