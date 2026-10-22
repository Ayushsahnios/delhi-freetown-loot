extends CharacterBody3D
## Arcade drivable vehicle: auto-rickshaw, hatchback, or delivery van.
## Front points toward -Z (Godot convention).

const KINDS := {
	"auto": {"max_speed": 26.0, "accel": 13.0, "turn": 1.9},
	"car": {"max_speed": 34.0, "accel": 16.0, "turn": 1.55},
	"van": {"max_speed": 21.0, "accel": 9.0, "turn": 1.3},
}
const CAR_COLORS := [
	Color(0.75, 0.12, 0.12), Color(0.10, 0.22, 0.55), Color(0.85, 0.82, 0.78),
	Color(0.12, 0.14, 0.16), Color(0.55, 0.52, 0.20), Color(0.20, 0.45, 0.28),
]

var driver_inside := false
## Traction 0..1 — monsoon wetness lowers it: wider turns, longer
## brake slides and momentum that keeps drifting through the turn.
var grip := 1.0

var _spec: Dictionary = KINDS["auto"]
var _wheels: Array[MeshInstance3D] = []
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
	add_child(_box(Vector3(2.4, 1.3, 3.4), Color(0.18, 0.55, 0.20), Vector3(0, 1.0, 0)))
	add_child(_box(Vector3(2.4, 1.4, 2.2), Color(0.97, 0.77, 0.19), Vector3(0, 2.2, 0.2)))
	add_child(_box(Vector3(1.6, 1.1, 0.9), Color(0.97, 0.77, 0.19), Vector3(0, 1.35, -1.9)))
	for spec in [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]:
		_add_wheel(spec, 0.55)
	_add_collision(Vector3(2.6, 2.4, 3.8), Vector3(0, 1.4, 0))


func _build_car() -> void:
	var paint: Color = CAR_COLORS[_rng.randi_range(0, CAR_COLORS.size() - 1)]
	add_child(_box(Vector3(2.0, 0.9, 4.2), paint, Vector3(0, 0.85, 0)))
	add_child(_box(Vector3(1.8, 0.8, 2.2), Color(0.55, 0.65, 0.75), Vector3(0, 1.7, 0.2)))
	for spec in [Vector3(-1.0, 0.5, -1.4), Vector3(1.0, 0.5, -1.4), Vector3(-1.0, 0.5, 1.4), Vector3(1.0, 0.5, 1.4)]:
		_add_wheel(spec, 0.45)
	_add_collision(Vector3(2.2, 2.0, 4.4), Vector3(0, 1.2, 0))


func _build_van() -> void:
	var paint: Color = CAR_COLORS[_rng.randi_range(0, CAR_COLORS.size() - 1)]
	add_child(_box(Vector3(2.3, 1.3, 1.8), paint, Vector3(0, 1.15, -1.5)))
	add_child(_box(Vector3(2.3, 2.2, 2.9), Color(0.88, 0.86, 0.80), Vector3(0, 1.7, 1.0)))
	for spec in [Vector3(-1.05, 0.55, -1.5), Vector3(1.05, 0.55, -1.5), Vector3(-1.0, 0.55, 1.8), Vector3(1.0, 0.55, 1.8)]:
		_add_wheel(spec, 0.55)
	_add_collision(Vector3(2.5, 3.0, 5.0), Vector3(0, 1.6, 0))


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

	for w in _wheels:
		w.rotation.x += _speed * delta * 2.0


func _add_wheel(pos: Vector3, radius: float) -> void:
	var w := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.4
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.1, 0.11, 0.13)
	cm.material = wmat
	w.mesh = cm
	w.rotation.z = PI / 2.0
	w.position = pos
	add_child(w)
	_wheels.append(w)


func _add_collision(size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	add_child(col)


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	m.position = pos
	return m
