extends RefCounted
## World object richness (issue #124): the density pass that makes the
## streets read busy and lived-in instead of sparse. Four layers, all
## procedural MeshTools geometry, all placement fixed offsets —
## deterministic every launch:
##   - Market stall dressing (Chandni Chowk): produce pyramids on the
##     crate tops, woven leafy baskets at the counter ends, garlands of
##     chilies and onions hanging from the awning fronts, jute spice
##     sacks stacked at the stall corners.
##   - Shop signage variety: neon tube strips (emissive) over the bazaar
##     and Purani Dilli shop rows, plus small perpendicular hanging
##     shop boards on bracket arms — the boards of #131 stay.
##   - Street clutter: parked scooters and bicycles leaning on walls,
##     crate stacks at kerbs, chai glass trays on stools (bazaar lane,
##     CP colonnade gaps, Purani Dilli strip).
##   - Material variation on repeated props: scooters, bicycles, crates
##     and sacks draw as 2-3 color variants each (separate meshes, no
##     per-instance tinting needed).
## Nothing at street level is walk-through (slice-1 rule): every
## repeated prop carries its own collider box. Placement keeps clear of
## the bunting poles (±6.0 m), thela carts, chai stall, cows, shrine,
## dhaba, halwai front and the CP cart spots.

const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

const WOOD := Color(0.55, 0.40, 0.26)
const WOOD_DARK := Color(0.42, 0.30, 0.19)
const WOOD_PALE := Color(0.68, 0.53, 0.34)
const JUTE := Color(0.72, 0.60, 0.40)
const JUTE_DARK := Color(0.60, 0.48, 0.30)
const TURMERIC := Color(0.92, 0.62, 0.10)
const CHILI := Color(0.75, 0.16, 0.10)
const GREEN_LEAF := Color(0.22, 0.55, 0.20)
const ONION_SKIN := Color(0.88, 0.62, 0.72)
const ONION_PALE := Color(0.93, 0.88, 0.82)
const CHILI_GREEN := Color(0.18, 0.45, 0.16)
const RATTAN := Color(0.78, 0.64, 0.40)
const STEEL := Color(0.72, 0.74, 0.76)
const BRASS := Color(0.80, 0.64, 0.26)
const GLASS_BROWN := Color(0.80, 0.55, 0.30)
const TIRE := Color(0.10, 0.10, 0.10)
const SEAT_BLACK := Color(0.13, 0.13, 0.14)
const BACKBOARD := Color(0.10, 0.10, 0.11)
const SCOOTER_REDC := Color(0.78, 0.14, 0.12)
const SCOOTER_BLACK := Color(0.16, 0.17, 0.19)
const SCOOTER_BLUE := Color(0.14, 0.30, 0.62)
const SCOOTER_CREAM := Color(0.90, 0.86, 0.78)
const BIKE_RED := Color(0.70, 0.16, 0.12)
const BIKE_BLUE := Color(0.16, 0.32, 0.58)

const FRUIT := [
	Color(0.95, 0.55, 0.10), Color(0.25, 0.65, 0.25),
	Color(0.90, 0.20, 0.20), Color(0.95, 0.85, 0.30),
]

## Neon tube colors (emissive twins built per color).
const NEON := [
	Color(0.98, 0.16, 0.14), Color(0.16, 0.90, 0.28),
	Color(1.00, 0.68, 0.16), Color(0.20, 0.55, 1.00),
]


