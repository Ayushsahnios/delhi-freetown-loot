extends RefCounted
## Rigged character factory. The humans of the city (player, legends,
## pedestrians, stall vendors) are instanced from the CC0 Quaternius
## models vendored under assets/characters/ — each model carries its own
## Skeleton3D and AnimationPlayer with idle/walk/run clips, replacing the
## old box-part humans. Colors are baked into per-instance mesh copies.

const MALE := "res://assets/characters/male_rigged.glb"
const FEMALE_A := "res://assets/characters/female_a.glb"
const FEMALE_B := "res://assets/characters/female_b.glb"
const FEMALE_C := "res://assets/characters/female_c.glb"
const FEMALE_D := "res://assets/characters/female_d.glb"

## Procedural liveliness layer (issue 122): every spawned body gets a
## seeded LivelyRig on its skeleton.
const LIVELY := preload("res://scripts/lively.gd")

## Skeleton bone spans stop short of scalp and soles — pad to full height.
const BONE_PAD := 1.12

## Human height band (issue 128): every humanoid spawn — player,
## legends, walkers, vendors — is clamped into this range no matter
## what its caller requests, so no crowd can grow micros or dinosaurs.
const HEIGHT_MIN := 1.55
const HEIGHT_MAX := 1.90

## Upright bone extent of the rig's rest pose, in model units. The skinned
## mesh's raw vertex box is meaningless (bind space), the skeleton is not.
static var _span_cache := {}

## Cached height basis per model file (see _size_basis).
static var _basis_cache := {}


## Instantiate `path` sized to `height` world units, facing -Z (the
## project's forward). Returns a holder node; the model is its child.
## The corrective 180° flip lives on the MODEL child, never on the
## holder (issue 127): the CC0 walkers all author facing +Z, and drivers
## that steer the holder's global transform directly (the pedestrian
## recycler sets it every physics frame) would wipe a holder-side flip
## and make every walker glide backwards.
func spawn(path: String, height: float) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("character model missing: " + path)
		return null
	var model: Node3D = ps.instantiate()
	# Issue 128: clamp the request into the human height band, then
	# correct the scale against the model's TRUE rendered height — the
	# bone/visual basis is only a first guess, so a variant whose basis
	# misfires (tiny authoring units, padded spans) cannot sneak through.
	var target := clampf(height, HEIGHT_MIN, HEIGHT_MAX)
	var basis := _size_basis(model)
	if basis > 0.001:
		model.scale = Vector3.ONE * (target / basis)
	var rendered := _visual_height(model) * model.scale.y
	if rendered > 0.001 and absf(rendered - target) > 0.01:
		model.scale = Vector3.ONE * (target / rendered)
	model.rotation.y = PI
	# Issue 122: liveliness layer on every rigged spawn — seeded head
	# wander, weight shift, phone idles, turn bank. Self-disabling
	# no-op on rigs without a head bone.
	for skel_node in model.find_children("*", "Skeleton3D", true, false):
		var rig := LIVELY.new()
		rig.rig_seed = randi()
		skel_node.add_child(rig)
		break
	var holder := Node3D.new()
	holder.add_child(model)
	return holder


## Height to size this model against, in model units. Bone-rest span is
## the honest measure when the rig is in sane units — but some exports
## (the female walkers) keep the skeleton in tiny authoring units while
## the mesh nodes carry the display scale, so a bone span far shorter
## than the mesh it skews cannot size the model (issue #82: walkers
## spawned hundreds of units tall, off in the sky). In that case fall
## back to the model's visible mesh box, which is what actually renders.
func _size_basis(model: Node3D) -> float:
	var key := String(model.scene_file_path)
	if _basis_cache.has(key):
		return _basis_cache[key]
	var bone := _bone_span(model)
	var visual := _visual_height(model)
	var basis := visual
	if bone > 0.001 and (visual <= 0.001 or bone >= visual * 0.5):
		basis = bone * BONE_PAD
	if basis <= 0.001:
		basis = 0.0
	_basis_cache[key] = basis
	return basis


