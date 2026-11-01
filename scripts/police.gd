extends Node
## Wanted system: chaos behind the wheel raises heat — 1 to 5 stars on the
## HUD — and police jeeps spawn one per star to pursue the player along the
## road grid. Stay out of police sight for a while and the heat cools off.
## 3-star escalation (issue #188): jeeps push harder every star, the force
## plants roadblocks — parked jeeps plus a spike strip — on the road ahead
## of your heading, and a paan-shop bribe wipes heat (Rs per star, then the
## network goes quiet for a cooldown). Purely kinematic Node3D movers (same
## approach as traffic/pedestrians): nothing can fall through the world and
## there is no physics cost.

signal stars_changed(stars: int)
signal escaping_changed(active: bool)
signal arrested
signal spiked
signal roadblock_crash

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
const CRUISE_BASE := 17.0
const CRUISE_PER_STAR := 2.6
const ACCEL_PER_STAR := 0.15
const SPAWN_CD_MAX := 1.0
const SPAWN_CD_PER_STAR := 0.15
const ROADBLOCK_STARS := 3
const ROADBLOCK_CD := 12.0
const ROADBLOCK_AHEAD_MIN := 70.0
const ROADBLOCK_AHEAD_VAR := 30.0
const ROADBLOCK_MAX := 2
const ROADBLOCK_LATERAL := 2.9
const SPIKE_R := 2.9
const CRASH_R := 2.6
const CRASH_SPEED := 8.5
const ROADBLOCK_LIFE := 22.0
const BRIBE_PER_STAR := 120
const BRIBE_COOLDOWN := 90.0
const LANE := 2.8
const SPAWN_MIN := 60.0
const SPAWN_MAX := 95.0
const SPAWN_CD := 1.0
const EDGE := 6.0
const JEEP_WHITE := Color(0.93, 0.94, 0.95)
const JEEP_NAVY := Color(0.10, 0.16, 0.35)

var heat := 0.0
## Don-respect payoff (issue #264): Monty's closing chain discounts
## every heat rise by one star — applied via set_respect().
var respect := false

var _player: Node3D = null
var _jeeps: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _stars := 0
var _unseen := 0.0
var _escaping := false
var _spawn_cd := 0.0
var _flash := 0.0
var _arrest_t := 0.0
var _arrested := false
var _last_p := Vector3.ZERO
var _tracked := false
var _heading := Vector3(0.0, 0.0, 1.0)
var _player_speed := 0.0
var _roadblocks: Array[Dictionary] = []
var _rb_cd := 0.0
var _bribe_cd := 0.0


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
	## Bust/respawn/death/bribe: wipe heat, jeeps, roadblocks and any
	## arrest-in-progress.
	heat = 0.0
	_unseen = 0.0
	_arrest_t = 0.0
	_arrested = false
	_tracked = false
	_clear()
	_clear_roadblocks()
	_sync_stars()


func stars() -> int:
	return clampi(int(floor(heat + 0.001)), 0, MAX_STARS)


func set_respect(on: bool) -> void:
	respect = on


# ---------------------------------------------------------------- bribe

func bribe_cost() -> int:
	## Paan-shop rate (issue #188): the network charges per star.
	return BRIBE_PER_STAR * maxi(_stars, 1)


func can_bribe() -> bool:
	return _stars >= 1 and _bribe_cd <= 0.0


func bribe_cooldown_remaining() -> float:
	return maxf(_bribe_cd, 0.0)


func bribe() -> void:
	## The fix is in: heat wiped, jeeps stand down, roadblocks packed up,
	## and the network stays too hot to tap again for the cooldown.
	_bribe_cd = BRIBE_COOLDOWN
	reset()


# ---------------------------------------------------------------- roadblocks

func roadblock_positions() -> Array[Vector3]:
	## Live roadblock centers for the minimap + QA checks.
	var pts: Array[Vector3] = []
	for rb in _roadblocks:
		pts.append(rb["pos"])
	return pts


func jeep_positions() -> Array[Vector3]:
	## Live positions of the pursuing jeeps, for the minimap.
	var pts: Array[Vector3] = []
	for j in _jeeps:
		pts.append(j.node.position)
	return pts


func _raise(amount: float) -> void:
	if respect:
		# Don respect (issue #264): the first star of any rise is on
		# the house — small chaos never even registers.
		amount = maxf(amount - 1.0, 0.0)
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
	_rb_cd = maxf(_rb_cd - delta, 0.0)
	_bribe_cd = maxf(_bribe_cd - delta, 0.0)
	if _player == null:
		return
	_spawn_cd = maxf(_spawn_cd - delta, 0.0)
	var p: Vector3 = _player.global_position
	if _stars <= 0:
		_clear()
	var want := _stars
	var spawn_gap := maxf(0.35, SPAWN_CD_MAX - SPAWN_CD_PER_STAR * _stars)
	while _jeeps.size() < want and _spawn_cd <= 0.0:
		_spawn_jeep(p)
		_spawn_cd = spawn_gap
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
	var escaping_now := _stars > 0 and not seen
	if escaping_now != _escaping:
		_escaping = escaping_now
		escaping_changed.emit(escaping_now)
	for j in _jeeps.duplicate():
		_pursue(j, p, delta)
	_animate_lights()
	_tick_arrest(p, delta)
	_tick_roadblocks(p, delta)


# ---------------------------------------------------------------- arrest

