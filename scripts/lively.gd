class_name LivelyRig
extends SkeletonModifier3D
## Procedural liveliness layer for every rigged human (issue 122).
##
## The CC0 base clips are loop-perfect, so an untouched crowd reads as
## robots: identical loops, lock-step timing, statue idles. This modifier
## runs after the AnimationPlayer each frame and layers seeded, per-body
## motion on top:
##   - head/neck look-around wander (amplitude eases down as the body
##     moves faster, so sprinters keep their eyes forward),
##   - idle weight-shift sway on the model node,
##   - a phone-idle variant (head down, occasional glance up) rolled
##     from the same seed that dresses the body,
##   - banked lean into turns and a slight forward lean at speed, read
##     from the holder's motion — no per-caller wiring needed,
##   - a `talking` flag that adds rhythmic nod accents for dialogue
##     givers.
## Bone writes always compose on a captured base pose (never accumulate
## on the animated value), and model-node writes compose on the rest
## rotation the factory set, so recycled walkers can never drift.

## Motion seed: rolls the wander frequencies/phases and the phone
## variant, so no two bodies move in lock-step.
var rig_seed := 0

## Set true while this body is speaking (dialogue giver talking).
var talking := false

## Force the phone idle regardless of the seed roll.
var phone_override := false

## Rest stoop (radians, head-down pitch plus a slight forward lean) —
## issue #222 elders and ragpickers. Composes on the captured base
## pose like every other write, so recycled walkers never drift.
var stoop := 0.0

var _skel: Skeleton3D = null
var _model: Node3D = null
var _holder: Node3D = null
var _ap: AnimationPlayer = null
var _head := -1
var _neck := -1
var _base_head := Quaternion.IDENTITY
var _base_neck := Quaternion.IDENTITY
var _base_rot := Vector3(0.0, PI, 0.0)
var _t := 0.0
var _f1 := 0.3
var _f2 := 0.47
var _f3 := 0.21
var _f4 := 0.36
var _p1 := 0.0
var _p2 := 0.0
var _p3 := 0.0
var _p4 := 0.0
var _p5 := 0.0
var _phone := false
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _speed_sm := 0.0
var _yawrate_sm := 0.0
var _inited := false


func _process_modification(delta: float = 0.0) -> void:
	if delta <= 0.0001:
		delta = get_process_delta_time()
	if delta <= 0.0001:
		delta = 0.016
	_t += delta
	if not _inited:
		_init_rig()
		if not _inited:
			return
	var mode := _locomotion(delta)
	# --- head + neck: seeded look-around wander, eased by locomotion ---
	var amp := 0.5
	var lean := 0.0
	if mode == 1:
		amp = 0.27
	elif mode == 2:
		amp = 0.14
		lean = clampf(_speed_sm * 0.05, 0.0, 0.11)
	var yaw := (sin(_t * _f1 + _p1) * 0.62 + sin(_t * _f2 + _p2) * 0.38) * amp
	var pitch := sin(_t * _f3 + _p3) * amp * 0.34
	var roll := sin(_t * _f4 + _p4) * amp * 0.12
	if _phone:
		# Head down over the screen, with a rare glance up to cross.
		var gate := smoothstep(0.86, 0.98, sin(_t * 0.09 + _p5))
		pitch += (0.46 - 0.4 * gate) * (1.0 - float(mode == 2) * 0.5)
		yaw *= 0.35
	if talking:
		pitch += pow(sin(_t * 2.3 + _p4), 3.0) * 0.09 + 0.02
		yaw += sin(_t * 1.7 + _p1) * 0.045
	if stoop > 0.001:
		pitch += stoop  # neck share rides along with the neck write below
	if _skel != null and is_instance_valid(_skel):
		if _head >= 0:
			_skel.set_bone_pose_rotation(_head,
					_base_head * Quaternion.from_euler(Vector3(pitch, yaw, roll)))
		if _neck >= 0:
			_skel.set_bone_pose_rotation(_neck, _base_neck
					* Quaternion.from_euler(Vector3(
							pitch * 0.45 + stoop * 0.25, yaw * 0.45, roll * 0.4)))
	# --- model node: weight shift, turn bank, speed lean ---
	if _model != null and is_instance_valid(_model):
		var sway := 0.0
		if mode == 0 and _speed_sm < 0.25:
			sway = sin(_t * 0.42 + _p2) * 0.022
		var bank := clampf(-_yawrate_sm * 0.35, -0.16, 0.16)
		_model.rotation = _base_rot + Vector3(-lean - stoop * 0.45, 0.0, sway + bank)


