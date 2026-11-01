extends Node3D
## Railway station district (issue #133), built from the owner's art
## reference (.agent/art-ref-1.jpg): a terminal ground-level station with
## a cream/red-oxide checkered platform under a grey steel-truss canopy,
## a yellow hanging name board, wooden luggage trolleys and stacks of
## white bundles, static porters in white kurtas with turbans and head
## loads, catenary poles and wires, a signal and buffer stop — plus a
## red-cream passenger train that arrives from beyond the map edge,
## dwells at the platform and departs again (the metro shuttle's
## trapezoid speed profile, reused for a non-rideable scene train).
## Everything is procedural MeshTools geometry; no assets, no imports.
## Bilingual Devanagari text is NOT attempted here — the default font
## has no Devanagari glyphs; issue #131's signage system owns that layer.

const MeshTools := preload("res://scripts/meshtools.gd")

## Track runs along local z (north = -z); local (0,0,0) is the block
## center main.gd passes in. The block spans z -17..+17; the perimeter
## road north of it sits at local z -29..-17 (kept clear of ballast so
## nothing z-fights the asphalt — the rails cross it as a level
## crossing).
const STAGE_Z := -95.0   ## off-map staging point the train cycles from
const BUFFER_Z := 16.0   ## buffer stop / end of track
const DWELL := 12.0
const AWAY := 18.0
const CRUISE := 9.0
const ACCEL := 1.4

const CAR_LEN := 8.8
const CAR_GAP := 0.6

## Departure board (issue #184): fictional services, all platform 1.
const BOARD_SERVICES := [
	["GOMTI EXPRESS", "11:42"],
	["SHALIMAR EXPRESS", "12:05"],
	["TAJ EXPRESS", "12:30"],
	["HERITAGE SPECIAL", "13:10"],
	["NIGHT RAJDHANI", "21:50"],
]
const BOARD_STATUS := ["ON TIME", "BOARDING", "DELAYED 20", "ARRIVING",
	"AT PLATFORM"]

## Palette from the reference: cream + red-oxide checker floor, grey
## truss, green/white canopy stripes, yellow board with red border,
## terracotta station roof, red/cream train livery.
const CONCRETE := Color(0.72, 0.70, 0.66)
const TILE_A := Color(0.93, 0.89, 0.80)
const TILE_B := Color(0.60, 0.29, 0.21)
const TACTILE := Color(0.90, 0.74, 0.12)
const TRUSS := Color(0.52, 0.53, 0.56)
const ROOF_METAL := Color(0.60, 0.62, 0.65)
const STRIPE_GREEN := Color(0.16, 0.42, 0.28)
const STRIPE_WHITE := Color(0.92, 0.92, 0.90)
const BOARD_YELLOW := Color(0.94, 0.76, 0.10)
const BOARD_RED := Color(0.72, 0.12, 0.10)
const BOARD_DARK := Color(0.16, 0.14, 0.12)
const WALL_CREAM := Color(0.87, 0.79, 0.64)
const ROOF_TERRA := Color(0.62, 0.28, 0.15)
const DARK_WIN := Color(0.13, 0.15, 0.19)
const DOOR_WOOD := Color(0.35, 0.20, 0.10)
const BLUE_PANEL := Color(0.16, 0.35, 0.60)
const BALLAST := Color(0.45, 0.42, 0.38)
const RAIL := Color(0.26, 0.26, 0.28)
const SLEEPER := Color(0.34, 0.27, 0.19)
const BODY_CREAM := Color(0.93, 0.89, 0.82)
const LIVERY_RED := Color(0.68, 0.11, 0.09)
const TRAIN_WIN := Color(0.10, 0.12, 0.16)
const TRAIN_ROOF := Color(0.55, 0.56, 0.58)
const UNDER := Color(0.15, 0.15, 0.17)
const GOLD := Color(0.86, 0.66, 0.20)
const WOOD := Color(0.48, 0.33, 0.18)
const CRATE := Color(0.42, 0.28, 0.14)
const BUNDLE := Color(0.90, 0.88, 0.80)
const KURTA := Color(0.94, 0.93, 0.88)
const LEGS := Color(0.20, 0.18, 0.16)
const SKIN := Color(0.66, 0.46, 0.31)
const TURBAN_A := Color(0.52, 0.16, 0.14)
const TURBAN_B := Color(0.86, 0.66, 0.20)
const STEEL := Color(0.58, 0.58, 0.60)

signal arrived
signal departed
signal counter_near

var _state := "away"
var _timer := 4.0
var _speed := 0.0
var _train: Node3D = null
var _player: CharacterBody3D = null
var _audio: Node = null
var _counter_done := false
var _arrived_row_flipped := false
var _fans: Array[Node3D] = []
var _flap_hinge: Array[Node3D] = []
var _flap_label: Array[Label3D] = []
var _flap_status: Array[String] = []
var _flap_next: Array[String] = []
var _flap_flip_t: Array[float] = []
var _flip_timer := 6.0


func setup(center: Vector3) -> void:
	position = center
	name = "RailwayStation"
	_build_static()
	_build_hall_dynamic()
	_build_train()


# ------------------------------------------------------------ scene train

func _process(delta: float) -> void:
	_tick_hall(delta)
	if _train == null:
		return
	if _state == "dwell" or _state == "away":
		_timer -= delta
		if _timer <= 0.0:
			if _state == "dwell":
				_state = "depart"
				departed.emit()
			else:
				_state = "approach"
		return
	## Trapezoid profile toward the current target (stop at platform vs
	## staging point far north) — same math as the metro shuttle.
	var target := 0.0 if _state == "approach" else STAGE_Z
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
		if _state == "approach":
			_state = "dwell"
			_timer = DWELL
			arrived.emit()
		else:
			_state = "away"
			_timer = AWAY


# ------------------------------------------------------------ construction