func _tick_arrest(p: Vector3, delta: float) -> void:
	## Cornered while wanted: two or more jeeps parked on top of a slow (or
	## on-foot) player for a beat means the cops close in and it's BUSTED.
	## Player speed is measured from position deltas so it works the same
	## on foot and behind the wheel; the same delta feeds the pursuit
	## heading so roadblocks land on the road you are actually driving.
	if not _tracked:
		_last_p = p
		_tracked = true
		return
	var moved := Vector2(p.x - _last_p.x, p.z - _last_p.z)
	var speed := moved.length() / maxf(delta, 0.0001)
	if moved.length() > 0.05:
		_heading = Vector3(moved.x, 0.0, moved.y).normalized()
	_player_speed = speed
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
	j.speed = move_toward(j.speed, _cruise(), _accel_rate() * delta)
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

func _cruise() -> float:
	## Aggression curve (issue #188): 1-star patrols stay lazy (17+2.6),
	## 3-star jeeps ride a car's bumper (~24.8), 5-star is flat-out (30).
	## The player's rides still top out faster — escapes stay possible.
	return CRUISE_BASE + CRUISE_PER_STAR * float(_stars)


func _accel_rate() -> float:
	return ACCEL * (1.0 + ACCEL_PER_STAR * float(maxi(_stars - 1, 0)))


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
		"dir": 1 if pc > t else -1, "speed": _cruise() * 0.6, "cd": 0.5,
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


func _clear_roadblocks() -> void:
	for rb in _roadblocks:
		rb["node"].queue_free()
	_roadblocks.clear()


func _tick_roadblocks(p: Vector3, delta: float) -> void:
	## 3-star escalation (issue #188): the force plants roadblocks — parked
	## jeeps plus a spike strip — on the road ahead of your heading. Roll
	## over the strip and the tyres shred; plough into a parked jeep fast
	## enough and the post scatters (bodywork pays for it back in Main).
	if _stars < ROADBLOCK_STARS:
		if not _roadblocks.is_empty():
			_clear_roadblocks()
		return
	if _rb_cd <= 0.0 and _roadblocks.size() < ROADBLOCK_MAX:
		_spawn_roadblock(p)
		_rb_cd = ROADBLOCK_CD
	for rb in _roadblocks.duplicate():
		rb["life"] = float(rb["life"]) + delta
		var off := Vector2(p.x - rb["pos"].x, p.z - rb["pos"].z)
		var dist := off.length()
		var passed := off.dot(Vector2(_heading.x, _heading.z)) > 20.0
		if rb["life"] > ROADBLOCK_LIFE or dist > 280.0 or passed:
			rb["node"].queue_free()
			_roadblocks.erase(rb)
			continue
		if not rb["spent"] and dist < SPIKE_R:
			rb["spent"] = true
			rb["spike"].visible = false
			spiked.emit()
		if _player_speed > CRASH_SPEED:
			for jeep in rb["jeeps"]:
				var jp: Vector3 = jeep.global_position
				if Vector2(jp.x - p.x, jp.z - p.z).length() < CRASH_R:
					rb["smashed"] = true
					roadblock_crash.emit()
					rb["node"].queue_free()
					_roadblocks.erase(rb)
					break


func _spawn_roadblock(p: Vector3) -> void:
	## Snap a post onto the road the player is actually driving: the line
	## nearest their cross-axis coordinate, set 70-100 m along their heading.
	var ahead := p + _heading * (ROADBLOCK_AHEAD_MIN + _rng.randf() * ROADBLOCK_AHEAD_VAR)
	var along_z := absf(_heading.z) >= absf(_heading.x)
	var line := _nearest_line(p.x if along_z else p.z)
	var limit := _world / 2.0 - EDGE
	var t_coord: float = clampf(ahead.z if along_z else ahead.x, -limit, limit)
	var node := Node3D.new()
	var parts := _build_roadblock(node)
	add_child(node)
	if along_z:
		node.position = Vector3(line, 0.0, t_coord)
	else:
		node.position = Vector3(t_coord, 0.0, line)
		node.rotation.y = PI / 2.0
	_roadblocks.append({
		"node": node, "pos": node.position, "spike": parts["spike"],
		"jeeps": parts["jeeps"], "spent": false, "smashed": false,
		"life": 0.0,
	})


func _build_roadblock(parent: Node3D) -> Dictionary:
	## Parked pair angled across the lane, a chequered plank between them
	## and the spike strip just beyond (local X = across the road).
	var jeeps: Array = []
	for side in [-1.0, 1.0]:
		var jeep := Node3D.new()
		jeep.position = Vector3(side * ROADBLOCK_LATERAL, 0.0, 0.0)
		jeep.rotation.y = side * 0.55
		parent.add_child(jeep)
		var lights := _build_jeep(jeep)
		lights["red"].visible = true
		lights["blue"].visible = true
		jeeps.append(jeep)
	for i in range(4):
		parent.add_child(_box(Vector3(1.05, 0.42, 0.28),
				Color(0.92, 0.25, 0.2) if i % 2 == 0 else Color(0.95, 0.95, 0.92),
				Vector3(-1.6 + i * 1.05, 1.05, 0.0)))
	var spike := Node3D.new()
	spike.position = Vector3(0.0, 0.0, 2.0)
	parent.add_child(spike)
	spike.add_child(_box(Vector3(5.6, 0.1, 0.9), Color(0.16, 0.17, 0.19), Vector3.ZERO))
	for i in range(8):
		spike.add_child(_box(Vector3(0.14, 0.24, 0.14), Color(0.55, 0.57, 0.6),
				Vector3(-2.4 + i * 0.7, 0.16, 0.0)))
	return {"spike": spike, "jeeps": jeeps}


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
