extends Node3D
## Rideable elevated metro shuttle (issue #98, part 2). A three-car train
## ping-pongs along the x=0 viaduct between two canopied street stations:
## press E at a station gate to board, ride across the map from an interior
## cam between the benches, press E again at a stop to step out. The train,
## canopies, gates and signs are all procedural — boxes, cylinders,
## Label3Ds and one warm lamp per gate. No assets, no imports.

const MeshTools := preload("res://scripts/meshtools.gd")

## Viaduct facts (main.gd _build_metro): deck boxes 10 wide, 1.2 thick,
## centred at y=12.4 — so the rail surface the wheels sit on is y=13.0.
const DECK_TOP := 13.0
const CRUISE := 24.0
const ACCEL := 5.0
const DWELL := 4.5
const CAR_LEN := 8.4
const CAR_GAP := 0.7

const BODY_COLOR := Color(0.88, 0.90, 0.93)
const LIVERY := Color(0.18, 0.44, 0.70)
const UNDER_COLOR := Color(0.16, 0.17, 0.20)
const BENCH_COLOR := Color(0.16, 0.42, 0.38)
const GOLD := Color(1.0, 0.83, 0.25)

## Station 0 reuses the canopy hall main.gd already builds at z=-40;
## station 1 gets its twin here, 182 m north, so the ride crosses a
## third of the map end to end.
var stations: Array = [
	{"z": -40.0, "name": "OLD BAZAAR"},
	{"z": 142.0, "name": "LAKE DISTRICT"},
]

## Platform interior (issue #218): the east deck side at each station
## becomes a walkable platform one step up from the street lift — floor
## slab on real colliders, tactile edge broken by a lit door strip,
## pillars under a curved canopy, benches, a hanging route board and
## railings all round so nobody wanders onto the tracks. The lift tower
## at the north end carries the E-transfer between street and platform.
const PLAT_X0 := 1.55
const PLAT_X1 := 4.35
const PLAT_TOP := 13.55
const PLAT_Z0 := -13.0
const PLAT_Z1 := 9.4
const LIFT_DZ := 10.7

signal arrived(idx: int, stop_name: String)
signal departed(idx: int, next_name: String)

var _state := "dwell"
var _timer := DWELL
var _speed := 0.0
## Destination z for the current run leg, fixed at departure (QA sweep
## 1, issue #168): recomputing "farthest station" every frame flipped the
## target at the exact midpoint between stations, so the shuttle
## oscillated at z=51 forever and never reached the far platform —
## the ride stalled mid-viaduct and queued boarders waited endlessly.
var _target_z := -40.0
## This node is the static container (gates, canopies); _train is the
## moving shuttle so the ride never drags the stations along.
var _train: Node3D = null
var _glass_mat: StandardMaterial3D = null
var _lamp_mat: StandardMaterial3D = null
var _door_mat: StandardMaterial3D = null
var _gate_pos: Array[Vector3] = []


func setup() -> void:
	_build_glass()
	_build_canopy(1)
	for i in stations.size():
		_build_gate(i)
		_build_platform(i)
	_build_train()


# ------------------------------------------------------------ public API

func station_name(idx: int) -> String:
	return String(stations[clampi(idx, 0, stations.size() - 1)]["name"])


func other_idx(idx: int) -> int:
	return 0 if idx != 0 else 1


func is_dwelling_at(idx: int) -> bool:
	return _state == "dwell" and dwelling_idx() == idx


func dwelling_idx() -> int:
	if _state != "dwell" or _train == null:
		return -1
	for i in stations.size():
		if absf(_train.position.z - float(stations[i]["z"])) < 1.0:
			return i
	return -1


func gate_near(pos: Vector3, max_d: float) -> Dictionary:
	for i in _gate_pos.size():
		var d: float = pos.distance_to(_gate_pos[i])
		if d <= max_d:
			return {"idx": i, "name": station_name(i), "pos": _gate_pos[i]}
	return {}


func alight_pos(idx: int) -> Vector3:
	var p := _gate_pos[clampi(idx, 0, _gate_pos.size() - 1)]
	return Vector3(p.x, 1.0, p.z + 0.9)


## ------------------------------------------------------------ platform

