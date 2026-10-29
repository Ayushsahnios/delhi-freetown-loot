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

## Procedural fabric grain (issue #153): garment slots get woven
## albedo + roughness textures instead of flat single colors — the
## texture-carried realism of the PS2-era reference.
const Fabrics := preload("res://scripts/fabrics.gd")

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
	# Issue 158: normalize oversized heads toward the art-ref proportion
	# band (PS2-era ~6.5-7 heads tall). The universal male rig reads a
	# head ~12% too large against its shoulders next to art-ref-1.jpg;
	# pose-scale on the head bone is rig-legal (rests untouched, weight
	# paint untouched) and head-attached accessories inherit the shrink
	# automatically because BoneAttachment3D copies the bone pose.
	_normalize_head(model)
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


## Per-rig head-pose scale factors (issue 158). Keyed by scene-file
## basename; rigs absent from the map keep authored proportions. The
## female walkers measure 7.6-8.5 heads by bone span already, so only
## the universal male rig needs the correction.
const HEAD_SCALE := {
	"male_rigged": 0.88,
}


func _normalize_head(model: Node3D) -> void:
	var key := String(model.scene_file_path).get_file().get_basename()
	if not HEAD_SCALE.has(key):
		return
	for skel_node in model.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = skel_node
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower() == "head":
				skel.set_bone_pose_scale(i,
					Vector3.ONE * float(HEAD_SCALE[key]))
				break
		break


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
			# Issue #153: woven grain + matte roughness per garment kind,
			# so the tint keeps its shade but stops reading as flat toon.
			Fabrics.apply(m, role)
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
	var mat := _wrap_mat(turban)
	# Issue 160: each wrap layer gets the fold-grain cloth material at
	# a slightly different depth shade, so the stack reads as folded
	# cloth layers instead of one smooth solid.
	var layers := [0.0, 0.07, 0.13, 0.05]
	for i in wraps.size():
		var ring := TorusMesh.new()
		ring.inner_radius = float(wraps[i][1]) * u
		ring.outer_radius = (float(wraps[i][1]) + 0.17) * u
		ring.rings = 48
		ring.ring_segments = 10
		_bone_mesh(att, head_xf, ring, _wrap_mat(turban.darkened(layers[i])),
				Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)),
					Vector3(0.0, float(wraps[i][0]) * u, 0.0)))
	# Issue 160: a diagonal cross-wrap band — the cloth crossing over
	# the layered wraps.
	var cross := TorusMesh.new()
	cross.inner_radius = 0.52 * u
	cross.outer_radius = 0.68 * u
	cross.rings = 48
	cross.ring_segments = 10
	_bone_mesh(att, head_xf, cross, _wrap_mat(turban.darkened(0.03)),
			Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.45)
					* Basis().scaled(Vector3(1.0, 0.5, 1.0)),
					Vector3(0.0, 0.55 * u, 0.0)))
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
	var bmat := _hair_mat(beard)
	var chin := BoxMesh.new()
	# Issue 152: beard slab sized to read at title-portrait scale —
	# the first cut was too small to see against the face at 128x168.
	chin.size = Vector3(0.62 * u, 0.62 * u, 0.18 * u)
	_bone_mesh(att, head_xf, chin, bmat,
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.28), Vector3(0.0, 0.10 * u, 0.50 * u)))
	var stache := BoxMesh.new()
	stache.size = Vector3(0.48 * u, 0.09 * u, 0.13 * u)
	_bone_mesh(att, head_xf, stache, bmat,
			Transform3D(Basis(), Vector3(0.0, 0.33 * u, 0.54 * u)))


## ------------------------------------------------------------------ legends

## Legend identity (issue #121): the three playable legends dress far
## beyond an NPC tint — each def in Game.CHARACTERS carries look keys
## (hair, jacket, beard, helmet, anim_rate) and this factory adds a
## procedural identity kit on top of the palette tint, so title-screen
## portraits and street captures read three unmistakable characters:
##   sardarji — cream kurta + wool vest panels + dastaar + grey beard
##   riya     — riding palette + helmet slung on the back + ponytail
##   monty    — glossy slicked hair + shades + gold chain + open collar
## Rigs with sane bone units (the universal male) get bone-riding kit
## that follows idle/walk nods; the authored-hair female rig keeps its
## tiny authoring bones (issue #82) where bone-space accessories render
## misplaced, so her pieces are holder-fixed in world units instead.
func dress_legend(holder: Node3D, def: Dictionary) -> void:
	tint(holder, def.get("shirt", Color.WHITE), def.get("pants", Color.BLACK),
			def.get("skin", Color.WHITE), def.get("hair", Color(0.0, 0.0, 0.0, -1.0)))
	build_legend(holder, def)
	match String(def.get("id", "")):
		"sardarji":
			attach_sardar(holder, def.get("turban", Color(1.0, 0.56, 0.12)),
					def.get("beard", Color(0.44, 0.42, 0.40)))
			var tk := _torso_kit(holder)
			if not tk.is_empty():
				_vest(tk, def.get("jacket", Color(0.36, 0.17, 0.11)))
				_tailor_kurta(tk, def)
		"monty":
			var kit := _head_kit(holder)
			if not kit.is_empty():
				_slick_hair(kit, def.get("hair", Color(0.05, 0.04, 0.04)))
				_shades(kit)
			var tk2 := _torso_kit(holder)
			if not tk2.is_empty():
					_chain_and_collar(tk2, def.get("skin", Color(0.79, 0.56, 0.39)))
					_tailor_shirt(tk2, def)
		"riya":
			_rider_gear(holder, def)
			_tailor_jacket(holder, def)


## ------------------------------------------------------------------ body builds

## Legend body builds (issue #161): distinct silhouettes inside the
## shared height band, built from bone-pose SCALE factors on the torso
## chain so they ride every idle/walk/run frame — scale channels are
## not keyframed by the clip library, so the pose survives playback
## (the issue-158 head-scale pattern). Pose scale is a relative factor
## on the bone rest, so it is safe on both unit conventions: the male
## rig's sane units and the female rig's tiny authoring bones (the
## #82 hazard is bone-space offsets, not relative pose factors).
## Keyed by lowercase bone name.
const BODY_BUILDS := {
	"sardarji": {
		# Barrel chest: ribcage and shoulders flare wide, the weight of
		# the frame carried forward of the hips.
		"spine_01": Vector3(1.10, 1.0, 1.14),
		"spine_02": Vector3(1.16, 1.0, 1.17),
		"spine_03": Vector3(1.13, 1.0, 1.10),
	},
	"monty": {
		# Lean: narrow through ribs and waist, shoulders held narrow —
		# clothes hang off him.
		"spine_01": Vector3(0.93, 1.0, 0.95),
		"spine_02": Vector3(0.90, 1.0, 0.92),
		"spine_03": Vector3(0.90, 1.0, 0.90),
	},
	"riya": {
		# Athletic: shoulders and chest trained wide over a nipped
		# waist and compact hips.
		"abdomen": Vector3(0.93, 1.0, 0.95),
		"torso": Vector3(1.05, 1.0, 1.05),
		"hips": Vector3(0.97, 1.0, 0.98),
	},
}

