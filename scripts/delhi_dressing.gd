extends RefCounted
## Delhi street dressing (issue #129, first slice): the reference-driven
## look of an Old Delhi street, all procedural MeshTools geometry.
## Research pass (Chandni Chowk / Old Delhi photo references cited in the
## issue): the skyline-defining street-level traits are tangled overhead
## electric wiring, yellow-black painted kerbs, thela hand-carts piled
## with produce, and roadside chai stalls. This slice builds exactly
## those four around the landmark blocks and inside the Chandni Chowk
## market lane. Signage (#131), materials (#130), atmosphere (#132),
## vehicles (#125) and clutter (#124) are separate issues, untouched.
## Placement is deterministic — same city every launch.

const Roads := preload("res://scripts/roads.gd")
const MeshTools := preload("res://scripts/meshtools.gd")

## Landmark blocks that get poles, wiring and kerb paint (same set as
## the bus-stop shelters in street_furniture.gd).
const LANDMARKS := [
	Vector2i(5, 5),  # Connaught Place ring
	Vector2i(5, 3),  # India Gate
	Vector2i(3, 7),  # Purani Dilli
	Vector2i(4, 7),  # Chandni Chowk
	Vector2i(7, 5),  # Police station
]

const POLE_IN := 1.7     ## wire pole inset from the block edge
const POLE_H := 6.4
const POLE_STEP := 20.0  ## spacing between consecutive poles
const KERB_IN := 0.38    ## painted kerb stripe inset from the block edge
const KERB_SEG := 2.0    ## one painted stripe length
const KERB_MARGIN := 5.0 ## kept clear of block corners (crossing decks)
const WIRE_SEG := 7      ## boxes per sagging span
const WIRE_THICK := 0.045
const WIRE_SAG := 0.55   ## along-street wires
const JUMP_SAG := 0.85   ## cross-street jumps

const CONCRETE := Color(0.60, 0.59, 0.56)
const WIRE := Color(0.05, 0.05, 0.05)
const KERB_YELLOW := Color(0.93, 0.72, 0.10)
const KERB_BLACK := Color(0.07, 0.07, 0.07)
const CART_WOOD := Color(0.52, 0.36, 0.19)
const CART_RIM := Color(0.75, 0.55, 0.20)
const WHEEL := Color(0.13, 0.12, 0.11)
const CANOPY := Color(0.86, 0.44, 0.12)
const TARP := Color(0.82, 0.60, 0.18)
const STEEL := Color(0.58, 0.58, 0.60)
const GLASS := Color(0.90, 0.90, 0.86)
const CRATE := Color(0.45, 0.30, 0.15)
const PRODUCE := [
	Color(0.22, 0.52, 0.18), Color(0.88, 0.44, 0.10),
	Color(0.76, 0.16, 0.12), Color(0.94, 0.84, 0.22),
]


static func build(world: float, pitch: float, road_w: float) -> Node3D:
	## One root node: a merged shadow-free mesh (poles, wires, kerb
	## paint), MultiMeshes for the thela carts and chai stalls, and a
	## StaticBody3D of street-level colliders for carts and stalls.
	var half_block := (pitch - road_w) / 2.0
	var b := MeshTools.new()
	var cart_xfs: Array[Transform3D] = []
	var stall_xfs: Array[Transform3D] = []
	for block: Vector2i in LANDMARKS:
		var cx := -world / 2.0 + block.x * pitch + road_w / 2.0
		var cz := -world / 2.0 + block.y * pitch + road_w / 2.0
		for side: int in 4:
			_dress_side(b, cx, cz, half_block, side, road_w)
		if block == Vector2i(4, 7):
			# Chandni Chowk market lane: carts + a chai stall mid-lane
			_market_lane(cx + 6.0, cz, cart_xfs, stall_xfs)
		elif block == Vector2i(5, 5):
			# A couple of carts working the Connaught Place ring
			_cp_carts(cx, cz, half_block, cart_xfs)
	var root := Node3D.new()
	root.name = "DelhiDressing"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_add_prop(root, _cart_mesh(), cart_xfs, Vector3(1.9, 2.0, 1.3))
	_add_prop(root, _stall_mesh(), stall_xfs, Vector3(2.4, 2.4, 1.7))
	return root


