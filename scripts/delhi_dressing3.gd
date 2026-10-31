extends RefCounted
## Delhi dressing slice 3 (issue #129): the green and gastronomic layer.
## Research pass (photo/descriptions of Delhi avenues and Old Delhi food
## streets): the grand streets read as Delhi because of huge shade trees —
## peepal (sacred fig, tall broad crown) and banyan (vast low canopy held
## up by aerial prop roots, India's national tree) line the avenues; the
## food streets read as Delhi because of halwai sweet-shop fronts (glass
## counter of mithai trays under a striped awning) and dhaba corners
## (clay tandoor, wood pile, woven charpai cot under a tin roof); and the
## Old Delhi shrine sits behind a small masonry temple gate with a brass
## bell and a marigold strand. This slice builds exactly those four.
## Signage (#131), vehicles (#125), market clutter (#124) and the bazaar
## bunting are untouched. All procedural MeshTools geometry; placement
## deterministic — same city every launch.

const Roads := preload("res://scripts/roads.gd")
const MeshTools := preload("res://scripts/meshtools.gd")

## Landmark blocks that get avenue trees (same set as the slice-1 poles
## and slice-2 props, so the dressing layers stay in the same districts).
const LANDMARKS := [
	Vector2i(5, 5),  # Connaught Place ring
	Vector2i(5, 3),  # India Gate
	Vector2i(3, 7),  # Purani Dilli
	Vector2i(4, 7),  # Chandni Chowk
	Vector2i(7, 5),  # Police station
]

const TREE_IN := 2.9      ## avenue tree inset from the block edge
const TREE_SPOTS := [-2.5, 13.0]  ## along-edge offsets, mid-gap between
                                  ## the slice-1 wire poles (-12.5 / +7.5)

# Peepal — sacred fig: pale smooth bark, tall crown, moderate spread.
const PEEPAL_BARK := Color(0.55, 0.52, 0.46)
const LEAF_DEEP := Color(0.13, 0.37, 0.12)
# Banyan — dark furrowed bark, wider-than-tall canopy, aerial prop roots.
const BANYAN_BARK := Color(0.34, 0.29, 0.23)
const LEAF_DARK := Color(0.10, 0.30, 0.11)
const ROOT := Color(0.42, 0.37, 0.30)

# Halwai sweet-shop front.
const SHOP_WALL := Color(0.82, 0.70, 0.50)
const SHOP_FLOOR := Color(0.72, 0.66, 0.56)
const SHOP_ROOF := Color(0.55, 0.42, 0.30)
const COUNTER := Color(0.90, 0.88, 0.80)
const GLASS := Color(0.78, 0.84, 0.82)
const AWNING_A := Color(0.72, 0.16, 0.16)
const AWNING_B := Color(0.94, 0.92, 0.86)
const MITHAI := [
	Color(0.95, 0.60, 0.12), Color(0.92, 0.78, 0.30),
	Color(0.85, 0.45, 0.20), Color(0.94, 0.90, 0.80),
]
const JAR_BRASS := Color(0.80, 0.64, 0.26)

# Dhaba corner.
const TANDOOR := Color(0.48, 0.30, 0.20)
const EMBER := Color(0.85, 0.35, 0.08)
const WOOD := Color(0.45, 0.32, 0.18)
const CHARPAI := Color(0.62, 0.47, 0.28)
const WEAVE := Color(0.78, 0.68, 0.45)
const TIN := Color(0.62, 0.63, 0.65)
const BAMBOO := Color(0.72, 0.64, 0.38)
const PARATHA := Color(0.85, 0.68, 0.35)
const PLATE := Color(0.95, 0.93, 0.88)
const STEEL := Color(0.58, 0.58, 0.60)

# Temple gate.
const GATE_STONE := Color(0.76, 0.68, 0.55)
const GATE_RED := Color(0.78, 0.30, 0.14)
const MARIGOLD := Color(0.96, 0.63, 0.08)
const BELL := Color(0.78, 0.62, 0.25)