## Upright extent of every mesh instance combined, in model-root space.
## Unlike the raw vertex box this accounts for each node's transform, so
## baked-in authoring scale (the 100x mesh nodes in the female exports)
## is included — this is the box the renderer actually draws.
func _visual_height(model: Node3D) -> float:
	var box := AABB()
	var has := false
	for mi_node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh == null:
			continue
		var xf := _relative_transform(model, mi)
		var part: AABB = xf * mi.mesh.get_aabb()
		if has:
			box = box.merge(part)
		else:
			box = part
			has = true
	if not has or box.size.y <= 0.0:
		return 0.0
	return box.size.y


## Transform of `node` relative to ancestor `model` (both outside the
## tree, so node locals are chained manually).
func _relative_transform(model: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != model:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


## {"idle": String, "walk": String, "run": String} clip names for the
## model's AnimationPlayer, or an empty Dictionary when it has none.
func anim_names(holder: Node3D) -> Dictionary:
	for ap_node in holder.find_children("*", "AnimationPlayer", true, false):
		var ap: AnimationPlayer = ap_node
		var out := {}
		var list: Array = ap.get_animation_list()
		# Exact clip names first (libraries qualify names with a slash, so
		# match on the final segment), then looser fallbacks.
		for full in list:
			var seg := _seg(String(full))
			if seg == "idle" or seg == "female_idle" or seg == "male_idle":
				out["idle"] = full
			if seg == "walk" or seg == "female_walk":
				out["walk"] = full
			if seg == "run" or seg == "female_run" or seg == "sprint":
				out["run"] = full
		for full in list:
			var seg2 := _seg(String(full))
			if not out.has("idle") and seg2.ends_with("idle") \
					and not seg2.begins_with("crouch") and not seg2.begins_with("sitting") \
					and not seg2.begins_with("swim") and not seg2.begins_with("pistol") \
					and not seg2.begins_with("sword") and not seg2.begins_with("idle_"):
				out["idle"] = full
			if not out.has("walk") and seg2.contains("walk") and not seg2.contains("formal"):
				out["walk"] = full
			if not out.has("run") and (seg2.contains("jog") or seg2.contains("run") \
					or seg2.contains("sprint")) and not seg2.contains("jump"):
				out["run"] = full
		return out
	return {}


func _seg(anim_name: String) -> String:
	var n := anim_name.to_lower()
	return n.get_slice("/", n.get_slice_count("/") - 1)


func get_player(holder: Node3D) -> AnimationPlayer:
	for ap_node in holder.find_children("*", "AnimationPlayer", true, false):
		return ap_node
	return null


## Crossfade to `clip` (a key of anim_names()) with a playback rate that
## keeps feet on the ground as speed changes. Fades are per-target
## (issue 122): panic runs snap in fast, strolls blend, idles settle
## slowest — uniform 0.15s cuts were part of the robotic look.
const FADES := {"run": 0.12, "walk": 0.26, "idle": 0.34}


func play(anims: Dictionary, ap: AnimationPlayer, clip: String, rate: float) -> void:
	if ap == null or not anims.has(clip):
		return
	var full: StringName = anims[clip]
	if ap.current_animation != full or not ap.is_playing():
		ap.play(full, FADES.get(clip, 0.2))
	ap.speed_scale = clampf(rate, 0.55, 1.75)


## First LivelyRig under `holder`, or null — callers use it to flip
## `talking` for dialogue givers or force a variant pose.
func lively(holder: Node3D) -> Node:
	for rig_node in holder.find_children("*", "LivelyRig", true, false):
		return rig_node
	return null


## Recolor clothing/skin slots. The GLB materials name their parts
## (Shirt/Jacket/Pants/Skin/... for the women, M_Main/M_Joints for the
## universal-rig male), so the match is by material name. Colors are
## baked into a per-instance copy of the mesh, so every surface keeps a
## real material — never a null slot for the renderer to trip on.
func tint(holder: Node3D, shirt: Color, pants: Color, skin: Color,
		hair: Color = Color(0.0, 0.0, 0.0, -1.0)) -> void:
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh == null:
			continue
		var mesh := mi.mesh.duplicate() as ArrayMesh
		if mesh == null:
			continue
		var changed := false
		for s in mesh.get_surface_count():
			var base = mesh.surface_get_material(s)
			if base == null or not base is StandardMaterial3D:
				var fb := StandardMaterial3D.new()
				fb.albedo_color = skin
				mesh.surface_set_material(s, fb)
				changed = true
				continue
			var role := _role(String(base.resource_name))
			if role == "":
				## Eyes keep their authored look.
				continue
			var m := (base as StandardMaterial3D).duplicate()
			if role == "hair":
				## Authored hair/brows recolor only when a shade is given.
				if hair.a >= 0.0:
					m.albedo_color = hair
			else:
				var plain := shirt if role == "shirt" else pants
				m.albedo_color = plain if role != "skin" else skin
			mesh.surface_set_material(s, m)
			changed = true
		if changed:
			mi.mesh = mesh


## Sardar identity kit, bound to the head bone so it rides every
## idle/walk/run nod: a stylized cloth-wrap dastaar — stacked flattened
## torus wraps tapering to a dome with a front peak — plus a swept beard
## and mustache. All procedural primitives sized off the skeleton span,
## so it fits any rigged model.
func attach_sardar(holder: Node3D, turban: Color, beard: Color = Color(0.13, 0.08, 0.05)) -> void:
	var kit := _head_kit(holder)
	if kit.is_empty():
		return
	var att: BoneAttachment3D = kit["att"]
	var head_xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	# Wrap stack: [height above head bone, inner radius] in head units; each
	# wrap is a flattened torus so the silhouette reads as layered cloth.
	var wraps := [
		[0.36, 0.56], [0.50, 0.60], [0.64, 0.52], [0.76, 0.42],
	]
	var mat := _solid(turban)
	for w in wraps:
		var ring := TorusMesh.new()
		ring.inner_radius = float(w[1]) * u
		ring.outer_radius = (float(w[1]) + 0.17) * u
		ring.rings = 48
		ring.ring_segments = 10
		_bone_mesh(att, head_xf, ring, mat,
				Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)),
					Vector3(0.0, float(w[0]) * u, 0.0)))
	var dome := SphereMesh.new()
	dome.radius = 0.42 * u
	dome.height = 0.84 * u
	_bone_mesh(att, head_xf, dome, mat,
			Transform3D(Basis().scaled(Vector3(1.0, 0.7, 1.0)), Vector3(0.0, 0.86 * u, 0.0)))
	var peak := CylinderMesh.new()
	peak.top_radius = 0.0
	peak.bottom_radius = 0.15 * u
	peak.height = 0.36 * u
	_bone_mesh(att, head_xf, peak, mat,
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.45), Vector3(0.0, 0.92 * u, 0.34 * u)))
	# Beard: a slab tucked under the chin and swept slightly forward, with
	# a mustache bar on the lip. Reads clearly at gameplay scale.
	var bmat := _solid(beard)
	var chin := BoxMesh.new()
	chin.size = Vector3(0.55 * u, 0.5 * u, 0.14 * u)
	_bone_mesh(att, head_xf, chin, bmat,
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.28), Vector3(0.0, 0.14 * u, 0.46 * u)))
	var stache := BoxMesh.new()
	stache.size = Vector3(0.44 * u, 0.07 * u, 0.11 * u)
	_bone_mesh(att, head_xf, stache, bmat,
			Transform3D(Basis(), Vector3(0.0, 0.33 * u, 0.52 * u)))


