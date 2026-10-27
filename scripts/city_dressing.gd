extends RefCounted
## Delhi dressing slice 2 (issue #129): the skyline and street-life
## layer. Research pass (photo/descriptions of Chandni Chowk, Old Delhi
## roofs and CP): near every Indian rooftop carries one or two black
## plastic water tanks on a short slab, walls crowd with AC outdoor
## units and satellite dishes above the shop fronts, calm street cows
## stand at the kerb as incidental road life, and small roadside
## shrines sit on street corners. This slice builds exactly those:
## rooftop tanks + wall ACs/dishes on every generic city block (fed
## from main.gd's building loop), and two respectful incidental cows
## plus one chabutra shrine near the landmarks. Signage (#131),
## vehicles (#125), market clutter (#124), characters (#134) and the
## bazaar bunting (already on the market lane) are untouched.
## All procedural MeshTools geometry; placement deterministic.

const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

## Block-edge kerb line for street-level props (same inset band as the
## slice-1 poles, just at the curb face).
const TANK := Color(0.07, 0.07, 0.07)
const TANK_LID := Color(0.16, 0.16, 0.16)
const SLAB := Color(0.58, 0.56, 0.52)
const AC_BODY := Color(0.90, 0.89, 0.84)
const AC_GRILL := Color(0.55, 0.56, 0.55)
const DISH := Color(0.62, 0.61, 0.58)
const COW := Color(0.91, 0.88, 0.80)
const COW_DARK := Color(0.16, 0.14, 0.12)
const COW_SNOUT := Color(0.74, 0.58, 0.52)
const COW_HORN := Color(0.63, 0.58, 0.50)
const SHRINE_STONE := Color(0.74, 0.70, 0.62)
const SHRINE_WOOD := Color(0.50, 0.35, 0.20)
const SHRINE_RED := Color(0.78, 0.30, 0.14)
const MARIGOLD := Color(0.96, 0.63, 0.08)
const BRASS := Color(0.80, 0.64, 0.26)


# ------------------------------------------------- street-level props

static func build(world: float, pitch: float, road_w: float) -> Node3D:
	## Two incidental cows at landmark kerbs (calm, no interaction —
	## road life, not a target) and one roadside shrine on the Purani
	## Dilli lawn. Deterministic spots, real colliders (issue #77).
	var cc := _block_center(world, pitch, road_w, Vector2i(4, 7))
	var cp := _block_center(world, pitch, road_w, Vector2i(5, 5))
	var pd := _block_center(world, pitch, road_w, Vector2i(3, 7))
	var half := (pitch - road_w) / 2.0
	var cow_xfs: Array[Transform3D] = [
		# Chandni Chowk east kerb, between the stall rows (clear of
		# stalls, carts, chai stall and slice-1 poles by >2.5 m).
		Transform3D(Basis(Vector3.UP, PI / 2.0 + 0.15),
				Vector3(cc.x + half - 2.0, Roads.CURB_H, cc.y - 1.5)),
		# Connaught Place ring, east kerb near the India Gate corner.
		Transform3D(Basis(Vector3.UP, -0.9),
				Vector3(cp.x + half - 2.0, Roads.CURB_H, cp.y - 6.0)),
	]
	var b := MeshTools.new()
	_shrine(b, pd.x - 8.0, pd.y + 6.0)
	var root := Node3D.new()
	root.name = "CityDressing"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_add_prop(root, cow_mesh(), cow_xfs, Vector3(1.9, 1.5, 0.8))
	# Shrine collider matched to its platform footprint.
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 2.2, 1.7)
	shape.shape = box
	shape.position = Vector3(pd.x - 8.0, 1.1, pd.y + 6.0)
	solid.add_child(shape)
	root.add_child(solid)
	return root


static func _block_center(world: float, pitch: float, road_w: float,
		b: Vector2i) -> Vector2:
	## Same block-center convention as delhi_dressing.gd slice 1.
	return Vector2(-world / 2.0 + b.x * pitch + road_w / 2.0,
			-world / 2.0 + b.y * pitch + road_w / 2.0)


static func _add_prop(root: Node3D, mesh: ArrayMesh,
		xfs: Array[Transform3D], coll: Vector3) -> void:
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


# ------------------------------------------------- per-building decor