func _build_static() -> void:
	var b := MeshTools.new()
	var tiles_a: Array[Transform3D] = []
	var tiles_b: Array[Transform3D] = []
	var sleepers: Array[Transform3D] = []
	_build_track(b, sleepers)
	_build_platform(b, tiles_a, tiles_b)
	_build_canopy(b)
	_build_sign(b)
	_build_building(b)
	_build_counter(b)
	_build_hall_furniture(b)
	_build_furniture(b)
	_build_porters(b)
	_build_catenary(b)
	var root := Node3D.new()
	root.name = "StationYard"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	print("[railway] station-yard tris=%d" % b.tris)
	root.add_child(mi)
	var tile_a := BoxMesh.new()
	tile_a.size = Vector3(2.0, 0.03, 2.0)
	var tile_mm := _mm(tile_a, tiles_a, TILE_A)
	if tile_mm != null:
		root.add_child(tile_mm)
	var tile_b := BoxMesh.new()
	tile_b.size = Vector3(2.0, 0.03, 2.0)
	var tileb_mm := _mm(tile_b, tiles_b, TILE_B)
	if tileb_mm != null:
		root.add_child(tileb_mm)
	var slp := BoxMesh.new()
	slp.size = Vector3(2.6, 0.08, 0.24)
	var slp_mm := _mm(slp, sleepers, SLEEPER)
	if slp_mm != null:
		root.add_child(slp_mm)
	add_child(root)
	_build_lights()
	_build_colliders()


func _mm(mesh: PrimitiveMesh, xfs: Array[Transform3D], color: Color) -> MultiMeshInstance3D:
	## Shared material on the primitive, then one MultiMesh over the
	## transforms (the lamp/head pattern in main.gd).
	mesh.material = MeshTools.shared_material(color)
	return MeshTools.make_multimesh(mesh, xfs)


func _build_track(b: MeshTools, sleepers: Array[Transform3D]) -> void:
	## Ballast (two runs, clear of the perimeter road), rails the full
	## length as a level crossing, sleepers as one MultiMesh, buffer stop.
	for span in [[-95.0, -29.0], [-17.0, BUFFER_Z]]:
		var z0: float = span[0]
		var z1: float = span[1]
		b.add_box(Vector3(4.4, 0.22, z1 - z0), Vector3(0.0, 0.11, (z0 + z1) / 2.0), BALLAST)
		var zz := z0 + 0.5
		while zz < z1 - 0.3:
			sleepers.append(Transform3D(Basis(), Vector3(0.0, 0.24, zz)))
			zz += 0.85
	for xx in [-0.75, 0.75]:
		b.add_box(Vector3(0.09, 0.15, BUFFER_Z - STAGE_Z),
				Vector3(xx, 0.26, (STAGE_Z + BUFFER_Z) / 2.0), RAIL)
	# Buffer stop: base block + two angled arms + red face.
	b.add_box(Vector3(2.4, 0.5, 1.1), Vector3(0.0, 0.45, BUFFER_Z), LIVERY_RED)
	b.add_box(Vector3(0.28, 1.5, 0.28), Vector3(-0.7, 1.1, BUFFER_Z - 0.3), STEEL)
	b.add_box(Vector3(0.28, 1.5, 0.28), Vector3(0.7, 1.1, BUFFER_Z - 0.3), STEEL)
	b.add_box(Vector3(2.0, 0.5, 0.24), Vector3(0.0, 1.6, BUFFER_Z - 0.36), LIVERY_RED)


func _build_platform(b: MeshTools, tiles_a: Array[Transform3D], tiles_b: Array[Transform3D]) -> void:
	## Main platform west of the track (checker floor + yellow tactile
	## edge) and a plain far platform east of it.
	b.add_box(Vector3(8.8, 0.5, 28.0), Vector3(-6.6, 0.25, -1.0), CONCRETE)
	b.add_box(Vector3(8.0, 0.5, 24.0), Vector3(6.2, 0.25, -1.0), CONCRETE)
	b.add_box(Vector3(0.35, 0.03, 28.0), Vector3(-2.55, 0.515, -1.0), TACTILE)
	b.add_box(Vector3(0.35, 0.03, 24.0), Vector3(2.55, 0.515, -1.0), TACTILE)
	var col := 0
	for xx in [-10.0, -8.0, -6.0, -4.0]:
		var row := 0
		for zz in range(-14, 12, 2):
			var xf := Transform3D(Basis(), Vector3(xx, 0.53, zz + 0.0))
			if (col + row) % 2 == 0:
				tiles_a.append(xf)
			else:
				tiles_b.append(xf)
			row += 1
		col += 1
	# Entrance ramp at the south end of the main platform: a visual
	# slope slab plus step colliders (built in _build_colliders).
	var ramp := BoxMesh.new()
	ramp.size = Vector3(3.2, 0.12, 4.35)
	var ang := atan(0.5 / 4.0)
	b.add_mesh(ramp, Transform3D(Basis(Vector3.RIGHT, ang),
			Vector3(-6.5, 0.25, 15.0)), CONCRETE)