## One-time hookup: bones, base poses, seeded wander parameters. Returns
## without activating (stays a no-op) on rigs without a head bone.
func _init_rig() -> void:
	_skel = get_skeleton()
	if _skel == null or not is_instance_valid(_skel):
		return
	var found_head := false
	for i in _skel.get_bone_count():
		var n := _skel.get_bone_name(i).to_lower()
		var seg := n.get_slice(":", n.get_slice_count(":") - 1)
		if not found_head and (seg == "head" or n.contains("head")):
			_head = i
			found_head = true
		elif _neck < 0 and n.contains("neck"):
			_neck = i
	if not found_head:
		_head = -1
		return
	_base_head = _skel.get_bone_pose_rotation(_head)
	if _neck >= 0:
		_base_neck = _skel.get_bone_pose_rotation(_neck)
	_model = _skel.get_parent() as Node3D
	if _model != null:
		_base_rot = _model.rotation
		_holder = _model.get_parent() as Node3D
		if _holder == null:
			_holder = _model
		for ap_node in _holder.find_children("*", "AnimationPlayer", true, false):
			_ap = ap_node
			break
		_last_pos = _holder.global_position
		_last_yaw = _holder.global_transform.basis.get_euler().y
	var rng := RandomNumberGenerator.new()
	rng.seed = rig_seed if rig_seed != 0 else 1
	_f1 = rng.randf_range(0.22, 0.38)
	_f2 = rng.randf_range(0.38, 0.62)
	_f3 = rng.randf_range(0.14, 0.28)
	_f4 = rng.randf_range(0.28, 0.5)
	_p1 = rng.randf() * TAU
	_p2 = rng.randf() * TAU
	_p3 = rng.randf() * TAU
	_p4 = rng.randf() * TAU
	_p5 = rng.randf() * TAU
	_phone = phone_override or rng.randf() < 0.15
	_inited = true


## 0 idle, 1 walk, 2 run — from the sibling player's current clip when
## one is visible, else from the holder's measured speed, so sprinters
## stop window-gazing and idlers sway the most.
func _locomotion(delta: float) -> int:
	if _holder != null and is_instance_valid(_holder):
		var xf := _holder.global_transform
		var d := xf.origin.distance_to(_last_pos)
		var speed := d / delta if delta > 0.0001 else 0.0
		_speed_sm = lerpf(_speed_sm, clampf(speed, 0.0, 6.0), 0.2)
		var dy := angle_difference(_last_yaw, xf.basis.get_euler().y)
		var yr := dy / delta if delta > 0.0001 else 0.0
		_yawrate_sm = lerpf(_yawrate_sm, clampf(yr, -6.0, 6.0), 0.15)
		_last_pos = xf.origin
		_last_yaw = xf.basis.get_euler().y
	if _ap != null and is_instance_valid(_ap) and _ap.is_playing():
		var n := String(_ap.current_animation).to_lower()
		var seg := n.get_slice("/", n.get_slice_count("/") - 1)
		if seg.contains("run") or seg.contains("jog") or seg.contains("sprint"):
			return 2
		if seg.contains("walk"):
			return 1
		return 0
	# No player clip to ask (or it is parked): fall back to measured speed.
	if _speed_sm > 2.2:
		return 2
	if _speed_sm > 0.35:
		return 1
	return 0
