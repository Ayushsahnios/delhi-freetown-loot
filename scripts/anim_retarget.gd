extends RefCounted
## Animation retarget for the CC0 candidate humans (issue #291 Phase 2).
## The vendored Quaternius Modular bodies ship rigged but UNANIMATED on
## the v2 universal rig (Root/Hips/.../Foot.R). The in-tree female
## rigs (female_a..d) carry the idle/walk/run clips on a v1 rig whose
## CORE CHAIN bone names match the candidates exactly — so the clips
## transfer bone-by-bone with a rest-frame conversion per key:
##
##     pose_t = inverse(global_rest_t) * global_rest_s * pose_s
##
## which re-expresses every keyed absolute bone orientation in the
## target rig's local frame (verified empirically: the two rigs bind
## with mixed axis conventions, so raw track copies mangle limbs).
## Translational keys survive only on the root chain (Body->Root and
## Hips), scaled by the rigs' height-span ratio; foot/shoulder/IK
## position tracks are dropped (rotations carry the gait).
##
## The remapped clips land in a fresh AnimationPlayer on the candidate
## instance named plain "idle"/"walk"/"run", which characters.gd's
## anim_names() discovery picks up unchanged.

const SOURCE := "res://assets/characters/female_a.glb"

## v1 female rig bone -> v2 candidate rig bone.
const BONE_MAP := {
	"Body": "Root",
	"Hips": "Hips",
	"Abdomen": "Abdomen",
	"Torso": "Torso",
	"Neck": "Neck",
	"Head": "Head",
	"Shoulder.L": "Shoulder.L",
	"UpperArm.L": "UpperArm.L",
	"LowerArm.L": "LowerArm.L",
	"Palm.L": "Hand.L",
	"Shoulder.R": "Shoulder.R",
	"UpperArm.R": "UpperArm.R",
	"LowerArm.R": "LowerArm.R",
	"Palm.R": "Hand.R",
	"UpperLeg.L": "UpperLeg.L",
	"LowerLeg.L": "LowerLeg.L",
	"Foot.L": "Foot.L",
	"UpperLeg.R": "UpperLeg.R",
	"LowerLeg.R": "LowerLeg.R",
	"Foot.R": "Foot.R",
}

## Bones that keep their keyed translations (the body bob), converted
## as scaled deltas off each rig's rest offset.
const POSITION_BONES := ["Body", "Hips"]

## Source clip -> emitted clip name (characters.gd anim_names() keys).
const CLIPS := {
	"HumanArmature|Female_Idle": "idle",
	"HumanArmature|Female_Walk": "walk",
	"HumanArmature|Female_Run": "run",
}

static var _source_clips: Dictionary = {}
static var _source_rest: Dictionary = {}
static var _source_span := -1.0


static func attach(model: Node3D) -> void:
	## Give a candidate instance its idle/walk/run AnimationPlayer.
	var skel: Skeleton3D = null
	for s in model.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if skel == null:
		return
	_load_source()
	if _source_clips.is_empty():
		push_error("anim_retarget: source clips missing")
		return
	var lib := AnimationLibrary.new()
	for src_name in CLIPS:
		var src: Animation = _source_clips[src_name]
		lib.add_animation(CLIPS[src_name], _remap(src, skel, model))
	var ap := AnimationPlayer.new()
	ap.name = "RetargetPlayer"
	model.add_child(ap)
	# Track paths are authored against the model root; the player sits
	# directly under it, so the default root ("..") resolves them.
	ap.root_node = ap.get_path_to(model)
	ap.add_animation_library("", lib)


static func _load_source() -> void:
	if not _source_clips.is_empty():
		return
	var ps: PackedScene = load(SOURCE)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	var ap: AnimationPlayer = null
	var skel: Skeleton3D = null
	for a in inst.find_children("*", "AnimationPlayer", true, false):
		ap = a
		break
	for s in inst.find_children("*", "Skeleton3D", true, false):
		skel = s
		break
	if ap == null or skel == null:
		inst.free()
		return
	for clip_name in CLIPS:
		_source_clips[clip_name] = ap.get_animation(clip_name)
	var lo := INF
	var hi := -INF
	for i in skel.get_bone_count():
		var g: Transform3D = skel.get_bone_global_rest(i)
		_source_rest[skel.get_bone_name(i)] = g
		lo = minf(lo, g.origin.y)
		hi = maxf(hi, g.origin.y)
	_source_span = hi - lo
	inst.free()


static func _remap(src: Animation, skel: Skeleton3D, model: Node3D) -> Animation:
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = Animation.LOOP_LINEAR

	var tlo := INF
	var thi := -INF
	for i in skel.get_bone_count():
		var y: float = skel.get_bone_global_rest(i).origin.y
		tlo = minf(tlo, y)
		thi = maxf(thi, y)
	var span_ratio := 1.0
	if _source_span > 0.001 and thi - tlo > 0.001:
		span_ratio = (thi - tlo) / _source_span

	## Per-bone rest conversion: pose_t = inv(gr_t) * gr_s * pose_s.
	var conv := {}
	var trest := {}
	for src_bone in BONE_MAP:
		var dst_bone: String = BONE_MAP[src_bone]
		var di := skel.find_bone(dst_bone)
		if di < 0 or not _source_rest.has(src_bone):
			continue
		var gr_s: Basis = (_source_rest[src_bone] as Transform3D).basis
		var gr_t: Basis = skel.get_bone_global_rest(di).basis
		conv[src_bone] = (gr_t.inverse() * gr_s).get_rotation_quaternion()
		trest[src_bone] = skel.get_bone_rest(di)

	var skel_path := String(model.get_path_to(skel))
	for t in src.get_track_count():
		var path_str := String(src.track_get_path(t))
		if not path_str.contains(":"):
			continue
		var src_bone := path_str.get_slice(":", 1)
		if not BONE_MAP.has(src_bone) or not conv.has(src_bone):
			continue
		var dst_path := NodePath(skel_path + ":" + BONE_MAP[src_bone])
		var kind := src.track_get_type(t)
		if kind == 2:  ## rotation
			var nt := out.add_track(2)
			out.track_set_path(nt, dst_path)
			for k in src.track_get_key_count(t):
				var q: Quaternion = src.track_get_key_value(t, k)
				out.track_insert_key(nt, src.track_get_key_time(t, k),
					(conv[src_bone] as Quaternion) * q)
		elif kind == 1 and POSITION_BONES.has(src_bone):  ## root bob
			var nt := out.add_track(1)
			out.track_set_path(nt, dst_path)
			var rest_s: Vector3 = (_source_rest[src_bone] as Transform3D).origin
			var rest_t: Vector3 = (trest[src_bone] as Transform3D).origin
			for k in src.track_get_key_count(t):
				var p: Vector3 = src.track_get_key_value(t, k)
				out.track_insert_key(nt, src.track_get_key_time(t, k),
					rest_t + (p - rest_s) * span_ratio)
	return out