func _build_canopy(b: MeshTools) -> void:
	## Two longitudinal trusses (bottom chord y 3.8, top y 4.7) with
	## verticals and alternating diagonals every ~2.2 m, tied by cross
	## beams, columns down to the platform, a metal roof slab and the
	## green/white striped fascia from the reference.
	for tx in [-10.5, -3.0]:
		b.add_box(Vector3(0.22, 0.22, 26.0), Vector3(tx, 3.8, -1.0), TRUSS)
		b.add_box(Vector3(0.18, 0.18, 26.0), Vector3(tx, 4.7, -1.0), TRUSS)
		var z0 := -14.0
		var z1 := 12.0
		var bays := 12
		var step := (z1 - z0) / bays
		for i in bays:
			var za := z0 + i * step
			var zb := za + step
			b.add_box(Vector3(0.14, 0.14, step * 0.95), Vector3(tx, 4.25, (za + zb) / 2.0), TRUSS)
			var diag := BoxMesh.new()
			diag.size = Vector3(0.12, 0.12, sqrt(step * step + 0.81) * 0.98)
			var tilt := atan2(0.9, step) if i % 2 == 0 else atan2(0.9, step) - PI
			b.add_mesh(diag, Transform3D(Basis(Vector3.RIGHT, tilt),
					Vector3(tx, 4.25, (za + zb) / 2.0)), TRUSS)
	for zz in [-14.0, -7.0, 0.0, 7.0, 12.0]:
		b.add_box(Vector3(7.7, 0.14, 0.14), Vector3(-6.75, 4.72, zz), TRUSS)
		for tx in [-10.5, -3.0]:
			b.add_box(Vector3(0.18, 3.55, 0.18), Vector3(tx, 2.0, zz), TRUSS)
	b.add_box(Vector3(8.6, 0.14, 27.5), Vector3(-6.75, 4.86, -1.0), ROOF_METAL)
	for edge_z in [-14.6, 12.6]:
		var i := 0
		for zz in range(-14.0, 12.0, 1.75):
			var col := STRIPE_GREEN if i % 2 == 0 else STRIPE_WHITE
			b.add_box(Vector3(8.4, 0.34, 1.7), Vector3(-6.75, 4.62, zz + 0.85), col)
			i += 1
	for zz in [-14.0, 12.0]:
		var i := 0
		for xx in range(-10.5, -3.0, 1.75):
			var col := STRIPE_GREEN if i % 2 == 0 else STRIPE_WHITE
			b.add_box(Vector3(1.7, 0.34, 0.3), Vector3(xx + 0.85, 4.62, zz), col)
			i += 1


func _build_sign(b: MeshTools) -> void:
	## The yellow hanging name board on two yellow posts, red border
	## frame, station name in black on both faces (Label3Ds added in
	## _build_lights' parent scope — see setup ordering, they go on the
	## root here as plain children of self).
	for zz in [-2.0, 2.0]:
		b.add_box(Vector3(0.16, 3.9, 0.16), Vector3(-2.9, 1.95, zz), BOARD_YELLOW)
	b.add_box(Vector3(0.09, 1.05, 4.6), Vector3(-2.9, 3.35, 0.0), BOARD_YELLOW)
	b.add_box(Vector3(0.11, 0.12, 4.7), Vector3(-2.9, 3.9, 0.0), BOARD_RED)
	b.add_box(Vector3(0.11, 0.12, 4.7), Vector3(-2.9, 2.8, 0.0), BOARD_RED)
	b.add_box(Vector3(0.11, 1.05, 0.12), Vector3(-2.9, 3.35, -2.34), BOARD_RED)
	b.add_box(Vector3(0.11, 1.05, 0.12), Vector3(-2.9, 3.35, 2.34), BOARD_RED)
	var west := Label3D.new()
	west.text = "NEW DELHI"
	west.font_size = 92
	west.modulate = Color(0.07, 0.07, 0.07)
	west.pixel_size = 0.008
	west.rotation.y = -PI / 2.0
	west.position = Vector3(-2.82, 3.35, 0.0)
	add_child(west)
	var east := Label3D.new()
	east.text = "NEW DELHI"
	east.font_size = 92
	east.modulate = Color(0.07, 0.07, 0.07)
	east.pixel_size = 0.008
	east.rotation.y = PI / 2.0
	east.position = Vector3(-2.98, 3.35, 0.0)
	add_child(east)


func _build_building(b: MeshTools) -> void:
	## Station concourse (issue #184): a hollow through-hall — long
	## walls with matching doorways on both sides (west to the platform
	## and train, east to the street), end walls, a cream tile floor
	## with red-oxide border inlays, terracotta gable roof and dark
	## windows inside the wall span. Counter, benches, board and fans
	## live in the funcs that follow (static mesh + dynamic nodes).
	for wx in [3.6, 9.6]:
		# Doorway z 0.45..1.55 on BOTH long walls — the hall runs
		# straight through, platform side to street side.
		for seg in [[-7.5, 0.45], [1.55, 5.5]]:
			var z0: float = seg[0]
			var z1: float = seg[1]
			b.add_bev_box(Vector3(0.18, 3.2, z1 - z0),
					Vector3(wx, 2.1, (z0 + z1) / 2.0), 0.04, WALL_CREAM)
		b.add_bev_box(Vector3(0.18, 0.95, 1.1), Vector3(wx, 3.225, 1.0),
				0.02, WALL_CREAM)
		# Jambs plus one door leaf swung open against the inner face.
		b.add_box(Vector3(0.22, 2.3, 0.08), Vector3(wx, 1.65, 0.42), DOOR_WOOD)
		b.add_box(Vector3(0.22, 2.3, 0.08), Vector3(wx, 1.65, 1.58), DOOR_WOOD)
		var leaf := 3.73 if wx < 6.0 else 9.47
		b.add_box(Vector3(0.06, 2.2, 1.05), Vector3(leaf, 1.63, -0.08), DOOR_WOOD)
	for ez in [-7.5, 5.5]:
		b.add_bev_box(Vector3(6.0, 3.2, 0.18), Vector3(6.6, 2.1, ez), 0.04, WALL_CREAM)
	# Interior floor: cream tile with red-oxide border inlays.
	b.add_box(Vector3(5.7, 0.03, 12.7), Vector3(6.6, 0.515, -1.0), TILE_A)
	for bx in [3.87, 9.33]:
		b.add_box(Vector3(0.24, 0.012, 12.7), Vector3(bx, 0.536, -1.0), TILE_B)
	var pitch := atan(1.6 / 3.0)
	var slab := BoxMesh.new()
	slab.size = Vector3(3.55, 0.16, 14.2)
	b.add_mesh(slab, Transform3D(Basis(Vector3.FORWARD, -pitch),
			Vector3(5.15, 3.85, -1.0)), ROOF_TERRA)
	b.add_mesh(slab, Transform3D(Basis(Vector3.FORWARD, pitch),
			Vector3(8.05, 3.85, -1.0)), ROOF_TERRA)
	b.add_box(Vector3(0.34, 0.3, 14.2), Vector3(6.6, 4.7, -1.0), ROOF_TERRA)
	# Gable fills so the roof ridge reads closed from the platform.
	for gz in [-7.4, 5.4]:
		b.add_box(Vector3(6.0, 0.4, 0.2), Vector3(6.6, 3.9, gz), WALL_CREAM)
		b.add_box(Vector3(4.4, 0.4, 0.2), Vector3(6.6, 4.3, gz), WALL_CREAM)
		b.add_box(Vector3(2.6, 0.4, 0.2), Vector3(6.6, 4.65, gz), WALL_CREAM)
	# Windows inside the wall span (the old z -8/7 pair floated in
	# mid-air outside the building), proud of both wall faces.
	for wz in [-5.0, -2.0, 3.2]:
		b.add_box(Vector3(0.22, 1.1, 1.4), Vector3(3.6, 2.0, wz), DARK_WIN)
		b.add_box(Vector3(0.22, 1.1, 1.4), Vector3(9.6, 2.0, wz), DARK_WIN)
	b.add_box(Vector3(0.1, 0.5, 3.0), Vector3(3.49, 2.9, -3.0), BLUE_PANEL)