## Whole-model posture tilt per legend (radians, model pitch). Lives
## on the MODEL node rather than bone rotations because the clip
## library keyframes spine rotations every frame — a pose rotation
## would be stomped by the first walk frame, while a tiny ground-pivot
## tilt reads as stance and survives all playback. sardarji sits back
## chest-first, monty lolls forward, riya carries a rider's forward
## bias.
const POSTURE := {
	"sardarji": -0.05,
	"monty": 0.055,
	"riya": 0.03,
}


## Apply the legend's body build (pose scales) and posture tilt.
func build_legend(holder: Node3D, def: Dictionary) -> void:
	var id := String(def.get("id", ""))
	var builds: Dictionary = BODY_BUILDS.get(id, {})
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		var skel: Skeleton3D = skel_node
		for i in skel.get_bone_count():
			var key := skel.get_bone_name(i).to_lower()
			if builds.has(key):
				skel.set_bone_pose_scale(i, builds[key])
		break
	if POSTURE.has(id) and holder.get_child_count() > 0:
		var model: Node3D = holder.get_child(0)
		model.rotation.x = float(POSTURE[id])


## ------------------------------------------------------------------ tailoring

## Legend wardrobe detail pass (issue #161): stitching, collars and
## buttons on each legend's outfit, so the trio reads tailored at
## portrait scale on top of the body builds. Male-rig legends ride
## the chest bone (torso-kit units u); Riya's authored-hair rig keeps
## tiny authoring bones (#82), so her details are holder-fixed in
## world units off the rendered height — the _rider_gear pattern.

## Sardar Ji: standing collar + buttoned front placket on the vest,
## stitched shoulder seams, and a kurta-cloth barrel belly anchoring
## the broad build.
func _tailor_kurta(tk: Dictionary, def: Dictionary) -> void:
	var att: BoneAttachment3D = tk["att"]
	var xf: Transform3D = tk["xf"]
	var u: float = tk["u"]
	var vest: Color = def.get("jacket", Color(0.36, 0.17, 0.11))
	var kurta: Color = def.get("shirt", Color(0.93, 0.90, 0.83))
	var collar := CylinderMesh.new()
	collar.top_radius = 0.30 * u
	collar.bottom_radius = 0.32 * u
	collar.height = 0.16 * u
	_bone_mesh(att, xf, collar, _solid(kurta.darkened(0.10)),
			Transform3D(Basis(), Vector3(0.0, 1.02 * u, 0.0)))
	var placket := BoxMesh.new()
	placket.size = Vector3(0.07 * u, 0.95 * u, 0.03 * u)
	_bone_mesh(att, xf, placket, _solid(vest.darkened(0.22)),
			Transform3D(Basis(), Vector3(0.0, 0.32 * u, 0.70 * u)))
	for b in [0.62, 0.42, 0.22]:
		var button := CylinderMesh.new()
		button.top_radius = 0.045 * u
		button.bottom_radius = 0.045 * u
		button.height = 0.02 * u
		_bone_mesh(att, xf, button, _solid(kurta.darkened(0.35)),
				Transform3D(Basis(Vector3.RIGHT, PI / 2.0),
						Vector3(0.0, float(b) * u, 0.725 * u)))
	for sx in [-0.72, 0.72]:
		var seam := BoxMesh.new()
		seam.size = Vector3(0.02 * u, 0.04 * u, 0.82 * u)
		_bone_mesh(att, xf, seam, _solid(vest.darkened(0.30)),
				Transform3D(Basis(), Vector3(float(sx) * u, 0.92 * u, 0.0)))
	var belly := SphereMesh.new()
	belly.radius = 0.34 * u
	belly.height = 0.68 * u
	_bone_mesh(att, xf, belly, _solid(kurta.darkened(0.06)),
			Transform3D(Basis().scaled(Vector3(1.0, 0.82, 0.88)),
					Vector3(0.0, -0.42 * u, 0.30 * u)))


## Monty: open-shirt collar wings, dark buttons down the placket,
## stitched shoulder seams — sharp over the lean frame.
func _tailor_shirt(tk: Dictionary, def: Dictionary) -> void:
	var att: BoneAttachment3D = tk["att"]
	var xf: Transform3D = tk["xf"]
	var u: float = tk["u"]
	var shirt: Color = def.get("shirt", Color(0.35, 0.28, 0.45))
	for cx in [-0.30, 0.30]:
		var wing := BoxMesh.new()
		wing.size = Vector3(0.17 * u, 0.05 * u, 0.24 * u)
		_bone_mesh(att, xf, wing, _solid(shirt.darkened(0.18)),
				Transform3D(Basis(Vector3.UP, 0.35 if cx > 0.0 else -0.35),
						Vector3(float(cx) * u, 1.0 * u, 0.40 * u)))
	for b in [0.55, 0.37, 0.19]:
		var button := CylinderMesh.new()
		button.top_radius = 0.035 * u
		button.bottom_radius = 0.035 * u
		button.height = 0.018 * u
		_bone_mesh(att, xf, button, _solid(shirt.darkened(0.50)),
				Transform3D(Basis(Vector3.RIGHT, PI / 2.0),
						Vector3(0.0, float(b) * u, 0.565 * u)))
	for sx in [-0.66, 0.66]:
		var seam := BoxMesh.new()
		seam.size = Vector3(0.02 * u, 0.04 * u, 0.74 * u)
		_bone_mesh(att, xf, seam, _solid(shirt.darkened(0.30)),
				Transform3D(Basis(), Vector3(float(sx) * u, 0.88 * u, 0.0)))


## Riya: rider-jacket collar band, center zip line, stitched shoulder
## seams — holder-fixed in world units (her rig's bones ride tiny
## authoring units, #82).
func _tailor_jacket(holder: Node3D, def: Dictionary) -> void:
	if holder.get_child_count() == 0:
		return
	var model: Node3D = holder.get_child(0)
	var h := _visual_height(model) * model.scale.y
	if h <= 0.1:
		return
	var gear := Node3D.new()
	holder.add_child(gear)
	var jacket: Color = def.get("shirt", Color(0.55, 0.30, 0.36))
	var collar := CylinderMesh.new()
	collar.top_radius = 0.048 * h
	collar.bottom_radius = 0.050 * h
	collar.height = 0.032 * h
	_held_mesh(gear, collar, _solid(jacket.darkened(0.18)),
			Transform3D(Basis(), Vector3(0.0, 0.855 * h, -0.030 * h)))
	var zip := BoxMesh.new()
	zip.size = Vector3(0.008 * h, 0.22 * h, 0.006 * h)
	_held_mesh(gear, zip, _solid(Color(0.78, 0.76, 0.72)),
			Transform3D(Basis(), Vector3(0.0, 0.71 * h, -0.052 * h)))
	for sx in [-0.055, 0.055]:
		var seam := BoxMesh.new()
		seam.size = Vector3(0.007 * h, 0.012 * h, 0.10 * h)
		_held_mesh(gear, seam, _solid(jacket.darkened(0.30)),
				Transform3D(Basis(), Vector3(float(sx) * h, 0.82 * h, 0.0)))


