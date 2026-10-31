extends Node3D
## Animal life (issue #208): respectful incidental fauna around the city.
## Three street dogs sunbathe beside the bazaar stalls and trot between
## the stall rows on short straight beats, and a small macaque troop
## holds the railway-station roof ledges — mostly sitting, with the odd
## hop along a ledge line. Nobody begs, bites or chases (the cows of
## city_dressing.gd stay the calm baseline). Purely kinematic like the
## pedestrians: fixed anchors and ledge points, no navigation, nothing
## can fall through the world, and each animal hides past its draw
## distance so the troop costs nothing unless you go look at it.
## All procedural primitives (capsules/spheres/cones — the de-box
## directive), shared materials, one contact shadow blob each.

const ShadowBlob := preload("res://scripts/shadowblob.gd")
const MeshTools := preload("res://scripts/meshtools.gd")

const HIDE_DOG := 135.0
const HIDE_MONKEY := 155.0
const DOG_TROT := 2.3
const DOG_CADENCE := 10.5
const LIE_MIN := 16.0
const LIE_MAX := 38.0
const RISE_T := 0.55
const HOP_T := 0.5
const HOP_H := 0.55
const SIT_MIN := 4.0
const SIT_MAX := 13.0
const STAND_LEG_Y := 0.42
const LIE_DROP := 0.30

const DOG_COATS := [
	Color(0.58, 0.44, 0.28),
	Color(0.78, 0.71, 0.58),
	Color(0.40, 0.29, 0.19),
]

var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _dogs: Array[Dictionary] = []
var _monkeys: Array[Dictionary] = []
var _spots: Array[Dictionary] = []


func register_player(p: Node3D) -> void:
	_player = p


func setup_dogs(hawker_spots: Array[Dictionary]) -> void:
	## Three strays working the bazaar stall rows: sunbathe at a stall
	## front, rise, trot a short beat to another stall, settle again.
	if hawker_spots.is_empty():
		return
	_spots = hawker_spots
	_rng.randomize()
	var cross_z := _lane_cross_z()
	for i in range(mini(3, _spots.size())):
		var coat: Color = DOG_COATS[i % DOG_COATS.size()]
		var d := _build_dog(coat)
		var anchor := i * 2  # spread the pack across the lane
		if anchor >= _spots.size():
			anchor = i
		var spot := _sunbathe_spot(anchor)
		d["root"].position = spot
		d["root"].rotation.y = -_spots[anchor]["face"] * PI / 2.0
		d["anchor"] = anchor
		d["blend"] = 1.0
		d["lie_t"] = _rng.randf_range(LIE_MIN, LIE_MAX)
		d["phase"] = _rng.randf() * TAU
		d["seed"] = _rng.randf() * TAU
		d["cross_z"] = cross_z
		_dogs.append(d)
		add_child(d["root"])


func setup_monkeys(station_center: Vector3) -> void:
	## Five macaques on the station roof lines (railway.gd local
	## coords): three on the canopy slab, two on the building ridge.
	## Two are committed sitters — the issue asks for static poses plus
	## hop animation, so only three ever move, and only along their own
	## ledge line (no pathing chaos).
	_rng.randomize()
	var plan := [
		{"line": "canopy", "i": 2, "mobile": true},
		{"line": "canopy", "i": 6, "mobile": true},
		{"line": "canopy", "i": 10, "mobile": false},
		{"line": "ridge", "i": 1, "mobile": true},
		{"line": "ridge", "i": 5, "mobile": false},
	]
	for p in plan:
		var m := _build_monkey()
		var ledge := _ledge_points(p["line"] == "canopy", station_center)
		var idx: int = p["i"]
		m["ledge"] = ledge
		m["i"] = idx
		m["mobile"] = p["mobile"]
		m["root"].position = ledge[idx]
		m["root"].rotate_y(_rng.randf_range(0.0, TAU))
		m["sit_t"] = _rng.randf_range(SIT_MIN, SIT_MAX)
		m["groom_t"] = _rng.randf_range(6.0, 20.0)
		m["seed"] = _rng.randf() * TAU
		m["hop_t"] = 0.0
		m["from"] = ledge[idx]
		_monkeys.append(m)
		add_child(m["root"])