func _build_counter(b: MeshTools) -> void:
	## South-end ticket counter (issue #184): wooden body with a pale
	## slab top and red skirt, a barred grille on the south wall, a
	## clerk in a pale kurta reading over the counter, TICKETS plate.
	b.add_bev_box(Vector3(2.6, 0.72, 0.85), Vector3(6.6, 0.89, 4.6), 0.03, WOOD)
	b.add_box(Vector3(2.8, 0.07, 1.0), Vector3(6.6, 1.29, 4.6), TILE_A)
	b.add_box(Vector3(2.8, 0.44, 0.06), Vector3(6.6, 0.75, 4.13), TILE_B)
	b.add_box(Vector3(2.3, 1.2, 0.1), Vector3(6.6, 2.2, 5.42), BOARD_DARK)
	b.add_box(Vector3(2.1, 1.0, 0.05), Vector3(6.6, 2.2, 5.38), DARK_WIN)
	for gx in [5.85, 6.35, 6.85, 7.35]:
		b.add_box(Vector3(0.06, 1.0, 0.08), Vector3(gx, 2.2, 5.35), GOLD)
	# Clerk (~1.6 m): dark trouser legs, kurta lathe, head at grille
	# height facing into the hall over the counter top.
	for side in [-0.12, 0.12]:
		b.add_round_lathe(MeshTools.capsule_profile(0.105, 0.085, 0.60),
				Transform3D(Basis(), Vector3(6.6 + side, 0.83, 5.15)), LEGS)
	b.add_round_lathe(PackedVector2Array([
				Vector2(0.05, 0.0), Vector2(0.21, 0.08), Vector2(0.22, 0.32),
				Vector2(0.215, 0.60), Vector2(0.19, 0.74), Vector2(0.05, 0.78)]),
			Transform3D(Basis(), Vector3(6.6, 1.12, 5.15)), KURTA,
			MeshTools.FINISH_MATTE, 10, 0.62)
	b.add_round_lathe(MeshTools.capsule_profile(0.045, 0.05, 0.10),
			Transform3D(Basis(), Vector3(6.6, 1.90, 5.15)), SKIN)
	b.add_round_lathe(MeshTools.ball_profile(0.125, 3),
			Transform3D(Basis(), Vector3(6.6, 1.95, 5.15)), SKIN,
			MeshTools.FINISH_MATTE, 10, 0.95)
	b.add_box(Vector3(0.9, 0.32, 0.06), Vector3(5.0, 2.5, 5.41), TILE_A)


func _build_hall_furniture(b: MeshTools) -> void:
	## Concourse fittings (issue #184): two slat benches backing the
	## long walls, one luggage cluster by the north wall.
	_hall_bench(b, 4.35, -2.0, -1.0)
	_hall_bench(b, 8.85, -2.0, 1.0)
	var bx := BoxMesh.new()
	bx.size = Vector3(0.62, 0.34, 0.46)
	b.add_mesh(bx, Transform3D(Basis(Vector3.UP, 0.3), Vector3(5.6, 0.70, -5.5)), BUNDLE)
	b.add_mesh(bx, Transform3D(Basis(Vector3.UP, -0.2), Vector3(5.7, 1.04, -5.45)), BUNDLE)
	b.add_box(Vector3(0.7, 0.5, 0.22), Vector3(4.85, 0.78, -5.2), Color(0.40, 0.24, 0.12))


func _hall_bench(b: MeshTools, x: float, z: float, side: float) -> void:
	## Platform slat bench with its backrest against the nearest long
	## wall (side -1 west, +1 east).
	b.add_box(Vector3(0.5, 0.07, 1.9), Vector3(x, 0.68, z), WOOD)
	b.add_box(Vector3(0.07, 0.55, 1.9), Vector3(x + side * 0.22, 0.95, z), WOOD)
	for dz in [-0.8, 0.8]:
		b.add_box(Vector3(0.42, 0.36, 0.1), Vector3(x, 0.5, z + dz), STEEL)