## Sleeveless wool vest: front + back chest panels with a shoulder
## yoke, bone-attached to the chest so it rides every torso lean. Flat
## panels instead of a shell keep the swinging arms clear.
func _vest(tk: Dictionary, jacket: Color) -> void:
	var att: BoneAttachment3D = tk["att"]
	var xf: Transform3D = tk["xf"]
	var u: float = tk["u"]
	var mat := _solid(jacket)
	for z in [0.62, -0.62]:
		var panel := BoxMesh.new()
		panel.size = Vector3(1.5 * u, 1.6 * u, 0.16 * u)
		_bone_mesh(att, xf, panel, mat,
				Transform3D(Basis(), Vector3(0.0, 0.1 * u, z * u)))
	var yoke := BoxMesh.new()
	yoke.size = Vector3(1.75 * u, 0.3 * u, 0.85 * u)
	_bone_mesh(att, xf, yoke, mat,
			Transform3D(Basis(), Vector3(0.0, 0.85 * u, 0.0)))


## Monty's slicked-back hair: the crop sphere with a low-roughness
## finish so it reads glossy, pushed flat and slightly back.
func _slick_hair(kit: Dictionary, hair: Color) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = hair
	mat.roughness = 0.22
	# Issue 160: combed-back strand grain keeps the gloss — the detail
	# lives in the albedo, the sheen stays authored.
	Fabrics.apply_detail(mat, "hair", 10.0)
	var crop := SphereMesh.new()
	crop.radius = 0.5 * u
	crop.height = 0.98 * u
	_bone_mesh(att, xf, crop, mat,
			Transform3D(Basis().scaled(Vector3(1.02, 0.66, 1.06)),
					Vector3(0.0, 0.5 * u, -0.02 * u)))


## One dark slab across the eyes — sunglasses that read at gameplay
## scale and ride every head nod.
func _shades(kit: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.04)
	mat.roughness = 0.3
	var slab := BoxMesh.new()
	slab.size = Vector3(0.92 * u, 0.2 * u, 0.12 * u)
	_bone_mesh(att, xf, slab, mat,
			Transform3D(Basis(), Vector3(0.0, 0.3 * u, 0.54 * u)))


## Gold chain at the collarbone plus an open-collar V of skin below
## the throat, both riding the chest bone.
func _chain_and_collar(tk: Dictionary, skin: Color) -> void:
	var att: BoneAttachment3D = tk["att"]
	var xf: Transform3D = tk["xf"]
	var u: float = tk["u"]
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.25)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var chain := TorusMesh.new()
	chain.inner_radius = 0.34 * u
	chain.outer_radius = 0.44 * u
	chain.rings = 36
	chain.ring_segments = 8
	_bone_mesh(att, xf, chain, gold,
			Transform3D(Basis().scaled(Vector3(1.0, 0.4, 1.0)),
					Vector3(0.0, 0.95 * u, 0.02 * u)))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.5 * u, 0.42 * u, 0.14 * u)
	_bone_mesh(att, xf, collar, _solid(skin),
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.5),
					Vector3(0.0, 0.72 * u, 0.5 * u)))


## Riya's rider gear, holder-fixed in world units (her rig's bones sit
## in tiny authoring units — issue #82): a helmet slung on the back
## with a strap down to the shoulder, and a ponytail sweeping off the
## back of the head. Sized off the model's rendered height so it fits
## both the title portrait and the street.
func _rider_gear(holder: Node3D, def: Dictionary) -> void:
	if holder.get_child_count() == 0:
		return
	var model: Node3D = holder.get_child(0)
	var h := _visual_height(model) * model.scale.y
	if h <= 0.1:
		return
	var gear := Node3D.new()
	holder.add_child(gear)
	# Helmet: a rider dome resting between the shoulder blades — kept
	# close to the back (issue 152: any further out and it reads as a
	# floating blob rather than slung gear).
	var shell := SphereMesh.new()
	shell.radius = 0.085 * h
	shell.height = 0.17 * h
	_held_mesh(gear, shell, _solid(def.get("helmet", Color(0.93, 0.91, 0.87))),
			Transform3D(Basis(), Vector3(0.0, 0.70 * h, 0.112 * h)))
	# Strap from the helmet down over the shoulder — jacket-colored.
	var strap := BoxMesh.new()
	strap.size = Vector3(0.035 * h, 0.2 * h, 0.03 * h)
	_held_mesh(gear, strap, _solid(def.get("shirt", Color.WHITE)),
			Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.18),
					Vector3(0.0, 0.6 * h, 0.135 * h)))
	# Ponytail (issue 160): a strand-textured mass off the back of the
	# head, swept down-back, with fanned strand locks and a dark tie
	# band — hair, not a solid peg.
	var hair: Color = def.get("hair", Color(0.14, 0.09, 0.06))
	var hmat := _hair_mat(hair)
	var tail := CapsuleMesh.new()
	tail.radius = 0.018 * h
	tail.height = 0.15 * h
	_held_mesh(gear, tail, hmat,
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.6),
					Vector3(0.0, 0.86 * h, 0.075 * h)))
	for side in [-1, 0, 1]:
		var lock := CapsuleMesh.new()
		lock.radius = 0.007 * h
		lock.height = 0.13 * h
		_held_mesh(gear, lock, hmat,
				Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.6 + side * 0.16)
						* Basis(Vector3.UP, side * 0.10),
						Vector3(side * 0.012 * h, 0.845 * h, 0.078 * h)))
	var tie := TorusMesh.new()
	tie.inner_radius = 0.016 * h
	tie.outer_radius = 0.024 * h
	tie.rings = 20
	tie.ring_segments = 8
	_held_mesh(gear, tie, _solid(Color(0.10, 0.08, 0.07)),
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.6),
					Vector3(0.0, 0.885 * h, 0.070 * h)))


