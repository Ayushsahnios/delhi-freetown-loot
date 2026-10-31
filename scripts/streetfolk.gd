extends RefCounted
## Street-folk silhouettes (issue #222): the age-and-trade variety the
## crowd was missing — elders get a cane, chowkidars patrol with a
## lathi, ragpickers carry a jute sack over one shoulder, and
## sabzi-walas push a painted thela cart stacked with produce. All
## procedural primitives attached holder-fixed in world units off the
## body's rendered height (the characters.gd _wardrobe pattern), so
## every rig wears them alike. The cart merges into one beveled
## Meshtools mesh (de-box directive); handheld props stay low-poly
## cylinders and capsules. No flat-face boxes anywhere.

const Meshtools := preload("res://scripts/meshtools.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")

## Palette: matte street hues, no assets.
const CANE_WOOD := Color(0.52, 0.40, 0.25)
const BAMBOO := Color(0.66, 0.56, 0.34)
const WOOD := Color(0.44, 0.34, 0.22)
const JUTE := Color(0.58, 0.50, 0.38)
const JUTE_DARK := Color(0.46, 0.39, 0.29)
const CART_TEAL := Color(0.18, 0.42, 0.36)
const CART_TEAL_DARK := Color(0.13, 0.31, 0.27)
const RUBBER := Color(0.15, 0.15, 0.16)
const CRATE := Color(0.55, 0.45, 0.32)
const LEAFY_A := Color(0.28, 0.42, 0.20)
const LEAFY_B := Color(0.36, 0.50, 0.24)
const TOMATO := Color(0.72, 0.22, 0.15)
const ORANGE := Color(0.82, 0.50, 0.16)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