static func build(world: float, pitch: float, road_w: float) -> Node3D:
	var cc := _block_center(world, pitch, road_w, Vector2i(4, 7))  # Chandni Chowk
	var cp := _block_center(world, pitch, road_w, Vector2i(5, 5))  # Connaught Place
	var pd := _block_center(world, pitch, road_w, Vector2i(3, 7))  # Purani Dilli
	var street: float = cc.x + 6.0
	var cz: float = cc.y

	var root := Node3D.new()
	root.name = "WorldClutter"

	# -- one-off merged mesh: stall dressing + signs ---------------
	var b := MeshTools.new()
	var stall_x := [street - 9.0, street + 9.0]
	var zeds := [cz - 12.0, cz - 6.5, cz + 14.5]
	for side in 2:
		for i in 3:
			_dress_stall(b, Vector3(stall_x[side], 0, zeds[i]),
					1.0 if side == 0 else -1.0, side * 3 + i)
	_signage_variety(b, cc, pd)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.add_child(_neon_node(cc, pd))

	# -- repeated props: multimesh + collider per instance ----------
	var scoots: Array[Transform3D] = [
		# Bazaar lane edge, between bunting poles and carts.
		_scoot_xf(street - 5.8, cz - 7.8, PI / 2.0 + 0.08),
		_scoot_xf(street - 5.6, cz - 0.2, PI / 2.0 - 0.05),
		_scoot_xf(street + 5.4, cz - 8.8, -PI / 2.0 + 0.1),
		# CP colonnade gaps (angle 22.5 deg + 45k, radius 13.4).
		_gap_xf(cp, 0, 0.0), _gap_xf(cp, 2, -0.8),
		# Purani Dilli shop strip, facing the wall.
		_scoot_xf(pd.x + 5.5, pd.y - 15.3, PI + 0.12),
	]
	var bikes: Array[Transform3D] = [
		# Bazaar: against the west shop wall near the gate, and the
		# south shop row wall.
		Transform3D(Basis(Vector3.UP, 0.10), Vector3(street - 11.3, 0.10, cz - 13.2)),
		Transform3D(Basis(Vector3.UP, -PI / 2.0 + 0.08),
				Vector3(street - 6.15, 0.10, cz + 14.6)),
		# CP colonnade gap (202.5 deg) and Purani Dilli west corner.
		_gap_xf(cp, 4, 0.0), Transform3D(Basis(Vector3.UP, 0.06),
				Vector3(pd.x - 11.4, Roads.CURB_H, pd.y - 15.1)),
	]
	var crates: Array[Transform3D] = [
		# Stall ends on the bazaar lane.
		Transform3D(Basis(Vector3.UP, 0.2), Vector3(street - 9.0, 0.10, cz - 3.6)),
		Transform3D(Basis(Vector3.UP, -0.15), Vector3(street + 10.1, 0.10, cz - 15.8)),
		# CP colonnade gap (292.5 deg) + Purani Dilli near the dhaba.
		_gap_xf(cp, 6, 0.0), Transform3D(Basis(Vector3.UP, 0.3),
				Vector3(pd.x + 13.0, Roads.CURB_H, pd.y - 15.4)),
	]
	var sacks: Array[Transform3D] = [
		# Spice sacks at the stall counters' lane-side corners.
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(street - 7.2, 0.10, cz - 10.6)),
		Transform3D(Basis(Vector3.UP, 0.4), Vector3(street + 7.0, 0.10, cz - 7.5)),
		Transform3D(Basis(Vector3.UP, -0.3), Vector3(street - 6.7, 0.10, cz + 11.5)),
	]
	var trays: Array[Transform3D] = [
		# Chai point beside the bazaar chai stall + CP gap tray.
		Transform3D(Basis(Vector3.UP, -0.6), Vector3(street + 2.0, 0.10, cz + 5.5)),
		_gap_xf(cp, 0, 1.2),
	]

	_prop(root, _scooter_mesh(SCOOTER_REDC), [scoots[0], scoots[4], scoots[5]],
			Vector3(0.7, 1.1, 1.5))
	_prop(root, _scooter_mesh(SCOOTER_BLACK), [scoots[1]],
			Vector3(0.7, 1.1, 1.5))
	_prop(root, _scooter_mesh(SCOOTER_BLUE), [scoots[3]],
			Vector3(0.7, 1.1, 1.5))
	_prop(root, _bicycle_mesh(BIKE_RED), [bikes[0], bikes[2]],
			Vector3(1.7, 1.2, 0.6))
	_prop(root, _bicycle_mesh(BIKE_BLUE), [bikes[1], bikes[3]],
			Vector3(1.7, 1.2, 0.6))
	_prop(root, _crate_mesh(WOOD), [crates[0], crates[3]],
			Vector3(0.8, 1.0, 0.8))
	_prop(root, _crate_mesh(WOOD_DARK), [crates[1]],
			Vector3(0.8, 1.0, 0.8))
	_prop(root, _crate_mesh(WOOD_PALE), [crates[2]],
			Vector3(0.8, 1.0, 0.8))
	_prop(root, _sack_mesh(JUTE), [sacks[0], sacks[2]],
			Vector3(1.3, 0.9, 1.0))
	_prop(root, _sack_mesh(JUTE_DARK), [sacks[1]],
			Vector3(1.3, 0.9, 1.0))
	_prop(root, _tray_mesh(), trays, Vector3(0.7, 1.0, 0.7))
	return root