## Holder-fixed mesh at a world-unit transform (no bone riding).
func _held_mesh(parent: Node3D, mesh: PrimitiveMesh, mat: StandardMaterial3D,
		desired: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = desired
	parent.add_child(mi)


## Chest-bone rig for torso kit: finds the upper spine bone (the male
## rig's spine_03), sizes one unit off the skeleton span, and returns a
## live attachment plus its rest frame ({} when no chest bone exists).
func _torso_kit(holder: Node3D) -> Dictionary:
	var skel: Skeleton3D = null
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		skel = skel_node
		break
	if skel == null:
		return {}
	var chest := -1
	for i in skel.get_bone_count():
		var n: String = skel.get_bone_name(i).to_lower()
		if n == "spine_03" or n == "spine_02" or n == "torso":
			chest = i
			break
	if chest < 0:
		return {}
	var top := -INF
	var bottom := INF
	for i in skel.get_bone_count():
		var p := skel.get_bone_global_rest(i).origin
		top = maxf(top, p.y)
		bottom = minf(bottom, p.y)
	var u: float = (top - bottom) * 0.155
	var att := BoneAttachment3D.new()
	att.bone_idx = chest
	skel.add_child(att)
	return {"att": att, "xf": skel.get_bone_global_rest(chest), "u": u}


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
	Color(0.72, 0.48, 0.18), Color(0.24, 0.45, 0.45), Color(0.60, 0.28, 0.36),
	Color(0.92, 0.90, 0.86), Color(0.22, 0.30, 0.44), Color(0.45, 0.50, 0.25),
	Color(0.64, 0.34, 0.26), Color(0.46, 0.36, 0.50), Color(0.78, 0.60, 0.30),
	Color(0.20, 0.20, 0.24),
]
const ID_BOTTOMS := [
	Color(0.14, 0.18, 0.30), Color(0.30, 0.30, 0.34), Color(0.32, 0.24, 0.18),
	Color(0.10, 0.10, 0.12), Color(0.62, 0.55, 0.40), Color(0.45, 0.50, 0.55),
]
## Hair shades (issue 160): a black-brown spectrum — the roll lerps a
## random step between adjacent stops so no two heads share a flat
## shade, and elders wash subtly grey off whichever stop they drew.
const ID_HAIRS := [
	Color(0.05, 0.035, 0.03), Color(0.09, 0.06, 0.045),
	Color(0.15, 0.10, 0.06), Color(0.23, 0.15, 0.08),
	Color(0.34, 0.23, 0.13),
]
const HAIR_GREY := Color(0.56, 0.54, 0.51)
const ID_HATS := [
	Color(0.95, 0.55, 0.12), Color(0.92, 0.90, 0.86), Color(0.35, 0.16, 0.12),
	Color(0.85, 0.72, 0.20), Color(0.45, 0.50, 0.25), Color(0.55, 0.35, 0.60),
]


## Indian street wardrobe (issue #134), reference-driven: the art-ref
## crowd reads Indian through loose long kurtas, wrapped lungis, saree
## silhouettes on the women, maroon porter shirts with head-load
## bundles, and khaki security — layered over the same tint slots.
const W_WESTERN := 0
const W_KURTA := 1
const W_LUNGI := 2
const W_SAREE := 3
const KURTA_TOPS := [
	Color(0.93, 0.90, 0.84), Color(0.96, 0.94, 0.90), Color(0.91, 0.74, 0.32),
	Color(0.66, 0.79, 0.90), Color(0.88, 0.84, 0.95), Color(0.92, 0.88, 0.70),
]
const KURTA_BOTTOMS := [
	Color(0.92, 0.90, 0.86), Color(0.20, 0.20, 0.24), Color(0.76, 0.71, 0.60),
]
const LUNGI_COLORS := [
	Color(0.93, 0.91, 0.86), Color(0.85, 0.80, 0.68), Color(0.56, 0.61, 0.70),
	Color(0.63, 0.46, 0.36), Color(0.80, 0.76, 0.66),
]
const SAREE_COLORS := [
	Color(0.68, 0.30, 0.38), Color(0.18, 0.45, 0.42), Color(0.72, 0.45, 0.18),
	Color(0.55, 0.30, 0.45), Color(0.72, 0.63, 0.26), Color(0.30, 0.42, 0.55),
]
const BLOUSE_DARKS := [
	Color(0.26, 0.07, 0.12), Color(0.10, 0.13, 0.30), Color(0.10, 0.10, 0.11),
	Color(0.07, 0.25, 0.16),
]
const PORTER_RED := Color(0.62, 0.16, 0.12)
const GUARD_KHAKI := Color(0.56, 0.51, 0.38)
const GUARD_KHAKI_DARK := Color(0.44, 0.40, 0.30)
const BUNDLE_CLOTH := Color(0.90, 0.86, 0.78)