## ------------------------------------------------------------------ identity

## Modular NPC identity (issue #120): one integer seed rolls every slot
## a walker wears — body (height), head (headwear), hair (style +
## shade), outfit (shirt + pants), skin — so each NPC keeps a stable
## look of its own across recycles while the crowd stays varied.
const ID_SKINS := [
	Color(0.79, 0.57, 0.40), Color(0.72, 0.50, 0.33),
	Color(0.64, 0.44, 0.29), Color(0.55, 0.38, 0.26),
]
const ID_TOPS := [
	Color(0.95, 0.55, 0.12), Color(0.12, 0.55, 0.55), Color(0.85, 0.20, 0.45),
	Color(0.92, 0.90, 0.86), Color(0.16, 0.30, 0.60), Color(0.45, 0.50, 0.25),
	Color(0.88, 0.35, 0.25), Color(0.55, 0.35, 0.60), Color(0.99, 0.72, 0.30),
	Color(0.20, 0.20, 0.24),
]
const ID_BOTTOMS := [
	Color(0.14, 0.18, 0.30), Color(0.30, 0.30, 0.34), Color(0.32, 0.24, 0.18),
	Color(0.10, 0.10, 0.12), Color(0.62, 0.55, 0.40), Color(0.45, 0.50, 0.55),
]
const ID_HAIRS := [
	Color(0.07, 0.05, 0.04), Color(0.15, 0.10, 0.06), Color(0.27, 0.17, 0.09),
	Color(0.42, 0.30, 0.18), Color(0.55, 0.52, 0.50), Color(0.38, 0.15, 0.10),
]
const ID_HATS := [
	Color(0.95, 0.55, 0.12), Color(0.92, 0.90, 0.86), Color(0.35, 0.16, 0.12),
	Color(0.85, 0.72, 0.20), Color(0.45, 0.50, 0.25), Color(0.55, 0.35, 0.60),
]


