extends Node
## Wanted system: chaos behind the wheel raises heat — 1 to 5 stars on the
## HUD — and police jeeps spawn one per star to pursue the player along the
## road grid. Stay out of police sight for a while and the heat cools off.
## Purely kinematic Node3D movers (same approach as traffic/pedestrians):
## nothing can fall through the world and there is no physics cost.

signal stars_changed(stars: int)
signal arrested

const PED_HEAT := 2.0
const RAM_HEAT := 1.0
const MAX_HEAT := 5.0
const MAX_STARS := 5
const SIGHT := 55.0
const ESCAPE_TIME := 8.0
const COOL_RATE := 0.6
const ARREST_RADIUS := 9.0
const ARREST_JEEPS := 2
const ARREST_HOLD := 1.6
const ARREST_MAX_SPEED := 7.0
const CRUISE := 21.0
const ACCEL := 9.0
const LANE := 2.8
const SPAWN_MIN := 60.0
const SPAWN_MAX := 95.0
const SPAWN_CD := 1.0
const EDGE := 6.0
const JEEP_WHITE := Color(0.93, 0.94, 0.95)
const JEEP_NAVY := Color(0.10, 0.16, 0.35)

var heat := 0.0

var _player: Node3D = null
var _jeeps: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _stars := 0
var _unseen := 0.0
var _spawn_cd := 0.0
var _flash := 0.0
var _arrest_t := 0.0
var _arrested := false
var _last_p := Vector3.ZERO
var _tracked := false


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()


func register_player(p: Node3D) -> void:
	_player = p


func chaos_peds(count: int) -> void:
	## Struck pedestrians while driving: the bigger the crowd, the hotter.
	_raise(minf(count, 3) * PED_HEAT)


func chaos_ram() -> void:
	## Rammed a traffic vehicle.
	_raise(RAM_HEAT)


func reset() -> void:
	## Bust/respawn/death: wipe heat, jeeps and any arrest-in-progress.
	heat = 0.0
	_unseen = 0.0
	_arrest_t = 0.0
	_arrested = false
	_tracked = false
	_clear()
	_sync_stars()


func stars() -> int:
	return clampi(int(floor(heat + 0.001)), 0, MAX_STARS)


func jeep_positions() -> Array[Vector3]:
	## Live positions of the pursuing jeeps, for the minimap.
	var pts: Array[Vector3] = []
	for j in _jeeps:
		pts.append(j.node.position)
	return pts


func _raise(amount: float) -> void:
	heat = minf(heat + amount, MAX_HEAT)
	_unseen = 0.0
	_sync_stars()


func _sync_stars() -> void:
	var s := stars()
	if s == _stars:
		return
	_stars = s
	stars_changed.emit(s)


func _physics_process(delta: float) -> void:
	_flash = fmod(_flash + delta, 10.0)
	if _player == null:
		return
	_spawn_cd = maxf(_spawn_cd - delta, 0.0)
	var p: Vector3 = _player.global_position
	if _stars <= 0:
		_clear()
	var want := _stars
	while _jeeps.size() < want and _spawn_cd <= 0.0:
		_spawn_jeep(p)
		_spawn_cd = SPAWN_CD
	while _jeeps.size() > want:
		_despawn_far(p)
	var seen := false
	for j in _jeeps:
		var np: Vector3 = j.node.position
		if Vector2(np.x - p.x, np.z - p.z).length() < SIGHT:
			seen = true
			break
	if seen:
		_unseen = 0.0
	else:
		_unseen += delta
		if _stars > 0 and _unseen >= ESCAPE_TIME:
			heat = maxf(heat - COOL_RATE * delta, 0.0)
			_sync_stars()
	for j in _jeeps.duplicate():
		_pursue(j, p, delta)
	_animate_lights()
	_tick_arrest(p, delta)


# ---------------------------------------------------------------- arrest

func _tick_arrest(p: Vector3, delta: float) -> void:
	## Cornered while wanted: two or more jeeps parked on top of a slow (or
	## on-foot) player for a beat means the cops close in and it's BUSTED.
	## Player speed is measured from position deltas so it works the same
	## on foot and behind the wheel.
	if not _tracked:
		_last_p = p
		_tracked = true
		return
	var speed := Vector2(p.x - _last_p.x, p.z - _last_p.z).length() / maxf(delta, 0.0001)
	_last_p = p
	if _stars < 1 or speed > ARREST_MAX_SPEED:
		_arrest_t = 0.0
		return
	var near := 0
	for j in _jeeps:
		var jp: Vector3 = j.node.position
		if Vector2(jp.x - p.x, jp.z - p.z).length() < ARREST_RADIUS:
			near += 1
	if near >= ARREST_JEEPS:
		_arrest_t += delta
		if _arrest_t >= ARREST_HOLD and not _arrested:
			_arrested = true
			arrested.emit()
	else:
		_arrest_t = 0.0


# ---------------------------------------------------------------- pursuit

func _pursue(j: Dictionary, p: Vector3, delta: float) -> void:
	j.cd = maxf(j.cd - delta, 0.0)
	j.speed = move_toward(j.speed, CRUISE, ACCEL * delta)
	j.t += j.dir * j.speed * delta
	var limit := _world / 2.0 - EDGE
	if absf(j.t) > limit:
		j.t = clampf(j.t, -limit, limit)
		j.dir = -j.dir
		j.cd = 0.6
	elif j.cd <= 0.0:
		var cross := _nearest_line(j.t)
		if absf(j.t - cross) < 1.8:
			_decide(j, cross, p)
	_apply(j)
	for w in j.wheels:
		w.rotation.x += j.speed * delta * 2.0