func on_platform(pos: Vector3) -> bool:
	## Zone test for the walkable platforms (issue #218).
	if pos.y < 12.4 or pos.y > 17.2:
		return false
	if pos.x < PLAT_X0 - 0.4 or pos.x > PLAT_X1 + 0.4:
		return false
	for s in stations:
		if absf(pos.z - float(s["z"])) < 13.6:
			return true
	return false


func platform_door_near(pos: Vector3) -> Dictionary:
	## The lit door strip beside the tracks — E here boards the shuttle
	## (or queues for the next arrival).
	if not on_platform(pos):
		return {}
	for i in stations.size():
		if absf(pos.z - float(stations[i]["z"])) < 4.8:
			return {"idx": i}
	return {}


func platform_lift_near(pos: Vector3) -> Dictionary:
	## The lift head on the platform — E here rides down to the street.
	if not on_platform(pos):
		return {}
	for i in stations.size():
		if absf(pos.z - (float(stations[i]["z"]) + 8.3)) < 1.9:
			return {"idx": i}
	return {}


func street_entry_near(pos: Vector3, max_d: float) -> Dictionary:
	## Street level by the gate or under the lift tower — E rides up.
	if pos.y > 6.0:
		return {}
	for i in stations.size():
		var z := float(stations[i]["z"])
		for a in [Vector3(-1.8, 0.0, z), Vector3(5.5, 0.0, z + LIFT_DZ)]:
			if Vector2(pos.x - a.x, pos.z - a.z).length() <= max_d:
				return {"idx": i, "pos": a}
	return {}


func platform_entry_pos(idx: int) -> Vector3:
	var z := float(stations[clampi(idx, 0, stations.size() - 1)]["z"])
	return Vector3((PLAT_X0 + PLAT_X1) * 0.5, PLAT_TOP + 0.02, z + 8.3)


func platform_alight_pos(idx: int) -> Vector3:
	## Stepping out of the shuttle lands on the platform by the doors.
	var z := float(stations[clampi(idx, 0, stations.size() - 1)]["z"])
	return Vector3(2.6, PLAT_TOP + 0.02, z - 1.2)


func lift_street_pos(idx: int) -> Vector3:
	var z := float(stations[clampi(idx, 0, stations.size() - 1)]["z"])
	return Vector3(5.5, 0.2, z + LIFT_DZ)


func cam_eye() -> Vector3:
	## Aisle eye height in the middle car — symmetric, so the view works
	## whichever way the shuttle is pointing.
	return _train.to_global(Vector3(0.0, 1.55, 0.0))


func cam_look() -> Vector3:
	return _train.to_global(Vector3(0.0, 1.2, -8.0))


func carriage_floor_pos() -> Vector3:
	return _train.to_global(Vector3(0.0, 0.6, 0.0))


# ------------------------------------------------------------ movement

func _process(delta: float) -> void:
	if _train == null:
		return
	if _state == "dwell":
		_timer -= delta
		if _timer <= 0.0:
			var from := _at_station()
			_target_z = float(stations[other_idx(from)]["z"])
			_state = "run"
			departed.emit(from, station_name(other_idx(from)))
		return
	# Trapezoid speed profile: accelerate to cruise, then bleed speed so
	# the train eases to a stop exactly at the target station.
	var target := _target_z
	var dist: float = absf(target - _train.position.z)
	var v_max: float = minf(CRUISE, sqrt(2.0 * ACCEL * dist))
	if _speed < v_max:
		_speed = minf(_speed + ACCEL * delta, v_max)
	else:
		_speed = maxf(_speed - ACCEL * delta, v_max)
	var dir := 1.0 if target > _train.position.z else -1.0
	_train.position.z = move_toward(_train.position.z, target, _speed * delta)
	_train.rotation.y = PI if dir > 0.0 else 0.0
	if absf(target - _train.position.z) < 0.001:
		_speed = 0.0
		_state = "dwell"
		_timer = DWELL
		var idx := 1 if target == float(stations[1]["z"]) else 0
		arrived.emit(idx, station_name(idx))


func _at_station() -> int:
	## Which station z the train is standing at (dwell calls only).
	var at0 := absf(_train.position.z - float(stations[0]["z"]))
	var at1 := absf(_train.position.z - float(stations[1]["z"]))
	return 0 if at0 < at1 else 1


# ------------------------------------------------------------ construction

