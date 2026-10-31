extends Node
## Walk-in interiors, slice 2 (issue #206): a kirana general store on
## the Connaught Place block edge, a paan shop by the thana plaza and
## a pavement bookstore at the Neighbourhood Park corner — the three
## follow the slice-1/3 pattern: hollow chamfered wall prisms you walk
## into, beveled counters, a cast of idle locals, counter service
## through the street-food economy, the doorway chime (issue #187) and
## the rain low-pass behind the shopfront (issue #227). The paan shop
## also joins the bribe network (issue #188): its counter is a live
## [B] bribe spot, and it sells paan through the same wallet/HP path.
## De-box directive: every wall is a chamfered prism, counters are
## beveled, bottles and pots are lathe profiles, canopies arc shells.

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")
const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

const DOOR_HALF_X := 1.6
const DOOR_HALF_Z := 1.5
const BROWSE_R := 2.8

## Counter menus (issue #206): water and biscuits at the kirana, paan
## and soda at the paan shop — same wallet/HP path as cart food.
const WATER := {"name": "WATER", "price": 10, "heal": 10}
const BISCUITS := {"name": "BISCUITS", "price": 25, "heal": 25}
const PAAN := {"name": "PAAN", "price": 15, "heal": 8}
const SODA := {"name": "SODA", "price": 25, "heal": 18}

# Kirana palette.
const KIRANA_WALL := Color(0.93, 0.90, 0.82)
const KIRANA_FLOOR := Color(0.62, 0.58, 0.52)
const KIRANA_ROOF := Color(0.55, 0.30, 0.16)
const KIRANA_COUNTER := Color(0.58, 0.40, 0.22)
const KIRANA_GLASS := Color(0.80, 0.86, 0.84)
const KIRANA_BOARD := Color(0.12, 0.38, 0.55)
const SACK := Color(0.72, 0.62, 0.42)
const PACKET_COLORS := [
	Color(0.88, 0.30, 0.18), Color(0.95, 0.78, 0.20),
	Color(0.25, 0.55, 0.30), Color(0.90, 0.88, 0.84),
	Color(0.55, 0.35, 0.60),
]
const KIRANA_AWN_A := Color(0.85, 0.25, 0.12)
const KIRANA_AWN_B := Color(0.95, 0.93, 0.88)

# Paan shop palette.
const PAAN_WALL := Color(0.88, 0.86, 0.78)
const PAAN_FLOOR := Color(0.55, 0.52, 0.48)
const PAAN_ROOF := Color(0.16, 0.42, 0.22)
const PAAN_COUNTER := Color(0.35, 0.30, 0.24)
const PAAN_GLASS := Color(0.78, 0.90, 0.86)
const PAAN_BOARD := Color(0.05, 0.45, 0.18)
const LEAF := Color(0.16, 0.52, 0.22)
const LEAF_DARK := Color(0.10, 0.38, 0.16)
const BRASS := Color(0.78, 0.62, 0.24)
const LIME := Color(0.94, 0.94, 0.86)

# Bookstore palette.
const BOOK_WALL := Color(0.90, 0.87, 0.80)
const BOOK_FLOOR := Color(0.50, 0.42, 0.34)
const BOOK_ROOF := Color(0.38, 0.24, 0.44)
const SHELF_WOOD := Color(0.48, 0.34, 0.20)
const DESK := Color(0.55, 0.40, 0.26)
const BOOK_COLORS := [
	Color(0.70, 0.20, 0.15), Color(0.15, 0.35, 0.60),
	Color(0.85, 0.65, 0.15), Color(0.20, 0.50, 0.30),
	Color(0.60, 0.45, 0.65), Color(0.85, 0.82, 0.75),
	Color(0.45, 0.25, 0.20),
]

## Pavement book browsing (issue #206): [Q] at the shelves pulls the
## next spine — flavor only, free of charge.
const BROWSE_LINES := [
	"a railway timetable from 1987, every page soft with thumb oil",
	"a paperback of ghazals, someone's margin notes in green ink",
	"exam-guide arithmetic — 'success is 20 formulas and 80 practice'",
	"a spineless thriller, cover gone, last page missing",
	"a district atlas with the ring roads already drawn wrong",
	"a cook-stained book of mithai recipes, sindoor on the halwai page",
	"secondhand schoolbooks, three grades of pencil prices inside",
]

