extends Node
## Traffic AI: ambient autos and hatchbacks lane-following the road grid.
## Purely kinematic movers (no physics bodies): vehicles stay at road level
## on fixed lanes that never intersect building blocks, so nothing can fall
## through the ground or tunnel through geometry.

const COUNT := 22
const LANE := 2.8
const WRAP_MARGIN := 24.0
const ACCEL := 9.0
const BRAKE := 22.0
const CAR_COLORS := [
	Color(0.75, 0.12, 0.12), Color(0.10, 0.22, 0.55), Color(0.85, 0.82, 0.78),
	Color(0.12, 0.14, 0.16), Color(0.55, 0.52, 0.20), Color(0.20, 0.45, 0.28),
]

var _vehicles: Array[Dictionary] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _next_id := 0
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	for _i in range(COUNT):
		_vehicles.append(_spawn())


func register_player(p: Node3D) -> void:
	_player = p


func _spawn() -> Dictionary:
	var along_z := _rng.randf() < 0.5
	var road_i := _rng.randi_range(0, _roads - 1)
	var road := -_world / 2.0 + road_i * _pitch - (_pitch - _road_w) / 2.0
	var dir := 1 if _rng.randf() < 0.5 else -1
	var is_auto := _rng.randf() < 0.6
	var cruise := _rng.randf_range(8.0, 11.0) if is_auto else _rng.randf_range(12.0, 15.0)
	var node := Node3D.new()
	if is_auto:
		_build_auto(node)
	else:
		_build_car(node)
	add_child(node)
	_next_id += 1
	var v := {
		"id": _next_id, "node": node, "along_z": along_z, "road": road, "dir": dir,
		"t": _rng.randf_range(-_world / 2.0, _world / 2.0),
		"speed": cruise, "cruise": cruise,
	}
	_apply_transform(v)
	return v


func _physics_process(delta: float) -> void:
	for v in _vehicles:
		var target: float = minf(v.cruise, _player_limit(v))
		target = minf(target, _traffic_limit(v))
		var rate := BRAKE if target < v.speed else ACCEL
		v.speed = move_toward(v.speed, target, rate * delta)
		v.t += v.dir * v.speed * delta
		var edge := _world / 2.0 + WRAP_MARGIN
		if v.t > edge:
			v.t = -edge
		elif v.t < -edge:
			v.t = edge
		_apply_transform(v)


func _apply_transform(v: Dictionary) -> void:
	if v.along_z:
		v.node.position = Vector3(v.road + LANE * v.dir, 0.0, v.t)
		v.node.rotation.y = PI if v.dir > 0 else 0.0
	else:
		v.node.position = Vector3(v.t, 0.0, v.road - LANE * v.dir)
		v.node.rotation.y = -PI / 2.0 * v.dir


func _forward(v: Dictionary) -> Vector3:
	return Vector3(0.0, 0.0, 1.0) * v.dir if v.along_z else Vector3(1.0, 0.0, 0.0) * v.dir


func _player_limit(v: Dictionary) -> float:
	## Brake when the player (on foot or driving) stands in our lane ahead.
	if _player == null:
		return v.cruise
	var rel: Vector3 = _player.global_position - v.node.position
	var fwd := _forward(v)
	var along := rel.dot(fwd)
	var lateral := (rel - fwd * along).length()
	if along > 1.0 and along < 9.0 and lateral < 2.6:
		return 0.0
	return v.cruise


func _traffic_limit(v: Dictionary) -> float:
	## Keep distance to the vehicle ahead in the same lane and direction.
	var limit: float = v.cruise
	for w in _vehicles:
		if w.id == v.id or w.along_z != v.along_z or w.dir != v.dir:
			continue
		if absf(w.road - v.road) > 1.0:
			continue
		var gap: float = (w.t - v.t) * v.dir
		if gap > 0.5 and gap < 12.0:
			limit = minf(limit, w.speed * clampf(gap / 12.0, 0.0, 1.0))
	return limit


func worst_hazard_speed(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## on-foot impact damage. Kinematic movers, so no physics events exist.
	var worst := 0.0
	for v in _vehicles:
		if v.speed <= 2.5:
			continue
		var dx: float = v.node.position.x - pos.x
		var dz: float = v.node.position.z - pos.z
		if dx * dx + dz * dz < 5.29:
			worst = maxf(worst, v.speed)
	return worst


func ram_speed_at(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## wanted heat when the player's auto rams traffic.
	var worst := 0.0
	for v in _vehicles:
		var dx: float = v.node.position.x - pos.x
		var dz: float = v.node.position.z - pos.z
		if dx * dx + dz * dz < 8.4:
			worst = maxf(worst, absf(v.speed))
	return worst


# ---------------------------------------------------------------- visuals

func _build_auto(parent: Node3D) -> void:
	parent.add_child(_box(Vector3(2.4, 1.3, 3.4), Color(0.18, 0.55, 0.20), Vector3(0, 1.0, 0)))
	parent.add_child(_box(Vector3(2.4, 1.4, 2.2), Color(0.97, 0.77, 0.19), Vector3(0, 2.2, 0.2)))
	parent.add_child(_box(Vector3(1.6, 1.1, 0.9), Color(0.97, 0.77, 0.19), Vector3(0, 1.35, -1.9)))
	for spec in [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]:
		parent.add_child(_wheel(spec, 0.55))


func _build_car(parent: Node3D) -> void:
	var paint: Color = CAR_COLORS[_rng.randi_range(0, CAR_COLORS.size() - 1)]
	parent.add_child(_box(Vector3(2.0, 0.9, 4.2), paint, Vector3(0, 0.85, 0)))
	parent.add_child(_box(Vector3(1.8, 0.8, 2.2), Color(0.55, 0.65, 0.75), Vector3(0, 1.7, 0.2)))
	for spec in [Vector3(-1.0, 0.5, -1.4), Vector3(1.0, 0.5, -1.4), Vector3(-1.0, 0.5, 1.4), Vector3(1.0, 0.5, 1.4)]:
		parent.add_child(_wheel(spec, 0.45))


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


func _wheel(pos: Vector3, radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.11, 0.13)
	cm.material = mat
	m.mesh = cm
	m.rotation.z = PI / 2.0
	m.position = pos
	return m