func _build_glass() -> void:
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.10, 0.13, 0.19, 0.42)
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(1.0, 0.95, 0.82)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.9, 0.65)
	_lamp_mat.emission_energy_multiplier = 2.2
	_door_mat = StandardMaterial3D.new()
	_door_mat.albedo_color = Color(1.0, 0.9, 0.45)
	_door_mat.emission_enabled = true
	_door_mat.emission = Color(1.0, 0.85, 0.3)
	_door_mat.emission_energy_multiplier = 1.6


func _build_canopy(i: int) -> void:
	## Twin of the z=-40 hall main.gd builds: a light shell over the rails
	## with a livery-blue fascia band.
	var b := MeshTools.new()
	var z := float(stations[i]["z"])
	b.add_box(Vector3(3.4, 3.2, 30.0), Vector3(0.0, 14.6, z),
			Color(0.85, 0.87, 0.90))
	b.add_box(Vector3(3.5, 0.7, 30.0), Vector3(0.0, 14.0, z), LIVERY)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	add_child(mi)


func _build_gate(i: int) -> void:
	## Street-level entrance under the viaduct edge: two posts, a lintel,
	## a lit sign with the station name, a warm lamp for the night city
	## and a slim collider so the posts read as solid.
	var z := float(stations[i]["z"])
	var root := Node3D.new()
	root.position = Vector3(-1.8, 0.0, z)
	add_child(root)
	_gate_pos.append(root.position)
	var b := MeshTools.new()
	b.add_box(Vector3(0.18, 2.5, 0.18), Vector3(0.0, 1.25, -1.15),
			Color(0.55, 0.58, 0.62))
	b.add_box(Vector3(0.18, 2.5, 0.18), Vector3(0.0, 1.25, 1.15),
			Color(0.55, 0.58, 0.62))
	b.add_box(Vector3(0.22, 0.5, 2.7), Vector3(0.0, 2.75, 0.0), LIVERY)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	root.add_child(mi)
	var sign := Label3D.new()
	sign.text = "METRO · " + station_name(i)
	sign.font_size = 40
	sign.modulate = GOLD
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.012
	sign.position = Vector3(0.0, 3.35, 0.0)
	root.add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.0, 2.4, 0.0)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.omni_range = 6.0
	lamp.omni_attenuation = 1.2
	root.add_child(lamp)
	var solid := StaticBody3D.new()
	for zz in [-1.15, 1.15]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 2.5, 0.3)
		col.shape = box
		col.position = Vector3(0.0, 1.25, zz)
		solid.add_child(col)
	root.add_child(solid)


