extends Node
## Walk-in interiors, slice 3 (issue #224, rescoped 2026-10-29): a
## chemist's pharmacy counter on the India Gate lawns and a second
## roadside dhaba seating nook on the thana plaza. Geometry follows the
## de-box directive — chamfered wall prisms, beveled counters, lathe
## bottles and tandoor, cylinder poles and logs, a curved arc-shell
## canopy instead of flat tin. This node owns the life inside: the
## chemist at his counter, a shopper, the dhaba cook and a patron; the
## pharmacy counter sells first-aid MEDS through the street-food
## economy, the dhaba counter pours chai and paratha like slice 1, and
## crossing the pharmacy doorway rings the shop chime (issue #187)
## behind the shopfront rain muffle (issue #227).

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")
const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

const DOOR_HALF_X := 1.6
const DOOR_HALF_Z := 1.5

## Counter-only item (issue #224): the pharmacy's first-aid kit —
## pricier than street food, heals deeper. Same wallet/HP path.
const MEDS := {"name": "MEDS", "price": 60, "heal": 70}

# Chemist shop palette.
const SHOP_WALL := Color(0.90, 0.92, 0.90)
const SHOP_FLOOR := Color(0.72, 0.74, 0.72)
const SHOP_ROOF := Color(0.30, 0.62, 0.44)
const COUNTER := Color(0.92, 0.90, 0.84)
const GLASS := Color(0.78, 0.84, 0.82)
const CROSS := Color(0.05, 0.60, 0.32)
const AWNING_A := Color(0.10, 0.55, 0.35)
const AWNING_B := Color(0.94, 0.95, 0.90)
const POLE := Color(0.35, 0.38, 0.36)
const BOTTLE_COLORS := [
	Color(0.88, 0.24, 0.16), Color(0.20, 0.45, 0.85),
	Color(0.92, 0.72, 0.18), Color(0.85, 0.88, 0.90),
]
const STRIP := Color(0.95, 0.95, 0.92)

# Dhaba nook palette.
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

var _player: Node3D = null
var _audio: Node = null
var _chars := Chars.new()
var _idles: Array[Dictionary] = []
var _shop := Vector3.ZERO
var _dhaba := Vector3.ZERO
var _inside := false