func _build_furniture(b: MeshTools) -> void:
	## Four slat benches under the canopy, five luggage clusters (white
	## bundles + a brown suitcase), two wooden luggage trolleys.
	for zz in [-12.0, -7.0, 3.0, 8.0]:
		var x := -9.9
		b.add_box(Vector3(0.5, 0.07, 1.9), Vector3(x, 0.68, zz), WOOD)
		b.add_box(Vector3(0.07, 0.55, 1.9), Vector3(x - 0.22, 0.95, zz), WOOD)
		for dz in [-0.8, 0.8]:
			b.add_box(Vector3(0.42, 0.36, 0.1), Vector3(x, 0.5, zz + dz), STEEL)
	for spot in [[-3.4, -11.0], [-8.0, -13.5], [-4.8, 9.5], [-9.5, 3.5], [4.5, -12.0]]:
		var x: float = spot[0]
		var z: float = spot[1]
		var bx := BoxMesh.new()
		bx.size = Vector3(0.62, 0.34, 0.46)
		b.add_mesh(bx, Transform3D(Basis(Vector3.UP, 0.3), Vector3(x, 0.67, z)), BUNDLE)
		b.add_mesh(bx, Transform3D(Basis(Vector3.UP, -0.2), Vector3(x + 0.1, 1.01, z + 0.05)), BUNDLE)
		b.add_box(Vector3(0.7, 0.5, 0.22), Vector3(x - 0.75, 0.75, z + 0.3), Color(0.40, 0.24, 0.12))
	for t in [[-3.6, -8.0, 0.35], [-6.8, 11.5, -0.5]]:
		_trolley(b, t[0], t[1], t[2])


func _trolley(b: MeshTools, x: float, z: float, yaw: float) -> void:
	## Wooden luggage trolley: flat bed, four spoked wheels, handle
	## bars, crates and bundles stacked on top.
	var base := Basis(Vector3.UP, yaw)
	var bed := BoxMesh.new()
	bed.size = Vector3(1.5, 0.14, 1.0)
	b.add_mesh(bed, Transform3D(base, Vector3(x, 0.56, z)), WOOD)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.26
	wheel.bottom_radius = 0.26
	wheel.height = 0.08
	for dx in [-0.62, 0.62]:
		for dz in [-0.5, 0.5]:
			var wb := base * Basis(Vector3.FORWARD, PI / 2.0)
			b.add_mesh(wheel, Transform3D(wb,
					Vector3(x + dx * 0.8, 0.28, z + dz * 0.8)), WOOD)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.07, 0.07, 0.9)
	b.add_mesh(handle, Transform3D(base, Vector3(x - 0.6, 0.85, z + 0.55)), STEEL)
	b.add_mesh(handle, Transform3D(base, Vector3(x + 0.6, 0.85, z + 0.55)), STEEL)
	var crate := BoxMesh.new()
	crate.size = Vector3(0.7, 0.5, 0.6)
	b.add_mesh(crate, Transform3D(base * Basis(Vector3.UP, 0.15),
			Vector3(x, 0.9, z - 0.1)), CRATE)
	var bund := BoxMesh.new()
	bund.size = Vector3(0.6, 0.34, 0.5)
	b.add_mesh(bund, Transform3D(base * Basis(Vector3.UP, -0.25),
			Vector3(x - 0.2, 1.3, z + 0.2)), BUNDLE)


func _build_porters(b: MeshTools) -> void:
	## Static figures in the reference's dress: white kurta, turban,
	## head-load bundle. Three porters on the main platform (two walking
	## with loads, one waiting by a trolley) and two seated passengers.
	_porter(b, -5.2, -13.0, 0.25, TURBAN_A, true)
	_porter(b, -4.0, 5.5, PI - 0.15, TURBAN_B, true)
	_porter(b, -4.8, -6.8, 1.4, TURBAN_A, false)
	_seated(b, -9.9, -7.2, Color(0.75, 0.20, 0.16))
	_seated(b, -9.9, 8.2, Color(0.20, 0.35, 0.55))


func _porter(b: MeshTools, x: float, z: float, yaw: float, turban: Color, load: bool) -> void:
	## ~1.75 m figure (de-boxed, issue #238): capsule-tapered trouser
	## legs, elliptic flared kurta lathe, ball head with neck stub,
	## round turban wrap and knot; hanging arms on ball shoulders, and
	## for loaders one arm reaching up-inward to steady the head bundle.
	var base := Basis(Vector3.UP, yaw)
	var stride := 0.1 if load else 0.0
	var at := func(lx: float, ly: float, lz: float) -> Vector3:
		return base * Vector3(lx, ly, lz) + Vector3(x, 0.0, z)
	for side in [-1.0, 1.0]:
		b.add_round_lathe(MeshTools.capsule_profile(0.105, 0.085, 0.76),
				Transform3D(base, at.call(side * 0.12, 0.0, stride * -side)), LEGS)
	b.add_round_lathe(PackedVector2Array([
				Vector2(0.05, 0.0), Vector2(0.22, 0.08), Vector2(0.235, 0.32),
				Vector2(0.225, 0.60), Vector2(0.20, 0.78), Vector2(0.18, 0.84),
				Vector2(0.05, 0.86)]),
				Transform3D(base, at.call(0.0, 0.69, 0.0)), KURTA,
				MeshTools.FINISH_MATTE, 10, 0.62)
	for side in [-1.0, 1.0]:
		if load and side < 0.0:
			b.add_round_lathe(MeshTools.capsule_profile(0.075, 0.05, 0.62),
					Transform3D(base * Basis(Vector3(0, 0, 1), -0.5),
							at.call(side * 0.34, 1.36, 0.06)), KURTA)
		else:
			b.add_round_lathe(MeshTools.capsule_profile(0.055, 0.075, 0.60),
					Transform3D(base, at.call(side * 0.28, 0.88, 0.0)), KURTA)
		b.add_round_lathe(MeshTools.ball_profile(0.08, 3),
				Transform3D(base, at.call(side * 0.27, 1.46, 0.0)), KURTA)
	b.add_round_lathe(MeshTools.capsule_profile(0.05, 0.055, 0.12),
			Transform3D(base, at.call(0.0, 1.50, 0.0)), SKIN)
	b.add_round_lathe(MeshTools.ball_profile(0.135, 3),
			Transform3D(base, at.call(0.0, 1.545, 0.0)), SKIN,
				MeshTools.FINISH_MATTE, 10, 0.95)
	var wrap := CylinderMesh.new()
	wrap.top_radius = 0.17
	wrap.bottom_radius = 0.18
	wrap.height = 0.16
	b.add_mesh(wrap, Transform3D(base, at.call(0.0, 1.84, 0.0)), turban)
	b.add_round_lathe(MeshTools.ball_profile(0.055, 3),
			Transform3D(base, at.call(0.0, 1.94, 0.0)), turban)
	if load:
		b.add_round_lathe(MeshTools.ball_profile(0.30, 3),
				Transform3D(base * Basis().scaled(Vector3(1.0, 0.42, 0.74)),
						at.call(0.0, 1.86, 0.0)), BUNDLE)
		var strap := CylinderMesh.new()
		strap.top_radius = 0.305
		strap.bottom_radius = 0.305
		strap.height = 0.05
		b.add_mesh(strap, Transform3D(
				base * Basis().scaled(Vector3(1.0, 1.0, 0.74)),
				at.call(0.0, 1.99, 0.0)), Color(0.55, 0.40, 0.25))


