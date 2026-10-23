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

## Skeleton bone spans stop short of scalp and soles — pad to full height.
const BONE_PAD := 1.12

## Upright bone extent of the rig's rest pose, in model units. The skinned
## mesh's raw vertex box is meaningless (bind space), the skeleton is not.
static var _span_cache := {}

## Cached height basis per model file (see _size_basis).
static var _basis_cache := {}


## Instantiate `path` sized to `height` world units, facing -Z (the
## project's forward). Returns a holder node; the model is its child.
func spawn(path: String, height: float) -> Node3D:
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("character model missing: " + path)
		return null
	var model: Node3D = ps.instantiate()
	var basis := _size_basis(model)
	if basis > 0.001:
		model.scale = Vector3.ONE * (height / basis)
	var holder := Node3D.new()
	holder.rotation.y = PI
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
## keeps feet on the ground as speed changes.
func play(anims: Dictionary, ap: AnimationPlayer, clip: String, rate: float) -> void:
	if ap == null or not anims.has(clip):
		return
	var full: StringName = anims[clip]
	if ap.current_animation != full or not ap.is_playing():
		ap.play(full, 0.15)
	ap.speed_scale = clampf(rate, 0.55, 1.75)


## Recolor clothing/skin slots. The GLB materials name their parts
## (Shirt/Jacket/Pants/Skin/... for the women, M_Main/M_Joints for the
## universal-rig male), so the match is by material name. Colors are
## baked into a per-instance copy of the mesh, so every surface keeps a
## real material — never a null slot for the renderer to trip on.
func tint(holder: Node3D, shirt: Color, pants: Color, skin: Color) -> void:
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
				## Hair/eyes/eyebrows keep their authored look.
				continue
			var m := (base as StandardMaterial3D).duplicate()
			m.albedo_color = shirt if role == "shirt" else pants if role == "pants" else skin
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
	var skel: Skeleton3D = null
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		skel = skel_node
		break
	if skel == null:
		return
	var head := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).to_lower() == "head":
			head = i
			break
	if head < 0:
		return
	var head_xf: Transform3D = skel.get_bone_global_rest(head)
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
