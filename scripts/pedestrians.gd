extends Node
## Pedestrians: sidewalk NPCs walking the road grid. They turn at corners,
## scatter when the player sounds the horn nearby, then find their way back
## to the nearest sidewalk line. Purely kinematic Node3D movers (same
## approach as the traffic manager) recycled around the player, so there is
## no spawn cost and nothing can fall through the world.

const COUNT := 26
const EDGE := 1.4
const RECYCLE_DIST := 150.0
const SPAWN_ALONG := 110.0
const SPAWN_MIN_DIST := 42.0
const WALK_MIN := 2.2
const WALK_MAX := 3.6
const TURN_CHANCE := 0.4
const TURN_WINDOW := 0.9
const PANIC_TIME := 2.6
const PANIC_SPEED := 8.0
const SCATTER_RADIUS := 18.0
const REJOIN_SPEED := 5.5
const REJOIN_LIMIT := 4.0
const ZONE_EXTRA := 12
const ZONE_WAKE := 130.0
const ZONE_RECYCLE := 150.0
const ZONE_SPAWN_MIN := 26.0
const ZONE_BIAS := 42.0

const SKIN_TONES := [
	Color(0.79, 0.57, 0.40), Color(0.72, 0.50, 0.33),
	Color(0.64, 0.44, 0.29), Color(0.55, 0.38, 0.26),
]
const SHIRTS := [
	Color(0.95, 0.55, 0.12), Color(0.12, 0.55, 0.55), Color(0.85, 0.20, 0.45),
	Color(0.92, 0.90, 0.86), Color(0.16, 0.30, 0.60), Color(0.45, 0.50, 0.25),
]
const PANTS := [
	Color(0.14, 0.18, 0.30), Color(0.30, 0.30, 0.34), Color(0.32, 0.24, 0.18),
	Color(0.10, 0.10, 0.12), Color(0.62, 0.55, 0.40),
]
const TURBANS := [Color(1.0, 0.56, 0.12), Color(0.20, 0.40, 0.85), Color(0.95, 0.95, 0.92)]

var _peds: Array[Dictionary] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _placed := false
var _zone_center := Vector3.ZERO
var _zone_radius := 0.0
var _zone_set := false


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	for _i in range(COUNT):
		var node := Node3D.new()
		var limbs := _build_ped(node)
		node.visible = false
		add_child(node)
		_peds.append({
			"node": node, "legs": limbs["legs"], "arms": limbs["arms"],
			"along_z": true, "road": 0.0, "t": 0.0, "dir": 1,
			"speed": 3.0, "panic": 0.0, "panic_dir": Vector3.ZERO,
			"rejoin": 0.0, "cd": 0.0, "phase": _rng.randf() * TAU,
		})
	# Bazaar crowd squad: extra shoppers that only wake around the crowd
	# zone (see set_crowd_zone) — the district's density boost.
	for _i in range(ZONE_EXTRA):
		var znode := Node3D.new()
		var zlimbs := _build_ped(znode)
		znode.visible = false
		add_child(znode)
		_peds.append({
			"node": znode, "legs": zlimbs["legs"], "arms": zlimbs["arms"],
			"along_z": true, "road": 0.0, "t": 0.0, "dir": 1,
			"speed": 3.0, "panic": 0.0, "panic_dir": Vector3.ZERO,
			"rejoin": 0.0, "cd": 0.0, "phase": _rng.randf() * TAU,
			"zone": true,
		})


func set_crowd_zone(center: Vector3, radius: float) -> void:
	## Crowd density boost: ZONE_EXTRA extra shoppers walk the sidewalk
	## lines around `center` while the player is nearby; they sleep (and
	## cost nothing) when the district is far away.
	_zone_center = center
	_zone_radius = radius
	_zone_set = true


func register_player(p: Node3D) -> void:
	_player = p


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not _placed:
		_placed = true
		for v in _peds:
			if not bool(v.get("zone", false)):
				_place(v)
	if Input.is_action_just_pressed("horn"):
		_scatter(_player.global_position)
	for v in _peds:
		var is_zone := bool(v.get("zone", false))
		if is_zone:
			if not _zone_awake():
				if v.node.visible:
					v.node.visible = false
					v.panic = 0.0
					v.rejoin = 0.0
				continue
			if not v.node.visible:
				_place_zone(v)
		if v.cd > 0.0:
			v.cd -= delta
		if v.panic > 0.0 or v.rejoin > 0.0:
			_flee_tick(v, delta)
		else:
			_walk_tick(v, delta)
			var recycle := RECYCLE_DIST
			if is_zone:
				recycle = ZONE_RECYCLE
			if _flat_dist(v) > recycle:
				if is_zone:
					_place_zone(v)
				else:
					_place(v)
		_animate(v)


