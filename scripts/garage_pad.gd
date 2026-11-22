extends Node3D
## Kaali-Peeli garage pad (issue #347, slice 2) — the buyable showroom
## kerbstone. Walk up on foot, cycle the 15-rung ladder, pay from the
## mission wallet, and the tuned ride rolls out through the same
## auto.gd builder path the street fleet uses. Owned rides re-select
## free. The ladder itself lives in garage.gd (data-only, slice 1).

const Garage := preload("res://scripts/garage.gd")
const MeshTools := preload("res://scripts/meshtools.gd")

## Prompt reach, measured flat from the pad centre.
const REACH := 4.6

var _player: CharacterBody3D = null
var _missions: Node = null
var _garage: Garage = null
var _swap: Callable = Callable()
var _riding_check := Callable()
var _cursor := 0
var _on_change := Callable()
var _prompt: Label = null
var _toast: Label = null
var _toast_t := 0.0


func setup(player: CharacterBody3D, missions: Node, garage: Garage,
		swap: Callable, riding_check: Callable = Callable(),
		on_change: Callable = Callable()) -> void:
	_player = player
	_missions = missions
	_garage = garage
	_swap = swap
	_riding_check = riding_check
	_on_change = on_change
	_build_pad()
	_build_ui()
	_ensure_actions()
	set_process(true)


func place(pos: Vector3) -> void:
	position = pos


func rollout_pos() -> Vector3:
	## Kerbside rollout slot: off the pad toward the road, in line with
	## the parked street fleet, so the fresh ride never lands on the
	## customer standing at the disc.
	return global_position + Vector3(-3.5, 1.0, 1.0)


func rollout_heading() -> float:
	## Down the kerb (front toward -Z), matching the parked spawn row.
	return 0.0


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
	var flat := _player.global_position * Vector3(1.0, 0.0, 1.0)
	var pad_flat := global_position * Vector3(1.0, 0.0, 1.0)
	if flat.distance_to(pad_flat) > REACH:
		_prompt.visible = false
		return
	# The pad only serves foot traffic — step out of the ride to shop.
	# The caller's check covers the shared ride/metro state; the parent
	# probe stays as a belt-and-braces fallback.
	if (_riding_check.is_valid() and _riding_check.call()) or _riding_now():
		_prompt.visible = false
		return
	_show_rung()
	if Input.is_action_just_pressed("garage_next"):
		_cursor = (_cursor + 1) % Garage.rung_count()
		_show_rung()
	elif Input.is_action_just_pressed("garage_prev"):
		_cursor = (_cursor - 1 + Garage.rung_count()) % Garage.rung_count()
		_show_rung()
	elif Input.is_action_just_pressed("garage_buy"):
		_try_buy()


func _riding_now() -> bool:
	## The pad sits far from every road; a vehicle within arm's reach
	## means the player rolled onto the pad itself — no shop window
	## through a windscreen.
	var body := _player.get_parent()
	return body != null and body is VehicleBody3D


func _show_rung() -> void:
	var rung: Dictionary = Garage.rung(_cursor)
	var status := ""
	if _garage.owned.has(String(rung["id"])):
		status = "OWNED" if _garage.selected != String(rung["id"]) else "ACTIVE"
	elif _missions_done() < int(rung["unlock"]):
		status = "LOCKED · %d missions" % int(rung["unlock"])
	_prompt.text = "KAALI-PEELI GARAGE · %s — Rs %d  ·  %s  ·  [ ] prev · ] next · G buy/ride\n%s" \
			% [String(rung["name"]), int(rung["price"]), status,
			String(rung["blurb"])]
	_prompt.visible = true


func _try_buy() -> void:
	var rung: Dictionary = Garage.rung(_cursor)
	var id := String(rung["id"])
	if _garage.owned.has(id):
		if _garage.select(id):
			_swap.call(rung)
			_say("Rolling out the %s — she runs sweet" % String(rung["name"]))
			if _on_change.is_valid():
				_on_change.call()
		return
	var verdict := _garage.buy_gate(id, int(_missions.cash), _missions_done())
	if verdict == "locked":
		_say("Come back after %d missions — the keys stay here" % int(rung["unlock"]))
		return
	if verdict == "broke":
		_say("Rs %d short for the %s — hustle first" % [
				int(rung["price"]) - int(_missions.cash), String(rung["name"])])
		return
	if verdict != "":
		return
	# Cash math stays in missions.gd: spend first, record the sale after.
	if not bool(_missions.spend(int(rung["price"]))):
		return
	if not _garage.purchase(id):
		_missions.earn(int(rung["price"]), "finds")
		_say("Paperwork jam — nothing charged, try again")
		return
	_swap.call(rung)
	_say("Sold! The %s is yours — yours and the bank's" % String(rung["name"]))
	if _on_change.is_valid():
		_on_change.call()


func _missions_done() -> int:
	var done := 0
	for k in _missions.completed:
		done += int(_missions.completed[k])
	return done


func _say(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_t = 3.2


# ---------------------------------------------------------------- pad

func _build_pad() -> void:
	## De-box rule: cylinders and discs only — a kaali-peeli striped
	## kerb pad with a rank disc on a pole, no flat boxes anywhere.
	var tools := MeshTools.new()
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.1
	pad_mesh.bottom_radius = 2.3
	pad_mesh.height = 0.18
	pad.mesh = pad_mesh
	pad.position = Vector3(0.0, 0.09, 0.0)
	pad.material_override = _paint(Color(0.08, 0.08, 0.09))
	add_child(pad)
	for i in 8:
		var stud := MeshInstance3D.new()
		var stud_mesh := CylinderMesh.new()
		stud_mesh.top_radius = 0.16
		stud_mesh.bottom_radius = 0.16
		stud_mesh.height = 0.22
		stud.mesh = stud_mesh
		var ang := TAU * float(i) / 8.0
		stud.position = Vector3(cos(ang) * 1.7, 0.11, sin(ang) * 1.7)
		stud.material_override = _paint(
				Color(1.0, 0.75, 0.0) if i % 2 == 0 else Color(0.05, 0.05, 0.06))
		add_child(stud)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 2.6
	pole.mesh = pole_mesh
	pole.position = Vector3(1.5, 1.3, -1.5)
	pole.material_override = _paint(Color(0.55, 0.55, 0.58))
	add_child(pole)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.62
	disc_mesh.bottom_radius = 0.62
	disc_mesh.height = 0.1
	disc.mesh = disc_mesh
	disc.rotation_degrees.x = 90.0
	disc.position = Vector3(1.5, 2.3, -1.5)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(1.0, 0.75, 0.0)
	disc_mat.roughness = 0.35
	disc.material_override = disc_mat
	add_child(disc)
	var back := MeshInstance3D.new()
	var back_mesh := CylinderMesh.new()
	back_mesh.top_radius = 0.5
	back_mesh.bottom_radius = 0.5
	back_mesh.height = 0.06
	back.mesh = back_mesh
	back.rotation_degrees.x = 90.0
	back.position = Vector3(1.5, 2.3, -1.49)
	back.material_override = _paint(Color(0.05, 0.05, 0.06))
	add_child(back)


func _paint(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	return m


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_bottom = -84.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -132.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)


func _ensure_actions() -> void:
	## Runtime-registered keys so project.godot stays untouched: [ and ]
	## cycle the ladder, G buys. Skipped if an action already exists.
	for pair in [["garage_prev", KEY_BRACKETLEFT],
			["garage_next", KEY_BRACKETRIGHT], ["garage_buy", KEY_G]]:
		var action := String(pair[0])
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(action, ev)