# ------------------------------------------------------------ one-off mesh

static func _dress_stall(b: MeshTools, pos: Vector3, face: float,
		idx: int) -> void:
	## Riches on ONE bazaar stall: fruit pyramids on the crate tops, a
	## woven leafy basket at each counter end, a greens heap, and two
	## garlands hanging from the awning front edge. Reads from the lane
	## as stacked produce at eye height.
	for g in 2:
		var top := pos + Vector3(0, 3.25, 1.0 if g == 0 else -1.0)
		_pyramid(b, top, FRUIT[(idx + g) % 4])
	# Baskets + greens on the counter, clear of the crates (z ±1.0).
	for s in [-1.9, 1.9]:
		var bk := CylinderMesh.new()
		bk.top_radius = 0.28
		bk.bottom_radius = 0.22
		bk.height = 0.22
		b.add_mesh(bk, Transform3D(Basis(), pos + Vector3(0, 2.31, s)), RATTAN)
		b.add_box(Vector3(0.46, 0.20, 0.36),
				pos + Vector3(0, 2.44, s), GREEN_LEAF)
	# Garland strands from the awning underside (y 5.46) — chilies on
	# the north corner, onions on the south.
	var ax: float = pos.x + 0.6 * face + 1.35 * face
	_strand(b, Vector3(ax, 0, pos.z - 1.9), CHILI, CHILI_GREEN)
	_strand(b, Vector3(ax, 0, pos.z + 1.9), ONION_SKIN, ONION_PALE)


static func _pyramid(b: MeshTools, base: Vector3, color: Color) -> void:
	## 3+2+1 sphere pile (r 0.15) sitting on a crate top.
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.30
	sm.radial_segments = 8
	sm.rings = 4
	var offs := [
		Vector3(-0.17, 0, 0.03), Vector3(0.17, 0, -0.02), Vector3(0.0, 0, -0.18),
		Vector3(0.0, 0, 0.18),
		Vector3(-0.09, 0.14, 0.0), Vector3(0.10, 0.14, 0.02),
		Vector3(0.0, 0.28, 0.0),
	]
	for o in offs:
		b.add_mesh(sm, Transform3D(Basis(), base + o + Vector3(0, 0.14, 0)),
				color)


static func _strand(b: MeshTools, at: Vector3, a: Color, c: Color) -> void:
	## Hanging garland: 7 knots from the awning underside down to ~4.6.
	for k in 7:
		b.add_box(Vector3(0.11, 0.12, 0.11),
				Vector3(at.x, 5.40 - 0.16 * k, at.z), a if k % 2 == 0 else c)