## Roll a full identity from `seed`: deterministic, so a given NPC
## always dresses the same while different seeds never collide twice in
## one crowd. `female` rolls the women's wardrobe branch (saree /
## kameez) — the caller knows which model it picked.
static func identity(seed: int, female := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Issue 160: hair rolls a lerped step across the black-brown
	# spectrum; roughly 1 in 8 walkers is an elder washed subtly grey.
	var hi := rng.randi_range(0, ID_HAIRS.size() - 2)
	var shade: Color = ID_HAIRS[hi].lerp(ID_HAIRS[hi + 1], rng.randf() * 0.8)
	var elder := rng.randf() < 0.12
	if elder:
		shade = shade.lerp(HAIR_GREY, 0.45 + rng.randf() * 0.2)
	var part := rng.randi_range(0, 2) - 1
	var id := {
		"seed": seed,
		"skin": ID_SKINS[rng.randi_range(0, ID_SKINS.size() - 1)],
		"shirt": ID_TOPS[rng.randi_range(0, ID_TOPS.size() - 1)],
		"pants": ID_BOTTOMS[rng.randi_range(0, ID_BOTTOMS.size() - 1)],
		"hair": shade,
		"hat": ID_HATS[rng.randi_range(0, ID_HATS.size() - 1)],
		# 0 authored-only, 1 crop, 2 crop + bun, 3 crop + ponytail
		"hair_style": rng.randi_range(0, 3),
		# 0 none, 1 cap, 2 wrap, 3 patka, 4 headband
		"headwear": rng.randi_range(0, 4),
		"elder": elder,
		# Parting side for the hair kit: -1 left, 0 center, 1 right.
		"part": part,
		"height": rng.randf_range(0.93, 1.07),
	}
	_wardrobe_roll(id, rng, female)
	return id


## Layer the Indian street wardrobe onto the identity roll (issue
## #134): outfit style + role re-style the palette slots so the tint
## and the wardrobe meshes agree, then meshes are attached in
## _wardrobe(). Porters wear the maroon long shirt; guards wear khaki
## plus a cap.
static func _wardrobe_roll(id: Dictionary, rng: RandomNumberGenerator,
		female: bool) -> void:
	var outfit := W_WESTERN
	var r := rng.randf()
	if female:
		outfit = W_SAREE if r < 0.45 else (W_KURTA if r < 0.75 else W_WESTERN)
	else:
		outfit = W_KURTA if r < 0.40 else (W_LUNGI if r < 0.70 else W_WESTERN)
	var role := 0
	var rr := rng.randf()
	if not female and rr < 0.10:
		role = 1
	elif rr > 0.92:
		role = 2
	id["outfit"] = outfit
	id["role"] = role
	match role:
		1:
			# Porter: maroon long shirt (kurta cut) + dark trousers + head load.
			id["shirt"] = PORTER_RED
			id["pants"] = Color(0.16, 0.16, 0.20)
			id["outfit"] = W_KURTA
			id["headwear"] = 0
		2:
			# Security: khaki shirt + darker khaki trousers + khaki cap.
			id["shirt"] = GUARD_KHAKI
			id["pants"] = GUARD_KHAKI_DARK
			id["hat"] = GUARD_KHAKI_DARK
			id["headwear"] = 1
			id["outfit"] = W_WESTERN
			if female:
				id["headwear"] = 0
		_:
			match outfit:
				W_KURTA:
					id["shirt"] = KURTA_TOPS[rng.randi_range(0, KURTA_TOPS.size() - 1)]
					id["pants"] = KURTA_BOTTOMS[rng.randi_range(0, KURTA_BOTTOMS.size() - 1)]
				W_LUNGI:
					id["shirt"] = KURTA_TOPS[rng.randi_range(0, KURTA_TOPS.size() - 1)]
					id["pants"] = LUNGI_COLORS[rng.randi_range(0, LUNGI_COLORS.size() - 1)]
				W_SAREE:
					id["pants"] = SAREE_COLORS[rng.randi_range(0, SAREE_COLORS.size() - 1)]
					id["shirt"] = BLOUSE_DARKS[rng.randi_range(0, BLOUSE_DARKS.size() - 1)]
	# Issue 158: footwear roll, weighted by outfit so the street reads
	# right — western walkers in sneakers/formal shoes, kurta/lungi and
	# saree wearers in chappals/sandals. 0 chappal, 1 sandal, 2 sneaker,
	# 3 formal shoe.
	var shoes := 0
	var sr := rng.randf()
	match outfit:
		W_WESTERN:
			if female:
				shoes = 1 if sr < 0.30 else (2 if sr < 0.55 else 3)
			else:
				shoes = 2 if sr < 0.55 else 3
		W_KURTA:
			shoes = 0 if sr < 0.50 else (1 if sr < 0.80 else 3)
		W_LUNGI:
			shoes = 0 if sr < 0.60 else 1
		W_SAREE:
			shoes = 1 if sr < 0.70 else 0
	id["shoes"] = shoes


## Apply a full identity: palette tint (authored hair recolors to the
## seed shade), then procedural hair and headwear on rigs that ship
## bald. Authored-hair rigs (the female walkers) keep their modeled
## hair: their bones ride tiny authoring units (issue #82), so
## bone-space accessories render misplaced — recolor + outfit + body
## slots carry their variety instead. Wardrobe meshes (issue #134)
## attach holder-fixed in world units, so they fit every rig alike.
func dress(holder: Node3D, id: Dictionary) -> void:
	tint(holder, id["shirt"], id["pants"], id["skin"], id["hair"])
	_wardrobe(holder, id)
	_footwear(holder, id)
	if _has_authored_hair(holder):
		# Issue #153: authored-hair rigs (the female walkers) get faces
		# too — holder-fixed in world units, since their bones ride tiny
		# authoring units (issue #82) where bone-space parts land wrong.
		_attach_face_held(holder, id)
		return
	var kit := _head_kit(holder)
	if kit.is_empty():
		return
	_attach_face(kit, id)
	if int(id["hair_style"]) > 0:
		_attach_hair(kit, id)
	if int(id["headwear"]) > 0:
		_attach_headwear(kit, id)


## Wardrobe meshes (issue #134): long kurta skirt, wrapped lungi,
## saree skirt + pallu, porter head-load bundle. All holder-fixed in
## world units off the rendered height (the pattern _rider_gear uses,
## so tiny-authoring-bone female rigs are dressed just as correctly
## as the universal male) and all procedural primitives.
func _wardrobe(holder: Node3D, id: Dictionary) -> void:
	if holder.get_child_count() == 0:
		return
	var model: Node3D = holder.get_child(0)
	var h := _visual_height(model) * model.scale.y
	if h <= 0.1:
		return
	var gear := Node3D.new()
	holder.add_child(gear)
	match int(id.get("outfit", W_WESTERN)):
		W_KURTA:
			# Kurta/kameez: loose tunic skirt from waist to the knees.
			var skirt := CylinderMesh.new()
			skirt.top_radius = 0.085 * h
			skirt.bottom_radius = 0.125 * h
			skirt.height = 0.27 * h
			_held_mesh(gear, skirt, _solid(id["shirt"]),
					Transform3D(Basis(), Vector3(0.0, 0.40 * h, 0.0)))
		W_LUNGI:
			# Lungi: wrapped cloth from waist to the ankles.
			var wrap := CylinderMesh.new()
			wrap.top_radius = 0.088 * h
			wrap.bottom_radius = 0.105 * h
			wrap.height = 0.50 * h
			_held_mesh(gear, wrap, _solid(id["pants"]),
					Transform3D(Basis(), Vector3(0.0, 0.30 * h, 0.0)))
		W_SAREE:
			# Saree: fitted-ankle skirt in the saree fabric, plus the
			# pallu — a long drape from the right hip up over the left
			# shoulder, so the silhouette reads at gameplay scale.
			var petticoat := CylinderMesh.new()
			petticoat.top_radius = 0.078 * h
			petticoat.bottom_radius = 0.098 * h
			petticoat.height = 0.50 * h
			_held_mesh(gear, petticoat, _solid(id["pants"]),
					Transform3D(Basis(), Vector3(0.0, 0.30 * h, 0.0)))
			var pallu := BoxMesh.new()
			pallu.size = Vector3(0.13 * h, 0.62 * h, 0.02 * h)
			var xf := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.55)
					* Basis(Vector3.UP, 0.5), Vector3(0.0, 0.56 * h, 0.0))
			_held_mesh(gear, pallu, _solid(id["pants"]), xf)
	if int(id.get("role", 0)) == 1:
		# Porter head-load: a cloth-wrapped bundle balanced on a ring, in
		# world units off the rendered height (the same holder-fixed
		# pattern as the skirts — head-bone space proved unreliable for
		# this offset, the wardrobe gate measures the result instead).
		var bundle := SphereMesh.new()
		bundle.radius = 0.055 * h
		bundle.height = 0.11 * h
		_held_mesh(gear, bundle, _solid(BUNDLE_CLOTH),
				Transform3D(Basis().scaled(Vector3(1.15, 0.62, 1.15)),
						Vector3(0.0, 0.975 * h, 0.0)))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.033 * h
		ring.outer_radius = 0.046 * h
		ring.rings = 36
		ring.ring_segments = 8
		_held_mesh(gear, ring, _solid(BUNDLE_CLOTH),
				Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)),
						Vector3(0.0, 0.925 * h, 0.0)))