static func _part(parent: Node3D, mesh: PrimitiveMesh, c: Color,
		xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.transform = xf
	parent.add_child(mi)


static func _cyl(r: float, h: float, seg := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	return m


static func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


## Elder's walking cane: a thin wooden shaft with a knob head,
## reaching the ground at the right side.
static func cane(holder: Node3D, h: float) -> void:
	var gear := Node3D.new()
	holder.add_child(gear)
	var tilt := Basis(Vector3(0.0, 0.0, 1.0), 0.10)
	_part(gear, _cyl(0.016 * h, 0.52 * h), CANE_WOOD,
			Transform3D(tilt, Vector3(0.21 * h, 0.27 * h, 0.02)))
	_part(gear, _sph(0.026 * h), CANE_WOOD,
			Transform3D(Basis(), Vector3(0.245 * h, 0.545 * h, 0.02)))


## Chowkidar's lathi: a tall bamboo staff carried upright at the side.
static func lathi(holder: Node3D, h: float) -> void:
	var gear := Node3D.new()
	holder.add_child(gear)
	var tilt := Basis(Vector3(0.0, 0.0, 1.0), -0.06)
	_part(gear, _cyl(0.015 * h, 0.88 * h), BAMBOO,
			Transform3D(tilt, Vector3(0.24 * h, 0.44 * h, 0.0)))
	_part(gear, _cyl(0.019 * h, 0.05 * h), BAMBOO,
			Transform3D(tilt, Vector3(0.225 * h, 0.87 * h, 0.0)))


## Ragpicker's load: one big jute sack slung across the shoulders plus
## a small bundle riding the other side — the picking silhouette.
static func sack(holder: Node3D, h: float) -> void:
	var gear := Node3D.new()
	holder.add_child(gear)
	var flat := Basis(Vector3(0.0, 0.0, 1.0), PI / 2.0)
	var big := CapsuleMesh.new()
	big.radius = 0.085 * h
	big.height = 0.47 * h
	_part(gear, big, JUTE, Transform3D(flat, Vector3(0.06 * h, 0.83 * h, 0.01)))
	var small := CapsuleMesh.new()
	small.radius = 0.055 * h
	small.height = 0.27 * h
	_part(gear, small, JUTE_DARK, Transform3D(
			flat * Basis(Vector3(1.0, 0.0, 0.0), -0.25),
			Vector3(-0.17 * h, 0.86 * h, -0.02)))


## Sabzi-wala's thela: a painted two-wheel hand cart pushed ahead of
## the vendor — chamfered bed with rails and boards, rubber wheels on
## an axle, prop legs, handlebars raked back to the hands, and a
## stacked produce load (greens, tomatoes, oranges, plus standing
## bundles at the headboard). One merged mesh (~1.3k tris); soft
## contact shadow so the bed does not float.
static func cart(holder: Node3D, h: float) -> void:
	var u := h
	var mt := Meshtools.new()
	# Bed: chamfered box (de-box vocabulary).
	mt.add_bev_box(Vector3(0.62 * u, 0.07 * u, 1.00 * u),
			Vector3(0.0, 0.40 * u, -0.70 * u), 0.02 * u, CART_TEAL)
	# Side rails + head/tail boards keep the load aboard.
	for sx in [-1.0, 1.0]:
		mt.add_bev_box(Vector3(0.035 * u, 0.10 * u, 1.00 * u),
				Vector3(sx * 0.31 * u, 0.46 * u, -0.70 * u), 0.012 * u,
				CART_TEAL_DARK)
	for ez in [-1.0, 1.0]:
		mt.add_bev_box(Vector3(0.62 * u, 0.10 * u, 0.035 * u),
				Vector3(0.0, 0.46 * u, -0.70 * u + ez * 0.50 * u), 0.012 * u,
				CART_TEAL_DARK)
	# Axle + rubber wheels (12-gon cylinders read round at street range).
	var spin := Basis(Vector3(0.0, 0.0, 1.0), PI / 2.0)
	mt.add_mesh(_cyl(0.02 * u, 0.80 * u), Transform3D(spin,
			Vector3(0.0, 0.28 * u, -0.92 * u)), WOOD)
	for sx in [-1.0, 1.0]:
		mt.add_mesh(_cyl(0.28 * u, 0.05 * u, 12), Transform3D(spin,
				Vector3(sx * 0.40 * u, 0.28 * u, -0.92 * u)), RUBBER)
	# Prop legs + handlebars raked back up to the vendor's hands.
	for sx in [-1.0, 1.0]:
		mt.add_mesh(_cyl(0.014 * u, 0.34 * u), Transform3D(Basis(),
				Vector3(sx * 0.16 * u, 0.17 * u, -0.34 * u)), WOOD)
		mt.add_mesh(_cyl(0.018 * u, 0.44 * u), Transform3D(
				Basis(Vector3(1.0, 0.0, 0.0), -0.21),
				Vector3(sx * 0.20 * u, 0.47 * u, -0.16 * u)), WOOD)
	# Produce trays: two low chamfered crates on the bed.
	for cx in [-1.0, 1.0]:
		mt.add_bev_box(Vector3(0.26 * u, 0.09 * u, 0.42 * u),
				Vector3(cx * 0.14 * u, 0.48 * u, -0.66 * u), 0.015 * u, CRATE)
	# Produce mounds: leafy greens up front, tomatoes and oranges behind.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 8:
		var row := i / 4
		var col := i % 4
		var c: Color = LEAFY_A if i % 2 == 0 else LEAFY_B
		if i >= 4 and i < 6:
			c = TOMATO
		elif i >= 6:
			c = ORANGE
		mt.add_mesh(_sph(0.075 * u), Transform3D(Basis(),
				Vector3(-0.15 * u + col * 0.10 * u
						+ rng.randf_range(-0.02, 0.02) * u,
						0.57 * u + (0.055 * u if row == 1 else 0.0),
						-0.78 * u + row * 0.26 * u
						+ rng.randf_range(-0.03, 0.03) * u)), c)
	# The stack: leafy bundles standing against the headboard.
	var bundle := CapsuleMesh.new()
	bundle.radius = 0.09 * u
	bundle.height = 0.36 * u
	mt.add_mesh(bundle, Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.12),
			Vector3(0.0, 0.63 * u, -1.04 * u)), LEAFY_B)
	mt.add_mesh(bundle, Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.18)
			* Basis(Vector3(1.0, 0.0, 0.0), 0.16),
			Vector3(0.13 * u, 0.62 * u, -1.06 * u)), LEAFY_A)
	holder.add_child(mt.build_node())
	# Soft contact shadow under the bed (the walker blob covers feet).
	var anchor := Node3D.new()
	anchor.position = Vector3(0.0, 0.0, -0.70 * u)
	holder.add_child(anchor)
	ShadowBlob.attach(anchor, 0.85 * u, 0.05)