static func building_decor(center: Vector3, pos: Vector3,
		size: Vector3) -> Dictionary:
	## Deterministic rooftop/wall decor for ONE generic city building:
	## a black water tank (two on tall roofs), an AC outdoor unit and a
	## tilted satellite dish on the street-facing walls. Seeded from the
	## building's own coordinates — never consumes the city RNG, so the
	## existing layout is byte-identical.
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(absf(pos.x)) * 73856093) ^ (int(absf(pos.z)) * 19349663) \
			^ (int(size.y * 10.0) * 83492791)
	var out := {"tanks": [] as Array[Transform3D],
			"acs": [] as Array[Transform3D],
			"dishes": [] as Array[Transform3D]}
	# Rooftop tank(s): the black plastic tanki on a slab.
	if size.y >= 8.0 and rng.randf() < 0.70:
		var tx := pos.x + rng.randf_range(-1.0, 1.0) * (size.x * 0.5 - 0.9)
		var tz := pos.z + rng.randf_range(-1.0, 1.0) * (size.z * 0.5 - 0.9)
		out["tanks"].append(Transform3D(Basis(),
				Vector3(tx, size.y + 0.66, tz)))
		if size.y >= 18.0 and rng.randf() < 0.60:
			var t2x := pos.x + rng.randf_range(-1.0, 1.0) * (size.x * 0.5 - 0.9)
			var t2z := pos.z + rng.randf_range(-1.0, 1.0) * (size.z * 0.5 - 0.9)
			out["tanks"].append(Transform3D(Basis(),
					Vector3(t2x, size.y + 0.66, t2z)))
	# Wall clutter: AC low on the widest-offset face, dish higher on
	# the other axis, so the two never stack.
	var dx := pos.x - center.x
	var dz := pos.z - center.z
	var sx := 1.0 if dx >= 0.0 else -1.0
	var sz := 1.0 if dz >= 0.0 else -1.0
	var on_x := absf(dx) >= absf(dz)
	if size.y >= 8.0 and rng.randf() < 0.75:
		if on_x:
			out["acs"].append(Transform3D(Basis(Vector3.UP, PI / 2.0 * sx),
					Vector3(pos.x + sx * (size.x * 0.5 + 0.20),
							3.3 + rng.randf_range(0.0, 0.8),
							pos.z + rng.randf_range(-0.3, 0.3) * size.z)))
		else:
			out["acs"].append(Transform3D(Basis(Vector3.UP, PI if sz < 0.0 else 0.0),
					Vector3(pos.x + rng.randf_range(-0.3, 0.3) * size.x,
							3.3 + rng.randf_range(0.0, 0.8),
							pos.z + sz * (size.z * 0.5 + 0.20))))
		if size.y >= 16.0 and rng.randf() < 0.5:
			# Second unit one floor up on the same face.
			var xf: Transform3D = out["acs"][0]
			out["acs"].append(Transform3D(xf.basis,
					xf.origin + Vector3(0.0, 3.0, 0.0)))
	if size.y >= 9.0 and rng.randf() < 0.60:
		var dy := clampf(size.y * 0.6, 5.5, 19.0)
		if on_x:
			out["dishes"].append(Transform3D(Basis(Vector3.UP, PI if sz < 0.0 else 0.0),
					Vector3(pos.x + rng.randf_range(-0.3, 0.3) * size.x, dy,
							pos.z + sz * (size.z * 0.5 + 0.24))))
		else:
			out["dishes"].append(Transform3D(Basis(Vector3.UP, PI / 2.0 * sx),
					Vector3(pos.x + sx * (size.x * 0.5 + 0.24), dy,
							pos.z + rng.randf_range(-0.3, 0.3) * size.z)))
	return out


# ------------------------------------------------- prop meshes

static func tank_mesh() -> ArrayMesh:
	## Black plastic rooftop tank: cylinder + screw lid on a gray slab.
	var b := MeshTools.new()
	var tank := CylinderMesh.new()
	tank.top_radius = 0.55
	tank.bottom_radius = 0.58
	tank.height = 1.15
	b.add_mesh(tank, Transform3D(Basis(), Vector3(0, 0.66, 0)), TANK)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.13
	lid.bottom_radius = 0.15
	lid.height = 0.10
	b.add_mesh(lid, Transform3D(Basis(), Vector3(0, 1.28, 0)), TANK_LID)
	b.add_box(Vector3(1.24, 0.08, 1.24), Vector3(0, 0.04, 0), SLAB)
	return b.build_mesh()


static func ac_mesh() -> ArrayMesh:
	## AC outdoor unit: body with a darker protruding grill face. Local
	## front is +Z (the wall mounts local -Z).
	var b := MeshTools.new()
	b.add_box(Vector3(0.62, 0.52, 0.34), Vector3(0, 0, 0), AC_BODY)
	b.add_box(Vector3(0.50, 0.38, 0.06), Vector3(0, -0.02, 0.19), AC_GRILL)
	b.add_box(Vector3(0.58, 0.05, 0.30), Vector3(0, 0.28, 0.0), AC_GRILL)
	return b.build_mesh()