func _build_platform(i: int) -> void:
	## Issue #218: walkable platform on the east deck side. The visual
	## batch is one merged mesh; a sibling StaticBody3D carries matched
	## colliders (floor, railings, benches, pillars, lift tower) so the
	## walker stands on something real — fully railed, the only way on
	## or off is the lift transfer and the train doors.
	var z := float(stations[i]["z"])
	var cx := (PLAT_X0 + PLAT_X1) * 0.5
	var b := MeshTools.new()
	var solid := StaticBody3D.new()
	# Floor slab: south end z-13, lift tower face z+9.4.
	var floor_len := PLAT_Z1 - PLAT_Z0
	var floor_c := z + (PLAT_Z0 + PLAT_Z1) * 0.5
	b.add_bev_box(Vector3(PLAT_X1 - PLAT_X0, 0.4, floor_len),
			Vector3(cx, PLAT_TOP - 0.2, floor_c), 0.06, Color(0.72, 0.71, 0.68))
	_coll(solid, Vector3(PLAT_X1 - PLAT_X0, 0.4, floor_len),
			Vector3(cx, PLAT_TOP - 0.2, floor_c))
	# Tactile safety strip along the edge, split around the door zone.
	for seg in [[-12.4, -3.8], [3.8, 8.9]]:
		var sc: float = (seg[0] + seg[1]) * 0.5
		var sl: float = seg[1] - seg[0]
		b.add_bev_box(Vector3(0.5, 0.07, sl),
				Vector3(PLAT_X0 + 0.42, PLAT_TOP + 0.035, z + sc), 0.02,
				Color(0.95, 0.78, 0.12))
	# Lit door strip where the middle car aligns (emissive, its own mesh).
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.5, 0.06, 7.6)
	strip.mesh = strip_mesh
	strip.material_override = _door_mat
	strip.position = Vector3(PLAT_X0 + 0.42, PLAT_TOP + 0.03, z)
	add_child(strip)
	# Canopy pillars and the curved shell roof over them.
	for pz in [-10.0, -5.0, 0.0, 5.0, 8.0]:
		var pil := CylinderMesh.new()
		pil.top_radius = 0.16
		pil.bottom_radius = 0.16
		pil.height = 2.3
		pil.radial_segments = 8
		b.add_mesh(pil, Transform3D(Basis(),
				Vector3(4.05, PLAT_TOP + 1.15, z + pz)), Color(0.62, 0.65, 0.70))
		_coll(solid, Vector3(0.34, 2.3, 0.34),
				Vector3(4.05, PLAT_TOP + 1.15, z + pz))
	var crown := PackedVector2Array()
	for t in 7:
		var ft := float(t) / 6.0
		crown.append(Vector2(-1.85 + 3.7 * ft,
				2.3 + 0.8 * (1.0 - pow(2.0 * ft - 1.0, 2.0))))
	b.add_shell(crown, -12.0, 8.8, Vector3(cx, PLAT_TOP, z), true,
			Color(0.85, 0.87, 0.90))
	b.add_bev_box(Vector3(0.18, 0.22, 20.6),
			Vector3(4.62, PLAT_TOP + 2.45, z - 1.7), 0.04, LIVERY)
	# Benches against the outer railing, clear of the door strip.
	for cz in [-6.2, 3.2]:
		b.add_bev_box(Vector3(0.55, 0.12, 2.2),
				Vector3(3.5, PLAT_TOP + 0.44, z + cz), 0.03, BENCH_COLOR)
		b.add_bev_box(Vector3(0.1, 0.5, 2.2),
				Vector3(3.78, PLAT_TOP + 0.72, z + cz), 0.02, BENCH_COLOR)
		for lz in [-0.9, 0.9]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.05
			leg.bottom_radius = 0.05
			leg.height = 0.44
			leg.radial_segments = 6
			b.add_mesh(leg, Transform3D(Basis(),
					Vector3(3.5, PLAT_TOP + 0.22, z + cz + lz)),
				Color(0.4, 0.42, 0.46))
		_coll(solid, Vector3(0.7, 0.95, 2.2),
				Vector3(3.55, PLAT_TOP + 0.47, z + cz))
	# Hanging route board, readable from both directions.
	b.add_bev_box(Vector3(2.0, 0.62, 0.09),
			Vector3(cx, PLAT_TOP + 2.2, z - 2.5), 0.02, Color(0.92, 0.93, 0.94))
	for hx in [-0.8, 0.8]:
		var hang := CylinderMesh.new()
		hang.top_radius = 0.03
		hang.bottom_radius = 0.03
		hang.height = 0.55
		hang.radial_segments = 6
		b.add_mesh(hang, Transform3D(Basis(),
				Vector3(cx + hx, PLAT_TOP + 2.78, z - 2.5)), Color(0.4, 0.42, 0.46))
	for flip in [0.0, PI]:
		var board := Label3D.new()
		board.text = station_name(0) + " ↔ " + station_name(1)
		board.font_size = 44
		board.modulate = LIVERY
		board.pixel_size = 0.011
		board.position = Vector3(cx, PLAT_TOP + 2.2, z - 2.5 + 0.06)
		board.rotation.y = flip
		add_child(board)
	# Railings: chamfered rails on posts, track side doubled (top + mid).
	var rail_z0 := -12.85
	var rail_z1 := 9.3
	var rail_len := rail_z1 - rail_z0
	var rail_cz := z + (rail_z0 + rail_z1) * 0.5
	for side in [PLAT_X0 + 0.1, PLAT_X1 - 0.1]:
		b.add_bev_box(Vector3(0.09, 0.09, rail_len),
				Vector3(side, PLAT_TOP + 1.05, rail_cz), 0.02, Color(0.5, 0.53, 0.58))
		if side < 2.0:
			b.add_bev_box(Vector3(0.08, 0.08, rail_len),
					Vector3(side, PLAT_TOP + 0.55, rail_cz), 0.02,
					Color(0.5, 0.53, 0.58))
		var np := 11
		for p in np:
			var pz2 := rail_z0 + rail_len * float(p) / float(np - 1)
			b.add_bev_box(Vector3(0.07, 1.1, 0.07),
					Vector3(side, PLAT_TOP + 0.55, z + pz2), 0.015,
					Color(0.5, 0.53, 0.58))
		_coll(solid, Vector3(0.12, 1.1, rail_len + 0.1),
				Vector3(side, PLAT_TOP + 0.55, rail_cz))
	b.add_bev_box(Vector3(2.6, 0.09, 0.09),
			Vector3(cx, PLAT_TOP + 1.05, z + PLAT_Z0 + 0.05), 0.02,
			Color(0.5, 0.53, 0.58))
	for px in [PLAT_X0 + 0.1, PLAT_X1 - 0.1]:
		b.add_bev_box(Vector3(0.07, 1.1, 0.07),
				Vector3(px, PLAT_TOP + 0.55, z + PLAT_Z0 + 0.05), 0.015,
				Color(0.5, 0.53, 0.58))
	_coll(solid, Vector3(PLAT_X1 - PLAT_X0, 1.1, 0.12),
			Vector3(cx, PLAT_TOP + 0.55, z + PLAT_Z0 + 0.05))
	# Lift tower: street door on the east face, platform door on the
	# south face; the E-transfer does the riding.
	b.add_bev_box(Vector3(2.8, 17.2, 2.6),
			Vector3(cx, 8.6, z + LIFT_DZ), 0.15, Color(0.62, 0.64, 0.68))
	_coll(solid, Vector3(2.8, 17.2, 2.6), Vector3(cx, 8.6, z + LIFT_DZ))
	b.add_bev_box(Vector3(1.9, 2.5, 0.12),
			Vector3(cx, PLAT_TOP + 1.25, z + 9.36), 0.03, Color(0.13, 0.15, 0.19))
	b.add_bev_box(Vector3(2.1, 0.16, 0.14),
			Vector3(cx, PLAT_TOP + 2.62, z + 9.35), 0.03, GOLD)
	b.add_bev_box(Vector3(0.12, 2.5, 1.9),
			Vector3(4.34, 1.25, z + LIFT_DZ), 0.03, Color(0.13, 0.15, 0.19))
	b.add_bev_box(Vector3(0.14, 0.16, 2.1),
			Vector3(4.35, 2.62, z + LIFT_DZ), 0.03, GOLD)
	for lbl in [
			[Vector3(cx, PLAT_TOP + 1.4, z + 9.28), "LIFT \u00b7 STREET"],
			[Vector3(4.5, 2.9, z + LIFT_DZ), "LIFT \u00b7 PLATFORM"],
			[Vector3(2.3, PLAT_TOP + 1.7, z), "TRAIN DOORS"],
	]:
		var tag := Label3D.new()
		tag.text = lbl[1]
		tag.font_size = 34
		tag.modulate = GOLD
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = 0.012
		tag.position = lbl[0]
		add_child(tag)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	add_child(mi)
	add_child(solid)
	if OS.get_environment("DFL_DEBUG_TRIS") != "":
		var tris := 0
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
		print("platform %d tris=%d" % [i, tris])


