extends Node
## Animal life (issue #208): respectful incidental fauna to match the
## kerbside cows — three street dogs (two sunbathing by the bazaar
## stall rows, one trotting a fixed beat along the Chandni Chowk kerb)
## and a rhesus troop up on the two metro station canopies (sitters on
## the roof edges, two hoppers working the ledge line). All procedural
## MeshTools bodies — capsules, balls and torus curls, zero new box
## faces (de-box directive) — muted PS2-era palette, no assets.
## Movers are kinematic like the pedestrians: fixed paths, no
## interaction, no aggression, nothing for the player to collide with.

const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

# ---------------------------------------------------------- palette
const DOG_COAT := Color(0.62, 0.47, 0.34)      ## dusty tan street dog
const DOG_COAT2 := Color(0.48, 0.38, 0.28)     ## second dog, darker brindled
const DOG_DARK := Color(0.27, 0.21, 0.16)      ## muzzles, ears, nose
const DOG_BELLY := Color(0.76, 0.68, 0.58)     ## sun-bleached underside
const MONK_FUR := Color(0.47, 0.42, 0.37)      ## grey-brown macaque
const MONK_DARK := Color(0.30, 0.27, 0.23)     ## cap, hands, tail curl
const MONK_FACE := Color(0.72, 0.53, 0.47)     ## pink face disc

# ---------------------------------------------------------- behaviour
const TROT_SPEED := 1.6          ## m/s along the kerb beat (m/s)
const TROT_HZ := 5.0             ## trot bob frequency (Hz)
const TROT_BOB := 0.028          ## body bob height (m)
const HOP_T := 0.55              ## one ledge hop, takeoff to land (s)
const HOP_H := 0.55              ## hop apex above the perch (m)
const HOP_MIN := 2.2             ## hop length between perches (m)
const HOP_MAX := 3.4
const IDLE_MIN := 2.5            ## sit idle between hops (s)
const IDLE_MAX := 6.0
const PERCH_EDGE := 13.0         ## monkeys stay this far inside the canopy

## Canopy facts shared with metro.gd / main.gd station halls: the shell
## is 3.4 m wide, 3.2 m tall centred at y = 14.6, so the roof line the
## troop sits on is y = 16.2 over a z span of +-15 m at each station.
const ROOF_Y := 16.2
const STATION_Z := [-40.0, 142.0]

# ---------------------------------------------------------- state
var _trotter: MeshInstance3D = null
var _trot_a := Vector3.ZERO
var _trot_b := Vector3.ZERO
var _trot_t := 0.0
var _trot_dir := 1.0

var _hoppers: Array = []

var _tris := 0


func setup(world: float, pitch: float, road_w: float) -> void:
	var half := (pitch - road_w) / 2.0
	## Same block-centre convention as city_dressing.gd (slice 2).
	var cc := Vector3(-world / 2.0 + 4.0 * pitch + road_w / 2.0,
			Roads.CURB_H, -world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var cp := Vector3(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			Roads.CURB_H, -world / 2.0 + 5.0 * pitch + road_w / 2.0)

	var root := Node3D.new()
	root.name = "Fauna"

	# ---- static layer: two sunbathing dogs + five roof sitters, one
	# merged mesh (same pattern as the kerbside cows).
	var b := MeshTools.new()
	var dog_xfs: Array[Transform3D] = [
		## Chandni Chowk kerb, sun-side of the stall row, clear of the
		## cows (2.5 m+) and carts.
		Transform3D(Basis(Vector3.UP, 2.4), Vector3(cc.x + half - 2.9, 0.0, cc.y + 3.4)),
		## Connaught Place ring kerb near the chai end.
		Transform3D(Basis(Vector3.UP, -1.2), Vector3(cp.x + half - 2.6, 0.0, cp.y - 4.6)),
	]
	_dog_lying(b, DOG_COAT)
	_dog_lying(b, DOG_COAT2)
	var sits: Array[Transform3D] = []
	for i in 5:
		var st := 0 if i < 3 else 1
		var side := -1.0 if i % 2 == 0 else 1.0
		var zz: float = STATION_Z[st] + [-11.0, -4.0, 7.5, -8.5, 5.0][i]
		sits.append(Transform3D(Basis(Vector3.UP, side * 1.35),
				Vector3(side * 1.15, ROOF_Y, zz)))
	for xf in sits:
		_monkey(b)
	var mi := b.build_node()
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		_tris = b.tris

	# ---- street-level colliders for the two lying dogs (slice-1 rule:
	# nothing at street level is walk-through; movers match the
	# pedestrians and stay uncollided).
	var solid := StaticBody3D.new()
	for xf in dog_xfs:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 0.34, 0.52)
		shape.shape = box
		shape.transform = xf * Transform3D(Basis(), Vector3(0.0, 0.17, 0.0))
		solid.add_child(shape)
	root.add_child(solid)

	# ---- the trotter: one standing dog, one draw call, fixed beat.
	var tb := MeshTools.new()
	_dog_standing(tb, DOG_COAT)
	_trotter = tb.build_node()
	_trotter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trot_a = Vector3(cc.x + half - 3.4, Roads.CURB_H, cc.y - 8.0)
	_trot_b = Vector3(cc.x + half - 3.4, Roads.CURB_H, cc.y + 9.0)
	_trotter.position = _trot_a
	root.add_child(_trotter)
	_tris += tb.tris

	# ---- two ledge hoppers, one per station canopy.
	for st in 2:
		var hb := MeshTools.new()
		_monkey(hb)
		var hop := MeshInstance3D.new()
		hop.mesh = hb.build_mesh()
		hop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hop.position = Vector3(0.9 if st == 0 else -0.9, ROOF_Y, STATION_Z[st] - 6.0)
		root.add_child(hop)
		_tris += hb.tris
		_hoppers.append({
			"node": hop, "base_z": STATION_Z[st], "x": hop.position.x,
			"dir": 1.0 if st == 0 else -1.0, "idle": 1.5 + 2.0 * st,
			"t": -1.0, "z0": 0.0, "z1": 0.0,
		})

	add_child(root)
	print("fauna: dogs+monkeys ", _tris, " tris, 1 merged static + 3 movers")