static func build(world: float, pitch: float, road_w: float) -> Node3D:
	## One root: avenue trees as two species MultiMeshes with trunk
	## colliders, plus the one-off sweet-shop front, dhaba corner and
	## temple gate merged into a single static mesh with real colliders.
	var half_block := (pitch - road_w) / 2.0
	var b := MeshTools.new()
	var peepal_xfs: Array[Transform3D] = []
	var banyan_xfs: Array[Transform3D] = []
	var flip := 0
	for block: Vector2i in LANDMARKS:
		var cx := -world / 2.0 + block.x * pitch + road_w / 2.0
		var cz := -world / 2.0 + block.y * pitch + road_w / 2.0
		# Avenue trees on the north and south kerbs only (the east/west
		# edges carry the slice-1 cross-street wire jumps).
		for side_z: float in [-1.0, 1.0]:
			var line := cz - side_z * (half_block - TREE_IN)
			for t in TREE_SPOTS:
				var xf := Transform3D(
						Basis(Vector3.UP, (PI / 2.0 if flip % 2 == 0 else -PI / 2.0)),
						Vector3(cx + t, Roads.CURB_H, line))
				if flip % 2 == 0:
					peepal_xfs.append(xf)
				else:
					banyan_xfs.append(xf)
				flip += 1
	# One-off fronts (issue #183: the sweet shop and dhaba are hollow,
	# walk-in places — walls with a real doorway, per-prop colliders).
	var cc := _block_center(world, pitch, road_w, Vector2i(4, 7))
	var pd := _block_center(world, pitch, road_w, Vector2i(3, 7))
	var hx := cc.x - 5.0
	var hz := cc.y + 4.0
	var dx := pd.x + 9.5
	var dz := pd.y - 9.5
	var colliders: Array = [
		# Halwai shop: wall segments leave the east doorway open.
		[Vector3(0.25, 2.7, 3.2), Vector3(hx - 1.575, 0, hz)],
		[Vector3(3.4, 2.7, 0.25), Vector3(hx, 0, hz - 1.475)],
		[Vector3(3.4, 2.7, 0.25), Vector3(hx, 0, hz + 1.475)],
		[Vector3(0.25, 2.1, 1.0), Vector3(hx + 1.575, 0, hz - 1.1)],
		[Vector3(0.25, 2.1, 1.0), Vector3(hx + 1.575, 0, hz + 1.1)],
		[Vector3(0.5, 0.95, 2.2), Vector3(hx - 1.4, 0, hz + 0.15)],
		# Dhaba: per-prop boxes under the tin roof, open to walk in.
		[Vector3(1.3, 1.2, 1.3), Vector3(dx - 1.2, 0, dz - 1.0)],
		[Vector3(1.0, 0.7, 1.0), Vector3(dx + 0.4, 0, dz - 1.3)],
		[Vector3(0.9, 0.95, 1.8), Vector3(dx + 1.55, 0, dz - 0.1)],
		[Vector3(1.9, 0.55, 0.9), Vector3(dx + 0.4, 0, dz + 1.0)],
		# Seating nook (issue #218): second charpai + round table + stools.
		[Vector3(1.75, 0.6, 0.8), Vector3(dx - 0.95, 0, dz + 0.15)],
		[Vector3(1.6, 0.7, 1.7), Vector3(dx - 1.2, 0, dz + 1.7)],
		# Temple gate posts.
		[Vector3(1.4, 3.4, 1.4), Vector3(pd.x - 10.6, 0, pd.y - 0.5)],
		[Vector3(1.4, 3.4, 1.4), Vector3(pd.x - 5.4, 0, pd.y - 0.5)],
	]
	_sweet_shop(b, hx, hz)
	_dhaba(b, dx, dz)
	_temple_gate(b, pd.x - 8.0, pd.y - 0.5)

	var root := Node3D.new()
	root.name = "DelhiDressing3"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_add_tree_prop(root, _peepal_mesh(), peepal_xfs)
	_add_tree_prop(root, _banyan_mesh(), banyan_xfs)
	var solid := StaticBody3D.new()
	solid.name = "FrontColliders"
	for c in colliders:
		var size: Vector3 = c[0]
		var at: Vector3 = c[1]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.transform = Transform3D(Basis(),
				at + Vector3(0, Roads.CURB_H + size.y * 0.5, 0))
		solid.add_child(shape)
	root.add_child(solid)
	# Tandoor glow (issue #218): one warm ember light at the dhaba mouth,
	# the same fixed-lamp pattern as the railway platform lamps — the
	# seating nook reads at dusk without touching the night_check lamp
	# network.
	var tandoor := OmniLight3D.new()
	tandoor.position = Vector3(dx - 1.2, Roads.CURB_H + 1.35, dz - 1.0)
	tandoor.light_color = Color(1.0, 0.62, 0.30)
	tandoor.light_energy = 1.1
	tandoor.omni_range = 3.4
	tandoor.omni_attenuation = 1.6
	root.add_child(tandoor)
	return root


