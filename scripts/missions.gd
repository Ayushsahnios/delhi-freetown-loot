extends Node
## Mission system skeleton: data-driven mission table, glowing street
## markers, approach briefs, reach / timed-deliver objectives, fail flow,
## cash rewards. All visuals procedural — zero assets.

signal mission_completed(title: String, reward: int)
signal mission_failed(title: String)

const TRIGGER_R := 3.5
const OFFER_EXIT_R := 5.5
const MARKER_CD := 4.0

var cash := 0
var enabled := true

var _player: CharacterBody3D = null
var _defs: Array[Dictionary] = []
var _states := {}
var _cds := {}
var _givers := {}
var _offer_id := ""
var _active := {}
var _t := 0.0
var _toast_t := 0.0

var _ui: CanvasLayer
var _brief: PanelContainer
var _brief_title: Label
var _brief_body: Label
var _brief_obj: Label
var _brief_hint: Label
var _obj_hud: Label
var _toast: Label
var _cash_hud: Label
var _obj_ring: MeshInstance3D = null
var _obj_beam: MeshInstance3D = null


func _ready() -> void:
	_build_defs()
	_build_ui()
	for def in _defs:
		_spawn_giver(def)


# ---------------------------------------------------------------- public API

func register_player(p: CharacterBody3D) -> void:
	_player = p


func abort_active(reason: String) -> void:
	## Called by the main scene when the player goes down: fail any
	## running mission and pause new offers until respawn completes.
	if not _active.is_empty():
		_fail_mission(reason)
	enabled = false


func resume() -> void:
	enabled = true


# ---------------------------------------------------------------- data

func _build_defs() -> void:
	_defs = [
		{
			"id": "gate_stroll",
			"title": "Street test: Gate run",
			"brief": "Loop crew street test: get from your spawn corner to India Gate and stand under the arch. Walk it, run it, or grab an auto.",
			"giver": Vector3(8.0, 0.0, 50.0),
			"objective": {
				"kind": "reach",
				"label": "Reach India Gate",
				"pos": Vector3(0.0, 0.0, -82.0),
				"radius": 7.0,
				"time": 0.0,
			},
			"reward": 250,
			"repeatable": true,
		},
		{
			"id": "cp_crate",
			"title": "Street test: CP crate run",
			"brief": "A dhaba crate waits by the Connaught Place green. Run it up to the fort gate in Purani Dilli before the dal boils over.",
			"giver": Vector3(14.0, 0.0, 14.0),
			"objective": {
				"kind": "deliver",
				"label": "Deliver the crate to Purani Dilli",
				"pos": Vector3(-92.0, 0.0, 104.0),
				"radius": 8.0,
				"time": 70.0,
			},
			"reward": 400,
			"repeatable": true,
		},
	]


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_t += delta
	if _toast_t > 0.0:
		_toast_t = maxf(_toast_t - delta, 0.0)
		if _toast_t <= 0.0:
			_toast.visible = false
	for def in _defs:
		var id := String(def["id"])
		var g: Dictionary = _givers[id]
		if g["ring"].visible:
			g["ring"].rotate_y(delta * 1.4)
			g["beam"].position.y = float(def["giver"].y) + 4.6 + sin(_t * 2.2) * 0.35
		match String(_states[id]):
			"cooldown":
				_cds[id] = float(_cds[id]) - delta
				if float(_cds[id]) <= 0.0:
					_states[id] = "available"
					_show_giver(id, true)
			"available":
				if enabled and _active.is_empty() and _offer_id == "" and _player != null \
						and _flat_dist(_player.global_position, def["giver"]) < TRIGGER_R:
					_offer_id = id
					_states[id] = "offered"
					_show_brief(def)
			"offered":
				if _player == null or _flat_dist(_player.global_position, def["giver"]) > OFFER_EXIT_R:
					_states[id] = "available"
					_offer_id = ""
					_brief.visible = false
				elif Input.is_action_just_pressed("mission"):
					_brief.visible = false
					_offer_id = ""
					_start_mission(def)
	if not _active.is_empty():
		_tick_active(delta)
	if _obj_ring != null and _obj_ring.visible:
		var pulse := 0.9 + 0.1 * sin(_t * 5.0)
		_obj_ring.scale = Vector3(pulse, 1.0, pulse)
		_obj_ring.rotate_y(delta * 2.0)


func _tick_active(delta: float) -> void:
	var def: Dictionary = _active["def"]
	var obj: Dictionary = def["objective"]
	if float(obj["time"]) > 0.0:
		_active["left"] = float(_active["left"]) - delta
		if float(_active["left"]) <= 0.0:
			_fail_mission("too slow")
			return
	var d := _flat_dist(_player.global_position, obj["pos"])
	var txt := "> " + String(obj["label"]) + "  ·  %d m" % int(round(d))
	if float(obj["time"]) > 0.0:
		txt += "  ·  " + _fmt_time(float(_active["left"]))
	_obj_hud.text = txt
	if d <= float(obj["radius"]):
		_complete_mission()


# ---------------------------------------------------------------- flow

func _start_mission(def: Dictionary) -> void:
	var id := String(def["id"])
	_states[id] = "active"
	_show_giver(id, false)
	_active = {"def": def, "left": float(def["objective"]["time"])}
	_spawn_objective(def["objective"])
	_obj_hud.visible = true