# ---------------------------------------------------------------- walking

func _walk_tick(v: Dictionary, delta: float) -> void:
	v.t += v.dir * v.speed * delta
	if absf(v.t) > _world / 2.0 + 20.0:
		v.dir = -v.dir
	_maybe_turn(v)
	_apply(v)
	var d := Vector3(0.0, 0.0, 1.0) if v.along_z else Vector3(1.0, 0.0, 0.0)
	_face(v, d * v.dir)
	v.phase += delta * v.speed * 2.6


func _maybe_turn(v: Dictionary) -> void:
	## At an intersection, the crossing road's sidewalk lines cross ours at
	## cross +/- offset. Chance to turn onto one of those corners.
	if v.cd > 0.0:
		return
	var cross := _nearest_line(v.t)
	for side in [1.0, -1.0]:
		var corner: float = cross + side * _offset()
		if absf(v.t - corner) < TURN_WINDOW and _rng.randf() < TURN_CHANCE:
			v.t = v.road
			v.road = corner
			v.along_z = not v.along_z
			v.dir = 1 if _rng.randf() < 0.5 else -1
			v.cd = 2.0
			return


func _apply(v: Dictionary) -> void:
	if v.along_z:
		v.node.position = Vector3(v.road, 0.0, v.t)
	else:
		v.node.position = Vector3(v.t, 0.0, v.road)


# ---------------------------------------------------------------- panic

func _scatter(origin: Vector3) -> void:
	## Horn blast: NPCs within SCATTER_RADIUS bolt away from the sound.
	for v in _peds:
		var p: Vector3 = v.node.position
		var away := Vector3(p.x - origin.x, 0.0, p.z - origin.z)
		if away.length() > SCATTER_RADIUS:
			continue
		if away.length() < 0.05:
			away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		v.panic = PANIC_TIME
		v.rejoin = 0.0
		v.cd = 1.0
		v.panic_dir = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))


func vehicle_strike(pos: Vector3, radius: float) -> int:
	## Player auto plowed into the crowd: stricken NPCs bolt away and the
	## count feeds the wanted system (main.gd).
	var n := 0
	for v in _peds:
		var p: Vector3 = v.node.position
		var away := Vector2(p.x - pos.x, p.z - pos.z)
		if away.length() > radius:
			continue
		n += 1
		var dir := Vector3(away.x, 0.0, away.y)
		if away.length() < 0.05:
			dir = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		v.panic = PANIC_TIME
		v.rejoin = 0.0
		v.cd = 1.0
		v.panic_dir = dir.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	return n


func _flee_tick(v: Dictionary, delta: float) -> void:
	if v.rejoin > 0.0:
		v.rejoin += delta
		var mv: Vector3 = v.panic_dir * REJOIN_SPEED
		v.node.position += mv * delta
		v.phase += delta * REJOIN_SPEED * 2.6
		_face(v, mv)
		var near := _nearest_sidewalk(v.node.position)
		if near["dist"] < 1.6 or v.rejoin > REJOIN_LIMIT:
			_snap_to_sidewalk(v)
		return
	v.panic -= delta
	var falloff: float = 0.35 + 0.65 * v.panic / PANIC_TIME
	var mv2: Vector3 = v.panic_dir * PANIC_SPEED * falloff
	v.node.position += mv2 * delta
	v.phase += delta * 12.0
	_face(v, mv2)
	if v.panic <= 0.0:
		v.rejoin = 0.0001


func _snap_to_sidewalk(v: Dictionary) -> void:
	var near := _nearest_sidewalk(v.node.position)
	var pos: Vector3 = v.node.position
	v.along_z = near["along_z"]
	v.road = near["line"]
	v.t = pos.z if v.along_z else pos.x
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _rng.randf_range(WALK_MIN, WALK_MAX)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = 1.0
	_apply(v)


# ---------------------------------------------------------------- helpers

func _place(v: Dictionary) -> void:
	## (Re)spawn on a random sidewalk line, biased around the player but far
	## enough away that nothing pops into view.
	v.along_z = _rng.randf() < 0.5
	var i := _rng.randi_range(0, _roads - 1)
	v.road = _line_at(i) + (1.0 if _rng.randf() < 0.5 else -1.0) * _offset()
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _rng.randf_range(WALK_MIN, WALK_MAX)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = _rng.randf_range(0.5, 2.5)
	var p: Vector3 = _player.global_position
	var base: float = p.z if v.along_z else p.x
	for _attempt in range(6):
		v.t = base + _rng.randf_range(-1.0, 1.0) * SPAWN_ALONG
		_apply(v)
		if _flat_dist(v) >= SPAWN_MIN_DIST:
			break
	v.node.visible = true


