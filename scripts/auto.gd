extends CharacterBody3D
## Arcade auto-rickshaw. Front points toward -Z (Godot convention).

const MAX_SPEED := 26.0
const ACCEL := 13.0
const TURN := 1.9

var driver_inside := false

var _wheels: Array[MeshInstance3D] = []
var _speed := 0.0


func setup(pos: Vector3, heading: float) -> void:
	# Local transform: this node may not be in the tree yet when spawned.
	position = pos
	rotation.y = heading

	var chassis := _box(Vector3(2.4, 1.3, 3.4), Color(0.18, 0.55, 0.20))
	chassis.position.y = 1.0
	add_child(chassis)

	var canopy := _box(Vector3(2.4, 1.4, 2.2), Color(0.97, 0.77, 0.19))
	canopy.position = Vector3(0, 2.2, 0.2)
	add_child(canopy)

	var front := _box(Vector3(1.6, 1.1, 0.9), Color(0.97, 0.77, 0.19))
	front.position = Vector3(0, 1.35, -1.9)
	add_child(front)

	var wheel_specs := [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]
	for spec in wheel_specs:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.4
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.1, 0.11, 0.13)
		cm.material = wmat
		w.mesh = cm
		w.rotation.z = PI / 2.0
		w.position = spec
		add_child(w)
		_wheels.append(w)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.4, 3.8)
	col.shape = box
	col.position.y = 1.4
	add_child(col)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	return m


func _physics_process(_delta: float) -> void:
	if not driver_inside:
		velocity = Vector3.ZERO
		return


func drive(delta: float) -> void:
	## Called by Main while this auto is the active vehicle.
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

	_speed += accel * ACCEL * delta
	if is_zero_approx(accel):
		_speed *= pow(0.35, delta)
	_speed = clampf(_speed, -8.0, MAX_SPEED)

	if absf(_speed) > 0.5:
		rotate_y(steer * TURN * delta * _speed / MAX_SPEED)
		velocity = -global_transform.basis.z * _speed
	else:
		velocity = Vector3.ZERO
	move_and_slide()

	for w in _wheels:
		w.rotation.x += _speed * delta * 2.0