var _player: Node3D = null
var _audio: Node = null
var _chars := Chars.new()
var _idles: Array[Dictionary] = []
var _kirana := Vector3.ZERO
var _paan := Vector3.ZERO
var _books := Vector3.ZERO
var _shelves: Array[Vector3] = []
var _browse_i := 0
var _inside := false
var _prompt: Label
var _toast: Label
var _toast_tween: Tween


static func build(world: float, pitch: float, road_w: float) -> Node3D:
	## Static dressing from the main menu on (like interiors slice 3):
	## the block math mirrors setup() below so the pair never drifts.
	var cp := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var ps := Vector2(-world / 2.0 + 7.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var pk := Vector2(-world / 2.0 + 8.0 * pitch + road_w / 2.0,
			-world / 2.0 + 2.0 * pitch + road_w / 2.0)
	var kx := cp.x - 13.0
	var kz := cp.y - 12.0
	var px := ps.x + 10.0
	var pz := ps.y - 12.0
	var bx := pk.x - 12.0
	var bz := pk.y + 10.0
	var b := MeshTools.new()
	_kirana_shop(b, kx, kz)
	_paan_shop(b, px, pz)
	_book_shop(b, bx, bz)
	var colliders: Array = [
		# Kirana: back wall, ends, split front with a doorway, counter.
		[Vector3(0.25, 2.8, 3.2), Vector3(kx - 2.05, 0, kz)],
		[Vector3(4.4, 2.8, 0.25), Vector3(kx, 0, kz - 1.65)],
		[Vector3(4.4, 2.8, 0.25), Vector3(kx, 0, kz + 1.65)],
		[Vector3(0.25, 2.2, 0.85), Vector3(kx + 2.05, 0, kz - 0.96)],
		[Vector3(0.25, 2.2, 0.85), Vector3(kx + 2.05, 0, kz + 0.96)],
		[Vector3(0.55, 0.95, 2.6), Vector3(kx - 1.55, 0, kz + 0.1)],
		# Paan shop: smaller room, same doorway pattern.
		[Vector3(0.25, 2.4, 2.8), Vector3(px - 1.45, 0, pz)],
		[Vector3(3.0, 2.4, 0.25), Vector3(px, 0, pz - 1.35)],
		[Vector3(3.0, 2.4, 0.25), Vector3(px, 0, pz + 1.35)],
		[Vector3(0.25, 1.9, 0.55), Vector3(px + 1.45, 0, pz - 0.89)],
		[Vector3(0.25, 1.9, 0.55), Vector3(px + 1.45, 0, pz + 0.89)],
		[Vector3(0.5, 1.0, 2.0), Vector3(px - 1.0, 0, pz)],
		# Bookstore: taller room, two shelf racks plus the desk.
		[Vector3(0.25, 3.0, 3.6), Vector3(bx - 2.05, 0, bz)],
		[Vector3(4.4, 3.0, 0.25), Vector3(bx, 0, bz - 1.75)],
		[Vector3(4.4, 3.0, 0.25), Vector3(bx, 0, bz + 1.75)],
		[Vector3(0.25, 2.3, 0.95), Vector3(bx + 2.05, 0, bz - 0.99)],
		[Vector3(0.25, 2.3, 0.95), Vector3(bx + 2.05, 0, bz + 0.99)],
		[Vector3(0.9, 2.5, 0.6), Vector3(bx - 1.5, 0, bz - 0.65)],
		[Vector3(0.9, 2.5, 0.6), Vector3(bx - 0.35, 0, bz - 0.65)],
		[Vector3(0.6, 0.9, 1.6), Vector3(bx + 1.3, 0, bz - 1.1)],
	]
	var root := Node3D.new()
	root.name = "InteriorsSlice2"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var solid := StaticBody3D.new()
	solid.name = "Slice2Colliders"
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
	return root


static func _shop_room(b: MeshTools, x: float, z: float, hx: float,
		hz: float, wall_h: float, lintel_h: float, wall: Color,
		floor: Color, roof: Color) -> void:
	## One walk-in room on the slice-3 chemist pattern: chamfered wall
	## prisms with a doorway in the +X face under a chamfered lintel,
	## a worn floor slab and a roof plate.
	var y := Roads.CURB_H
	b.add_prism(MeshTools.chamfer_footprint(hx, hz, 0.12),
			Vector3(x, 0.0, z), y, y + 0.04, floor)
	b.add_prism(MeshTools.chamfer_footprint(0.125, hz, 0.08),
			Vector3(x - hx - 0.05, 0.0, z), y, y + wall_h, wall)
	b.add_prism(MeshTools.chamfer_footprint(hx + 0.2, 0.125, 0.08),
			Vector3(x, 0.0, z - hz - 0.05), y, y + wall_h, wall)
	b.add_prism(MeshTools.chamfer_footprint(hx + 0.2, 0.125, 0.08),
			Vector3(x, 0.0, z + hz + 0.05), y, y + wall_h, wall)
	var seg := hz - 0.75
	b.add_prism(MeshTools.chamfer_footprint(0.125, seg * 0.5, 0.08),
			Vector3(x + hx + 0.05, 0.0, z - 0.75 - seg * 0.25), y,
			y + lintel_h, wall)
	b.add_prism(MeshTools.chamfer_footprint(0.125, seg * 0.5, 0.08),
			Vector3(x + hx + 0.05, 0.0, z + 0.75 + seg * 0.25), y,
			y + lintel_h, wall)
	b.add_prism(MeshTools.chamfer_footprint(0.125, 0.8, 0.08),
			Vector3(x + hx + 0.05, 0.0, z), y + lintel_h,
			y + wall_h, wall)
	b.add_prism(MeshTools.chamfer_footprint(hx + 0.3, hz + 0.3, 0.14),
			Vector3(x, 0.0, z), y + wall_h, y + wall_h + 0.14, roof)


static func _kirana_shop(b: MeshTools, x: float, z: float) -> void:
	## Walk-in kirana general store (issue #206): shelf racks of packets
	## and lathe bottles along the back wall, grain sacks by the
	## counter, a beveled counter with glass top and biscuit tins, a
	## blue board over the door and a striped arc awning on poles.
	var y := Roads.CURB_H
	_shop_room(b, x, z, 2.0, 1.6, 2.8, 2.2, KIRANA_WALL,
			KIRANA_FLOOR, KIRANA_ROOF)
	# Two shelf racks on the back wall: chamfered uprights + three
	# beveled ledges each, stacked packet rows between the uprights.
	for r in 2:
		var rx := x - 1.55 + r * 1.1
		for u in [-0.42, 0.42]:
			b.add_bev_box(Vector3(0.1, 2.0, 0.1),
					Vector3(rx + u, y + 1.0, z - 0.85), 0.02, SHELF_WOOD)
		for l in 3:
			b.add_bev_box(Vector3(0.85, 0.06, 0.55),
					Vector3(rx, y + 0.65 + l * 0.62, z - 0.55), 0.02,
					SHELF_WOOD)
			for p in 4:
				b.add_bev_box(Vector3(0.14, 0.34, 0.3),
						Vector3(rx - 0.3 + p * 0.2,
						y + 0.85 + l * 0.62, z - 0.5), 0.01,
						PACKET_COLORS[(r * 4 + p + l) % 5])
	# Lathe bottles on the top ledges — the kirana's tonic shelf.
	var bottle := PackedVector2Array([
		Vector2(0.07, 0.0), Vector2(0.08, 0.10), Vector2(0.07, 0.20),
		Vector2(0.04, 0.25), Vector2(0.03, 0.30),
	])
	for s in 5:
		b.add_lathe(bottle, Vector3(x - 1.55 + (s % 2) * 1.1,
				y + 1.9, z - 0.45 + s * 0.12),
				PACKET_COLORS[s % 5], MeshTools.FINISH_GLOSS, 8)
	# Counter along the north end with a glass top and tin stack.
	b.add_bev_box(Vector3(0.55, 0.95, 2.6), Vector3(x - 1.55, y + 0.475,
			z + 0.1), 0.05, KIRANA_COUNTER)
	b.add_bev_box(Vector3(0.65, 0.08, 2.7), Vector3(x - 1.55, y + 0.99,
			z + 0.1), 0.03, KIRANA_GLASS, 0.0, MeshTools.FINISH_GLOSS)
	for t in 2:
		var tin := CylinderMesh.new()
		tin.top_radius = 0.14
		tin.bottom_radius = 0.14
		tin.height = 0.16
		b.add_mesh(tin, Transform3D(Basis(),
				Vector3(x - 1.5, y + 1.11 + t * 0.17, z + 0.75)),
				BOOK_COLORS[t * 3])
	# Grain sacks: two capsule sacks slumped by the counter end.
	var sack := CapsuleMesh.new()
	sack.radius = 0.3
	sack.height = 0.7
	for s in 2:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 + s * 0.4),
				Vector3(x - 0.9 + s * 0.55, y + 0.28, z - 1.05))
		b.add_mesh(sack, xf, SACK)
	# Blue general-store board over the doorway.
	b.add_bev_box(Vector3(0.12, 0.5, 2.2),
			Vector3(x + 2.08, y + 2.45, z), 0.02, KIRANA_BOARD)
	# Striped arc awning on two cylinder poles at the door.
	for pole_z in [-1.15, 1.15]:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.05
		pm.height = 2.5
		b.add_mesh(pm, Transform3D(Basis(),
				Vector3(x + 2.45, y + 1.25, z + pole_z)), PAAN_COUNTER)
	for s in 3:
		var col := KIRANA_AWN_A if s % 2 == 0 else KIRANA_AWN_B
		b.add_arc_shell(1.3, 0.75, 0.24,
				Vector3(x + 2.2, y + 2.42, z - 0.78 + s * 0.78), col)