static func dish_mesh() -> ArrayMesh:
	## Tilted satellite dish on a short arm; local aim is up-and-+Z.
	var b := MeshTools.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.26
	disc.bottom_radius = 0.26
	disc.height = 0.05
	b.add_mesh(disc, Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(55.0)),
			Vector3(0, 0.10, 0.03)), DISH)
	b.add_box(Vector3(0.05, 0.22, 0.05), Vector3(0, -0.02, 0.0), DISH)
	return b.build_mesh()


static func cow_mesh() -> ArrayMesh:
	## Calm street cow (zebu): humped white body, four legs, lowered
	## head with horns, ears and a tail tuft. Front is +X. Purely
	## incidental road life — nothing in the game interacts with it.
	var b := MeshTools.new()
	b.add_box(Vector3(1.50, 0.72, 0.60), Vector3(0, 0.98, 0), COW)
	b.add_box(Vector3(0.34, 0.26, 0.42), Vector3(0.42, 1.44, 0), COW)  # hump
	for x in [0.52, -0.52]:
		for z in [0.20, -0.20]:
			b.add_box(Vector3(0.13, 0.62, 0.13), Vector3(x, 0.31, z), COW)
			b.add_box(Vector3(0.14, 0.05, 0.14), Vector3(x, 0.03, z), COW_DARK)
	b.add_box(Vector3(0.34, 0.34, 0.30), Vector3(0.72, 1.22, 0), COW)  # neck
	var head := BoxMesh.new()
	head.size = Vector3(0.42, 0.40, 0.30)
	b.add_mesh(head, Transform3D(Basis(Vector3(0, 0, 1), 0.28),
			Vector3(0.94, 1.24, 0)), COW)
	b.add_box(Vector3(0.20, 0.22, 0.26), Vector3(1.10, 1.06, 0), COW_SNOUT)
	for z in [0.22, -0.22]:
		b.add_box(Vector3(0.07, 0.13, 0.20), Vector3(0.80, 1.40, z), COW)
	for z in [0.13, -0.13]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.025
		horn.bottom_radius = 0.035
		horn.height = 0.24
		b.add_mesh(horn, Transform3D(
				Basis(Vector3(0, 0, 1), -0.5) * Basis(Vector3.UP, 0.35 * signf(z)),
				Vector3(0.82, 1.56, z)), COW_HORN)
	b.add_box(Vector3(0.07, 0.55, 0.07), Vector3(-0.78, 1.02, 0), COW)
	b.add_box(Vector3(0.10, 0.14, 0.10), Vector3(-0.78, 0.72, 0), COW_DARK)
	return b.build_mesh()


static func _shrine(b: MeshTools, x: float, z: float) -> void:
	## Roadside chabutra shrine: stone platform + step, small red
	## niche with a warm figure, saffron canopy on two posts, marigold
	## garland row and a hanging brass bell. Respectful, decorative.
	b.add_box(Vector3(1.5, 0.22, 1.5), Vector3(x, 0.21, z), SHRINE_STONE)
	b.add_box(Vector3(0.8, 0.12, 0.5), Vector3(x, 0.16, z + 1.0), SHRINE_STONE)
	b.add_box(Vector3(0.55, 0.65, 0.16), Vector3(x, 0.64, z - 0.60), SHRINE_RED)
	b.add_box(Vector3(0.18, 0.28, 0.08), Vector3(x, 0.64, z - 0.50),
			Color(0.96, 0.78, 0.34))
	for sx in [-0.55, 0.55]:
		b.add_box(Vector3(0.08, 1.30, 0.08),
				Vector3(x + sx, 0.97, z - 0.50), SHRINE_WOOD)
	for side in [-1, 1]:
		var roof := BoxMesh.new()
		roof.size = Vector3(1.15, 0.05, 0.62)
		b.add_mesh(roof, Transform3D(Basis(Vector3(1, 0, 0), 0.42 * side),
				Vector3(x, 1.76, z - 0.14 - 0.22 * side)), SHRINE_RED)
	for i in 5:
		b.add_box(Vector3(0.06, 0.06, 0.06),
				Vector3(x - 0.30 + 0.15 * i, 1.02, z - 0.38), MARIGOLD)
	var bell := CylinderMesh.new()
	bell.top_radius = 0.05
	bell.bottom_radius = 0.03
	bell.height = 0.09
	b.add_mesh(bell, Transform3D(Basis(), Vector3(x, 1.32, z + 0.30)), BRASS)