static func _add_prop(root: Node3D, mesh: ArrayMesh, xfs: Array[Transform3D],
		coll: Vector3) -> void:
	## MultiMesh draw plus one collider box per instance, so nothing
	## at street level is walk-through (issue #77 rule).
	var mmi := MultiMeshInstance3D.new()
	if not xfs.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		mmi.multimesh = mm
	else:
		return
	root.add_child(mmi)
	var solid := StaticBody3D.new()
	for xf: Transform3D in xfs:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = coll
		shape.shape = box
		shape.transform = xf * Transform3D(Basis(), Vector3(0, coll.y * 0.5, 0))
		solid.add_child(shape)
	root.add_child(solid)


# ------------------------------------------------------------ sidewalk pass

static func _dress_side(b: MeshTools, cx: float, cz: float,
		half_block: float, side: int, road_w: float) -> void:
	## side 0/1 = north/south edges (road along X), 2/3 = west/east.
	## Wire poles with sagging along-street wires, one cross-street jump
	## to a receiver pole on the facing sidewalk, alternating kerb paint.
	var along_x := side < 2
	var sgn := 1.0 if side % 2 == 0 else -1.0
	var yaw: float = [0.0, PI, PI / 2.0, -PI / 2.0][side]
	var fwd := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	var pole_line := (cz - sgn * half_block + sgn * POLE_IN) if along_x \
			else (cx - sgn * half_block + sgn * POLE_IN)
	var kerb_line := (cz - sgn * half_block + sgn * KERB_IN) if along_x \
			else (cx - sgn * half_block + sgn * KERB_IN)
	var fixed := cx if along_x else cz
	var span := half_block * 2.0
	## wire poles in street order
	var tops: Array = []
	var t := -span / 2.0 + 4.5
	while t < span / 2.0 - 3.0:
		var p := _street_pt(fixed, pole_line, along_x, t)
		_pole(b, p, fwd)
		tops.append(p)
		t += POLE_STEP
	if tops.size() >= 2:
		for i in range(tops.size() - 1):
			var a: Vector3 = tops[i]
			var c: Vector3 = tops[i + 1]
			_span(b, a + Vector3(0, POLE_H - 0.45, 0) + fwd * 0.35,
					c + Vector3(0, POLE_H - 0.45, 0) + fwd * 0.35, WIRE_SAG)
			_span(b, a + Vector3(0, POLE_H - 0.45, 0) + fwd * 1.55,
					c + Vector3(0, POLE_H - 0.45, 0) + fwd * 1.55, WIRE_SAG)
			_span(b, a + Vector3(0, POLE_H - 0.15, 0),
					c + Vector3(0, POLE_H - 0.15, 0), WIRE_SAG * 0.6)
	## one cross-street jump: pole top to a receiver pole top across the
	## road (both ends visibly anchored — issue #78 rule)
	if not tops.is_empty():
		var near: Vector3 = tops[0]
		var far := near + fwd * (road_w + POLE_IN * 2.0)
		_pole(b, far, -fwd)
		_span(b, near + Vector3(0, POLE_H - 0.30, 0) + fwd * 0.9,
				far + Vector3(0, POLE_H - 0.30, 0) - fwd * 0.9, JUMP_SAG)
		_span(b, near + Vector3(0, POLE_H - 0.60, 0),
				far + Vector3(0, POLE_H - 0.60, 0), JUMP_SAG * 1.3)
	## yellow-black kerb paint along the same block edge
	var k := -span / 2.0 + KERB_MARGIN
	var stripe := 0
	while k + KERB_SEG <= span / 2.0 - KERB_MARGIN:
		var col := KERB_YELLOW if stripe % 2 == 0 else KERB_BLACK
		var center := _street_pt(fixed, kerb_line, along_x, k + KERB_SEG / 2.0)
		var size := Vector3(KERB_SEG, 0.045, 0.22) if along_x \
				else Vector3(0.22, 0.045, KERB_SEG)
		b.add_box(size, Vector3(center.x, Roads.CURB_H + 0.025, center.z), col)
		k += KERB_SEG
		stripe += 1