static func _block_center(world: float, pitch: float, road_w: float,
		block: Vector2i) -> Vector2:
	return Vector2(-world / 2.0 + block.x * pitch + road_w / 2.0,
			-world / 2.0 + block.y * pitch + road_w / 2.0)


static func _add_tree_prop(root: Node3D, mesh: ArrayMesh,
		xfs: Array[Transform3D]) -> void:
	## Species MultiMesh plus one slim trunk collider per tree — the
	## canopy stays walk-under, the trunk does not (issue #77 rule).
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var solid := StaticBody3D.new()
	for xf: Transform3D in xfs:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, 3.0, 0.7)
		shape.shape = box
		shape.transform = xf * Transform3D(Basis(), Vector3(0, 1.5, 0))
		solid.add_child(shape)
	root.add_child(solid)


# ------------------------------------------------------------ avenue trees

static func _peepal_mesh() -> ArrayMesh:
	## Sacred fig: pale trunk, crown stacked high and moderate spread.
	var b := MeshTools.new()
	b.add_box(Vector3(0.55, 2.8, 0.55), Vector3(0, 1.4, 0), PEEPAL_BARK)
	b.add_box(Vector3(0.38, 1.4, 0.38), Vector3(0, 3.4, 0), PEEPAL_BARK)
	_crown(b, 5.35, 2.6, 1.25, LEAF_DEEP)
	_crown(b, 4.15, 2.0, 1.1, LEAF_DEEP)
	return b.build_mesh()


static func _banyan_mesh() -> ArrayMesh:
	## Banyan: dark trunk, wider-than-tall canopy, aerial prop roots
	## hanging from the branch line to the ground around the trunk.
	var b := MeshTools.new()
	b.add_box(Vector3(0.8, 2.4, 0.8), Vector3(0, 1.2, 0), BANYAN_BARK)
	_crown(b, 4.6, 3.3, 1.1, LEAF_DARK)
	_crown(b, 3.5, 2.6, 1.0, LEAF_DARK)
	for i in 5:
		var a := TAU * i / 5.0 + 0.35
		var r := 2.35
		b.add_box(Vector3(0.12, 3.4, 0.12),
				Vector3(cos(a) * r, 1.7, sin(a) * r), ROOT)
	return b.build_mesh()


static func _crown(b: MeshTools, cy: float, radius: float, h: float,
		leaf: Color) -> void:
	## One crown slab as a cylinder — MeshTools buckets it by color.
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.82
	cm.bottom_radius = radius
	cm.height = h
	b.add_mesh(cm, Transform3D(Basis(), Vector3(0, cy, 0)), leaf)


# ------------------------------------------------------------ food fronts

static func _sweet_shop(b: MeshTools, x: float, z: float) -> void:
	## Halwai sweet shop, walk-in (issue #183): hollow masonry box with
	## a doorway in the east face — inside, a glass mithai counter
	## against the back wall, brass jars on a shelf, worn floor tiles.
	var y := Roads.CURB_H
	# Floor: worn concrete patch inside the walls.
	b.add_box(Vector3(3.15, 0.04, 2.95), Vector3(x, y + 0.02, z), SHOP_FLOOR)
	# Back wall (west) + the two ends.
	b.add_box(Vector3(0.25, 2.7, 3.2), Vector3(x - 1.575, y + 1.35, z), SHOP_WALL)
	b.add_box(Vector3(3.4, 2.7, 0.25), Vector3(x, y + 1.35, z - 1.475), SHOP_WALL)
	b.add_box(Vector3(3.4, 2.7, 0.25), Vector3(x, y + 1.35, z + 1.475), SHOP_WALL)
	# East face: two segments flanking a 1.2 m doorway + lintel above.
	b.add_box(Vector3(0.25, 2.1, 1.0), Vector3(x + 1.575, y + 1.05, z - 1.1), SHOP_WALL)
	b.add_box(Vector3(0.25, 2.1, 1.0), Vector3(x + 1.575, y + 1.05, z + 1.1), SHOP_WALL)
	b.add_box(Vector3(0.25, 0.6, 1.2), Vector3(x + 1.575, y + 2.4, z), SHOP_WALL)
	b.add_box(Vector3(3.7, 0.12, 3.5), Vector3(x, y + 2.76, z), SHOP_ROOF)
	# Counter against the back wall: glass top with mithai trays on it.
	b.add_box(Vector3(0.5, 0.95, 2.2), Vector3(x - 1.4, y + 0.475, z + 0.15), COUNTER)
	b.add_box(Vector3(0.6, 0.1, 2.3), Vector3(x - 1.4, y + 1.0, z + 0.15), GLASS)
	for s in 5:
		b.add_box(Vector3(0.42, 0.16, 0.42),
				Vector3(x - 1.4, y + 1.08, z - 0.85 + s * 0.5), MITHAI[s % 4])
	# Brass sweet jars on a back-wall shelf ledge.
	b.add_box(Vector3(0.2, 0.05, 2.4), Vector3(x - 1.72, y + 1.7, z + 0.15), SHOP_WALL)
	for j in 4:
		var jm := CylinderMesh.new()
		jm.top_radius = 0.13
		jm.bottom_radius = 0.1
		jm.height = 0.4
		b.add_mesh(jm, Transform3D(Basis(),
				Vector3(x - 1.68, y + 1.93, z - 0.85 + j * 0.66)), JAR_BRASS)
	# Striped awning on two poles over the doorway.
	for pole_z in [-1.15, 1.15]:
		b.add_box(Vector3(0.1, 2.6, 0.1), Vector3(x + 2.05, y + 1.3, z + pole_z),
				Color(0.35, 0.25, 0.16))
	for s in 4:
		var col := AWNING_A if s % 2 == 0 else AWNING_B
		b.add_box(Vector3(1.15, 0.08, 0.72),
				Vector3(x + 1.62, y + 2.62, z - 1.08 + s * 0.72), col)

