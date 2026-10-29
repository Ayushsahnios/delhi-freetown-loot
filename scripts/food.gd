extends Node
## Street food economy: chai/samosa thela carts parked at the landmarks.
## Walk up, read the prices on the prompt, pay from the mission wallet,
## get HP back — the first real money sink in the Paisa systems.

const HealthScript := preload("res://scripts/health.gd")
const MissionScript := preload("res://scripts/missions.gd")
const Chars := preload("res://scripts/characters.gd")

const BUY_R := 3.6
const CHAI := {"name": "CHAI", "price": 20, "heal": 20}
const SAMOSA := {"name": "SAMOSA", "price": 35, "heal": 45}
## Counter service (issue #183): the walk-in halwai and dhaba counters
## sell through the same wallet/HP path as the carts.
const MITHAI := {"name": "MITHAI", "price": 30, "heal": 35}
const PARATHA := {"name": "PARATHA", "price": 45, "heal": 55}

## Flat offset from each landmark center — sidewalk spots that stay clear
## of mission givers, spawns and drivable roads.
const OFFSETS := {
	"Connaught Place": Vector3(-14.0, 0.0, 8.0),
	"India Gate": Vector3(14.0, 0.0, 2.0),
	"Purani Dilli Fort": Vector3(10.0, 0.0, 4.0),
	# Chandni Chowk: the old (-5, 0, -5) anchor landed the cart on the
	# west shop-row corner — rotated toward the block center it clipped
	# into the wall at ~45° (issue #79). (9, 0, -5) parks it in the clear
	# market lane between the stall rows, clear of stalls, bunting poles
	# and shop walls on every side.
	"Chandni Chowk": Vector3(9.0, 0.0, -5.0),
	"Neighbourhood Park": Vector3(10.0, 0.0, 10.0),
	"Police Station": Vector3(-12.0, 0.0, 8.0),
}

var _player: CharacterBody3D = null
var _health: HealthScript = null
var _missions: MissionScript = null
var _audio: Node = null
var _stalls: Array[Dictionary] = []
var _t := 0.0

var _prompt: Label
var _toast: Label
var _toast_tween: Tween
var night_f := 0.0
var rush_f := 0.0
var _bulb_mat: StandardMaterial3D = null


func setup(landmarks: Array[Dictionary]) -> void:
	## Carts exist from the main menu on (world dressing); buying only
	## works once register() has handed over the live game nodes.
	# Night-market bulbs (issue #185): one shared emissive material lights
	# every cart's bulb + counter strip after dusk — glow bloom does the
	# halo, no extra OmniLights to blow the light budget.
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(1.0, 0.92, 0.74)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.74, 0.4)
	_bulb_mat.emission_energy_multiplier = 0.0
	for lm in landmarks:
		var key := String(lm["name"])
		if not OFFSETS.has(key):
			continue
		var center: Vector3 = lm["center"]
		var pos: Vector3 = center + OFFSETS[key]
		_stalls.append({"pos": pos, "steam": _build_cart(pos, center),
				"items": [CHAI, SAMOSA]})
	_build_ui()


func add_counter(pos: Vector3, items: Array) -> void:
	## Walk-in counters (issue #183): same economy, same Q/R prompt —
	## the interior dressing owns the visuals, this only takes orders.
	_stalls.append({"pos": pos, "steam": [], "items": items})


func stall_positions() -> Array[Vector3]:
	## World positions of every chai/samosa cart — the ambience bed
	## anchors crowd murmur and stall clatter on these (issue #165).
	var out: Array[Vector3] = []
	for stall in _stalls:
		out.append(stall["pos"])
	return out


func register(p: CharacterBody3D, health: HealthScript, missions: MissionScript,
		audio: Node = null) -> void:
	_player = p
	_health = health
	_missions = missions
	_audio = audio


# ---------------------------------------------------------------- loop

func set_night_rush(night: float, rush: float) -> void:
	## Daily rhythm (issue #185), driven by daily_life.gd: dusk lights the
	# market bulbs, the 07:00-10:00 chai rush boils the kettles harder.
	night_f = night
	rush_f = rush


func _process(delta: float) -> void:
	_t += delta
	# Kettle boil rides the rush (issue #185): morning steam cycles faster
	# and wider; the night market keeps a calm simmer.
	var boil := 1.0 + 0.9 * rush_f
	for stall in _stalls:
		for puff in stall["steam"]:
			puff["mesh"].position.y = float(puff["base"]) \
					+ sin(_t * 2.2 * boil + float(puff["phase"])) * 0.13 * boil
	if _bulb_mat != null:
		_bulb_mat.emission_energy_multiplier = lerpf(0.0, 2.6, night_f)
	if _player == null or _health == null or _missions == null:
		return
	var near := _nearest_stall(_player.global_position)
	if near == null or not _player.controls_enabled:
		_prompt.visible = false
		return
	# A running dialogue owns the bottom of the screen — keep the stall
	# prompt out of its box (issue #80).
	for d in get_tree().get_nodes_in_group("dialogue"):
		if d.is_running():
			_prompt.visible = false
			return
	var its: Array = near.get("items", [CHAI, SAMOSA])
	if its.size() < 2:
		its = [CHAI, SAMOSA]
	_prompt.text = "%s Rs %d [Q]  ·  %s Rs %d [R]  ·  stall food is hot%s" % [
			its[0]["name"], its[0]["price"], its[1]["name"], its[1]["price"], _mood()]
	_prompt.visible = true
	if Input.is_action_just_pressed("buy_chai"):
		_buy(its[0])
	elif Input.is_action_just_pressed("buy_samosa"):
		_buy(its[1])