func _process(delta: float) -> void:
	var pp: Vector3 = _player.global_position if _player != null \
			and is_instance_valid(_player) else Vector3(INF, 0.0, 0.0)
	for d in _dogs:
		if not d["root"].visible:
			if d["root"].global_position.distance_to(pp) < HIDE_DOG:
				d["root"].visible = true
			else:
				continue
		elif d["root"].global_position.distance_to(pp) > HIDE_DOG + 20.0:
			d["root"].visible = false
			continue
		_tick_dog(d, delta)
	for m in _monkeys:
		if not m["root"].visible:
			if m["root"].global_position.distance_to(pp) < HIDE_MONKEY:
				m["root"].visible = true
			else:
				continue
		elif m["root"].global_position.distance_to(pp) > HIDE_MONKEY + 20.0:
			m["root"].visible = false
			continue
		_tick_monkey(m, delta)


# ------------------------------------------------------------------ dogs

func _tick_dog(d: Dictionary, dt: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	match d["state"]:
		"lie":
			d["blend"] = minf(d["blend"] + dt / RISE_T, 1.0)
			d["lie_t"] -= dt
			# slow head survey + the odd tail thump
			d["head"].rotation.y = sin(t * 0.35 + d["seed"]) * 0.45
			var thump := maxf(0.0, sin(t * 1.1 + d["seed"]))
			d["tail"].rotation.y = sin(t * 16.0) * 0.4 * pow(thump, 6.0)
			if d["lie_t"] <= 0.0:
				d["state"] = "rise"
		"rise":
			d["blend"] = maxf(d["blend"] - dt / RISE_T, 0.0)
			if d["blend"] <= 0.0:
				var next := _next_anchor(d["anchor"])
				d["waypoints"] = _trot_path(d["anchor"], next)
				d["anchor"] = next
				d["state"] = "trot"
		"trot":
			d["phase"] += dt * DOG_CADENCE
			var wps: Array = d["waypoints"]
			if wps.is_empty():
				d["state"] = "settle"
				return
			var tgt: Vector3 = wps[0]
			var here: Vector3 = d["root"].position
			var step := DOG_TROT * dt
			if here.distance_to(tgt) <= step:
				d["root"].position = tgt
				wps.pop_front()
			else:
				var dir := (tgt - here).normalized()
				d["root"].position = here + dir * step
				var face := here + dir
				if face != d["root"].position:
					d["root"].look_at(face)
		"settle":
			d["blend"] = minf(d["blend"] + dt / RISE_T, 1.0)
			if d["blend"] >= 1.0:
				d["state"] = "lie"
				d["lie_t"] = _rng.randf_range(LIE_MIN, LIE_MAX)
	_apply_dog_pose(d)


func _apply_dog_pose(d: Dictionary) -> void:
	var b: float = d["blend"]
	d["rig"].position.y = -LIE_DROP * b
	var moving: float = 1.0 if d["state"] == "trot" else 0.0
	var swing := 0.0
	if moving > 0.0:
		swing = sin(d["phase"]) * 0.5
	var i := 0
	for leg in d["legs"]:
		# diagonal gait: front-left with back-right etc.
		var diag: float = 1.0 if i == 0 or i == 3 else -1.0
		var splay: float = 1.15 if i < 2 else -1.15
		leg.rotation.x = lerp(splay * b, swing * diag, moving * (1.0 - b))
		i += 1
	if moving > 0.0:
		d["rig"].position.y += sin(d["phase"] * 2.0) * 0.012 * (1.0 - b)
		d["head"].rotation.y = 0.0
	d["tail"].rotation.x = lerp(-0.95, 0.15, b)


func _trot_path(from_anchor: int, to_anchor: int) -> Array:
	## Straight beats only: down this stall row to the wide cross gap,
	## across the lane, down the far row into the next sunbathe spot.
	var a: Dictionary = _spots[from_anchor]
	var bspot: Dictionary = _spots[to_anchor]
	var out: Array = []
	var lane_a := _lane_x(a)
	var lane_b := _lane_x(bspot)
	var cross_z: float = _dogs[0]["cross_z"] if not _dogs.is_empty() else 0.0
	if lane_a != lane_b:
		out.append(Vector3(lane_a, 0.0, cross_z))
		out.append(Vector3(lane_b, 0.0, cross_z))
	out.append(_sunbathe_spot(to_anchor))
	return out


func _next_anchor(current: int) -> int:
	var pick := current
	while pick == current:
		pick = _rng.randi_range(0, _spots.size() - 1)
	return pick


func _lane_x(spot: Dictionary) -> float:
	return spot["pos"].x + spot["face"] * 2.7


func _sunbathe_spot(anchor: int) -> Vector3:
	var s: Dictionary = _spots[anchor]
	var z: float = s["pos"].z + _rng.randf_range(-1.0, 1.0)
	return Vector3(_lane_x(s), 0.0, z)


func _lane_cross_z() -> float:
	## Midpoint of the widest gap between stall rows — the polite place
	## for a dog to cross the market lane.
	var zs: Array[float] = []
	for s in _spots:
		if not zs.has(s["pos"].z):
			zs.append(s["pos"].z)
	zs.sort()
	if zs.size() < 2:
		return zs[0] if not zs.is_empty() else 0.0
	var best_z := (zs[0] + zs[1]) / 2.0
	var best_gap := 0.0
	for i in range(zs.size() - 1):
		var gap := zs[i + 1] - zs[i]
		if gap > best_gap:
			best_gap = gap
			best_z = (zs[i] + zs[i + 1]) / 2.0
	return best_z


func _build_dog(coat: Color) -> Dictionary:
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.position.y = -LIE_DROP
	root.add_child(rig)
	var body := CapsuleMesh.new()
	body.radius = 0.125
	body.height = 0.58
	_part(rig, body, coat, Vector3(0.0, 0.46, 0.0), Vector3(PI / 2.0, 0.0, 0.0))
	var chest := SphereMesh.new()
	chest.radius = 0.13
	chest.height = 0.26
	_part(rig, chest, coat, Vector3(0.0, 0.44, -0.16))
	var rump := SphereMesh.new()
	rump.radius = 0.115
	rump.height = 0.23
	_part(rig, rump, coat, Vector3(0.0, 0.45, 0.20))
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.60, -0.33)
	rig.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.095
	skull.height = 0.19
	_part(head, skull, coat, Vector3.ZERO)
	var snout := CapsuleMesh.new()
	snout.radius = 0.042
	snout.height = 0.17
	_part(head, snout, coat.darkened(0.35), Vector3(0.0, -0.035, -0.12),
			Vector3(PI / 2.0, 0.0, 0.0))
	for side in [-0.06, 0.06]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.012
		ear.bottom_radius = 0.045
		ear.height = 0.11
		_part(head, ear, coat.darkened(0.2), Vector3(side, 0.085, 0.015))
	var tail := Node3D.new()
	tail.position = Vector3(0.0, 0.54, 0.31)
	tail.rotation.x = -0.95
	rig.add_child(tail)
	var tseg := CapsuleMesh.new()
	tseg.radius = 0.024
	tseg.height = 0.30
	_part(tail, tseg, coat, Vector3(0.0, 0.0, 0.15), Vector3(PI / 2.0, 0.0, 0.0))
	var legs: Array[Node3D] = []
	for lx in [-0.078, 0.078]:
		for lz in [-0.19, 0.18]:
			var piv := Node3D.new()
			piv.position = Vector3(lx, STAND_LEG_Y, lz)
			rig.add_child(piv)
			var leg := CapsuleMesh.new()
			leg.radius = 0.032
			leg.height = 0.36
			_part(piv, leg, coat, Vector3(0.0, -0.17, 0.0))
			legs.append(piv)
	ShadowBlob.attach(root, 0.45)
	return {"root": root, "rig": rig, "legs": legs, "tail": tail,
			"head": head, "state": "lie"}