func _seated(b: MeshTools, x: float, z: float, shirt: Color) -> void:
	## Bench-sized seated passenger (de-boxed, issue #238): forward
	## capsule thighs on hip balls, elliptic capsule torso, ball head
	## on a neck stub. The two dark pads are bench parts, kept as-is.
	b.add_box(Vector3(0.3, 0.09, 0.42), Vector3(x, 0.72, z + 0.3), Color(0.25, 0.28, 0.35))
	b.add_box(Vector3(0.3, 0.34, 0.1), Vector3(x, 0.55, z + 0.5), Color(0.25, 0.28, 0.35))
	var hip := Basis(Vector3(1, 0, 0), PI * 0.5)
	for side in [-1.0, 1.0]:
		b.add_round_lathe(MeshTools.capsule_profile(0.095, 0.085, 0.44),
				Transform3D(hip, Vector3(x + side * 0.12, 0.80, z + 0.06)), shirt)
		b.add_round_lathe(MeshTools.ball_profile(0.085, 3),
				Transform3D(Basis(), Vector3(x + side * 0.12, 0.80, z + 0.06)), shirt)
	b.add_round_lathe(PackedVector2Array([
				Vector2(0.05, 0.0), Vector2(0.19, 0.07), Vector2(0.205, 0.26),
				Vector2(0.19, 0.48), Vector2(0.165, 0.56), Vector2(0.05, 0.60)]),
				Transform3D(Basis(), Vector3(x, 0.72, z)), shirt,
				MeshTools.FINISH_MATTE, 10, 0.66)
	b.add_round_lathe(MeshTools.capsule_profile(0.045, 0.05, 0.10),
			Transform3D(Basis(), Vector3(x, 1.27, z)), SKIN)
	b.add_round_lathe(MeshTools.ball_profile(0.125, 3),
			Transform3D(Basis(), Vector3(x, 1.32, z)), SKIN,
				MeshTools.FINISH_MATTE, 10, 0.95)


func _build_catenary(b: MeshTools) -> void:
	## Steel masts on the far side of the track with bracket arms over
	## the rails, a contact wire at running height and a messenger wire
	## above it with droppers.
	for zz in [-13.0, -4.5, 4.5, 13.5]:
		b.add_box(Vector3(0.2, 6.3, 0.2), Vector3(2.7, 3.15, zz), STEEL)
		b.add_box(Vector3(3.0, 0.12, 0.12), Vector3(1.35, 5.9, zz), STEEL)
	b.add_box(Vector3(0.05, 0.05, BUFFER_Z - STAGE_Z), Vector3(0.0, 5.35, (STAGE_Z + BUFFER_Z) / 2.0), Color(0.08, 0.08, 0.08))
	b.add_box(Vector3(0.05, 0.05, BUFFER_Z - STAGE_Z), Vector3(0.0, 5.95, (STAGE_Z + BUFFER_Z) / 2.0), Color(0.08, 0.08, 0.08))
	for zz in range(-90, 15, 5):
		b.add_box(Vector3(0.04, 0.55, 0.04), Vector3(0.0, 5.65, zz), Color(0.08, 0.08, 0.08))
	# Signal by the buffer: cream mast, red/green lamp head.
	b.add_box(Vector3(0.14, 3.6, 0.14), Vector3(1.6, 1.8, 14.5), Color(0.88, 0.86, 0.78))
	b.add_box(Vector3(0.4, 0.9, 0.24), Vector3(1.6, 3.6, 14.5), Color(0.10, 0.10, 0.10))
	b.add_box(Vector3(0.16, 0.16, 0.1), Vector3(1.6, 3.85, 14.38), Color(0.85, 0.12, 0.10))
	b.add_box(Vector3(0.16, 0.16, 0.1), Vector3(1.6, 3.45, 14.38), Color(0.15, 0.75, 0.25))


func _build_lights() -> void:
	## Three warm platform lamps under the canopy (fixed, like the metro
	## gates) so the station reads at night — even 7 m spacing across
	## the platform (issue #265 lamp evenness check).
	for zz in [-8.0, -1.0, 6.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-6.75, 4.2, zz)
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.omni_range = 14.0
		lamp.omni_attenuation = 1.2
		add_child(lamp)
	# Concourse interior (issue #184): warm hall wash + counter glow.
	var hall := OmniLight3D.new()
	hall.position = Vector3(6.6, 3.15, 0.2)
	hall.light_color = Color(1.0, 0.88, 0.66)
	hall.omni_range = 11.0
	hall.omni_attenuation = 1.2
	add_child(hall)
	var glow := OmniLight3D.new()
	glow.position = Vector3(6.6, 2.7, 4.3)
	glow.light_color = Color(1.0, 0.82, 0.55)
	glow.omni_range = 6.0
	glow.omni_attenuation = 1.4
	add_child(glow)


