extends Node
## Traffic AI: ambient autos and hatchbacks lane-following the road grid.
## Purely kinematic movers (no physics bodies): vehicles stay at road level
## on fixed lanes that never intersect building blocks, so nothing can fall
## through the ground or tunnel through geometry.
## The whole fleet renders through a handful of MultiMeshes (one merged
## mesh per vehicle style), so full traffic costs only a few draw calls.

const MeshTools := preload("res://scripts/meshtools.gd")

const COUNT := 22
const LANE := 2.8
const WRAP_MARGIN := 24.0
const ACCEL := 9.0
const BRAKE := 22.0
const CAR_COLORS := [
	Color(0.75, 0.12, 0.12), Color(0.10, 0.22, 0.55), Color(0.85, 0.82, 0.78),
	Color(0.12, 0.14, 0.16), Color(0.55, 0.52, 0.20), Color(0.20, 0.45, 0.28),
]
const RICK_GREEN := Color(0.18, 0.55, 0.20)
const RICK_YELLOW := Color(0.97, 0.77, 0.19)
const CABIN := Color(0.55, 0.65, 0.75)
const WHEEL := Color(0.1, 0.11, 0.13)

var _vehicles: Array[Dictionary] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _next_id := 0
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _auto_mm: MultiMesh = null
var _car_mms: Array[MultiMesh] = []
var _mm_used := {}
var _mm_free := {}


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	_auto_mm = _new_mm(_auto_mesh())
	for paint in CAR_COLORS:
		_car_mms.append(_new_mm(_car_mesh(paint)))
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
	var mm := _auto_mm if is_auto else _car_mms[_rng.randi_range(0, _car_mms.size() - 1)]
	_next_id += 1
	var v := {
		"id": _next_id, "mm": mm, "idx": _alloc(mm), "pos": Vector3.ZERO,
		"heading": 0.0, "along_z": along_z, "road": road, "dir": dir,
		"kind": ("auto" if is_auto else "car"),
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
		v.pos = Vector3(v.road + LANE * v.dir, 0.0, v.t)
		v.heading = PI if v.dir > 0 else 0.0
	else:
		v.pos = Vector3(v.t, 0.0, v.road - LANE * v.dir)
		v.heading = -PI / 2.0 * v.dir
	v.mm.set_instance_transform(v.idx,
			Transform3D(Basis(Vector3.UP, v.heading), v.pos))


func _forward(v: Dictionary) -> Vector3:
	return Vector3(0.0, 0.0, 1.0) * v.dir if v.along_z else Vector3(1.0, 0.0, 0.0) * v.dir


func _player_limit(v: Dictionary) -> float:
	## Brake when the player (on foot or driving) stands in our lane ahead.
	if _player == null:
		return v.cruise
	var rel: Vector3 = _player.global_position - v.pos
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


func nearest_enterable(pos: Vector3, max_dist: float) -> Dictionary:
	## Closest ambient traffic vehicle within max_dist, as a takeover spec
	## (id, kind, pos, heading). Empty dict when nothing is in range.
	var best := {}
	var best_d := max_dist * max_dist
	for v in _vehicles:
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < best_d:
			best_d = dx * dx + dz * dz
			best = {"id": v.id, "kind": v.kind,
				"pos": v.pos + Vector3(0.0, 1.0, 0.0),
				"heading": v.heading}
	return best


func take_vehicle(id: int) -> void:
	## Remove a traffic vehicle (the player took it over) and spawn a
	## replacement so street density stays constant. The freed MultiMesh
	## slot is parked below the world until reused.
	for i in range(_vehicles.size()):
		if _vehicles[i].id == id:
			var dead: Dictionary = _vehicles[i]
			_release(dead)
			_vehicles.remove_at(i)
			_vehicles.append(_spawn())
			return


func worst_hazard_speed(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## on-foot impact damage. Kinematic movers, so no physics events exist.
	var worst := 0.0
	for v in _vehicles:
		if v.speed <= 2.5:
			continue
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < 5.29:
			worst = maxf(worst, v.speed)
	return worst


func ram_speed_at(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## wanted heat when the player's auto rams traffic.
	var worst := 0.0
	for v in _vehicles:
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < 8.4:
			worst = maxf(worst, absf(v.speed))
	return worst


# ---------------------------------------------------------------- instancing

func _new_mm(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = COUNT
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func _alloc(mm: MultiMesh) -> int:
	## Reuse a released slot when one is free, else grow the visible range.
	if _mm_free.has(mm) and not _mm_free[mm].is_empty():
		return int(_mm_free[mm].pop_back())
	var used: int = _mm_used.get(mm, 0)
	_mm_used[mm] = used + 1
	mm.visible_instance_count = used + 1
	return used


func _release(v: Dictionary) -> void:
	v.mm.set_instance_transform(v.idx,
			Transform3D(Basis(), Vector3(0.0, -500.0, 0.0)))
	if not _mm_free.has(v.mm):
		_mm_free[v.mm] = []
	_mm_free[v.mm].append(v.idx)


# ---------------------------------------------------------------- visuals

func _auto_mesh() -> ArrayMesh:
	## Whole rickshaw merged into one mesh (wheels included — they never
	## animate separately), one surface per color.
	var b := MeshTools.new()
	b.add_box(Vector3(2.4, 1.3, 3.4), Vector3(0, 1.0, 0), RICK_GREEN)
	b.add_box(Vector3(2.4, 1.4, 2.2), Vector3(0, 2.2, 0.2), RICK_YELLOW)
	b.add_box(Vector3(1.6, 1.1, 0.9), Vector3(0, 1.35, -1.9), RICK_YELLOW)
	for spec in [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]:
		b.add_mesh(_wheel_mesh(0.55), Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), spec), WHEEL)
	return b.build_mesh()


func _car_mesh(paint: Color) -> ArrayMesh:
	var b := MeshTools.new()
	b.add_box(Vector3(2.0, 0.9, 4.2), Vector3(0, 0.85, 0), paint)
	b.add_box(Vector3(1.8, 0.8, 2.2), Vector3(0, 1.7, 0.2), CABIN)
	for spec in [Vector3(-1.0, 0.5, -1.4), Vector3(1.0, 0.5, -1.4), Vector3(-1.0, 0.5, 1.4), Vector3(1.0, 0.5, 1.4)]:
		b.add_mesh(_wheel_mesh(0.45), Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), spec), WHEEL)
	return b.build_mesh()


func _wheel_mesh(radius: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.4
	return cm
