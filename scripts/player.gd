extends CharacterBody3D
## Third-person on-foot player with procedural low-poly visuals.
## Sardar characters get turban + beard.

const WALK_SPEED := 6.5
const RUN_SPEED := 11.5

var run_boost := 1.0

var _legs: Array[MeshInstance3D] = []
var _arms: Array[MeshInstance3D] = []
var _walk_phase := 0.0


func setup(def: Dictionary) -> void:
	run_boost = 1.18 if String(def.get("id")) == "riya" else 1.0

	var body := _box(Vector3(2.0, 2.6, 1.1), def["shirt"])
	body.position.y = 3.0
	add_child(body)

	var head := _box(Vector3(1.15, 1.15, 1.15), def["skin"])
	head.position.y = 4.9
	add_child(head)

	for side in [-0.55, 0.55]:
		var leg := _box(Vector3(0.75, 1.8, 0.8), def["pants"])
		leg.position = Vector3(side, 0.9, 0)
		add_child(leg)
		_legs.append(leg)
	for side in [-1.35, 1.35]:
		var arm := _box(Vector3(0.6, 2.0, 0.6), def["skin"])
		arm.position = Vector3(side, 3.1, 0)
		add_child(arm)
		_arms.append(arm)

	if def.get("sardar", false):
		var turban := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.78
		tm.height = 1.15
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = def["turban"]
		tm.material = tmat
		turban.mesh = tm
		turban.position.y = 5.55
		add_child(turban)
		var beard := _box(Vector3(1.0, 0.9, 0.35), Color(0.17, 0.13, 0.09))
		beard.position = Vector3(0, 4.45, 0.62)
		add_child(beard)
	else:
		var hair := _box(Vector3(1.2, 0.4, 1.2), Color(0.12, 0.09, 0.06))
		hair.position.y = 5.45
		add_child(hair)

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 6.0
	col.shape = capsule
	col.position.y = 3.0
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


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var input := Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0.0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var moving := input.length() > 0.05
	if moving:
		var speed: float = WALK_SPEED
		if Input.is_action_pressed("run"):
			speed = RUN_SPEED
		speed *= run_boost
		velocity.x = input.x * speed
		velocity.z = input.z * speed
		rotation.y = atan2(-input.x, -input.z)
		_walk_phase += delta * speed * 1.6
	else:
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
		_walk_phase = lerpf(_walk_phase, 0.0, 0.12)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta

	move_and_slide()

	var amp := (0.55 if moving else 0.0)
	var s := sin(_walk_phase) * amp
	if _legs.size() == 2:
		_legs[0].rotation.x = s
		_legs[1].rotation.x = -s
	if _arms.size() == 2:
		_arms[0].rotation.x = -s * 0.8
		_arms[1].rotation.x = s * 0.8