func _zone_awake() -> bool:
	## The bazaar squad is only simulated while the player can plausibly
	## see the district.
	if not _zone_set:
		return false
	var p: Vector3 = _player.global_position
	return Vector2(p.x - _zone_center.x, p.z - _zone_center.z).length() <= ZONE_WAKE


func _place_zone(v: Dictionary) -> void:
	## (Re)spawn a bazaar shopper on a sidewalk line near the crowd zone,
	## biased toward whichever side the player is watching from.
	v.along_z = _rng.randf() < 0.5
	var along_center: float = _zone_center.z if v.along_z else _zone_center.x
	v.road = _nearest_line(_zone_center.x if v.along_z else _zone_center.z) \
			+ (1.0 if _rng.randf() < 0.5 else -1.0) * _offset()
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _rng.randf_range(WALK_MIN, WALK_MAX)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = _rng.randf_range(0.5, 2.5)
	var p: Vector3 = _player.global_position
	var p_along: float = p.z if v.along_z else p.x
	for _attempt in range(6):
		v.t = clampf(p_along + _rng.randf_range(-1.0, 1.0) * ZONE_BIAS,
				along_center - _zone_radius, along_center + _zone_radius)
		_apply(v)
		if _flat_dist(v) >= ZONE_SPAWN_MIN:
			break
	v.node.visible = true


func _nearest_sidewalk(pos: Vector3) -> Dictionary:
	## Closest sidewalk line of either axis: {"line", "along_z", "dist"}.
	var best := {"line": 0.0, "along_z": true, "dist": INF}
	for axis in [true, false]:
		var fixed: float = pos.x if axis else pos.z
		var base_line := _nearest_line(fixed)
		for side in [1.0, -1.0]:
			var cand: float = base_line + side * _offset()
			var d := absf(fixed - cand)
			if d < best["dist"]:
				best = {"line": cand, "along_z": axis, "dist": d}
	return best


func _offset() -> float:
	return _road_w / 2.0 + EDGE


func _line_at(i: int) -> float:
	return -_world / 2.0 + i * _pitch - (_pitch - _road_w) / 2.0


func _nearest_line(coord: float) -> float:
	var i := clampi(roundi((coord + _world / 2.0 + (_pitch - _road_w) / 2.0) / _pitch), 0, _roads - 1)
	return _line_at(i)


func _flat_dist(v: Dictionary) -> float:
	var p: Vector3 = _player.global_position
	var np: Vector3 = v.node.position
	return Vector2(np.x - p.x, np.z - p.z).length()


func _face(v: Dictionary, dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		v.node.rotation.y = atan2(-dir.x, -dir.z)


func _animate(v: Dictionary) -> void:
	var amp := 0.5
	if v.panic > 0.0 or v.rejoin > 0.0:
		amp = 0.85
	var s := sin(v.phase) * amp
	if v.legs.size() == 2:
		v.legs[0].rotation.x = s
		v.legs[1].rotation.x = -s
	if v.arms.size() == 2:
		v.arms[0].rotation.x = -s * 0.8
		v.arms[1].rotation.x = s * 0.8


# ---------------------------------------------------------------- visuals

func _build_ped(parent: Node3D) -> Dictionary:
	var skin: Color = SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)]
	var shirt: Color = SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)]
	var pants: Color = PANTS[_rng.randi_range(0, PANTS.size() - 1)]

	var legs: Array = []
	for side in [-0.42, 0.42]:
		var leg := _box(Vector3(0.62, 1.7, 0.68), pants)
		leg.position = Vector3(side, 0.85, 0)
		parent.add_child(leg)
		legs.append(leg)

	var body := _box(Vector3(1.8, 2.2, 1.0), shirt)
	body.position.y = 2.6
	parent.add_child(body)

	var arms: Array = []
	for side in [-1.15, 1.15]:
		var arm := _box(Vector3(0.5, 1.7, 0.5), skin)
		arm.position = Vector3(side, 2.8, 0)
		parent.add_child(arm)
		arms.append(arm)

	var head := _box(Vector3(1.05, 1.05, 1.05), skin)
	head.position.y = 4.15
	parent.add_child(head)

	var roll := _rng.randf()
	if roll < 0.14:
		var turban := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.7
		tm.height = 1.05
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = TURBANS[_rng.randi_range(0, TURBANS.size() - 1)]
		tm.material = tmat
		turban.mesh = tm
		turban.position.y = 4.7
		parent.add_child(turban)
	elif roll < 0.34:
		var scarf := _box(Vector3(2.0, 0.5, 1.2), SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)])
		scarf.position.y = 3.55
		parent.add_child(scarf)
	else:
		var hair := _box(Vector3(1.1, 0.35, 1.1), Color(0.12, 0.09, 0.06))
		hair.position.y = 4.6
		parent.add_child(hair)
	return {"legs": legs, "arms": arms}


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	return m