static func _street_pt(fixed: float, line: float, along_x: float,
		t: float) -> Vector3:
	## Point on a sidewalk line; t runs along the street direction.
	if along_x:
		return Vector3(fixed + t, Roads.CURB_H, line)
	return Vector3(line, Roads.CURB_H, fixed + t)


static func _pole(b: MeshTools, base: Vector3, fwd: Vector3) -> void:
	## Concrete pole with a cross-arm reaching over the road, drawn
	## rotated so both arm ends stay visibly anchored (issue #78 rule).
	b.add_box(Vector3(0.18, POLE_H, 0.18), base + Vector3(0, POLE_H / 2.0, 0), CONCRETE)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.13, 0.13, 2.1)
	b.add_mesh(bm, Transform3D(Basis.looking_at(fwd, Vector3.UP),
			base + Vector3(0, POLE_H - 0.45, 0) + fwd * 0.55), CONCRETE)


static func _span(b: MeshTools, p0: Vector3, p1: Vector3, sag: float) -> void:
	## One sagging wire: WIRE_SEG stretched thin boxes approximating the
	## catenary between two anchors (4·t·(1-t) bell curve).
	for i in WIRE_SEG:
		var t0 := float(i) / float(WIRE_SEG)
		var t1 := float(i + 1) / float(WIRE_SEG)
		var a := p0.lerp(p1, t0) - Vector3(0, sag * 4.0 * t0 * (1.0 - t0), 0)
		var c := p0.lerp(p1, t1) - Vector3(0, sag * 4.0 * t1 * (1.0 - t1), 0)
		_seg(b, a, c, WIRE)


static func _seg(b: MeshTools, p0: Vector3, p1: Vector3, color: Color) -> void:
	## Thin stretched box from p0 to p1.
	var d := p1 - p0
	var len := d.length()
	if len < 0.02:
		return
	var dir := d / len
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var bm := BoxMesh.new()
	bm.size = Vector3(WIRE_THICK, WIRE_THICK, len)
	b.add_mesh(bm, Transform3D(Basis.looking_at(dir, up), (p0 + p1) * 0.5), color)


# ------------------------------------------------------------ market lane

static func _market_lane(cx: float, cz: float, cart_xfs: Array[Transform3D],
		stall_xfs: Array[Transform3D]) -> void:
	## Thela carts parked along the Chandni Chowk market lane (axis runs
	## along Z at x = block_x + 6, inboard of the stall awnings), plus
	## one chai stall mid-lane. Fixed offsets — identical every launch.
	var spots := [
		[Vector3(cx - 3.5, Roads.CURB_H, cz - 9.0), PI / 2.0 + 0.12],
		[Vector3(cx + 3.5, Roads.CURB_H, cz + 1.0), -PI / 2.0 + 0.15],
		[Vector3(cx - 3.0, Roads.CURB_H, cz + 9.5), PI / 2.0 - 0.1],
	]
	for e in spots:
		cart_xfs.append(Transform3D(Basis(Vector3.UP, e[1]), e[0]))
	stall_xfs.append(Transform3D(Basis(Vector3.UP, PI / 2.0 + 0.05),
			Vector3(cx + 4.2, Roads.CURB_H, cz + 5.5)))


static func _cp_carts(cx: float, cz: float, half_block: float,
		cart_xfs: Array[Transform3D]) -> void:
	## Two carts working the Connaught Place ring sidewalk, at quarter
	## points of the north and east edges — clear of the mid-side bus
	## shelters (which sit 7.1 m in from the edge).
	cart_xfs.append(Transform3D(Basis(Vector3.UP, 0.9),
			Vector3(cx - 10.0, Roads.CURB_H, cz - half_block + 3.0)))
	cart_xfs.append(Transform3D(Basis(Vector3.UP, -PI / 2.0 + 0.85),
			Vector3(cx + half_block - 3.0, Roads.CURB_H, cz + 8.0)))


# ------------------------------------------------------------ prop meshes

