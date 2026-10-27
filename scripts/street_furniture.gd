extends RefCounted
## Street furniture (issue #69): bus-stop shelters and speed bumps.
## Shelters (bench + posts + roof + windbreak + route-sign pole) sit on
## the sidewalks of the major roads — the four bounding roads of each
## landmark block plus the elevated-metro line — facing their lane and
## never blocking it. Speed bumps are raised yellow-striped strips
## guarding every approach arm of the intersections around Connaught
## Place and Chandni Chowk. The city is kinematic, so their physical
## effect (braking, suspension jolt, chassis thunk) is scripted:
## auto.gd for the driven vehicle, traffic.gd for ambient traffic.
## All geometry is procedural MeshTools boxes; placement is deterministic.

const Roads := preload("res://scripts/roads.gd")
const MeshTools := preload("res://scripts/meshtools.gd")

## Landmark blocks (ix, iz): their four bounding roads count as major.
const LANDMARKS := [
	Vector2i(5, 5),  # Connaught Place ring
	Vector2i(5, 3),  # India Gate
	Vector2i(3, 7),  # Purani Dilli
	Vector2i(4, 7),  # Chandni Chowk
	Vector2i(7, 5),  # Police station
]
## Speed-bump sites: every intersection bounding these blocks gets bumps.
const BUMP_SITES := [Vector2i(5, 5), Vector2i(4, 7)]  # CP, Chandni Chowk

const STOP_OFFSET := 7.1  ## shelter center from road center (band 6.0..8.2)
const BUMP_DIST := 11.5  ## strip center from intersection center
const BUMP_HALF_SPAN := 5.6  ## strip reach across the road (lane band +-5.6)
const BUMP_DEPTH := 2.4  ## strip length along the traffic direction
const BUMP_H := 0.13

const STEEL := Color(0.55, 0.57, 0.61)
const ROOF := Color(0.16, 0.23, 0.35)
const SLAT := Color(0.48, 0.33, 0.19)
const FRAME := Color(0.15, 0.16, 0.18)
const PANEL := Color(0.74, 0.78, 0.80)
const SIGN_BG := Color(0.97, 0.78, 0.20)
const SIGN_STRIPE := Color(0.12, 0.12, 0.14)
const PLINTH := Color(0.62, 0.63, 0.66)
const BUMP_BODY := Color(0.17, 0.17, 0.18)
const BUMP_PAINT := Color(0.92, 0.76, 0.14)