func _decide(j: Dictionary, cross: float, p: Vector3) -> void:
	## Greedy grid routing at an intersection: turn if the player is clearly
	## closer to the crossing road's axis, otherwise u-turn/reverse as needed.
	var pc: float = p.z if j.along_z else p.x
	var pf: float = p.x if j.along_z else p.z
	var d_cur: float = pc - j.t
	var d_fix: float = pf - j.road
	if absf(d_fix) > absf(d_cur) + 6.0 and absf(d_fix) > _road_w:
		_turn(j, cross, p)
	elif absf(d_cur) > 5.0 and (1.0 if d_cur > 0.0 else -1.0) != float(j.dir):
		j.dir = -j.dir
		j.cd = 1.0
	else:
		j.cd = 0.8


func _turn(j: Dictionary, cross: float, p: Vector3) -> void:
	var old_road: float = j.road
	j.along_z = not j.along_z
	j.road = cross
	j.t = old_road
	var pc: float = p.z if j.along_z else p.x
	if absf(pc - j.t) > 1.0:
		j.dir = 1 if pc > j.t else -1
	j.cd = 1.2


func _apply(j: Dictionary) -> void:
	if j.along_z:
		j.node.position = Vector3(j.road + LANE * j.dir, 0.0, j.t)
		j.node.rotation.y = PI if j.dir > 0 else 0.0
	else:
		j.node.position = Vector3(j.t, 0.0, j.road - LANE * j.dir)
		j.node.rotation.y = -PI / 2.0 * j.dir


# ---------------------------------------------------------------- fleet

func _spawn_jeep(p: Vector3) -> void:
	var along_z := _rng.randf() < 0.5
	var road := _nearest_line(p.x if along_z else p.z)
	var pc: float = p.z if along_z else p.x
	var t := pc + (SPAWN_MIN + _rng.randf() * (SPAWN_MAX - SPAWN_MIN)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	t = clampf(t, -_world / 2.0 + 10.0, _world / 2.0 - 10.0)
	var node := Node3D.new()
	var parts := _build_jeep(node)
	add_child(node)
	var j := {
		"node": node, "along_z": along_z, "road": road, "t": t,
		"dir": 1 if pc > t else -1, "speed": CRUISE * 0.6, "cd": 0.5,
		"red": parts["red"], "blue": parts["blue"], "wheels": parts["wheels"],
	}
	_apply(j)
	_jeeps.append(j)


func _despawn_far(p: Vector3) -> void:
	var worst_i := 0
	var worst_d := -1.0
	for i in range(_jeeps.size()):
		var np: Vector3 = _jeeps[i].node.position
		var d := Vector2(np.x - p.x, np.z - p.z).length_squared()
		if d > worst_d:
			worst_d = d
			worst_i = i
	_jeeps[worst_i].node.queue_free()
	_jeeps.remove_at(worst_i)


func _clear() -> void:
	for j in _jeeps:
		j.node.queue_free()
	_jeeps.clear()


func _animate_lights() -> void:
	var on := int(_flash * 5.0) % 2
	for j in _jeeps:
		j.red.visible = on == 0
		j.blue.visible = on == 1


# ---------------------------------------------------------------- grid helpers

func _line_at(i: int) -> float:
	return -_world / 2.0 + i * _pitch - (_pitch - _road_w) / 2.0


func _nearest_line(coord: float) -> float:
	var i := clampi(roundi((coord + _world / 2.0 + (_pitch - _road_w) / 2.0) / _pitch), 0, _roads - 1)
	return _line_at(i)


# ---------------------------------------------------------------- visuals

func _build_jeep(parent: Node3D) -> Dictionary:
	parent.add_child(_box(Vector3(2.3, 1.0, 4.6), JEEP_WHITE, Vector3(0, 1.0, 0)))
	parent.add_child(_box(Vector3(2.34, 0.34, 3.2), JEEP_NAVY, Vector3(0, 1.28, 0)))
	parent.add_child(_box(Vector3(2.1, 0.9, 2.2), JEEP_WHITE, Vector3(0, 1.95, 0.3)))
	parent.add_child(_box(Vector3(2.2, 0.7, 0.9), Color(0.62, 0.72, 0.82), Vector3(0, 1.35, -1.85)))
	var red := _box(Vector3(0.5, 0.28, 0.5), Color(0.95, 0.08, 0.12), Vector3(-0.32, 2.55, 0.3))
	var blue := _box(Vector3(0.5, 0.28, 0.5), Color(0.10, 0.30, 0.98), Vector3(0.32, 2.55, 0.3))
	parent.add_child(red)
	parent.add_child(blue)
	var wheels: Array = []
	for spec in [Vector3(-1.1, 0.5, -1.5), Vector3(1.1, 0.5, -1.5), Vector3(-1.1, 0.5, 1.5), Vector3(1.1, 0.5, 1.5)]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.4
		cm.material = _mat(Color(0.1, 0.11, 0.13))
		w.mesh = cm
		w.rotation.z = PI / 2.0
		w.position = spec
		parent.add_child(w)
		wheels.append(w)
	return {"red": red, "blue": blue, "wheels": wheels}


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	m.mesh = bm
	m.position = pos
	return m


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