func _process(delta: float) -> void:
	if _trotter != null:
		## Ping-pong the kerb beat: distance-phase along the segment,
		## body bob plus a hint of roll reads as a trot at PS2 weight.
		var len_a := _trot_a.distance_to(_trot_b)
		_trot_t += _trot_dir * TROT_SPEED * delta / maxf(len_a, 0.001)
		if _trot_t >= 1.0:
			_trot_t = 1.0
			_trot_dir = -1.0
		elif _trot_t <= 0.0:
			_trot_t = 0.0
			_trot_dir = 1.0
		var pos := _trot_a.lerp(_trot_b, _trot_t)
		var ph := Time.get_ticks_msec() * 0.001 * TROT_HZ
		pos.y += sin(ph) * TROT_BOB
		_trotter.position = pos
		_trotter.rotation.y = PI if _trot_dir < 0.0 else 0.0
		_trotter.rotation.z = sin(ph) * 0.03

	for h in _hoppers:
		## Sit, then a parabolic hop to the next ledge perch — the troop
		## never leaves the canopy line and never reacts to the street.
		if h["t"] < 0.0:
			h["idle"] -= delta
			if h["idle"] <= 0.0:
				var dz: float = randf_range(HOP_MIN, HOP_MAX) * h["dir"]
				var z: float = h["node"].position.z
				if z + dz > h["base_z"] + PERCH_EDGE or z + dz < h["base_z"] - PERCH_EDGE:
					h["dir"] = -h["dir"]
					dz = -dz
				h["z0"] = z
				h["z1"] = z + dz
				h["t"] = 0.0
			continue
		h["t"] += delta / HOP_T
		var t: float = clampf(h["t"], 0.0, 1.0)
		var node: MeshInstance3D = h["node"]
		node.position.z = lerpf(h["z0"], h["z1"], t)
		node.position.y = ROOF_Y + HOP_H * 4.0 * t * (1.0 - t)
		node.rotation.y = PI if h["dir"] < 0.0 else 0.0
		node.scale = Vector3.ONE * (1.0 - 0.12 * sin(PI * t))
		if h["t"] >= 1.0:
			node.position.y = ROOF_Y
			node.scale = Vector3.ONE
			h["t"] = -1.0
			h["idle"] = randf_range(IDLE_MIN, IDLE_MAX)


# ---------------------------------------------------------- bodies
# Every animal is capsules (CapsuleMesh), balls (SphereMesh) and torus
# curls — round silhouettes only, no new flat-face boxes anywhere.