func _build_colliders() -> void:
	## Walkable platforms and ramp steps, solid building, buffer and
	## trolley spots.
	var body := StaticBody3D.new()
	body.name = "StationColliders"
	_col(body, Vector3(8.8, 0.5, 28.0), Vector3(-6.6, 0.25, -1.0), 0.0)
	_col(body, Vector3(8.0, 0.5, 24.0), Vector3(6.2, 0.25, -1.0), 0.0)
	# Hollow concourse (issue #184): wall segments with the doorways
	# (z 0.45..1.55 both long walls) left clear, end walls, counter,
	# hall benches.
	for wx in [3.6, 9.6]:
		_col(body, Vector3(0.18, 3.2, 7.95), Vector3(wx, 2.1, -3.525), 0.0)
		_col(body, Vector3(0.18, 3.2, 3.95), Vector3(wx, 2.1, 3.525), 0.0)
	for ez in [-7.5, 5.5]:
		_col(body, Vector3(6.0, 3.2, 0.18), Vector3(6.6, 2.1, ez), 0.0)
	_col(body, Vector3(2.6, 0.8, 0.85), Vector3(6.6, 0.93, 4.6), 0.0)
	_col(body, Vector3(1.1, 0.7, 1.9), Vector3(4.35, 0.88, -2.0), 0.0)
	_col(body, Vector3(1.1, 0.7, 1.9), Vector3(8.85, 0.88, -2.0), 0.0)
	_col(body, Vector3(2.4, 1.7, 1.2), Vector3(0.0, 0.85, BUFFER_Z), 0.0)
	for t in [[-3.6, -8.0], [-6.8, 11.5]]:
		_col(body, Vector3(1.8, 1.2, 1.4), Vector3(t[0], 0.6, t[1]), 0.0)
	# Ramp as three curb-height steps (the player already climbs road
	# curbs, so 0.17 rises are proven walkable).
	for i in 3:
		_col(body, Vector3(3.2, 0.17 * (i + 1), 1.34),
				Vector3(-6.5, 0.17 * (i + 1) / 2.0, 13.65 + 1.34 * i), 0.0)
	add_child(body)


func _col(parent: Node, size: Vector3, pos: Vector3, _yaw: float) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	parent.add_child(col)


func _build_hall_dynamic() -> void:
	## Moving concourse pieces (issue #184): split-flap departure board
	## (dark frame, DEPARTURES header, five flap rows hinged at the
	## top), TICKETS label, and two ceiling fans (static rod + hub,
	## spinning blade hubs ticked in _tick_hall).
	var frame := MeshTools.new()
	frame.add_bev_box(Vector3(3.6, 1.8, 0.14), Vector3(6.6, 2.35, -7.40),
			0.04, BOARD_DARK)
	for fp in [[6.0, -3.0], [7.2, 1.6]]:
		var fx: float = fp[0]
		var fz: float = fp[1]
		var rod := CylinderMesh.new()
		rod.top_radius = 0.03
		rod.bottom_radius = 0.03
		rod.height = 0.8
		frame.add_mesh(rod, Transform3D(Basis(), Vector3(fx, 3.83, fz)), STEEL)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.10
		hub.bottom_radius = 0.10
		hub.height = 0.14
		frame.add_mesh(hub, Transform3D(Basis(), Vector3(fx, 3.42, fz)), STEEL)
		var spin := Node3D.new()
		spin.position = Vector3(fx, 3.40, fz)
		var blades := MeshTools.new()
		var blade := BoxMesh.new()
		blade.size = Vector3(0.98, 0.02, 0.18)
		for k in 3:
			var bas := Basis(Vector3.UP, TAU * k / 3.0) * Basis(Vector3.RIGHT, 0.18)
			blades.add_mesh(blade, Transform3D(bas, bas * Vector3(0.5, 0.0, 0.0)), STEEL)
		var bmi := MeshInstance3D.new()
		bmi.mesh = blades.build_mesh()
		spin.add_child(bmi)
		add_child(spin)
		_fans.append(spin)
	var fmi := MeshInstance3D.new()
	fmi.mesh = frame.build_mesh()
	add_child(fmi)
	var head := Label3D.new()
	head.text = "DEPARTURES"
	head.font_size = 44
	head.modulate = BOARD_YELLOW
	head.pixel_size = 0.008
	head.position = Vector3(6.6, 2.98, -7.31)
	add_child(head)
	var tickets := Label3D.new()
	tickets.text = "TICKETS"
	tickets.font_size = 40
	tickets.modulate = BOARD_RED
	tickets.pixel_size = 0.008
	tickets.rotation.y = PI
	tickets.position = Vector3(5.0, 2.5, 5.35)
	add_child(tickets)
	for i in BOARD_SERVICES.size():
		var y := 2.62 - i * 0.28
		var hinge := Node3D.new()
		hinge.position = Vector3(6.6, y + 0.125, -7.34)
		var flap := MeshTools.new()
		flap.add_box(Vector3(3.34, 0.25, 0.03), Vector3(0.0, -0.125, 0.0),
				Color(0.10, 0.10, 0.11))
		var row := MeshInstance3D.new()
		row.mesh = flap.build_mesh()
		hinge.add_child(row)
		var lab := Label3D.new()
		lab.text = _row_text(i, BOARD_STATUS[i % BOARD_STATUS.size()])
		lab.font_size = 24
		lab.pixel_size = 0.006
		lab.modulate = Color(0.95, 0.93, 0.85)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector3(0.0, -0.125, 0.03)
		hinge.add_child(lab)
		add_child(hinge)
		_flap_hinge.append(hinge)
		_flap_label.append(lab)
		_flap_status.append(BOARD_STATUS[i % BOARD_STATUS.size()])
		_flap_next.append("")
		_flap_flip_t.append(0.0)


