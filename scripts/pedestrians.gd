extends Node
## Pedestrians: sidewalk NPCs walking the road grid. They turn at corners,
## scatter when the player sounds the horn nearby, then find their way back
## to the nearest sidewalk line. Purely kinematic movers (same approach as
## the traffic manager) recycled around the player, so there is no spawn
## cost and nothing can fall through the world.
## Every walker is an instanced rigged CC0 character (see characters.gd)
## playing its own walk/run clips — the old MultiMesh box bodies are gone.

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")

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
const PED_HEIGHT := 4.7
const WALK_CLIP_SPEED := 3.8
const ROAD_Y := 0.08  ## asphalt surface height (roads.gd ROAD_Y)
const WALK_H := 0.14  ## sidewalk top height (roads.gd CURB_H)
const WALK_W := 2.2   ## sidewalk band width (roads.gd WALK_TILE)
const MODELS := [
	Chars.FEMALE_A, Chars.FEMALE_B, Chars.FEMALE_C, Chars.FEMALE_D, Chars.MALE,
]

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
var _chars := Chars.new()
var _last_model := -1


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	var total := COUNT + ZONE_EXTRA
	for i in range(total):
		var v := _new_ped(i >= COUNT)
		_dress(v)
		_peds.append(v)


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
				if v.visible:
					v.visible = false
					_hide_ped(v)
					v.panic = 0.0
					v.rejoin = 0.0
				continue
			if not v.visible:
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
		v.pos = Vector3(v.road, 0.0, v.t)
	else:
		v.pos = Vector3(v.t, 0.0, v.road)


# ---------------------------------------------------------------- panic

func _scatter(origin: Vector3) -> void:
	## Horn blast: NPCs within SCATTER_RADIUS bolt away from the sound.
	for v in _peds:
		var p: Vector3 = v.pos
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
		var p: Vector3 = v.pos
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
		v.pos += mv * delta
		v.phase += delta * REJOIN_SPEED * 2.6
		_face(v, mv)
		var near := _nearest_sidewalk(v.pos)
		if near["dist"] < 1.6 or v.rejoin > REJOIN_LIMIT:
			_snap_to_sidewalk(v)
		return
	v.panic -= delta
	var falloff: float = 0.35 + 0.65 * v.panic / PANIC_TIME
	var mv2: Vector3 = v.panic_dir * PANIC_SPEED * falloff
	v.pos += mv2 * delta
	v.phase += delta * 12.0
	_face(v, mv2)
	if v.panic <= 0.0:
		v.rejoin = 0.0001


func _snap_to_sidewalk(v: Dictionary) -> void:
	var near := _nearest_sidewalk(v.pos)
	var pos: Vector3 = v.pos
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
	v.visible = true
	if v.node != null:
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
	v.visible = true
	if v.node != null:
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
	var np: Vector3 = v.pos
	return Vector2(np.x - p.x, np.z - p.z).length()


func _ground_y(x: float, z: float) -> float:
	## Analytic ground height under a point (mirrors roads.gd build()):
	## asphalt strips at ROAD_Y, sidewalk bands at CURB_H, block interiors
	## at 0. Walkers are kinematic, so they read the street shape instead
	## of raycasting every frame (issue #75: no more floating/sunk peds).
	var dx := absf(x - _nearest_line(x))
	var dz := absf(z - _nearest_line(z))
	var hw := _road_w / 2.0
	if dx <= hw or dz <= hw:
		return ROAD_Y
	if dx <= hw + WALK_W or dz <= hw + WALK_W:
		return WALK_H
	return 0.0

func _face(v: Dictionary, dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		v.heading = atan2(-dir.x, -dir.z)


func _animate(v: Dictionary) -> void:
	## Place one walker in the world and keep its clip honest: stroll on
	## the sidewalk, run while panicking.
	var node: Node3D = v.node
	if node == null:
		return
	var grounded := Vector3(v.pos.x, _ground_y(v.pos.x, v.pos.z), v.pos.z)
	node.global_transform = Transform3D(Basis(Vector3.UP, v.heading), grounded)
	if v.panic > 0.0 or v.rejoin > 0.0:
		_chars.play(v.anims, v.ap, "run", 1.1)
	else:
		_chars.play(v.anims, v.ap, "walk", v.speed / WALK_CLIP_SPEED)


func _hide_ped(v: Dictionary) -> void:
	## Park the walker out of sight until its zone wakes again.
	if v.node != null:
		v.node.visible = false
	if v.ap != null:
		v.ap.stop()


# ---------------------------------------------------------------- visuals


func _new_ped(zone: bool) -> Dictionary:
	return {
		"pos": Vector3.ZERO, "heading": 0.0, "visible": false, "parts": [],
		"along_z": true, "road": 0.0, "t": 0.0, "dir": 1,
		"speed": 3.0, "panic": 0.0, "panic_dir": Vector3.ZERO,
		"rejoin": 0.0, "cd": 0.0, "phase": _rng.randf() * TAU,
		"zone": zone, "node": null, "ap": null, "anims": {},
	}


func _dress(v: Dictionary) -> void:
	## One rigged walker: random model from the CC0 set, random palette.
	## The model's own AnimationPlayer drives the walk. A reroll keeps the
	## same body from spawning twice in a row, so clones rarely stand
	## shoulder to shoulder (acceptance: crowd visibly varied).
	var pick := _rng.randi_range(0, MODELS.size() - 1)
	if pick == _last_model and MODELS.size() > 1:
		pick = (pick + 1 + _rng.randi_range(0, MODELS.size() - 2)) % MODELS.size()
	_last_model = pick
	var path: String = MODELS[pick]
	var node := _chars.spawn(path, PED_HEIGHT)
	ShadowBlob.attach(node, 0.48)
	var skin: Color = SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)]
	var shirt: Color = SHIRTS[_rng.randi_range(0, SHIRTS.size() - 1)]
	var pants: Color = PANTS[_rng.randi_range(0, PANTS.size() - 1)]
	_chars.tint(node, shirt, pants, skin)
	add_child(node)
	node.visible = false
	v.node = node
	v.ap = _chars.get_player(node)
	v.anims = _chars.anim_names(node)
