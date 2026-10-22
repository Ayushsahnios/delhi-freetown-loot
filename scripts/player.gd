extends CharacterBody3D
## Third-person on-foot player driving a rigged CC0 character model
## (assets/characters/). The skeleton's idle/walk/run clips blend by
## ground speed; colors come from the selected legend's def.

const WALK_SPEED := 6.5
const RUN_SPEED := 11.5
const FALL_SAFE_SPEED := 14.0
const MODEL_HEIGHT := 5.9

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")

signal landed_hard(impact_speed: float)

var run_boost := 1.0
var controls_enabled := true
## Traction 0..1 — monsoon wetness lowers it, so momentum lags the
## input direction and the character slides a little before gripping.
var grip := 1.0

var _chars := Chars.new()
var _visuals: Array[Node] = []
var _ap: AnimationPlayer = null
var _anims := {}
var _air_vy := 0.0
var _was_on_floor := true
var _collision_added := false


func setup(def: Dictionary) -> void:
	_build_look(def)
	_ensure_collision()


func swap_character(def: Dictionary) -> void:
	## Character-switch rebuild: replace the model and the per-character
	## stat while keeping this node's identity — collision, velocity and
	## every registration (traffic, peds, police, missions) stay attached.
	for v in _visuals:
		v.queue_free()
	_visuals.clear()
	_ap = null
	_anims = {}
	_build_look(def)


func _build_look(def: Dictionary) -> void:
	run_boost = 1.18 if String(def.get("id")) == "riya" else 1.0
	var path: String = Chars.FEMALE_A if String(def.get("id")) == "riya" else Chars.MALE
	var model := _chars.spawn(path, MODEL_HEIGHT)
	ShadowBlob.attach(model, 0.55)
	_chars.tint(model, def.get("shirt", Color.WHITE), def.get("pants", Color.BLACK),
			def.get("skin", Color.WHITE))
	if def.get("sardar", false):
		_chars.attach_sardar(model, def.get("turban", Color(1.0, 0.56, 0.12)))
	_ap = _chars.get_player(model)
	_anims = _chars.anim_names(model)
	_chars.play(_anims, _ap, "idle", 1.0)
	_add(model)


func _ensure_collision() -> void:
	if _collision_added:
		return
	_collision_added = true
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 6.0
	col.shape = capsule
	col.position.y = 3.0
	add_child(col)


func _add(node: Node) -> void:
	add_child(node)
	_visuals.append(node)


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var input := Vector3.ZERO
	if controls_enabled:
		input = Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			0.0,
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
	var moving := input.length() > 0.05
	if moving:
		var speed: float = WALK_SPEED
		if Input.is_action_pressed("run"):
			speed = RUN_SPEED
		speed *= run_boost
		var target := Vector3(input.x * speed, 0.0, input.z * speed)
		if grip >= 0.999:
			velocity.x = target.x
			velocity.z = target.z
		else:
			# Slick streets: the body turns while the feet keep sliding.
			var follow: float = clampf(lerpf(3.5, 18.0, grip) * delta, 0.0, 1.0)
			velocity.x = lerpf(velocity.x, target.x, follow)
			velocity.z = lerpf(velocity.z, target.z, follow)
		rotation.y = atan2(-input.x, -input.z)
	else:
		var stop: float = 60.0 * lerpf(0.3, 1.0, grip)
		velocity.x = move_toward(velocity.x, 0.0, stop * delta)
		velocity.z = move_toward(velocity.z, 0.0, stop * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 25.0 * delta
		_air_vy = minf(_air_vy, velocity.y)

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		var impact := -_air_vy
		if impact > FALL_SAFE_SPEED:
			landed_hard.emit(impact)
		_air_vy = 0.0
	_was_on_floor = is_on_floor()

	_animate(moving)


func _animate(moving: bool) -> void:
	## Blend idle / walk / run by ground speed, feet matching pace.
	if _ap == null:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	if not moving and spd < 0.6:
		_chars.play(_anims, _ap, "idle", 1.0)
	elif spd < (WALK_SPEED * run_boost + RUN_SPEED) * 0.5:
		_chars.play(_anims, _ap, "walk", spd / WALK_SPEED)
	else:
		_chars.play(_anims, _ap, "run", spd / RUN_SPEED)