static func _signage_variety(b: MeshTools, cc: Vector2, pd: Vector2) -> void:
	## Neon backboards + brackets (tubes are separate emissive meshes)
	## and small perpendicular hanging boards. Board faces stay clear of
	## the #131 painted boards (offset in z / y).
	var street: float = cc.x + 6.0
	# Bazaar west shop row (face +X): neon housings between the boards.
	for nz in [cc.y - 9.0, cc.y - 3.5, cc.y + 1.5]:
		b.add_box(Vector3(0.10, 0.42, 1.7), Vector3(street - 11.95, 5.10, nz),
				BACKBOARD)
	# Bazaar south shop row (face +X, lower parapet).
	b.add_box(Vector3(0.10, 0.40, 1.5), Vector3(street - 6.95, 4.85, cc.y + 14.9),
			BACKBOARD)
	# Purani Dilli shop strip (face -Z), between the painted boards.
	for nx in [pd.x + 4.0, pd.x - 4.0]:
		b.add_box(Vector3(1.7, 0.42, 0.10), Vector3(nx, 5.20, pd.y - 16.62),
				BACKBOARD)
	# Perpendicular hanging boards on bracket arms: the arm anchors on
	# the wall face and the board hangs at its tip. Local +Z is "out
	# from the wall" once yawed (bazaar walls face +X, PD faces -Z).
	for hb: Dictionary in [
		{"p": Vector3(street - 12.0, 3.55, cc.y - 10.5), "yaw": PI / 2.0, "out": 1.0},
		{"p": Vector3(street - 12.0, 3.55, cc.y - 5.0), "yaw": PI / 2.0, "out": 1.0},
		{"p": Vector3(street - 7.0, 3.30, cc.y + 14.9), "yaw": PI / 2.0, "out": 1.0},
		{"p": Vector3(pd.x - 5.0, 3.45, pd.y - 17.0), "yaw": 0.0, "out": -1.0},
	]:
		var xf := Transform3D(Basis(Vector3.UP, hb["yaw"]), hb["p"])
		var o: float = hb["out"]
		var arm := BoxMesh.new()
		arm.size = Vector3(0.05, 0.05, 0.95)
		b.add_mesh(arm, xf * Transform3D(Basis(),
				Vector3(0, 0.24, o * 0.21)), STEEL)
		var board := BoxMesh.new()
		board.size = Vector3(0.06, 0.55, 0.95)
		b.add_mesh(board, xf * Transform3D(Basis(),
				Vector3(0, 0, o * 0.42)), Color(0.88, 0.72, 0.18))
		var face := BoxMesh.new()
		face.size = Vector3(0.05, 0.42, 0.72)
		b.add_mesh(face, xf * Transform3D(Basis(),
				Vector3(o * 0.045, 0.02, o * 0.42)), Color(0.15, 0.12, 0.10))


static func _neon_node(cc: Vector2, pd: Vector2) -> Node3D:
	## The emissive neon tubes — one merged mesh + material per color,
	## glowing day and night (energy 1.1). Sits in front of the
	## backboards built above.
	var street: float = cc.x + 6.0
	var sites := [
		{"c": 0, "p": Vector3(street - 11.88, 5.10, cc.y - 9.0), "yaw": 0.0},
		{"c": 1, "p": Vector3(street - 11.88, 5.10, cc.y - 3.5), "yaw": 0.0},
		{"c": 2, "p": Vector3(street - 11.88, 5.10, cc.y + 1.5), "yaw": 0.0},
		{"c": 3, "p": Vector3(street - 6.88, 4.85, cc.y + 14.9), "yaw": 0.0},
		{"c": 0, "p": Vector3(pd.x + 4.0, 5.20, pd.y - 16.72), "yaw": PI / 2.0},
		{"c": 1, "p": Vector3(pd.x - 4.0, 5.20, pd.y - 16.72), "yaw": PI / 2.0},
	]
	var root := Node3D.new()
	root.name = "NeonSigns"
	for col in NEON.size():
		var b := MeshTools.new()
		var any := false
		for s: Dictionary in sites:
			if s["c"] != col:
				continue
			any = true
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, s["yaw"]), s["p"])
			var tube := BoxMesh.new()
			tube.size = Vector3(0.07, 0.07, 1.5)
			for v_off in [-0.28, 0.28]:
				b.add_mesh(tube, xf * Transform3D(Basis(),
						Vector3(0, v_off, 0)), Color.WHITE)
		if not any:
			continue
		var mesh := b.build_mesh()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = NEON[col]
		mat.emission_enabled = true
		mat.emission = NEON[col]
		mat.emission_energy_multiplier = 1.1
		mat.roughness = 0.4
		for surf in mesh.get_surface_count():
			mesh.surface_set_material(surf, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


# ------------------------------------------------------------ prop meshes

static func _scooter_mesh(tank: Color) -> ArrayMesh:
	## Parked scooter: floorboards, front shield, seat, handlebar,
	## wheels, mirrors. Lean comes from the placement transform.
	var b := MeshTools.new()
	b.add_box(Vector3(0.24, 0.10, 1.05), Vector3(0, 0.34, -0.05), SEAT_BLACK)
	b.add_box(Vector3(0.30, 0.55, 0.10), Vector3(0, 0.62, 0.48), tank)
	b.add_box(Vector3(0.34, 0.22, 0.55), Vector3(0, 0.50, -0.28), tank)
	b.add_box(Vector3(0.30, 0.10, 0.42), Vector3(0, 0.78, -0.30), SEAT_BLACK)
	b.add_box(Vector3(0.62, 0.05, 0.05), Vector3(0, 1.00, 0.50), SEAT_BLACK)
	b.add_box(Vector3(0.07, 0.34, 0.07), Vector3(0, 0.83, 0.52), tank)
	for m in [-0.24, 0.24]:
		b.add_box(Vector3(0.04, 0.16, 0.04), Vector3(m, 1.10, 0.46), STEEL)
		b.add_box(Vector3(0.10, 0.07, 0.03), Vector3(m, 1.17, 0.46), STEEL)
	for z in [0.52, -0.62]:
		var w := CylinderMesh.new()
		w.top_radius = 0.20
		w.bottom_radius = 0.20
		w.height = 0.10
		b.add_mesh(w, Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0),
				Vector3(0, 0.20, z)), TIRE)
		b.add_box(Vector3(0.03, 0.34, 0.03), Vector3(0.08 if z > 0 else -0.05,
				0.20, z), STEEL)
	return b.build_mesh()