## Roll a full identity from `seed`: deterministic, so a given NPC
## always dresses the same while different seeds never collide twice in
## one crowd.
static func identity(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {
		"seed": seed,
		"skin": ID_SKINS[rng.randi_range(0, ID_SKINS.size() - 1)],
		"shirt": ID_TOPS[rng.randi_range(0, ID_TOPS.size() - 1)],
		"pants": ID_BOTTOMS[rng.randi_range(0, ID_BOTTOMS.size() - 1)],
		"hair": ID_HAIRS[rng.randi_range(0, ID_HAIRS.size() - 1)],
		"hat": ID_HATS[rng.randi_range(0, ID_HATS.size() - 1)],
		# 0 authored-only, 1 crop, 2 crop + bun, 3 crop + ponytail
		"hair_style": rng.randi_range(0, 3),
		# 0 none, 1 cap, 2 wrap, 3 patka, 4 headband
		"headwear": rng.randi_range(0, 4),
		"height": rng.randf_range(0.93, 1.07),
	}


## Apply a full identity: palette tint (authored hair recolors to the
## seed shade), then procedural hair and headwear on rigs that ship
## bald. Authored-hair rigs (the female walkers) keep their modeled
## hair: their bones ride tiny authoring units (issue #82), so
## bone-space accessories render misplaced — recolor + outfit + body
## slots carry their variety instead.
func dress(holder: Node3D, id: Dictionary) -> void:
	tint(holder, id["shirt"], id["pants"], id["skin"], id["hair"])
	if _has_authored_hair(holder):
		return
	var kit := _head_kit(holder)
	if kit.is_empty():
		return
	if int(id["hair_style"]) > 0:
		_attach_hair(kit, id)
	if int(id["headwear"]) > 0:
		_attach_headwear(kit, id)


func _has_authored_hair(holder: Node3D) -> bool:
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base = mi.mesh.surface_get_material(s)
			if base != null and _role(String(base.resource_name)) == "hair":
				return true
	return false


func _attach_hair(kit: Dictionary, id: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var mat := _solid(id["hair"])
	var crop := SphereMesh.new()
	crop.radius = 0.52 * u
	crop.height = 1.02 * u
	_bone_mesh(att, xf, crop, mat,
			Transform3D(Basis().scaled(Vector3(1.0, 0.74, 1.0)),
					Vector3(0.0, 0.52 * u, 0.0)))
	match int(id["hair_style"]):
		2:
			var bun := SphereMesh.new()
			bun.radius = 0.22 * u
			bun.height = 0.44 * u
			_bone_mesh(att, xf, bun, mat,
					Transform3D(Basis().scaled(Vector3(1.0, 0.85, 1.0)),
						Vector3(0.0, 0.78 * u, -0.44 * u)))
		3:
			var tail := CapsuleMesh.new()
			tail.radius = 0.13 * u
			tail.height = 0.62 * u
			_bone_mesh(att, xf, tail, mat,
					Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.35),
						Vector3(0.0, 0.42 * u, -0.56 * u)))