func _coll(parent: Node, size: Vector3, at: Vector3) -> void:
	## One box collider in the platform's static body.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	parent.add_child(col)


func _build_train() -> void:
	## Three cars: outer shells in one merged mesh, glass bands and lit
	## ceiling strips as their own instances (they need special
	## materials), interior fittings only in the middle car where the
	## ride cam sits. Local -Z is the direction of travel.
	var start_z := float(stations[0]["z"])
	_train = Node3D.new()
	_train.name = "Shuttle"
	_train.position = Vector3(0.0, DECK_TOP, start_z)
	_train.rotation.y = PI
	add_child(_train)
	var shell := MeshTools.new()
	var glass := MeshTools.new()
	var fittings := MeshTools.new()
	var lit := MeshTools.new()
	for c in range(-1, 2):
		var cz := float(c) * (CAR_LEN + CAR_GAP)
		_build_car_shell(shell, cz, c == -1)
		_build_car_glass(glass, cz, c == -1)
		if c == 0:
			_build_middle_interior(fittings, lit)
	var mi := MeshInstance3D.new()
	mi.mesh = shell.build_mesh()
	_train.add_child(mi)
	var gm := MeshInstance3D.new()
	gm.mesh = glass.build_mesh()
	gm.material_override = _glass_mat
	_train.add_child(gm)
	var fm := MeshInstance3D.new()
	fm.mesh = fittings.build_mesh()
	_train.add_child(fm)
	var lm := MeshInstance3D.new()
	lm.mesh = lit.build_mesh()
	lm.material_override = _lamp_mat
	_train.add_child(lm)