static func build(world: float, pitch: float, road_w: float) -> Node3D:
	## Static dressing from the main menu on (like delhi_dressing3.gd):
	## the block math mirrors setup() below so the pair never drifts.
	var ig := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 3.0 * pitch + road_w / 2.0)
	var ps := Vector2(-world / 2.0 + 7.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var sx := ig.x - 10.5
	var sz := ig.y + 9.5
	var dx := ps.x + 7.0
	var dz := ps.y + 9.0
	var b := MeshTools.new()
	_chemist(b, sx, sz)
	_dhaba_nook(b, dx, dz)
	var colliders: Array = [
		# Chemist shop: wall segments leave the east doorway open.
		[Vector3(0.25, 2.7, 3.2), Vector3(sx - 1.575, 0, sz)],
		[Vector3(3.4, 2.7, 0.25), Vector3(sx, 0, sz - 1.475)],
		[Vector3(3.4, 2.7, 0.25), Vector3(sx, 0, sz + 1.475)],
		[Vector3(0.25, 2.1, 1.0), Vector3(sx + 1.575, 0, sz - 1.1)],
		[Vector3(0.25, 2.1, 1.0), Vector3(sx + 1.575, 0, sz + 1.1)],
		[Vector3(0.5, 0.95, 2.2), Vector3(sx - 1.35, 0, sz + 0.15)],
		# Dhaba nook: per-prop boxes under the canopy, open to walk in.
		[Vector3(1.2, 1.25, 1.2), Vector3(dx - 1.2, 0, dz - 1.0)],
		[Vector3(1.0, 0.5, 1.0), Vector3(dx + 0.4, 0, dz - 1.3)],
		[Vector3(0.9, 0.95, 1.8), Vector3(dx + 1.55, 0, dz - 0.1)],
		[Vector3(1.75, 0.55, 0.8), Vector3(dx - 1.15, 0, dz + 1.1)],
		[Vector3(1.75, 0.55, 0.8), Vector3(dx + 0.35, 0, dz + 1.0)],
		[Vector3(0.9, 0.45, 0.9), Vector3(dx - 0.4, 0, dz + 1.05)],
	]
	var root := Node3D.new()
	root.name = "InteriorsSlice3"
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var solid := StaticBody3D.new()
	solid.name = "Slice3Colliders"
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


static func _chemist(b: MeshTools, x: float, z: float) -> void:
	## Walk-in chemist shop (issue #224): chamfered wall prisms with a
	## doorway in the east face — inside, a beveled counter under glass,
	## medicine shelves of lathe bottles and strip packs; a gloss green
	## cross over the roof, a curved striped awning at the door.
	var y := Roads.CURB_H
	# Floor: worn vinyl patch inside the walls (chamfered slab).
	b.add_prism(MeshTools.chamfer_footprint(1.6, 1.5, 0.12),
			Vector3(x, 0.0, z), y, y + 0.04, SHOP_FLOOR)
	# Walls (west back + two ends, 2.7 m) as chamfered prisms.
	b.add_prism(MeshTools.chamfer_footprint(0.125, 1.6, 0.08),
			Vector3(x - 1.575, 0.0, z), y, y + 2.7, SHOP_WALL)
	b.add_prism(MeshTools.chamfer_footprint(1.7, 0.125, 0.08),
			Vector3(x, 0.0, z - 1.475), y, y + 2.7, SHOP_WALL)
	b.add_prism(MeshTools.chamfer_footprint(1.7, 0.125, 0.08),
			Vector3(x, 0.0, z + 1.475), y, y + 2.7, SHOP_WALL)
	# East face: two segments flanking a 1.2 m doorway + chamfered lintel.
	b.add_prism(MeshTools.chamfer_footprint(0.125, 0.5, 0.08),
			Vector3(x + 1.575, 0.0, z - 1.1), y, y + 2.1, SHOP_WALL)
	b.add_prism(MeshTools.chamfer_footprint(0.125, 0.5, 0.08),
			Vector3(x + 1.575, 0.0, z + 1.1), y, y + 2.1, SHOP_WALL)
	b.add_prism(MeshTools.chamfer_footprint(0.125, 0.6, 0.08),
			Vector3(x + 1.575, 0.0, z), y + 2.1, y + 2.7, SHOP_WALL)
	b.add_prism(MeshTools.chamfer_footprint(1.9, 1.8, 0.14),
			Vector3(x, 0.0, z), y + 2.7, y + 2.84, SHOP_ROOF)
	# Counter against the back wall: beveled body, glass top.
	b.add_bev_box(Vector3(0.5, 0.95, 2.2), Vector3(x - 1.35, y + 0.475,
			z + 0.15), 0.05, COUNTER)
	b.add_bev_box(Vector3(0.6, 0.1, 2.3), Vector3(x - 1.35, y + 1.0,
			z + 0.15), 0.04, GLASS, 0.0, MeshTools.FINISH_GLOSS)
	# Medicine shelf: chamfered ledge on the back wall with lathe
	# bottles and strip packs.
	b.add_bev_box(Vector3(0.2, 0.06, 2.4), Vector3(x - 1.68, y + 1.7,
			z + 0.15), 0.02, SHOP_WALL)
	var bottle := PackedVector2Array([
		Vector2(0.09, 0.0), Vector2(0.10, 0.12), Vector2(0.09, 0.24),
		Vector2(0.05, 0.28), Vector2(0.04, 0.34), Vector2(0.04, 0.36),
	])
	for s in 6:
		b.add_lathe(bottle, Vector3(x - 1.68, y + 1.73,
				z - 0.85 + s * 0.4), BOTTLE_COLORS[s % 4],
				MeshTools.FINISH_GLOSS, 8)
	for s in 3:
		b.add_bev_box(Vector3(0.3, 0.08, 0.16),
				Vector3(x - 1.35, y + 1.08, z - 0.7 + s * 0.24),
				0.015, STRIP)
	# Gloss green cross on the roof parapet, over the doorway side.
	b.add_bev_box(Vector3(0.14, 0.62, 0.14), Vector3(x + 1.3, y + 3.2, z),
			0.02, CROSS, 0.0, MeshTools.FINISH_GLOSS)
	b.add_bev_box(Vector3(0.46, 0.14, 0.14), Vector3(x + 1.3, y + 3.2, z),
			0.02, CROSS, 0.0, MeshTools.FINISH_GLOSS)
	# Curved striped awning (arc shells) on two cylinder poles.
	for pole_z in [-1.15, 1.15]:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.05
		pm.height = 2.55
		b.add_mesh(pm, Transform3D(Basis(),
				Vector3(x + 2.05, y + 1.28, z + pole_z)), POLE)
	for s in 3:
		var col := AWNING_A if s % 2 == 0 else AWNING_B
		b.add_arc_shell(1.35, 0.78, 0.24,
				Vector3(x + 1.78, y + 2.46, z - 0.78 + s * 0.78), col)


static func _dhaba_nook(b: MeshTools, x: float, z: float) -> void:
	## Second roadside dhaba seating nook (issue #224): a lathe clay
	## tandoor with an ember mouth, a cylinder log pile, a beveled
	## service counter with tawa and paratha stack, two charpai cots
	## around a round table under a curved tin canopy on bamboo poles.
	var y := Roads.CURB_H
	# Tandoor: bulbous lathe clay drum, ember glow at the mouth.
	var tandoor := PackedVector2Array([
		Vector2(0.18, 0.0), Vector2(0.44, 0.08), Vector2(0.57, 0.35),
		Vector2(0.60, 0.70), Vector2(0.50, 1.05), Vector2(0.34, 1.18),
		Vector2(0.18, 1.22),
	])
	b.add_lathe(tandoor, Vector3(x - 1.2, y, z - 1.0), TANDOOR,
			MeshTools.FINISH_MATTE, 10)
	var glow := CylinderMesh.new()
	glow.top_radius = 0.20
	glow.bottom_radius = 0.20
	glow.height = 0.06
	b.add_mesh(glow, Transform3D(Basis(),
			Vector3(x - 1.2, y + 1.24, z - 1.0)), EMBER,
			MeshTools.FINISH_GLOSS)
	# Log pile: stacked cylinders on their side.
	var log := CylinderMesh.new()
	log.top_radius = 0.09
	log.bottom_radius = 0.09
	log.height = 0.85
	var log_xf := Transform3D(Basis(Vector3.FORWARD, PI / 2.0),
			Vector3(x + 0.4, y + 0.09, z - 1.3))
	for w in 3:
		for l in 2:
			var xf := log_xf * Transform3D(Basis(),
					Vector3(0, 0, 0))
			xf.origin = Vector3(x + 0.4 + (l - 0.5) * 0.19,
					y + 0.09 + w * 0.155, z - 1.3)
			b.add_mesh(log, xf, WOOD)
	# Service counter along the east edge, serving face to the west.
	b.add_bev_box(Vector3(0.9, 0.92, 1.8), Vector3(x + 1.55, y + 0.46,
			z - 0.1), 0.05, CHARPAI)
	b.add_bev_box(Vector3(1.0, 0.06, 1.9), Vector3(x + 1.55, y + 0.95,
			z - 0.1), 0.03, WEAVE)
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
	# Two charpai cots (beveled frame, woven top, cylinder legs) and a
	# round table between them — the seating nook.
	for cot: Vector2 in [Vector2(-1.15, 1.1), Vector2(0.35, 1.0)]:
		var cx := x + cot.x
		var cz := z + cot.y
		b.add_bev_box(Vector3(1.75, 0.26, 0.8),
				Vector3(cx, y + 0.5, cz), 0.04, CHARPAI)
		b.add_bev_box(Vector3(1.55, 0.07, 0.6),
				Vector3(cx, y + 0.64, cz), 0.03, WEAVE)
		for lx in [-0.75, 0.75]:
			for lz in [-0.3, 0.3]:
				var leg := CylinderMesh.new()
				leg.top_radius = 0.05
				leg.bottom_radius = 0.05
				leg.height = 0.42
				b.add_mesh(leg, Transform3D(Basis(),
						Vector3(cx + lx, y + 0.21, cz + lz)), CHARPAI)
	var top := CylinderMesh.new()
	top.top_radius = 0.45
	top.bottom_radius = 0.45
	top.height = 0.05
	b.add_mesh(top, Transform3D(Basis(),
			Vector3(x - 0.4, y + 0.42, z + 1.05)), PLATE)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.07
	stem.bottom_radius = 0.09
	stem.height = 0.4
	b.add_mesh(stem, Transform3D(Basis(),
			Vector3(x - 0.4, y + 0.2, z + 1.05)), STEEL)
	for pl in 2:
		var pc := CylinderMesh.new()
		pc.top_radius = 0.16
		pc.bottom_radius = 0.16
		pc.height = 0.025
		b.add_mesh(pc, Transform3D(Basis(),
				Vector3(x - 0.5 + pl * 0.22, y + 0.46, z + 1.0)), PLATE)
	# Curved tin canopy on four bamboo poles over the whole nook.
	for px in [-1.7, 1.7]:
		for pz in [-1.6, 1.6]:
			var pole := CylinderMesh.new()
			pole.top_radius = 0.06
			pole.bottom_radius = 0.06
			pole.height = 2.4
			b.add_mesh(pole, Transform3D(Basis(),
					Vector3(x + px, y + 1.2, z + pz)), BAMBOO)
	b.add_arc_shell(4.4, 4.2, 0.55, Vector3(x, y + 2.45, z), TIN)


func setup(world: float, pitch: float, road_w: float, food: Node) -> void:
	## Interior life from the main menu on: the block math mirrors
	## build() above so geometry and cast never drift.
	var ig := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 3.0 * pitch + road_w / 2.0)
	var ps := Vector2(-world / 2.0 + 7.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	_shop = Vector3(ig.x - 10.5, Roads.CURB_H, ig.y + 9.5)
	_dhaba = Vector3(ps.x + 7.0, Roads.CURB_H, ps.y + 9.0)
	# The chemist behind his counter, a shopper deciding at the glass.
	_npc(Chars.MALE, 22401, false, 1.70,
			_shop + Vector3(-1.3, 0.0, -0.5), Vector3(1.0, 0.0, 0.5))
	_npc(Chars.FEMALE_B, 22402, true, 1.60,
			_shop + Vector3(0.5, 0.0, 0.4), Vector3(-1.0, 0.0, -0.2))
	# The dhaba cook at the tawa end of his counter, a patron parked by
	# the round table between the charpais.
	_npc(Chars.MALE, 22403, false, 1.74,
			_dhaba + Vector3(1.5, 0.0, -0.5), Vector3(-1.0, 0.0, 0.0))
	_npc(Chars.MALE, 22404, false, 1.66,
			_dhaba + Vector3(-0.9, 0.0, 0.35), Vector3(1.0, 0.0, 0.6))
	# Counter service through the food system (same Q/R economy).
	if food != null and food.has_method("add_counter"):
		food.add_counter(_shop + Vector3(-0.9, 0.0, 0.15), [MEDS])
		food.add_counter(_dhaba + Vector3(0.5, 0.0, -0.1),
				[food.CHAI, food.PARATHA])


func register(p: Node3D, audio: Node) -> void:
	## Live-game nodes: the doorway check needs the walker, the chime
	## needs the audio bus.
	_player = p
	_audio = audio


func _process(_delta: float) -> void:
	## Idle clips loop forever on the interior cast (rigs import the
	## clip without loop flags, so nudge the player when one lands).
	for n in _idles:
		if not n["ap"].is_playing():
			_chars.play(n["anims"], n["ap"], "idle", 0.9)
	if _player == null or _audio == null:
		return
	var p := _player.global_position
	var inside := absf(p.x - _shop.x) < DOOR_HALF_X \
			and absf(p.z - _shop.z) < DOOR_HALF_Z
	if inside != _inside:
		_inside = inside
		_audio.door_chime()
		# Rain and street beds low-pass behind the shopfront (issue #227).
		if _audio.has_method("set_indoors"):
			_audio.set_indoors(inside)


func _npc(model_path: String, seed: int, female: bool, height: float,
		at: Vector3, face: Vector3) -> void:
	## One rigged idle local — same spawn path as the slice-1 interior
	## cast (characters.gd identity + dress), parked facing a spot.
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