static func _dhaba(b: MeshTools, x: float, z: float) -> void:
	## Roadside dhaba corner (walk-in, issue #183): clay tandoor with a
	## glow at the mouth, a wood pile, a service counter with tawa and
	## paratha stack, a woven charpai cot and a tin roof on bamboo poles.
	var y := Roads.CURB_H
	# Tandoor: squat clay drum, ember glow at the mouth.
	var td := CylinderMesh.new()
	td.top_radius = 0.55
	td.bottom_radius = 0.75
	td.height = 1.2
	b.add_mesh(td, Transform3D(Basis(), Vector3(x - 1.2, y + 0.6, z - 1.0)), TANDOOR)
	b.add_box(Vector3(0.5, 0.14, 0.5), Vector3(x - 1.2, y + 1.22, z - 1.0),
			EMBER, MeshTools.FINISH_GLOSS)
	# Wood pile beside it: stacked logs.
	for w in 3:
		b.add_box(Vector3(0.9, 0.22, 0.9), Vector3(x + 0.4, y + 0.13 + w * 0.24,
				z - 1.3), WOOD)
	# Service counter (issue #183) along the east edge, serving face to
	# the west: wooden body, woven top, tawa griddle, paratha + plates.
	b.add_box(Vector3(0.9, 0.92, 1.8), Vector3(x + 1.55, y + 0.46, z - 0.1), CHARPAI)
	b.add_box(Vector3(1.0, 0.06, 1.9), Vector3(x + 1.55, y + 0.95, z - 0.1), WEAVE)
	var tawa := CylinderMesh.new()
	tawa.top_radius = 0.28
	tawa.bottom_radius = 0.28
	tawa.height = 0.05
	b.add_mesh(tawa, Transform3D(Basis(),
				Vector3(x + 1.55, y + 1.0, z - 0.72)), STEEL)
	for p in 3:
		var pr := CylinderMesh.new()
		pr.top_radius = 0.12
		pr.bottom_radius = 0.12
		pr.height = 0.03
		b.add_mesh(pr, Transform3D(Basis(),
					Vector3(x + 1.55, y + 1.02 + p * 0.035, z + 0.5)), PARATHA)
	for pl in 3:
		var pc := CylinderMesh.new()
		pc.top_radius = 0.16
		pc.bottom_radius = 0.16
		pc.height = 0.025
		b.add_mesh(pc, Transform3D(Basis(),
					Vector3(x + 1.42, y + 1.01 + pl * 0.03, z + 0.05)), PLATE)
	# Charpai: frame + woven top.
	b.add_box(Vector3(1.9, 0.28, 0.9), Vector3(x + 0.4, y + 0.5, z + 1.0), CHARPAI)
	b.add_box(Vector3(1.7, 0.08, 0.7), Vector3(x + 0.4, y + 0.62, z + 1.0), WEAVE)
	for lx in [-0.8, 0.8]:
		for lz in [-0.35, 0.35]:
			b.add_box(Vector3(0.12, 0.55, 0.12),
					Vector3(x + 0.4 + lx, y + 0.27, z + 1.0 + lz), CHARPAI)
	# Seating nook (issue #218): a second charpai west of the counter and
	# a round steel table with two stools — beveled frames and cylinder
	# legs per the de-box rule, matching the slice-3 nook vocabulary.
	var cot_x := x - 0.95
	var cot_z := z + 0.15
	b.add_bev_box(Vector3(1.75, 0.26, 0.8),
			Vector3(cot_x, y + 0.5, cot_z), 0.04, CHARPAI)
	b.add_bev_box(Vector3(1.55, 0.07, 0.6),
			Vector3(cot_x, y + 0.64, cot_z), 0.03, WEAVE)
	for lx in [-0.75, 0.75]:
		for lz in [-0.3, 0.3]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.05
			leg.bottom_radius = 0.05
			leg.height = 0.42
			leg.radial_segments = 6
			b.add_mesh(leg, Transform3D(Basis(),
					Vector3(cot_x + lx, y + 0.21, cot_z + lz)), CHARPAI)
	var top := CylinderMesh.new()
	top.top_radius = 0.45
	top.bottom_radius = 0.45
	top.height = 0.05
	top.radial_segments = 14
	b.add_mesh(top, Transform3D(Basis(),
			Vector3(x - 1.0, y + 0.42, z + 1.75)), PLATE)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.07
	stem.bottom_radius = 0.09
	stem.height = 0.4
	stem.radial_segments = 8
	b.add_mesh(stem, Transform3D(Basis(),
			Vector3(x - 1.0, y + 0.21, z + 1.75)), STEEL)
	var base := CylinderMesh.new()
	base.top_radius = 0.22
	base.bottom_radius = 0.24
	base.height = 0.04
	base.radial_segments = 10
	b.add_mesh(base, Transform3D(Basis(),
			Vector3(x - 1.0, y + 0.02, z + 1.75)), STEEL)
	for st in [Vector2(x - 1.75, z + 1.75), Vector2(x - 1.0, z + 1.0)]:
		var seat := CylinderMesh.new()
		seat.top_radius = 0.17
		seat.bottom_radius = 0.19
		seat.height = 0.32
		seat.radial_segments = 8
		b.add_mesh(seat, Transform3D(Basis(),
				Vector3(st.x, y + 0.16, st.y)), WOOD)
	# Tin roof on four bamboo poles over the whole corner.
	for px in [-1.6, 1.6]:
		for pz in [-1.5, 1.5]:
			b.add_box(Vector3(0.12, 2.5, 0.12), Vector3(x + px, y + 1.25, z + pz), BAMBOO)
	b.add_box(Vector3(4.0, 0.08, 3.7), Vector3(x, y + 2.55, z), TIN)