func _build_car_shell(b: MeshTools, cz: float, lead: bool) -> void:
	# Underframe, body with livery stripe, roof line, AC unit, bogie
	# skirts; the lead car gets a cab face with windshield and lamps.
	var y_body := 1.45
	b.add_box(Vector3(2.55, 0.5, CAR_LEN - 0.3), Vector3(0.0, 0.35, cz),
			UNDER_COLOR)
	b.add_box(Vector3(2.6, 2.0, CAR_LEN), Vector3(0.0, y_body, cz),
			BODY_COLOR)
	b.add_box(Vector3(2.66, 0.26, CAR_LEN - 0.2), Vector3(0.0, 0.95, cz),
			LIVERY)
	b.add_box(Vector3(2.45, 0.26, CAR_LEN - 0.4), Vector3(0.0, 2.55, cz),
			Color(0.80, 0.82, 0.86))
	b.add_box(Vector3(1.3, 0.28, 2.2), Vector3(0.0, 2.78, cz),
			Color(0.70, 0.73, 0.78))
	for zz in [-2.7, 2.7]:
		b.add_box(Vector3(2.1, 0.45, 1.7), Vector3(0.0, 0.08, cz + zz),
				UNDER_COLOR)
	for zz in [-2.55, 2.55]:
		b.add_box(Vector3(2.64, 1.85, 1.05), Vector3(0.0, 1.35, cz + zz),
				Color(0.74, 0.77, 0.82))
	if lead:
		var fz := cz - CAR_LEN / 2.0 - 0.05
		b.add_box(Vector3(2.5, 2.0, 0.2), Vector3(0.0, y_body, fz),
				Color(0.82, 0.84, 0.88))
		b.add_box(Vector3(2.3, 0.5, 0.24), Vector3(0.0, 0.55, fz),
				GOLD)
		for xx in [-0.85, 0.85]:
			b.add_box(Vector3(0.34, 0.22, 0.1), Vector3(xx, 0.9, fz - 0.06),
					Color(1.0, 0.98, 0.9))


func _build_car_glass(b: MeshTools, cz: float, lead: bool) -> void:
	## Window band down each side; the lead car also gets a cab
	## windshield strip on its front face.
	b.add_box(Vector3(2.7, 0.85, CAR_LEN - 2.9), Vector3(0.0, 1.85, cz),
			Color.WHITE)
	if lead:
		var fz := cz - CAR_LEN / 2.0 - 0.14
		b.add_box(Vector3(2.0, 0.8, 0.16), Vector3(0.0, 1.95, fz),
				Color.WHITE)


func _build_middle_interior(fit: MeshTools, lit: MeshTools) -> void:
	## What the ride cam sees: aisle floor, benches along both walls,
	## grab poles between the windows, and a lit ceiling strip.
	fit.add_box(Vector3(2.3, 0.1, CAR_LEN - 0.8), Vector3(0.0, 0.55, 0.0),
			Color(0.62, 0.60, 0.56))
	for xx in [-0.95, 0.95]:
		fit.add_box(Vector3(0.55, 0.42, CAR_LEN - 1.6), Vector3(xx, 0.82, 0.0),
				BENCH_COLOR)
	for xx in [-0.72, 0.72]:
		for zz in [-2.6, 0.0, 2.6]:
			var pole := CylinderMesh.new()
			pole.top_radius = 0.04
			pole.bottom_radius = 0.04
			pole.height = 1.9
			fit.add_mesh(pole, Transform3D(Basis(),
					Vector3(xx, 1.55, zz)), Color(0.75, 0.78, 0.82))
	lit.add_box(Vector3(0.55, 0.07, CAR_LEN - 1.4), Vector3(0.0, 2.44, 0.0),
			Color.WHITE)