## Footwear (issue 158): every walker gets defined shoes so feet stop
## reading as bare clumps at gameplay distance. Four styles — chappal,
## sandal, sneaker, formal shoe — from the identity roll. Rigs with
## foot bones (the universal male) get bone-attached shoes that ride
## the walk cycle; tiny-authoring-unit rigs (the female walkers,
## issue #82) get holder-fixed soles at ground level, the same pattern
## as the wardrobe skirts. All procedural primitives, zero assets.
const SHOE_SOLES := {
	0: Color(0.16, 0.14, 0.12),
	1: Color(0.38, 0.24, 0.14),
	2: Color(0.78, 0.76, 0.72),
	3: Color(0.10, 0.08, 0.08),
}
const SHOE_UPPERS := {
	0: Color(0.16, 0.14, 0.12),
	1: Color(0.34, 0.21, 0.12),
	2: Color(0.66, 0.63, 0.58),
	3: Color(0.07, 0.06, 0.06),
}


func _footwear(holder: Node3D, id: Dictionary) -> void:
	if holder.get_child_count() == 0:
		return
	var model: Node3D = holder.get_child(0)
	var style := int(id.get("shoes", 0))
	var skel: Skeleton3D = null
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		skel = skel_node
		break
	var feet := {}
	if skel != null:
		for i in skel.get_bone_count():
			var n := skel.get_bone_name(i).to_lower()
			if n == "foot_l" or n == "foot.1" or n == "foot_l_end":
				feet["l"] = i
			elif n == "foot_r" or n == "foot.0" or n == "foot_r_end":
				feet["r"] = i
	if feet.has("l") and feet.has("r"):
		# Bone-attached path (universal male rig): shoes ride the walk.
		var span := _bone_span(model)
		if span <= 0.01:
			return
		var fu := span * 0.150  # one foot unit ~= one head unit
		var sole: Color = SHOE_SOLES.get(style, SHOE_SOLES[0])
		var upper: Color = SHOE_UPPERS.get(style, SHOE_UPPERS[0])
		for side_key in ["l", "r"]:
			var idx: int = feet[side_key]
			var rest := skel.get_bone_global_rest(idx).origin
			var att := BoneAttachment3D.new()
			att.bone_idx = idx
			skel.add_child(att)
			var toe_out := 0.12 if side_key == "l" else -0.12
			var sole_thick: float = {0: 0.05, 1: 0.09, 2: 0.11, 3: 0.08}.get(style, 0.06)
			# Sole: ground level in bone-local space (rest.y is the ankle
			# height), centered over the foot's heel-to-toe span, toes out.
			var sm := BoxMesh.new()
			sm.size = Vector3(0.42 * fu, sole_thick * fu, 1.02 * fu)
			_bone_mesh(att, Transform3D.IDENTITY, sm, _solid(sole),
					Transform3D(Basis(Vector3.UP, toe_out),
						Vector3(0.0, -rest.y + sole_thick * fu * 0.5,
								0.23 * fu)))
			match style:
				0:
					# Chappal: a single toe strap across the instep.
					var strap := BoxMesh.new()
					strap.size = Vector3(0.07 * fu, 0.05 * fu, 0.62 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, strap, _solid(sole),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + sole_thick * fu + 0.02 * fu,
											0.28 * fu)))
				1:
					# Sandal: instep band + heel strap.
					var band := BoxMesh.new()
					band.size = Vector3(0.40 * fu, 0.06 * fu, 0.18 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, band, _solid(upper),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + (sole_thick + 0.04) * fu,
											0.38 * fu)))
					var heel := BoxMesh.new()
					heel.size = Vector3(0.36 * fu, 0.34 * fu, 0.07 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, heel, _solid(upper),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + (sole_thick + 0.14) * fu,
											-0.30 * fu)))
				2:
					# Sneaker: padded upper + darker toe cap.
					var body := BoxMesh.new()
					body.size = Vector3(0.40 * fu, 0.40 * fu, 0.86 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, body, _solid(upper),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + (sole_thick + 0.20) * fu,
											0.20 * fu)))
					var cap := BoxMesh.new()
					cap.size = Vector3(0.38 * fu, 0.20 * fu, 0.28 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, cap,
								solid_dark(sole, 0.35),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + (sole_thick + 0.10) * fu,
											0.55 * fu)))
				3:
					# Formal: closed upper + rear heel block.
					var body := BoxMesh.new()
					body.size = Vector3(0.38 * fu, 0.34 * fu, 0.84 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, body, _solid(upper),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + (sole_thick + 0.17) * fu,
											0.22 * fu)))
					var block := BoxMesh.new()
					block.size = Vector3(0.38 * fu, 0.09 * fu, 0.26 * fu)
					_bone_mesh(att, Transform3D.IDENTITY, block, _solid(upper),
							Transform3D(Basis(Vector3.UP, toe_out),
									Vector3(0.0, -rest.y + 0.045 * fu,
											-0.28 * fu)))
	else:
		# Holder-fixed fallback (female rigs): a defined sole under each
		# foot line, in world units off the rendered height — skirts and
		# sarees cover most of the foot, so the sole carries the read.
		var h := _visual_height(model) * model.scale.y
		if h <= 0.1:
			return
		var sole_c: Color = SHOE_SOLES.get(style, SHOE_SOLES[0])
		for side_x in [-0.048, 0.048]:
			var sm := BoxMesh.new()
			sm.size = Vector3(0.058 * h, 0.022 * h, 0.115 * h)
			_held_mesh(holder, sm, _solid(sole_c), Transform3D(Basis(
					Vector3.UP, 0.10 if side_x < 0.0 else -0.10),
					Vector3(side_x * h, 0.012 * h, -0.035 * h)))
			if style == 2 or style == 3:
				var up := BoxMesh.new()
				up.size = Vector3(0.052 * h, 0.055 * h, 0.095 * h)
				_held_mesh(holder, up, _solid(
						SHOE_UPPERS.get(style, SHOE_UPPERS[0])),
					Transform3D(Basis(Vector3.UP,
								0.10 if side_x < 0.0 else -0.10),
						Vector3(side_x * h, 0.048 * h, -0.038 * h)))


func solid_dark(c: Color, amt: float) -> StandardMaterial3D:
	return _solid(c.darkened(amt))