static func _bicycle_mesh(frame: Color) -> ArrayMesh:
	## Leaning bicycle: two wheels, diamond frame, bars, saddle,
	## rack + fenders. Local +Z runs along the bike.
	var b := MeshTools.new()
	for z in [0.48, -0.48]:
		var w := CylinderMesh.new()
		w.top_radius = 0.33
		w.bottom_radius = 0.33
		w.height = 0.05
		b.add_mesh(w, Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0),
				Vector3(0, 0.33, z)), TIRE)
		b.add_box(Vector3(0.03, 0.66, 0.03), Vector3(0, 0.33, z), STEEL)
	b.add_box(Vector3(0.05, 0.02, 0.72), Vector3(0, 0.68, 0.12), frame)
	b.add_box(Vector3(0.05, 0.46, 0.02), Vector3(0, 0.56, 0.36), frame)
	b.add_box(Vector3(0.05, 0.40, 0.02), Vector3(0, 0.54, -0.34), frame)
	b.add_box(Vector3(0.05, 0.36, 0.02), Vector3(0, 0.50, 0.05), frame)
	b.add_box(Vector3(0.05, 0.05, 0.42), Vector3(0, 0.96, 0.40), STEEL)
	b.add_box(Vector3(0.56, 0.04, 0.04), Vector3(0, 0.98, 0.42), STEEL)
	b.add_box(Vector3(0.24, 0.07, 0.30), Vector3(0, 0.92, -0.28), SEAT_BLACK)
	b.add_box(Vector3(0.30, 0.04, 0.44), Vector3(0, 0.86, -0.42), frame)
	return b.build_mesh()


static func _crate_mesh(wood: Color) -> ArrayMesh:
	## Three stacked crates, the top one loaded with produce.
	var b := MeshTools.new()
	var rot := [0.14, -0.18, 0.06]
	for i in 3:
		var xf := Transform3D(Basis(Vector3.UP, rot[i]),
				Vector3(0.04 * i, 0.29 + 0.30 * i, -0.03 * i))
		var box := BoxMesh.new()
		box.size = Vector3(0.60, 0.30, 0.60)
		b.add_mesh(box, xf * Transform3D(Basis(), Vector3(0, 0, 0)),
				wood if i != 1 else WOOD_DARK)
		var lid := BoxMesh.new()
		lid.size = Vector3(0.64, 0.05, 0.64)
		b.add_mesh(lid, xf * Transform3D(Basis(),
				Vector3(0, 0.16, 0)), wood)
	b.add_box(Vector3(0.42, 0.16, 0.42), Vector3(0.02, 1.03, -0.03),
			FRUIT[0])
	b.add_box(Vector3(0.34, 0.14, 0.34), Vector3(-0.04, 1.15, 0.02), FRUIT[2])
	return b.build_mesh()


