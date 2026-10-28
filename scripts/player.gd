extends CharacterBody3D
## Third-person on-foot player driving a rigged CC0 character model
## (assets/characters/). The skeleton's idle/walk/run clips blend by
## ground speed; colors come from the selected legend's def.

const WALK_SPEED := 6.5
const RUN_SPEED := 11.5
const FALL_SAFE_SPEED := 14.0
const MODEL_HEIGHT := 1.78

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")

signal landed_hard(impact_speed: float)
signal stamina_changed(fraction: float)

## Sprint stamina (issue #154, free-roam feel): the run key burns a
## stamina pool; at empty the legend is winded and held to a walk until
## the bar recovers past the re-arm threshold — sprint, exhaust, recover,
## sprint again, the classic on-foot free-roam rhythm.
const STAMINA_DRAIN := 0.14
const STAMINA_REGEN := 0.22
const STAMINA_REGEN_IDLE := 0.35
const STAMINA_REARM := 0.30

var stamina := 1.0
var run_boost := 1.0
var controls_enabled := true
## Traction 0..1 — monsoon wetness lowers it, so momentum lags the
## input direction and the character slides a little before gripping.
var grip := 1.0

var _chars := Chars.new()
var _visuals: Array[Node] = []
var _ap: AnimationPlayer = null
var _anims := {}
## Legend personality (issue #121): each legend's idle/walk pace runs
## at its own rate — Sardar Ji unhurried, Riya quick, Monty even.
var _anim_rate := 1.0
var _air_vy := 0.0
var _was_on_floor := true
var _collision_added := false
var _winded := false


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
	_anim_rate = float(def.get("anim_rate", 1.0))
	var path: String = Chars.FEMALE_A if String(def.get("id")) == "riya" else Chars.MALE
	# Issue 161: each legend stands at their own height inside the band
	# — stocky Sardar Ji, compact Riya, tall lean Monty.
	var model := _chars.spawn(path, float(def.get("height", MODEL_HEIGHT)))
	ShadowBlob.attach(model, 0.55)
	_chars.dress_legend(model, def)
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
	capsule.radius = 0.35
	capsule.height = 1.75
	col.shape = capsule
	col.position.y = 0.875
	add_child(col)


func _add(node: Node) -> void:
	add_child(node)
	_visuals.append(node)


func suspend_for_ride() -> void:
	## Carried by the shuttle (issue #112): the carriage has no floor
	## collision, so a simulating body banks fall speed the whole trip,
	## drops between frames and slams down — or "lands hard" on alight
	## from banked velocity. Park the physics until the ride ends.
	set_physics_process(false)
	velocity = Vector3.ZERO
	_air_vy = 0.0
	_was_on_floor = true


func resume_after_ride() -> void:
	set_physics_process(true)
	velocity = Vector3.ZERO
	_air_vy = 0.0
	_was_on_floor = true


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
	var sprinting := false
	if moving:
		var speed: float = WALK_SPEED
		if Input.is_action_pressed("run") and not _winded:
			speed = RUN_SPEED
			sprinting = true
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
	_tick_stamina(delta, sprinting, moving)


func _tick_stamina(delta: float, sprinting: bool, moving: bool) -> void:
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if is_zero_approx(stamina):
			_winded = true
	else:
		stamina = minf(stamina + (STAMINA_REGEN_IDLE if not moving else STAMINA_REGEN) * delta, 1.0)
		if _winded and stamina >= STAMINA_REARM:
			_winded = false
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina)


func _animate(moving: bool) -> void:
	## Blend idle / walk / run by ground speed, feet matching pace.
	if _ap == null:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	if not moving and spd < 0.6:
		_chars.play(_anims, _ap, "idle", _anim_rate)
	elif spd < (WALK_SPEED * run_boost + RUN_SPEED) * 0.5:
		_chars.play(_anims, _ap, "walk", spd / WALK_SPEED * _anim_rate)
	else:
		_chars.play(_anims, _ap, "run", spd / RUN_SPEED * _anim_rate)