func _complete_mission() -> void:
	var def: Dictionary = _active["def"]
	var reward := int(def["reward"])
	cash += reward
	_cash_hud.text = "Rs %d" % cash
	_toast.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	_toast.text = "MISSION COMPLETE  ·  + Rs %d" % reward
	_toast.visible = true
	_toast_t = 2.5
	mission_completed.emit(String(def["title"]), reward)
	_end_mission(def)


func _fail_mission(reason: String) -> void:
	var def: Dictionary = _active["def"]
	_toast.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_toast.text = "MISSION FAILED  ·  %s" % reason
	_toast.visible = true
	_toast_t = 2.5
	mission_failed.emit(String(def["title"]))
	_end_mission(def)


func _end_mission(def: Dictionary) -> void:
	var id := String(def["id"])
	if _obj_ring != null:
		_obj_ring.queue_free()
		_obj_ring = null
	if _obj_beam != null:
		_obj_beam.queue_free()
		_obj_beam = null
	_obj_hud.visible = false
	_active = {}
	if bool(def.get("repeatable", false)):
		_states[id] = "cooldown"
		_cds[id] = MARKER_CD
	else:
		_states[id] = "done"
		_show_giver(id, false)


# ---------------------------------------------------------------- world

func _spawn_giver(def: Dictionary) -> void:
	var pos: Vector3 = def["giver"]
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 2.2
	rm.bottom_radius = 2.2
	rm.height = 2.6
	rm.material = _xmat(Color(1.0, 0.84, 0.25), 0.42)
	ring.mesh = rm
	ring.position = pos + Vector3(0.0, 1.3, 0.0)
	add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.25
	bm.bottom_radius = 0.25
	bm.height = 9.0
	bm.material = _xmat(Color(1.0, 0.9, 0.45), 0.55)
	beam.mesh = bm
	beam.position = pos + Vector3(0.0, 4.5, 0.0)
	add_child(beam)
	_states[String(def["id"])] = "available"
	_givers[String(def["id"])] = {"ring": ring, "beam": beam}


func _spawn_objective(obj: Dictionary) -> void:
	var pos: Vector3 = obj["pos"]
	var radius := float(obj["radius"])
	_obj_ring = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = radius * 0.85
	rm.bottom_radius = radius * 0.85
	rm.height = 0.4
	rm.material = _xmat(Color(0.3, 1.0, 0.6), 0.35)
	_obj_ring.mesh = rm
	_obj_ring.position = pos + Vector3(0.0, 0.25, 0.0)
	add_child(_obj_ring)
	_obj_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 0.6
	bm.height = 60.0
	bm.material = _xmat(Color(0.3, 1.0, 0.6), 0.22)
	_obj_beam.mesh = bm
	_obj_beam.position = pos + Vector3(0.0, 30.0, 0.0)
	add_child(_obj_beam)


func _show_giver(id: String, on: bool) -> void:
	var g: Dictionary = _givers[id]
	g["ring"].visible = on
	g["beam"].visible = on


func _xmat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fmt_time(s: float) -> String:
	var t := int(ceil(maxf(s, 0.0)))
	return "%d:%02d" % [int(t / 60.0), t % 60]


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	add_child(_ui)

	_cash_hud = Label.new()
	_cash_hud.position = Vector2(1004, 46)
	_cash_hud.add_theme_font_size_override("font_size", 18)
	_cash_hud.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_cash_hud.text = "Rs 0"
	_ui.add_child(_cash_hud)

	_obj_hud = Label.new()
	_obj_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_obj_hud.offset_top = 12.0
	_obj_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_hud.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_obj_hud.add_theme_font_size_override("font_size", 20)
	_obj_hud.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_obj_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_hud.visible = false
	_ui.add_child(_obj_hud)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 32)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_ui.add_child(_toast)

	_brief = PanelContainer.new()
	_brief.position = Vector2(340, 470)
	_brief.custom_minimum_size = Vector2(600, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.92)
	sb.border_color = Color(1.0, 0.84, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_brief.add_theme_stylebox_override("panel", sb)
	_brief.visible = false
	_ui.add_child(_brief)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_brief.add_child(box)
	_brief_title = Label.new()
	_brief_title.add_theme_font_size_override("font_size", 21)
	_brief_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	box.add_child(_brief_title)
	_brief_body = Label.new()
	_brief_body.add_theme_font_size_override("font_size", 14)
	_brief_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_body.custom_minimum_size = Vector2(560, 0)
	box.add_child(_brief_body)
	_brief_obj = Label.new()
	_brief_obj.add_theme_font_size_override("font_size", 14)
	_brief_obj.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	box.add_child(_brief_obj)
	_brief_hint = Label.new()
	_brief_hint.add_theme_font_size_override("font_size", 12)
	_brief_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	_brief_hint.text = "F — accept  ·  walk away — decline"
	box.add_child(_brief_hint)


func _show_brief(def: Dictionary) -> void:
	_brief_title.text = String(def["title"])
	_brief_body.text = String(def["brief"])
	var obj: Dictionary = def["objective"]
	var line := String(obj["label"])
	if float(obj["time"]) > 0.0:
		line += " · %d s" % int(obj["time"])
	line += " · pays Rs %d" % int(def["reward"])
	_brief_obj.text = line
	_brief.visible = true