static func build(world: float, pitch: float, road_w: float,
		count: int) -> Dictionary:
	## Returns {"node": Node3D (null when empty), "bumps": Array,
	## "stops": Array[Transform3D]}. The node holds the merged shelters
	## and bump strips; the bumps array feeds the scripted physics in
	## auto.gd / traffic.gd; the stops array feeds the shelter collision
	## boxes (issue #77).
	var stops := _stop_transforms(world, pitch, road_w)
	var bumps := _bump_list(world, pitch, road_w)
	var root := Node3D.new()
	var added := false
	if not stops.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _stop_mesh()
		mm.instance_count = stops.size()
		for i in stops.size():
			mm.set_instance_transform(i, stops[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
		added = true
	if not bumps.is_empty():
		var b := MeshTools.new()
		for bump: Dictionary in bumps:
			_bump_boxes(b, bump)
		var mi := MeshInstance3D.new()
		mi.mesh = b.build_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		added = true
	return {"node": root if added else null, "bumps": bumps, "stops": stops}


# ------------------------------------------------------------ bus stops

static func _stop_transforms(world: float, pitch: float,
		road_w: float) -> Array[Transform3D]:
	## One shelter mid-way along each bounding-road sidewalk of every
	## landmark block, facing its road, plus four along the metro line.
	## Yaw turns local -Z (the bench's facing) toward the road.
	var out: Array[Transform3D] = []
	var seen := {}
	var half_block := (pitch - road_w) / 2.0
	for block: Vector2i in LANDMARKS:
		var cx := -world / 2.0 + block.x * pitch + road_w / 2.0
		var cz := -world / 2.0 + block.y * pitch + road_w / 2.0
		var spots := [
			[Vector3(cx, 0.0, cz - half_block + STOP_OFFSET), 0.0],
			[Vector3(cx, 0.0, cz + half_block - STOP_OFFSET), PI],
			[Vector3(cx - half_block + STOP_OFFSET, 0.0, cz), PI / 2.0],
			[Vector3(cx + half_block - STOP_OFFSET, 0.0, cz), -PI / 2.0],
		]
		for e in spots:
			if not _put_stop(out, seen, e[0], e[1]):
				continue
	# Elevated-metro road (road-line index 4): shelters on its north
	# sidewalk, facing the road.
	var mz := -world / 2.0 + 4.0 * pitch - half_block
	for ix: int in [1, 3, 5, 7]:
		var mx := -world / 2.0 + float(ix) * pitch + road_w / 2.0
		_put_stop(out, seen, Vector3(mx, 0.0, mz + STOP_OFFSET), 0.0)
	return out


static func _put_stop(out: Array[Transform3D], seen: Dictionary,
		pos: Vector3, yaw: float) -> bool:
	## Append one shelter transform, deduped by ground position.
	var key := Vector2(roundf(pos.x * 10.0), roundf(pos.z * 10.0))
	if seen.has(key):
		return false
	seen[key] = true
	out.append(Transform3D(Basis(Vector3.UP, yaw), pos))
	return true


static func _stop_mesh() -> ArrayMesh:
	## One shelter: bench with backrest, two posts under a roof, a
	## windbreak panel behind the bench and a route-sign pole with a
	## striped board. Local front is -Z (toward the road); the origin
	## sits on the sidewalk surface.
	var b := MeshTools.new()
	# bench
	_sb(b, Vector3(1.8, 0.07, 0.45), Vector3(0, 0.45, -0.15), SLAT)
	_sb(b, Vector3(0.07, 0.45, 0.40), Vector3(-0.75, 0.225, -0.15), FRAME)
	_sb(b, Vector3(0.07, 0.45, 0.40), Vector3(0.75, 0.225, -0.15), FRAME)
	_sb(b, Vector3(1.8, 0.35, 0.06), Vector3(0, 0.72, 0.10), SLAT)
	# shelter — four posts, not two: thicker sticks at the back plus a
	# matching pair at the road-side corners, so the roof never reads as
	# a floating slab at capture distance (issue #103 sweep finding)
	_sb(b, Vector3(0.14, 2.5, 0.14), Vector3(-1.05, 1.25, 0.15), STEEL)
	_sb(b, Vector3(0.14, 2.5, 0.14), Vector3(1.05, 1.25, 0.15), STEEL)
	_sb(b, Vector3(0.14, 2.5, 0.14), Vector3(-1.05, 1.25, -0.55), STEEL)
	_sb(b, Vector3(0.14, 2.5, 0.14), Vector3(1.05, 1.25, -0.55), STEEL)
	_sb(b, Vector3(2.6, 0.08, 1.5), Vector3(0, 2.52, -0.05), ROOF)
	_sb(b, Vector3(2.3, 1.05, 0.05), Vector3(0, 1.30, 0.42), PANEL)
	# route sign (anchored: base plinth on the sidewalk, board
	# captive on the pole so neither end reads as floating — issue #78)
	_sb(b, Vector3(0.34, 0.22, 0.34), Vector3(1.45, 0.11, -0.55), PLINTH)
	_sb(b, Vector3(0.08, 2.9, 0.08), Vector3(1.45, 1.45, -0.55), STEEL)
	_sb(b, Vector3(0.75, 0.50, 0.06), Vector3(1.45, 2.62, -0.55), SIGN_BG)
	_sb(b, Vector3(0.75, 0.13, 0.07), Vector3(1.45, 2.62, -0.55), SIGN_STRIPE)
	return b.build_mesh()


static func _sb(b: MeshTools, size: Vector3, pos: Vector3, color: Color) -> void:
	## Box lifted onto the sidewalk surface (CURB_H from roads.gd).
	b.add_box(size, Vector3(pos.x, Roads.CURB_H + pos.y, pos.z), color)


# ------------------------------------------------------------ speed bumps

static func _bump_list(world: float, pitch: float, road_w: float) -> Array:
	## One strip per approach arm of every intersection bounding a
	## BUMP_SITES block: {"x", "z", "along_x"} where along_x means the
	## road runs along X, so the strip crosses at a fixed x.
	var out: Array = []
	var half_block := (pitch - road_w) / 2.0
	for site: Vector2i in BUMP_SITES:
		var cx := -world / 2.0 + site.x * pitch + road_w / 2.0
		var cz := -world / 2.0 + site.y * pitch + road_w / 2.0
		for x: float in [cx - half_block, cx + half_block]:
			for z: float in [cz - half_block, cz + half_block]:
				for arm: float in [-1.0, 1.0]:
					out.append({"x": x, "z": z + arm * BUMP_DIST,
							"along_x": false})
					out.append({"x": x + arm * BUMP_DIST, "z": z,
							"along_x": true})
	return out


static func _bump_boxes(b: MeshTools, bump: Dictionary) -> void:
	## Raised strip: dark body just proud of the asphalt with two yellow
	## paint stripes on top so the crossing reads at speed.
	var x: float = bump.x
	var z: float = bump.z
	var y := Roads.ROAD_Y + BUMP_H / 2.0
	var paint_y := Roads.ROAD_Y + BUMP_H + 0.012
	if bump.along_x:
		# Road runs along X: the strip spans Z at a fixed x.
		b.add_box(Vector3(BUMP_DEPTH, BUMP_H, BUMP_HALF_SPAN * 2.0),
				Vector3(x, y, z), BUMP_BODY)
		b.add_box(Vector3(0.45, 0.025, BUMP_HALF_SPAN * 2.0),
				Vector3(x + 0.75, paint_y, z), BUMP_PAINT)
		b.add_box(Vector3(0.45, 0.025, BUMP_HALF_SPAN * 2.0),
				Vector3(x - 0.75, paint_y, z), BUMP_PAINT)
	else:
		b.add_box(Vector3(BUMP_HALF_SPAN * 2.0, BUMP_H, BUMP_DEPTH),
				Vector3(x, y, z), BUMP_BODY)
		b.add_box(Vector3(BUMP_HALF_SPAN * 2.0, 0.025, 0.45),
				Vector3(x, paint_y, z + 0.75), BUMP_PAINT)
		b.add_box(Vector3(BUMP_HALF_SPAN * 2.0, 0.025, 0.45),
				Vector3(x, paint_y, z - 0.75), BUMP_PAINT)