# --------------------------------------------------------------- monkeys

func _tick_monkey(m: Dictionary, dt: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	match m["state"]:
		"sit":
			m["sit_t"] -= dt
			m["head"].rotation.y = sin(t * 0.5 + m["seed"]) * 0.5
			m["tail"].rotation.y = sin(t * 1.3 + m["seed"]) * 0.25
			m["groom_t"] -= dt
			var groom: float = 0.0
			if m["groom_t"] < 1.4 and m["groom_t"] > 0.0:
				groom = sin(m["groom_t"] / 1.4 * PI)
			m["arm_l"].rotation.x = 0.35 - groom * 1.5
			m["arm_r"].rotation.x = 0.35 - groom * 1.5
			if m["groom_t"] <= 0.0:
				m["groom_t"] = _rng.randf_range(6.0, 22.0)
			if m["sit_t"] <= 0.0:
				if m["mobile"] and m["ledge"].size() > 1:
					var step := 1 if m["i"] + 1 < m["ledge"].size() else -1
					if _rng.randf() < 0.4:
						step = -step
					var j: int = clampi(m["i"] + step, 0, m["ledge"].size() - 1)
					if j == m["i"]:
						m["sit_t"] = _rng.randf_range(SIT_MIN, SIT_MAX)
					else:
						m["from"] = m["ledge"][m["i"]]
						m["to"] = m["ledge"][j]
						m["i"] = j
						m["hop_t"] = HOP_T
						m["state"] = "hop"
				else:
					m["sit_t"] = _rng.randf_range(SIT_MIN, SIT_MAX)
		"hop":
			m["hop_t"] -= dt
			var p := 1.0 - clampf(m["hop_t"] / HOP_T, 0.0, 1.0)
			m["root"].position = m["from"].lerp(m["to"], p)
			m["root"].position.y += sin(PI * p) * HOP_H
			m["rig"].rotation.x = sin(PI * p) * 0.3
			if m["hop_t"] <= 0.0:
				m["root"].position = m["to"]
				m["rig"].rotation.x = 0.0
				m["root"].rotate_y(_rng.randf_range(0.0, TAU))
				m["state"] = "sit"
				m["sit_t"] = _rng.randf_range(SIT_MIN, SIT_MAX)


func _ledge_points(canopy: bool, center: Vector3) -> Array[Vector3]:
	## Walk lines along the canopy slab top (y ~4.93) and the station
	## building ridge (y ~4.86) — railway.gd geometry, local z along the
	## platforms, world-shifted by the station block center.
	var out: Array[Vector3] = []
	if canopy:
		for z in range(-12, 13, 2):
			out.append(center + Vector3(-6.75, 4.94, z))
	else:
		for z in range(-6, 7, 2):
			out.append(center + Vector3(6.6, 4.87, z + 0.4))
	return out


func _build_monkey() -> Dictionary:
	var root := Node3D.new()
	var rig := Node3D.new()
	root.add_child(rig)
	var coat := Color(0.47, 0.39, 0.31)
	var face := Color(0.72, 0.51, 0.43)
	var hips := SphereMesh.new()
	hips.radius = 0.085
	hips.height = 0.17
	_part(rig, hips, coat, Vector3(0.0, 0.07, 0.0))
	var torso := CapsuleMesh.new()
	torso.radius = 0.082
	torso.height = 0.30
	_part(rig, torso, coat, Vector3(0.0, 0.24, 0.02), Vector3(-0.28, 0.0, 0.0))
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.44, -0.03)
	rig.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.075
	skull.height = 0.15
	_part(head, skull, coat, Vector3.ZERO)
	var muzzle := SphereMesh.new()
	muzzle.radius = 0.042
	muzzle.height = 0.084
	_part(head, muzzle, face, Vector3(0.0, -0.015, -0.062))
	for side in [-0.07, 0.07]:
		var ear := SphereMesh.new()
		ear.radius = 0.028
		ear.height = 0.056
		_part(head, ear, face, Vector3(side, 0.02, 0.0))
	var arm_l := Node3D.new()
	arm_l.position = Vector3(-0.095, 0.36, 0.0)
	arm_l.rotation.x = 0.35
	rig.add_child(arm_l)
	var arm_r := Node3D.new()
	arm_r.position = Vector3(0.095, 0.36, 0.0)
	arm_r.rotation.x = 0.35
	rig.add_child(arm_r)
	for piv in [arm_l, arm_r]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.026
		arm.height = 0.28
		_part(piv, arm, coat, Vector3(0.0, -0.12, 0.0))
	for side in [-0.05, 0.05]:
		var thigh := CapsuleMesh.new()
		thigh.radius = 0.03
		thigh.height = 0.22
		_part(rig, thigh, coat, Vector3(side, 0.09, 0.10),
				Vector3(PI / 2.0, 0.0, 0.0))
	var tail := Node3D.new()
	tail.position = Vector3(0.0, 0.05, 0.10)
	rig.add_child(tail)
	var tseg := CapsuleMesh.new()
	tseg.radius = 0.02
	tseg.height = 0.44
	_part(tail, tseg, coat, Vector3(0.0, 0.09, 0.12), Vector3(1.15, 0.0, 0.0))
	ShadowBlob.attach(root, 0.24)
	return {"root": root, "rig": rig, "head": head, "tail": tail,
			"arm_l": arm_l, "arm_r": arm_r, "state": "sit"}


# ---------------------------------------------------------------- shared

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	mesh.material = MeshTools.shared_material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