static func _paan_shop(b: MeshTools, x: float, z: float) -> void:
	## Walk-in paan shop (issue #206): the thana's corner counter — a
	## glass display of betel trays, a brass paan pot, lime paste jar,
	## the deep green PAAN board and a stool by the door.
	var y := Roads.CURB_H
	_shop_room(b, x, z, 1.4, 1.3, 2.4, 1.9, PAAN_WALL,
			PAAN_FLOOR, PAAN_ROOF)
	# Display counter along the back wall: beveled body, glass top.
	b.add_bev_box(Vector3(0.5, 0.95, 2.0), Vector3(x - 1.0, y + 0.475,
			z), 0.05, PAAN_COUNTER)
	b.add_bev_box(Vector3(0.6, 0.08, 2.1), Vector3(x - 1.0, y + 0.99,
			z), 0.03, PAAN_GLASS, 0.0, MeshTools.FINISH_GLOSS)
	# Betel trays on the glass: flat beveled trays with leaf stacks.
	for t in 3:
		var tz := z - 0.6 + t * 0.6
		b.add_bev_box(Vector3(0.4, 0.03, 0.42),
				Vector3(x - 1.0, y + 1.05, tz), 0.01, LIME)
		for l in 3:
			b.add_bev_box(Vector3(0.3 - l * 0.06, 0.025, 0.32 - l * 0.06),
					Vector3(x - 1.0, y + 1.08 + l * 0.025, tz), 0.008,
					LEAF if l % 2 == 0 else LEAF_DARK)
	# Brass paan pot and lime jar on the counter end.
	var pot := PackedVector2Array([
		Vector2(0.16, 0.0), Vector2(0.22, 0.05), Vector2(0.24, 0.16),
		Vector2(0.20, 0.24), Vector2(0.10, 0.28), Vector2(0.06, 0.30),
	])
	b.add_lathe(pot, Vector3(x - 1.0, y + 1.03, z + 0.85), BRASS,
			MeshTools.FINISH_GLOSS, 10)
	var jar := CylinderMesh.new()
	jar.top_radius = 0.09
	jar.bottom_radius = 0.09
	jar.height = 0.18
	b.add_mesh(jar, Transform3D(Basis(),
			Vector3(x - 0.7, y + 1.1, z + 0.85)), LIME,
			MeshTools.FINISH_GLOSS)
	# Stool by the doorway for the loiterers.
	var stool := CylinderMesh.new()
	stool.top_radius = 0.22
	stool.bottom_radius = 0.18
	stool.height = 0.45
	b.add_mesh(stool, Transform3D(Basis(),
			Vector3(x + 0.85, y + 0.225, z + 0.75)), PAAN_COUNTER)
	# Deep green PAAN board over the roof edge, over the doorway.
	b.add_bev_box(Vector3(0.12, 0.45, 1.9),
			Vector3(x + 1.5, y + 2.62, z), 0.02, PAAN_BOARD)
	b.add_bev_box(Vector3(0.12, 0.18, 0.9),
			Vector3(x + 1.56, y + 2.62, z), 0.02, LIME)