static func _sack_mesh(jute: Color) -> ArrayMesh:
	## Cluster of three jute spice sacks, tops pinched and dusted with
	## turmeric / chili powder.
	var b := MeshTools.new()
	var spots := [
		[Vector3(-0.38, 0, -0.22), 0.18, TURMERIC],
		[Vector3(0.36, 0, -0.10), -0.22, CHILI],
		[Vector3(-0.02, 0, 0.34), 0.05, TURMERIC],
	]
	for s: Array in spots:
		var xf := Transform3D(Basis(Vector3.UP, s[1]), s[0])
		var body := BoxMesh.new()
		body.size = Vector3(0.50, 0.62, 0.38)
		b.add_mesh(body, xf * Transform3D(Basis(),
				Vector3(0, 0.31, 0)), jute)
		var pinch := BoxMesh.new()
		pinch.size = Vector3(0.30, 0.14, 0.24)
		b.add_mesh(pinch, xf * Transform3D(Basis(),
				Vector3(0, 0.68, 0)), jute)
		var dust := BoxMesh.new()
		dust.size = Vector3(0.34, 0.06, 0.28)
		b.add_mesh(dust, xf * Transform3D(Basis(),
				Vector3(0, 0.74, 0)), s[2])
	return b.build_mesh()


static func _tray_mesh() -> ArrayMesh:
	## Chai point: wooden stool, steel tray, six glasses, thermos.
	var b := MeshTools.new()
	for lx in [-0.16, 0.16]:
		for lz in [-0.16, 0.16]:
			b.add_box(Vector3(0.07, 0.42, 0.07), Vector3(lx, 0.21, lz), WOOD)
	var tr := CylinderMesh.new()
	tr.top_radius = 0.34
	tr.bottom_radius = 0.30
	tr.height = 0.05
	b.add_mesh(tr, Transform3D(Basis(), Vector3(0, 0.45, 0)), STEEL)
	var glass := CylinderMesh.new()
	glass.top_radius = 0.045
	glass.bottom_radius = 0.035
	glass.height = 0.09
	var g := 0
	for gx in [-0.16, 0.0, 0.16]:
		for gz in [-0.12, 0.12]:
			b.add_mesh(glass, Transform3D(Basis(),
					Vector3(gx, 0.52, gz)), GLASS_BROWN)
			g += 1
	b.add_box(Vector3(0.13, 0.30, 0.13), Vector3(0.24, 0.62, 0.18), BRASS)
	return b.build_mesh()


# ------------------------------------------------------------ placement

static func _scoot_xf(x: float, z: float, yaw: float) -> Transform3D:
	## Scooter transform with the parked-on-stand lean (6 deg roll).
	return Transform3D(Basis(Vector3.UP, yaw)
			* Basis(Vector3(0, 0, 1), deg_to_rad(6.0)), Vector3(x, 0.10, z))


static func _gap_xf(cp: Vector2, k: int, slide: float) -> Transform3D:
	## A spot in a CP colonnade gap: angle 22.5 deg + 45k, radius 15.8 —
	## the clear band between the colonnade and the block edge, well off
	## the mid-side road furniture. `slide` nudges along the gap chord
	## (kept within the ~3.3 m gap between neighbouring footprints).
	var ang := deg_to_rad(22.5 + 45.0 * k)
	var dir := Vector2(cos(ang), sin(ang))
	var p := cp + dir * 15.8 + dir.orthogonal() * slide
	return Transform3D(Basis(Vector3.UP, ang + PI / 2.0),
			Vector3(p.x, Roads.CURB_H, p.y))


static func _prop(root: Node3D, mesh: ArrayMesh, xfs: Array[Transform3D],
		coll: Vector3) -> void:
	## MultiMesh draw plus one collider box per instance (slice-1 rule:
	## nothing at street level is walk-through).
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


static func _block_center(world: float, pitch: float, road_w: float,
		b: Vector2i) -> Vector2:
	## Same block-center convention as the other dressing layers.
	return Vector2(-world / 2.0 + b.x * pitch + road_w / 2.0,
			-world / 2.0 + b.y * pitch + road_w / 2.0)