## Female-walker faces (issue #153): the #149 vocabulary — sclera
## band, dark pupils, hair-shade brows — but holder-fixed in world
## units off the rendered height (the _wardrobe pattern), because the
## authored-hair rigs keep tiny authoring bones (issue #82). Holder -Z
## is the character's forward.
func _attach_face_held(holder: Node3D, id: Dictionary) -> void:
	if holder.get_child_count() == 0:
		return
	var model: Node3D = holder.get_child(0)
	var h := _visual_height(model) * model.scale.y
	if h <= 0.1:
		return
	var gear := Node3D.new()
	holder.add_child(gear)
	var shade: Color = id["hair"]
	var band := BoxMesh.new()
	band.size = Vector3(0.080 * h, 0.018 * h, 0.014 * h)
	_held_mesh(gear, band, _solid(Color(0.95, 0.93, 0.88)),
			Transform3D(Basis(), Vector3(0.0, 0.905 * h, -0.048 * h)))
	for side in [-0.0175, 0.0175]:
		var pupil := BoxMesh.new()
		pupil.size = Vector3(0.016 * h, 0.017 * h, 0.012 * h)
		_held_mesh(gear, pupil, _solid(Color(0.07, 0.05, 0.04)),
				Transform3D(Basis(), Vector3(side * h, 0.905 * h, -0.054 * h)))
	for side_b in [-0.0185, 0.0185]:
		var brow := BoxMesh.new()
		brow.size = Vector3(0.032 * h, 0.007 * h, 0.009 * h)
		_held_mesh(gear, brow, _solid(shade.darkened(0.15)),
				Transform3D(Basis(), Vector3(side_b * h, 0.926 * h, -0.045 * h)))
	# Issue 159: sculpted shading decals — sockets ring the sclera
	# band, nose-side shade, lip tone, cheek warmth, under-jaw shadow.
	var skin: Color = id["skin"]
	var cols := _sculpt_colors(skin)
	for side_s in [-0.024, 0.024]:
		var socket := BoxMesh.new()
		socket.size = Vector3(0.045 * h, 0.026 * h, 0.006 * h)
		_held_mesh(gear, socket, _solid(cols[0]),
				Transform3D(Basis(),
						Vector3(side_s * h, 0.903 * h, -0.046 * h)))
		var cheek := BoxMesh.new()
		cheek.size = Vector3(0.024 * h, 0.020 * h, 0.006 * h)
		_held_mesh(gear, cheek, _solid(cols[3]),
				Transform3D(Basis(),
						Vector3(side_s * 1.6 * h, 0.893 * h, -0.043 * h)))
	for side_n in [-0.0075, 0.0075]:
		var nose := BoxMesh.new()
		nose.size = Vector3(0.009 * h, 0.042 * h, 0.006 * h)
		_held_mesh(gear, nose, _solid(cols[1]),
				Transform3D(Basis(),
						Vector3(side_n * h, 0.888 * h, -0.049 * h)))
	var lip := BoxMesh.new()
	lip.size = Vector3(0.032 * h, 0.012 * h, 0.006 * h)
	_held_mesh(gear, lip, _solid(cols[2]),
			Transform3D(Basis(), Vector3(0.0, 0.878 * h, -0.050 * h)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.084 * h, 0.026 * h, 0.006 * h)
	_held_mesh(gear, jaw, _solid(cols[4]),
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.35),
				Vector3(0.0, 0.866 * h, -0.040 * h)))


## Sculpted-face shading palette (issue 159): the baked-AO decal
## vocabulary — recessed sockets, nose-side shade, lip tone distinct
## from skin, cheek warmth, under-jaw shadow — derived from each
## walker's own skin tone so every palette shades coherently.
func _sculpt_colors(skin: Color) -> Array[Color]:
	return [
		skin.darkened(0.24),  # sockets
		skin.darkened(0.16),  # nose sides
		Color(skin.r * 0.92, skin.g * 0.66, skin.b * 0.60),  # lips
		skin.lerp(Color(0.82, 0.48, 0.38), 0.18),  # cheek warmth
		skin.darkened(0.20),  # under-jaw shadow
	]


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


## Face features (issue #123): readable low-poly faces — one sclera
## band with two dark pupils and a pair of brows in the walker's hair
## shade, all bone-attached so they ride every head nod. Sized off the
## same head units as the hair and headwear kits.
func _attach_face(kit: Dictionary, id: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var head_xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var shade: Color = id["hair"]
	var band := BoxMesh.new()
	band.size = Vector3(0.34 * u, 0.09 * u, 0.03 * u)
	_bone_mesh(att, head_xf, band, _solid(Color(0.95, 0.93, 0.88)),
			Transform3D(Basis(), Vector3(0.0, 0.42 * u, 0.49 * u)))
	for side in [-0.085, 0.085]:
		var pupil := BoxMesh.new()
		pupil.size = Vector3(0.065 * u, 0.07 * u, 0.032 * u)
		_bone_mesh(att, head_xf, pupil, _solid(Color(0.07, 0.05, 0.04)),
				Transform3D(Basis(), Vector3(side * u, 0.42 * u, 0.51 * u)))
	for side_b in [-0.09, 0.09]:
		var brow := BoxMesh.new()
		brow.size = Vector3(0.15 * u, 0.03 * u, 0.035 * u)
		_bone_mesh(att, head_xf, brow, _solid(shade.darkened(0.15)),
				Transform3D(Basis(), Vector3(side_b * u, 0.53 * u, 0.495 * u)))
	# Issue 159: sculpted shading decals on the bone-attached path —
	# sockets ring the sclera band, nose-side shade, lip tone, cheek
	# warmth, under-jaw shadow.
	var skin: Color = id["skin"]
	var cols := _sculpt_colors(skin)
	for side_s in [-0.105, 0.105]:
		var socket := BoxMesh.new()
		socket.size = Vector3(0.19 * u, 0.12 * u, 0.02 * u)
		_bone_mesh(att, head_xf, socket, _solid(cols[0]),
				Transform3D(Basis(),
						Vector3(side_s * u, 0.41 * u, 0.47 * u)))
		var cheek := BoxMesh.new()
		cheek.size = Vector3(0.10 * u, 0.09 * u, 0.02 * u)
		_bone_mesh(att, head_xf, cheek, _solid(cols[3]),
				Transform3D(Basis(),
						Vector3(side_s * 1.4 * u, 0.30 * u, 0.455 * u)))
	for side_n in [-0.03, 0.03]:
		var nose := BoxMesh.new()
		nose.size = Vector3(0.035 * u, 0.16 * u, 0.02 * u)
		_bone_mesh(att, head_xf, nose, _solid(cols[1]),
				Transform3D(Basis(),
						Vector3(side_n * u, 0.31 * u, 0.49 * u)))
	var lip := BoxMesh.new()
	lip.size = Vector3(0.13 * u, 0.045 * u, 0.02 * u)
	_bone_mesh(att, head_xf, lip, _solid(cols[2]),
			Transform3D(Basis(), Vector3(0.0, 0.17 * u, 0.49 * u)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.34 * u, 0.10 * u, 0.02 * u)
	_bone_mesh(att, head_xf, jaw, _solid(cols[4]),
			Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.35),
				Vector3(0.0, 0.05 * u, 0.43 * u)))