func _attach_headwear(kit: Dictionary, id: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var mat := _solid(id["hat"])
	match int(id["headwear"]):
		1:
			# Cap: soft dome plus a stitched brim over the brow.
			var dome := SphereMesh.new()
			dome.radius = 0.55 * u
			dome.height = 0.80 * u
			_bone_mesh(att, xf, dome, mat,
					Transform3D(Basis().scaled(Vector3(1.0, 0.7, 1.0)),
						Vector3(0.0, 0.74 * u, 0.0)))
			var brim := CylinderMesh.new()
			brim.top_radius = 0.34 * u
			brim.bottom_radius = 0.34 * u
			brim.height = 0.07 * u
			_bone_mesh(att, xf, brim, mat,
					Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.18),
						Vector3(0.0, 0.52 * u, 0.42 * u)))
		2:
			# Wrap: two layered cloth bands.
			for w in [[0.40, 0.56], [0.58, 0.50]]:
				var ring := TorusMesh.new()
				ring.inner_radius = float(w[1]) * u
				ring.outer_radius = (float(w[1]) + 0.16) * u
				ring.rings = 40
				ring.ring_segments = 10
				_bone_mesh(att, xf, ring, mat,
						Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)),
							Vector3(0.0, float(w[0]) * u, 0.0)))
		3:
			# Patka: small knotted turban.
			for w in [[0.38, 0.52], [0.52, 0.58], [0.64, 0.44]]:
				var band := TorusMesh.new()
				band.inner_radius = float(w[1]) * u
				band.outer_radius = (float(w[1]) + 0.15) * u
				band.rings = 40
				band.ring_segments = 10
				_bone_mesh(att, xf, band, mat,
						Transform3D(Basis().scaled(Vector3(1.0, 0.55, 1.0)),
							Vector3(0.0, float(w[0]) * u, 0.0)))
			var knot := SphereMesh.new()
			knot.radius = 0.20 * u
			knot.height = 0.40 * u
			_bone_mesh(att, xf, knot, mat, Transform3D(Basis(),
					Vector3(0.0, 0.72 * u, 0.38 * u)))
		4:
			# Headband: a thin band across the brow.
			var strip := TorusMesh.new()
			strip.inner_radius = 0.54 * u
			strip.outer_radius = 0.68 * u
			strip.rings = 36
			strip.ring_segments = 8
			_bone_mesh(att, xf, strip, mat,
					Transform3D(Basis().scaled(Vector3(1.0, 0.22, 1.0)),
						Vector3(0.0, 0.42 * u, 0.0)))


## Shared head rig for every bone-riding accessory: finds the head bone,
## sizes one head unit off the skeleton span and returns a live
## BoneAttachment3D plus its rest frame ({} when the rig has no head
## bone).
func _head_kit(holder: Node3D) -> Dictionary:
	var skel: Skeleton3D = null
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		skel = skel_node
		break
	if skel == null:
		return {}
	var head := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).to_lower() == "head":
			head = i
			break
	if head < 0:
		return {}
	var top := -INF
	var bottom := INF
	for i in skel.get_bone_count():
		var p := skel.get_bone_global_rest(i).origin
		top = maxf(top, p.y)
		bottom = minf(bottom, p.y)
	var u: float = (top - bottom) * 0.155
	var att := BoneAttachment3D.new()
	att.bone_idx = head
	skel.add_child(att)
	return {"att": att, "xf": skel.get_bone_global_rest(head), "u": u}


func _solid(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


## Add `mesh` under `att`, placed at `desired` (a transform in skeleton
## space) converted into the head bone's rest frame, so it lands exactly
## in the rest pose and follows the bone rigidly through animation.
func _bone_mesh(att: BoneAttachment3D, head_xf: Transform3D, mesh: PrimitiveMesh,
		mat: StandardMaterial3D, desired: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = head_xf.affine_inverse() * desired
	att.add_child(mi)


func _role(mat_name: String) -> String:
	var n := mat_name.to_lower()
	if n.begins_with("m_main") or n.contains("shirt") or n.contains("jacket"):
		return "shirt"
	if n.begins_with("m_joints") or n.contains("pants") or n.contains("shoes"):
		return "pants"
	if n == "hair" or n == "hairbase" or n == "eyebrows":
		return "hair"
	if n == "skin" or n.ends_with("_skin"):
		return "skin"
	return ""


func _bone_span(model: Node3D) -> float:
	var key := String(model.scene_file_path)
	if _span_cache.has(key):
		return _span_cache[key]
	var span := 0.0
	for skel_node in model.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = skel_node
		var top := -INF
		var bottom := INF
		for i in skel.get_bone_count():
			var p := skel.get_bone_global_rest(i).origin
			top = maxf(top, p.y)
			bottom = minf(bottom, p.y)
		if bottom < top:
			span = top - bottom
		break
	_span_cache[key] = span
	return span