func _mood() -> String:
	## Prompt tail for the daily rhythm (issue #185).
	if rush_f > 0.5:
		return "  ·  morning rush"
	if night_f > 0.5:
		return "  ·  night market"
	return ""


func _nearest_stall(pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_d := BUY_R
	for stall in _stalls:
		var d := Vector2(pos.x - stall["pos"].x, pos.z - stall["pos"].z).length()
		if d < best_d:
			best_d = d
			best = stall
	return best


func _buy(item: Dictionary) -> void:
	if float(_health.hp) >= float(_health.MAX_HP):
		_show_toast("Full already — save your paisa")
		return
	if not _missions.spend(int(item["price"])):
		_show_toast("Not enough paisa — Rs %d needed" % int(item["price"]))
		return
	# Cash pip the moment paisa leaves the wallet (issue #187).
	if _audio != null and _audio.has_method("purchase_blip"):
		_audio.purchase_blip()
	_health.heal(float(item["heal"]))
	_show_toast("%s  ·  +%d HP  ·  Rs %d" % [item["name"], int(item["heal"]), int(item["price"])])
	_prompt.visible = false


# ---------------------------------------------------------------- cart visuals

func _build_cart(pos: Vector3, face_toward: Vector3) -> Array[Dictionary]:
	## Procedural thela: wooden counter, striped awning, kettle with steam,
	## cup stack, samosa tray and a vendor. Mesh-only — no collision, like
	## the city trees.
	var root := Node3D.new()
	root.position = pos
	root.look_at_from_position(pos, face_toward, Vector3.UP)
	add_child(root)

	root.add_child(_box(Vector3(2.8, 0.9, 1.5), Color(0.55, 0.38, 0.22), Vector3(0, 1.05, 0)))
	root.add_child(_box(Vector3(3.1, 0.12, 1.7), Color(0.80, 0.68, 0.52), Vector3(0, 1.56, 0)))
	root.add_child(_box(Vector3(2.4, 0.5, 1.2), Color(0.42, 0.28, 0.16), Vector3(0, 0.3, 0)))
	for side in [-1.55, 1.55]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.35
		wm.bottom_radius = 0.35
		wm.height = 0.18
		wm.material = _mat(Color(0.12, 0.12, 0.14))
		wheel.mesh = wm
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(side, 0.35, 0)
		root.add_child(wheel)
	for px in [-1.4, 1.4]:
		for pz in [-0.7, 0.7]:
			root.add_child(_box(Vector3(0.1, 2.2, 0.1), Color(0.35, 0.24, 0.14), Vector3(px, 2.65, pz)))
	for i in range(4):
		var stripe := _box(Vector3(0.78, 0.08, 2.1), Color(0.9, 0.2, 0.16) if i % 2 == 0 else Color(0.95, 0.92, 0.85), Vector3(-1.17 + i * 0.78, 3.78, 0))
		stripe.rotation.x = -0.16
		root.add_child(stripe)
	# Night-market glow (issue #185): hanging bulb under the awning plus a
	# warm strip along the counter front — dark until dusk.
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	root.add_child(_glow(bulb, Vector3(0, 3.3, 0.55)))
	var strip := BoxMesh.new()
	strip.size = Vector3(2.8, 0.05, 0.03)
	root.add_child(_glow(strip, Vector3(0, 1.48, 0.77)))
	var kettle := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.28
	km.bottom_radius = 0.24
	km.height = 0.55
	km.material = _mat(Color(0.62, 0.65, 0.70))
	kettle.mesh = km
	kettle.position = Vector3(-0.7, 1.9, 0)
	root.add_child(kettle)
	for i in range(3):
		var cup := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.09
		cm.height = 0.2
		cm.material = _mat(Color(0.95, 0.93, 0.88))
		cup.mesh = cm
		cup.position = Vector3(0.1 + i * 0.28, 1.72, 0.35)
		root.add_child(cup)
	root.add_child(_box(Vector3(1.0, 0.1, 0.6), Color(0.5, 0.4, 0.3), Vector3(0.75, 1.66, -0.2)))
	for i in range(3):
		var snack := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		sm.material = _mat(Color(0.9, 0.68, 0.2))
		snack.mesh = sm
		snack.position = Vector3(0.5 + i * 0.25, 1.8, -0.2)
		root.add_child(snack)
	# Vendor: rigged CC0 character (idle clip), tinted like the old apron.
	var chars := Chars.new()
	var vendor := chars.spawn(Chars.MALE, 1.78)
	chars.tint(vendor, Color(0.9, 0.5, 0.12), Color(0.16, 0.14, 0.13), Color(0.78, 0.55, 0.38))
	vendor.position = Vector3(0, 0, 1.35)
	root.add_child(vendor)
	chars.play(chars.anim_names(vendor), chars.get_player(vendor), "idle", 0.9)

	var steam: Array[Dictionary] = []
	for i in range(3):
		var puff := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.13 + 0.04 * i
		pm.height = pm.radius * 2.0
		pm.material = _steam_mat()
		puff.mesh = pm
		var base := 2.35 + i * 0.3
		puff.position = Vector3(-0.7 + 0.06 * i, base, 0)
		root.add_child(puff)
		steam.append({"mesh": puff, "base": base, "phase": i * 2.1})
	return steam


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	m.mesh = bm
	m.position = pos
	return m


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _glow(mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	## A night-market bulb mesh (issue #185) wearing the shared emissive
	## material that daily_life.gd fades in after dusk.
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.material_override = _bulb_mat
	return m


func _steam_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.98, 0.38)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	_toast.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)