static func _temple_gate(b: MeshTools, x: float, z: float) -> void:
	## Small masonry gateway on the shrine approach: two pillars, a
	## stepped lintel, a brass bell under the arch and a marigold strand.
	var y := Roads.CURB_H
	for px in [-2.6, 2.6]:
		b.add_box(Vector3(1.1, 3.2, 1.1), Vector3(x + px, y + 1.6, z), GATE_STONE)
		b.add_box(Vector3(1.3, 0.25, 1.3), Vector3(x + px, y + 3.3, z), GATE_RED)
	b.add_box(Vector3(6.4, 0.5, 1.2), Vector3(x, y + 3.55, z), GATE_STONE)
	b.add_box(Vector3(4.6, 0.45, 1.0), Vector3(x, y + 4.0, z), GATE_RED)
	b.add_box(Vector3(2.6, 0.4, 0.9), Vector3(x, y + 4.4, z), GATE_STONE)
	# Brass bell hanging under the lintel.
	var bc := CylinderMesh.new()
	bc.top_radius = 0.08
	bc.bottom_radius = 0.26
	bc.height = 0.4
	b.add_mesh(bc, Transform3D(Basis(), Vector3(x, y + 3.0, z)), BELL)
	b.add_box(Vector3(0.05, 0.3, 0.05), Vector3(x, y + 3.32, z), BELL)
	# Marigold strand looping between the pillar tops.
	for f in 7:
		var t := (f + 1) / 8.0
		var fy := y + 3.45 - sin(PI * t) * 0.35
		b.add_box(Vector3(0.16, 0.16, 0.16),
				Vector3(x - 2.6 + 5.2 * t, fy, z), MARIGOLD)