static func _book_shop(b: MeshTools, x: float, z: float) -> void:
	## Walk-in pavement bookstore (issue #206): two tall shelf racks of
	## secondhand spines on the back wall, a seller's desk by the
	## window with a cash box, and a reading bench inside the door.
	var y := Roads.CURB_H
	_shop_room(b, x, z, 2.0, 1.7, 3.0, 2.3, BOOK_WALL,
			BOOK_FLOOR, BOOK_ROOF)
	# Two tall shelf racks: chamfered uprights, four shelves, rows of
	# thin beveled spines in varied heights and colors.
	for r in 2:
		var rx := x - 1.5 + r * 1.15
		for u in [-0.45, 0.45]:
			b.add_bev_box(Vector3(0.1, 2.5, 0.1),
					Vector3(rx + u, y + 1.25, z - 1.0), 0.02, SHELF_WOOD)
		for l in 4:
			b.add_bev_box(Vector3(0.9, 0.06, 0.6),
					Vector3(rx, y + 0.45 + l * 0.6, z - 0.65), 0.02,
					SHELF_WOOD)
			var seed_i := r * 7 + l
			for bk in 5:
				var h := 0.3 + ((seed_i * 5 + bk) % 3) * 0.05
				b.add_bev_box(Vector3(0.12, h, 0.34),
						Vector3(rx - 0.34 + bk * 0.17,
						y + 0.48 + l * 0.6 + h * 0.5, z - 0.6), 0.008,
						BOOK_COLORS[(seed_i + bk) % 7])
	# A leaning stack on the bottom shelf of each rack.
	for r in 2:
		var rx := x - 1.5 + r * 1.15
		for st in 3:
			b.add_bev_box(Vector3(0.34, 0.045, 0.26),
					Vector3(rx, y + 0.075 + st * 0.05, z - 0.95), 0.01,
					BOOK_COLORS[(r * 3 + st) % 7])
	# Seller's desk by the +Z end with a cash box.
	b.add_bev_box(Vector3(0.6, 0.9, 1.6), Vector3(x + 1.3, y + 0.45,
			z - 1.1), 0.05, DESK)
	b.add_bev_box(Vector3(0.3, 0.18, 0.4), Vector3(x + 1.3, y + 0.99,
			z - 1.35), 0.02, BOOK_COLORS[1])
	# Reading bench inside the door.
	b.add_bev_box(Vector3(0.45, 0.1, 1.7), Vector3(x + 1.55, y + 0.45,
			z + 0.9), 0.03, SHELF_WOOD)
	for bz in [-0.7, 0.7]:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.05
		leg.bottom_radius = 0.05
		leg.height = 0.42
		b.add_mesh(leg, Transform3D(Basis(),
				Vector3(x + 1.55, y + 0.21, z + 0.9 + bz)), PAAN_COUNTER)