func _dog_standing(b: MeshTools, coat: Color) -> void:
	## Trotting pose: level back, head forward, tail up.
	var flat := Basis().rotated(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	b.add_mesh(_caps(0.105, 0.46), Transform3D(flat, Vector3(0.0, 0.40, 0.0)), coat)
	b.add_mesh(_ball(0.085), Transform3D(Basis(), Vector3(0.17, 0.44, 0.0)), DOG_BELLY)
	b.add_mesh(_ball(0.095), Transform3D(Basis(), Vector3(0.28, 0.50, 0.0)), coat)
	b.add_mesh(_caps(0.036, 0.13), Transform3D(flat, Vector3(0.40, 0.475, 0.0)), DOG_DARK)
	b.add_mesh(_ball(0.024), Transform3D(Basis(), Vector3(0.465, 0.485, 0.0)), DOG_DARK)
	for s in [-1.0, 1.0]:
		var ear := Basis().scaled(Vector3.ONE * 0.9)
		b.add_mesh(_ball(0.036), Transform3D(ear, Vector3(0.245, 0.585, 0.05 * s)), DOG_DARK)
		for x in [0.15, -0.15]:
			b.add_mesh(_cyl(0.026, 0.32), Transform3D(Basis(), Vector3(x, 0.16, 0.065 * s)), coat)
	b.add_mesh(_cyl(0.018, 0.26), Transform3D(
			Basis().rotated(Vector3(0.0, 0.0, 1.0), 0.6),
			Vector3(-0.30, 0.55, 0.0)), coat)


func _dog_lying(b: MeshTools, coat: Color) -> void:
	## Sunbathing pose: flank on the kerb, head up, tail curled round.
	var flat := Basis().rotated(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	var low := flat.scaled(Vector3(1.0, 1.0, 0.88))
	b.add_mesh(_caps(0.115, 0.50), Transform3D(low, Vector3(0.0, 0.115, 0.0)), coat)
	b.add_mesh(_ball(0.08), Transform3D(Basis(), Vector3(0.24, 0.24, 0.0)), coat)
	b.add_mesh(_caps(0.034, 0.12), Transform3D(flat, Vector3(0.35, 0.225, 0.0)), DOG_DARK)
	b.add_mesh(_ball(0.022), Transform3D(Basis(), Vector3(0.41, 0.235, 0.0)), DOG_DARK)
	for s in [-1.0, 1.0]:
		var ear := Basis().rotated(Vector3(0.0, 1.0, 0.0), -0.7).scaled(Vector3(0.9, 0.35, 0.9))
		b.add_mesh(_ball(0.04), Transform3D(ear, Vector3(0.215, 0.315, 0.055 * s)), DOG_DARK)
		b.add_mesh(_caps(0.038, 0.22), Transform3D(flat,
				Vector3(0.10, 0.055, 0.105 * s)), coat)
	var curl := TorusMesh.new()
	curl.inner_radius = 0.062
	curl.outer_radius = 0.088
	b.add_mesh(curl, Transform3D(Basis().rotated(Vector3(1.0, 0.0, 0.0), PI * 0.5),
			Vector3(-0.30, 0.075, 0.02)), DOG_DARK)


func _monkey(b: MeshTools) -> void:
	## Rhesus sit: haunches down, arms forward, tail curled up behind.
	var squash := Basis().scaled(Vector3(1.0, 1.05, 0.85))
	b.add_mesh(_ball(0.13), Transform3D(squash, Vector3(0.0, 0.125, 0.0)), MONK_FUR)
	var lean := Basis().rotated(Vector3(0.0, 0.0, 1.0), -0.18).scaled(Vector3(0.95, 1.0, 0.8))
	b.add_mesh(_ball(0.105), Transform3D(lean, Vector3(0.035, 0.27, 0.0)), MONK_FUR)
	b.add_mesh(_ball(0.085), Transform3D(Basis(), Vector3(0.05, 0.41, 0.0)), MONK_FUR)
	var face := Basis().scaled(Vector3(0.55, 0.9, 0.85))
	b.add_mesh(_ball(0.062), Transform3D(face, Vector3(0.115, 0.405, 0.0)), MONK_FACE)
	b.add_mesh(_ball(0.075), Transform3D(Basis().scaled(Vector3(0.8, 0.55, 0.9)),
			Vector3(0.01, 0.455, 0.0)), MONK_DARK)
	for s in [-1.0, 1.0]:
		b.add_mesh(_ball(0.028), Transform3D(Basis(), Vector3(0.035, 0.435, 0.085 * s)), MONK_FUR)
		var arm := Basis().rotated(Vector3(0.0, 0.0, 1.0), 0.25)
		b.add_mesh(_caps(0.021, 0.19), Transform3D(arm,
				Vector3(0.085, 0.185, 0.075 * s)), MONK_FUR)
	var curl := TorusMesh.new()
	curl.inner_radius = 0.06
	curl.outer_radius = 0.084
	b.add_mesh(curl, Transform3D(Basis().rotated(Vector3(1.0, 0.0, 0.0), PI * 0.5),
			Vector3(-0.125, 0.16, 0.0)), MONK_DARK)


static func _caps(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 3
	return m


static func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	return m