static func _cart_mesh() -> ArrayMesh:
	## Thela (hand cart): wooden platform on two fat wheels, legs at the
	## handle end, a draw handle, produce crates piled two-deep, and a
	## small tilted canopy on a stick. Local +X runs along the street.
	var b := MeshTools.new()
	b.add_box(Vector3(1.9, 0.10, 1.1), Vector3(0, 0.78, 0), CART_WOOD)
	for x in [0.7, -0.7]:
		b.add_box(Vector3(0.08, 0.62, 0.08), Vector3(x, 0.34, 0.45), CART_WOOD)
		b.add_box(Vector3(0.08, 0.62, 0.08), Vector3(x, 0.34, -0.45), CART_WOOD)
	for z in [0.62, -0.62]:
		var w := CylinderMesh.new()
		w.top_radius = 0.38
		w.bottom_radius = 0.38
		w.height = 0.10
		b.add_mesh(w, Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0),
				Vector3(0.55, 0.38, z)), WHEEL)
		b.add_box(Vector3(0.06, 0.76, 0.06), Vector3(0.55, 0.38, z), CART_RIM)
	b.add_box(Vector3(0.7, 0.07, 0.07), Vector3(1.25, 0.95, 0.28), CART_WOOD)
	b.add_box(Vector3(0.7, 0.07, 0.07), Vector3(1.25, 0.95, -0.28), CART_WOOD)
	var crate_i := 0
	for x in [-0.55, 0.15]:
		for z in [0.27, -0.27]:
			var c: Color = PRODUCE[crate_i % PRODUCE.size()]
			b.add_box(Vector3(0.55, 0.24, 0.45), Vector3(x, 0.95, z), CRATE)
			b.add_box(Vector3(0.44, 0.14, 0.34), Vector3(x, 1.10, z), c)
			crate_i += 1
	b.add_box(Vector3(0.05, 1.15, 0.05), Vector3(-0.3, 1.35, 0), CART_WOOD)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 1.05
	cone.height = 0.42
	b.add_mesh(cone, Transform3D(Basis(Vector3(1, 0, 0), 0.16),
			Vector3(-0.3, 1.95, 0)), CANOPY)
	return b.build_mesh()


static func _stall_mesh() -> ArrayMesh:
	## Chai stall: counter with kettle and glasses, back shelf with
	## thermos jars, four poles under a striped tarp canopy.
	var b := MeshTools.new()
	b.add_box(Vector3(2.2, 0.08, 0.9), Vector3(0, 0.95, 0), CART_WOOD)
	b.add_box(Vector3(0.12, 0.9, 0.8), Vector3(-1.0, 0.48, 0), CART_WOOD)
	b.add_box(Vector3(0.12, 0.9, 0.8), Vector3(1.0, 0.48, 0), CART_WOOD)
	b.add_box(Vector3(0.12, 0.9, 0.8), Vector3(0.0, 0.48, 0.35), CART_WOOD)
	var kettle := CylinderMesh.new()
	kettle.top_radius = 0.16
	kettle.bottom_radius = 0.20
	kettle.height = 0.34
	b.add_mesh(kettle, Transform3D(Basis(), Vector3(-0.6, 1.16, 0)), STEEL)
	for i in 3:
		b.add_box(Vector3(0.10, 0.16, 0.10),
				Vector3(0.1 + 0.24 * i, 1.07, 0.1), GLASS)
	b.add_box(Vector3(1.9, 0.08, 0.35), Vector3(0, 1.45, -0.32), CART_WOOD)
	b.add_box(Vector3(0.08, 1.0, 0.08), Vector3(-0.95, 1.2, -0.32), CART_WOOD)
	b.add_box(Vector3(0.08, 1.0, 0.08), Vector3(0.95, 1.2, -0.32), CART_WOOD)
	for i in 4:
		var jc := Color(0.85, 0.28, 0.2) if i % 2 == 0 else Color(0.2, 0.45, 0.75)
		b.add_box(Vector3(0.18, 0.42, 0.18), Vector3(-0.6 + 0.4 * i, 1.7, -0.32), jc)
	for x in [-1.05, 1.05]:
		b.add_box(Vector3(0.07, 2.3, 0.07), Vector3(x, 1.15, -0.5), CART_WOOD)
		b.add_box(Vector3(0.07, 2.3, 0.07), Vector3(x, 1.15, 0.5), CART_WOOD)
	for s in 6:
		var c := TARP if s % 2 == 0 else Color(0.90, 0.88, 0.80)
		b.add_box(Vector3(0.36, 0.05, 1.5),
				Vector3(-0.95 + 0.38 * s, 2.34, 0.05), c)
	return b.build_mesh()