func setup(world: float, pitch: float, road_w: float, food: Node) -> void:
	## Interior life from the main menu on: the block math mirrors
	## build() above so geometry and cast never drift.
	var cp := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var ps := Vector2(-world / 2.0 + 7.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var pk := Vector2(-world / 2.0 + 8.0 * pitch + road_w / 2.0,
			-world / 2.0 + 2.0 * pitch + road_w / 2.0)
	_kirana = Vector3(cp.x - 13.0, Roads.CURB_H, cp.y - 12.0)
	_paan = Vector3(ps.x + 10.0, Roads.CURB_H, ps.y - 12.0)
	_books = Vector3(pk.x - 12.0, Roads.CURB_H, pk.y + 10.0)
	# The kirana shopkeeper behind his counter, a shopper at the racks.
	_npc(Chars.MALE, 20601, false, 1.72,
			_kirana + Vector3(-1.3, 0.0, 0.1), Vector3(1.0, 0.0, 0.3))
	_npc(Chars.FEMALE_A, 20602, true, 1.58,
			_kirana + Vector3(-0.7, 0.0, -0.5), Vector3(-1.0, 0.0, -0.4))
	# The paan-wala behind his glass, a constable loitering at the door.
	_npc(Chars.MALE, 20603, false, 1.66,
			_paan + Vector3(-1.1, 0.0, 0.35), Vector3(1.0, 0.0, -0.3))
	_npc(Chars.MALE, 20604, false, 1.76,
			_paan + Vector3(0.9, 0.0, 0.8), Vector3(-1.0, 0.0, -0.2))
	# The bookseller at her desk, a browser at the racks.
	_npc(Chars.FEMALE_B, 20605, true, 1.60,
			_books + Vector3(1.3, 0.0, -0.3), Vector3(-1.0, 0.0, -0.8))
	_npc(Chars.MALE, 20606, false, 1.70,
			_books + Vector3(-0.9, 0.0, -0.6), Vector3(0.0, 0.0, 1.0))
	# Counter service through the food system (same Q/R economy).
	if food != null and food.has_method("add_counter"):
		food.add_counter(_kirana + Vector3(-1.0, 0.0, 0.1),
				[WATER, BISCUITS])
		food.add_counter(_paan + Vector3(-0.6, 0.0, 0.0),
				[PAAN, SODA])
	# Browse spots at the two book racks (issue #206 flavor).
	_shelves = [_books + Vector3(-1.5, 0.0, -0.4),
			_books + Vector3(-0.35, 0.0, -0.4)]
	_build_ui()


func paan_shop_position() -> Vector3:
	## The walk-in paan counter joins the [B] bribe network (issue
	## #188): main.gd appends this to _paan_shops, so carrying heat
	## inside the shop offers the same crossed-palms fix as the carts.
	return _paan


func register(p: Node3D, audio: Node) -> void:
	## Live-game nodes: the doorway checks need the walker, the chime
	## needs the audio bus.
	_player = p
	_audio = audio


func _process(_delta: float) -> void:
	## Idle clips loop forever on the interior cast (rigs import the
	## clip without loop flags, so nudge the player when one lands).
	for n in _idles:
		if not n["ap"].is_playing():
			_chars.play(n["anims"], n["ap"], "idle", 0.9)
	if _player == null:
		return
	var p := _player.global_position
	var inside := _at_any_door(p)
	if inside != _inside and _audio != null:
		_inside = inside
		_audio.door_chime()
		# Rain and street beds low-pass behind the shopfront (issue #227).
		if _audio.has_method("set_indoors"):
			_audio.set_indoors(inside)
	_tick_browse(p)


func _at_any_door(p: Vector3) -> bool:
	## Indoors = within any of the three shop doorways (slice-3 zone).
	for shop in [_kirana, _paan, _books]:
		if absf(p.x - shop.x) < DOOR_HALF_X \
				and absf(p.z - shop.z) < DOOR_HALF_Z:
			return true
	return false


func _tick_browse(p: Vector3) -> void:
	## Pavement browsing (issue #206): near a shelf rack, [Q] or [R]
	## pulls the next spine — flavor only, no paisa, no HP.
	if _prompt == null:
		return
	var walker := _player as CharacterBody3D
	if walker != null and not walker.controls_enabled:
		_prompt.visible = false
		return
	var near := false
	for shelf in _shelves:
		if Vector2(p.x - shelf.x, p.z - shelf.z).length() < BROWSE_R:
			near = true
			break
	if not near:
		_prompt.visible = false
		return
	# A running dialogue owns the bottom of the screen (issue #80).
	for d in get_tree().get_nodes_in_group("dialogue"):
		if d.is_running():
			_prompt.visible = false
			return
	_prompt.text = "browse shelves [Q]  ·  next spine [R]  ·  all free to read"
	_prompt.visible = true
	if Input.is_action_just_pressed("buy_chai") \
			or Input.is_action_just_pressed("buy_samosa"):
		_browse_i = (_browse_i + 1) % BROWSE_LINES.size()
		_show_toast(BROWSE_LINES[_browse_i])


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	## Same prompt/toast pattern as the food economy, kept separate so
	## browsing never fights the stall menus for the same label.
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_bottom = -108.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -156.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 19)
	_toast.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _npc(model_path: String, seed: int, female: bool, height: float,
		at: Vector3, face: Vector3) -> void:
	## One rigged idle local — same spawn path as the slice-1/3 interior
	## casts (characters.gd identity + dress), parked facing a spot.
	var id := Chars.identity(seed, female)
	var node := _chars.spawn(model_path, height)
	ShadowBlob.attach(node, 0.48)
	_chars.dress(node, id)
	add_child(node)
	node.position = at
	# In-tree before look_at — Godot rejects it on detached nodes.
	node.look_at(at + face, Vector3.UP)
	var ap := _chars.get_player(node)
	var anims := _chars.anim_names(node)
	_chars.play(anims, ap, "idle", 0.9)
	_idles.append({"ap": ap, "anims": anims})