func register(p: CharacterBody3D, audio: Node) -> void:
	## Live-game handover (food.gd pattern): the ticket-counter toast
	## and the flap-clack volume need the real player + audio node.
	_player = p
	_audio = audio


func _tick_hall(delta: float) -> void:
	## Concourse life, run ahead of the train block's early returns:
	## fans spin, flap rows flip on a slow cadence (clack from
	## audio.gd, distance-attenuated), a train arrival forces the
	## Rajdhani row to ARRIVING, and the counter toast fires once.
	for fan in _fans:
		fan.rotate_y(5.2 * delta)
	for i in _flap_hinge.size():
		var t := _flap_flip_t[i]
		if t <= 0.0:
			continue
		t = minf(t + delta / 0.2, 1.0)
		_flap_hinge[i].rotation.x = t * PI
		if t >= 0.5 and _flap_next[i] != "":
			_flap_status[i] = _flap_next[i]
			_flap_label[i].text = _row_text(i, _flap_status[i])
			_flap_next[i] = ""
		if t >= 1.0:
			_flap_hinge[i].rotation.x = 0.0
			t = 0.0
		_flap_flip_t[i] = t
	_flip_timer -= delta
	if _flip_timer <= 0.0 and not _flap_hinge.is_empty():
		_flip_timer = randf_range(4.0, 10.0)
		var i := randi() % _flap_hinge.size()
		if _flap_flip_t[i] <= 0.0:
			var pool: Array = BOARD_STATUS.duplicate()
			pool.erase(_flap_status[i])
			_start_flip(i, pool[randi() % pool.size()])
	if _state == "dwell" and not _arrived_row_flipped:
		_arrived_row_flipped = true
		if _flap_flip_t.size() == 5 and _flap_flip_t[4] <= 0.0:
			_start_flip(4, "ARRIVING")
	elif _state == "away":
		_arrived_row_flipped = false
	if _player != null and not _counter_done:
		var lp := to_local(_player.global_position)
		if absf(lp.x - 6.6) < 2.6 and lp.z > 2.4 and lp.z < 6.2:
			_counter_done = true
			counter_near.emit()


func _start_flip(i: int, status: String) -> void:
	_flap_next[i] = status
	_flap_flip_t[i] = 0.0001
	if _audio != null and _player != null:
		var d: float = _player.global_position.distance_to(
				to_global(Vector3(6.6, 2.3, -7.4)))
		if d < 26.0:
			_audio.board_clack(
					lerpf(-11.0, -26.0, clampf((d - 3.0) / 23.0, 0.0, 1.0)))


func _row_text(i: int, status: String) -> String:
	return "%s  %s  PL 1  %s" % [BOARD_SERVICES[i][0],
			BOARD_SERVICES[i][1], status]


func _build_train() -> void:
	## Three red-and-cream cars on the trapezoid cycle; local -Z is the
	## direction of travel (metro convention).
	_train = Node3D.new()
	_train.name = "PassengerTrain"
	_train.position = Vector3(0.0, 0.0, STAGE_Z)
	_train.rotation.y = 0.0
	add_child(_train)
	var shell := MeshTools.new()
	var glass := MeshTools.new()
	for c in range(3):
		var cz := (c - 1) * (CAR_LEN + CAR_GAP)
		_car(shell, glass, cz, c == 0)
	var mi := MeshInstance3D.new()
	mi.mesh = shell.build_mesh()
	_train.add_child(mi)
	var gm := MeshInstance3D.new()
	gm.mesh = glass.build_mesh()
	_train.add_child(gm)


func _car(b: MeshTools, g: MeshTools, cz: float, lead: bool) -> void:
	## One carriage: bogies, cream body with a red window band, dark
	## windows, grey roof with vents; the lead car gets a red cab face
	## with windshield and a gold skirt stripe.
	for dz in [-2.9, 2.9]:
		b.add_box(Vector3(2.3, 0.55, 1.8), Vector3(0.0, 0.55, cz + dz), UNDER)
	b.add_box(Vector3(2.9, 2.3, CAR_LEN), Vector3(0.0, 1.9, cz), BODY_CREAM)
	b.add_box(Vector3(2.98, 0.5, CAR_LEN - 0.2), Vector3(0.0, 1.75, cz), LIVERY_RED)
	g.add_box(Vector3(2.96, 0.62, CAR_LEN - 2.6), Vector3(0.0, 2.45, cz), TRAIN_WIN)
	b.add_box(Vector3(2.6, 0.2, CAR_LEN - 0.6), Vector3(0.0, 3.13, cz), TRAIN_ROOF)
	for dz in [-3.0, 0.0, 3.0]:
		b.add_box(Vector3(1.1, 0.16, 1.4), Vector3(0.0, 3.3, cz + dz), TRAIN_ROOF)
	if lead:
		var fz := cz - CAR_LEN / 2.0 - 0.06
		b.add_box(Vector3(2.9, 2.3, 0.16), Vector3(0.0, 1.9, fz), LIVERY_RED)
		g.add_box(Vector3(2.1, 0.7, 0.2), Vector3(0.0, 2.55, fz), TRAIN_WIN)
		b.add_box(Vector3(2.92, 0.28, 0.18), Vector3(0.0, 0.78, fz), GOLD)
	var rz := cz + CAR_LEN / 2.0 + 0.06
	b.add_box(Vector3(2.9, 2.3, 0.16), Vector3(0.0, 1.9, rz), LIVERY_RED)