## Hair as shaped masses (issue 160): the solid cap becomes a strand-
## textured crop tilted with the part roll, a combed-over crown ridge,
## a fringe lock past the brow and a parting groove meeting a small
## crown whorl — left / center / right per identity. Buns and
## ponytails keep their style mass plus a darker tie. Headwear hides
## the brow pieces, so those skip under caps and wraps.
func _attach_hair(kit: Dictionary, id: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	var shade: Color = id["hair"]
	var mat := _hair_mat(shade)
	var dark := _solid(shade.darkened(0.45))
	var part := int(id.get("part", 0))
	var bare := int(id.get("headwear", 0)) == 0
	var crop := SphereMesh.new()
	crop.radius = 0.52 * u
	crop.height = 1.02 * u
	_bone_mesh(att, xf, crop, mat,
			Transform3D(Basis(Vector3(0.0, 0.0, 1.0), part * 0.07)
					* Basis().scaled(Vector3(1.0, 0.74, 1.0)),
					Vector3(part * 0.03 * u, 0.52 * u, 0.0)))
	if bare:
		# Crown ridge: a combed-over ellipsoid riding the top of the
		# crop, swept toward the part side — the shaped-mass read.
		var ridge := SphereMesh.new()
		ridge.radius = 0.34 * u
		ridge.height = 0.68 * u
		_bone_mesh(att, xf, ridge, mat,
				Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -part * 0.06)
						* Basis().scaled(Vector3(0.80, 0.30, 1.30)),
						Vector3(part * 0.08 * u, 0.95 * u, 0.10 * u)))
		# Fringe lock: volume poking past the crop above the brow,
		# pushed to the part side; its underside sits at 0.55u so brows
		# (0.53u) and pupils (0.42u) stay clear.
		var fringe := SphereMesh.new()
		fringe.radius = 0.28 * u
		fringe.height = 0.56 * u
		_bone_mesh(att, xf, fringe, mat,
				Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -part * 0.08)
						* Basis().scaled(Vector3(0.85, 0.45, 1.0)),
						Vector3(part * 0.08 * u, 0.68 * u, 0.36 * u)))
	# Parting groove: a thin darker seam along the crown where the
	# mass divides, offset to the part side.
	var seam := BoxMesh.new()
	seam.size = Vector3(0.035 * u, 0.045 * u, 0.50 * u)
	_bone_mesh(att, xf, seam, dark,
			Transform3D(Basis(Vector3(0.0, 0.0, 1.0), part * 0.07),
					Vector3(part * 0.15 * u, 0.90 * u, -0.02 * u)))
	if bare:
		# Crown whorl: a small dark ring on the back of the crown —
		# the swirl the strands seem to comb out of.
		var whorl := TorusMesh.new()
		whorl.inner_radius = 0.05 * u
		whorl.outer_radius = 0.10 * u
		whorl.rings = 24
		whorl.ring_segments = 8
		_bone_mesh(att, xf, whorl, dark,
				Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.35)
						* Basis().scaled(Vector3(1.0, 0.50, 1.0)),
						Vector3(part * 0.04 * u, 0.88 * u, -0.16 * u)))
	match int(id["hair_style"]):
		2:
			var bun := SphereMesh.new()
			bun.radius = 0.22 * u
			bun.height = 0.44 * u
			_bone_mesh(att, xf, bun, mat,
					Transform3D(Basis().scaled(Vector3(1.0, 0.85, 1.0)),
						Vector3(0.0, 0.78 * u, -0.44 * u)))
			var tie := TorusMesh.new()
			tie.inner_radius = 0.10 * u
			tie.outer_radius = 0.155 * u
			tie.rings = 24
			tie.ring_segments = 8
			_bone_mesh(att, xf, tie, _solid(Color(0.10, 0.08, 0.07)),
					Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)),
						Vector3(0.0, 0.74 * u, -0.38 * u)))
		3:
			var tail := CapsuleMesh.new()
			tail.radius = 0.13 * u
			tail.height = 0.62 * u
			_bone_mesh(att, xf, tail, mat,
					Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.35),
						Vector3(0.0, 0.42 * u, -0.56 * u)))
			var band := CylinderMesh.new()
			band.top_radius = 0.135 * u
			band.bottom_radius = 0.135 * u
			band.height = 0.07 * u
			_bone_mesh(att, xf, band, _solid(Color(0.10, 0.08, 0.07)),
					Transform3D(Basis(Vector3(1.0, 0.0, 0.0), 0.35),
						Vector3(0.0, 0.58 * u, -0.50 * u)))



func _attach_headwear(kit: Dictionary, id: Dictionary) -> void:
	var att: BoneAttachment3D = kit["att"]
	var xf: Transform3D = kit["xf"]
	var u: float = kit["u"]
	# Issue 160: wraps and patkas take the fold-grain cloth material;
	# caps and headbands stay smooth solids.
	var hw := int(id["headwear"])
	var mat := _wrap_mat(id["hat"]) if hw == 2 or hw == 3 else _solid(id["hat"])
	match hw:
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
			# Issue 160: a diagonal cross-wrap band — the cloth crossing
			# over the layered wraps, folded over itself.
			var cross := TorusMesh.new()
			cross.inner_radius = 0.56 * u
			cross.outer_radius = 0.70 * u
			cross.rings = 40
			cross.ring_segments = 10
			_bone_mesh(att, xf, cross, mat,
					Transform3D(Basis(Vector3(0.0, 0.0, 1.0), 0.5)
						* Basis().scaled(Vector3(1.0, 0.55, 1.0)),
						Vector3(0.0, 0.50 * u, 0.0)))
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


## Strand-flow hair material (issue 160): the tinted shade multiplied
## by the combed-strand texture with its sheen roughness map, so caps
## read as shaped hair masses instead of solid helmets.
func _hair_mat(shade: Color) -> StandardMaterial3D:
	var m := _solid(shade)
	Fabrics.apply_kind(m, "hair", 6.0)
	return m


## Wrapped-cloth material (issue 160): fold-band grain so dastaars and
## wrap turbans read as layered fabric, not smooth solid rings.
func _wrap_mat(cloth: Color) -> StandardMaterial3D:
	var m := _solid(cloth)
	Fabrics.apply_kind(m, "wrap", 4.0)
	return m


## Add `mesh` under `att`, placed at `desired` — a transform in the
## BONE's local frame (offsets from the bone origin), so the piece
## lands at bone + offset in the rest pose and rides the bone rigidly
## through animation. Issue 152: `desired` values across every kit are
## authored as bone-local offsets (0.36u above the head bone, etc.),
## but this used to pre-multiply by the bone rest's inverse — mapping
## the small offsets to skeleton-space y≈0, dropping every turban,
## beard, shade and chain at the model's FEET where the title-screen
## camera (and the street camera) never showed them.
func _bone_mesh(att: BoneAttachment3D, _head_xf: Transform3D, mesh: PrimitiveMesh,
		mat: StandardMaterial3D, desired: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = desired
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
