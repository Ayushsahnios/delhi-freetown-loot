extends Node
## Mission system: data-driven mission table, glowing street markers,
## approach briefs, multi-stage reach / timed-delivery objectives, rival
## racers, fail flow, cash rewards. All visuals procedural — zero assets.
## First two real jobs: the chai run (three stops before it cools) and
## the CP ring race (checkpoints against two AI rickshaws).

signal mission_completed(title: String, reward: int)
signal mission_failed(title: String)

const TRIGGER_R := 3.5
const OFFER_EXIT_R := 5.5
const MARKER_CD := 4.0

var cash := 0
var enabled := true
## Mission id -> times completed; persisted in the save file.
var completed := {}

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
var _racers: Array[Dictionary] = []
const RACER_CANOPIES := [Color(0.95, 0.35, 0.15), Color(0.25, 0.55, 0.95)]


func _ready() -> void:
	_build_defs()
	for def in _defs:
		if def.has("objectives"):
			def["objs"] = def["objectives"]
			if not def.has("time"):
				def["time"] = 0.0
		else:
			def["objs"] = [def["objective"]]
			if not def.has("time"):
				def["time"] = float(def["objective"].get("time", 0.0))
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


func restore(saved_cash: int, saved_completed: Dictionary) -> void:
	## Load-from-save entry point: cash, HUD, completion records.
	## Repeatable missions stay at their markers; any one-shot mission
	## completed in a past session stays done and hidden.
	cash = maxi(saved_cash, 0)
	_cash_hud.text = "Rs %d" % cash
	completed = {}
	for key in saved_completed:
		completed[String(key)] = maxi(int(saved_completed[key]), 0)
	for def in _defs:
		var id := String(def["id"])
		if int(completed.get(id, 0)) > 0 and not bool(def.get("repeatable", false)):
			_states[id] = "done"
			_show_giver(id, false)


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
		{
			"id": "chai_run",
			"title": "Chai run: three cups, one flask",
			"brief": "Chotu called in sick and the flask is full. Run three cups across town — the guard at India Gate, the chowkidar at Purani Dilli, the joggers at Neighbourhood Park — before the chai cools. An auto strongly advised.",
			"giver": Vector3(6.0, 0.0, -16.0),
			"objectives": [
				{
					"kind": "deliver",
					"label": "Cup 1 — the guard at India Gate",
					"pos": Vector3(0.0, 0.0, -82.0),
					"radius": 8.0,
				},
				{
					"kind": "deliver",
					"label": "Cup 2 — the chowkidar at Purani Dilli",
					"pos": Vector3(-92.0, 0.0, 104.0),
					"radius": 8.0,
				},
				{
					"kind": "deliver",
					"label": "Cup 3 — the joggers at Neighbourhood Park",
					"pos": Vector3(138.0, 0.0, -126.0),
					"radius": 8.0,
				},
			],
			"time": 130.0,
			"reward": 500,
			"repeatable": true,
		},
		{
			"id": "cp_race",
			"title": "CP ring race: rickshaw rally",
			"brief": "Two rival pullers talk big around the Connaught Place ring. Grab an auto, tag the start line on the west road, and lap the ring through all four crossings before they do. Mind the traffic.",
			"giver": Vector3(-30.0, 0.0, 6.0),
			"objectives": [
				{
					"kind": "reach",
					"label": "Tag the start line",
					"pos": Vector3(-40.0, 0.0, 6.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — north-west crossing",
					"pos": Vector3(-40.0, 0.0, -40.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — north-east crossing",
					"pos": Vector3(6.0, 0.0, -40.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — south-east crossing",
					"pos": Vector3(6.0, 0.0, 6.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Finish — back to the start line",
					"pos": Vector3(-40.0, 0.0, 6.0),
					"radius": 8.0,
				},
			],
			"race": {
				"corners": [
					Vector3(-40.0, 0.0, 6.0),
					Vector3(-40.0, 0.0, -40.0),
					Vector3(6.0, 0.0, -40.0),
					Vector3(6.0, 0.0, 6.0),
					],
				"rivals": [13.5, 15.0],
			},
			"reward": 600,
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
	var objs: Array = def["objs"]
	var stage := int(_active["stage"])
	var obj: Dictionary = objs[stage]
	if float(_active["time"]) > 0.0:
		_active["left"] = float(_active["left"]) - delta
		if float(_active["left"]) <= 0.0:
			_fail_mission("the chai went cold")
			return
	if def.has("race"):
		if _tick_racers(delta):
			_fail_mission("a rival crossed the line first")
			return
	var d := _flat_dist(_player.global_position, obj["pos"])
	var txt := "> %s  (%d/%d)  ·  %d m" % [String(obj["label"]), stage + 1, objs.size(), int(round(d))]
	if float(_active["time"]) > 0.0:
		txt += "  ·  " + _fmt_time(float(_active["left"]))
	_obj_hud.text = txt
	if d <= float(obj["radius"]):
		if stage == objs.size() - 1:
			_complete_mission()
		else:
			_advance_stage(objs, stage)


# ---------------------------------------------------------------- flow

func _start_mission(def: Dictionary) -> void:
	var id := String(def["id"])
	_states[id] = "active"
	_show_giver(id, false)
	_active = {"def": def, "stage": 0, "time": float(def["time"]), "left": float(def["time"])}
	if def.has("race"):
		_spawn_racers(def)
	_spawn_objective(def["objs"][0])
	_obj_hud.visible = true


func _advance_stage(objs: Array, stage: int) -> void:
	_active["stage"] = stage + 1
	_spawn_objective(objs[stage + 1])
	_toast.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	if _active["def"].has("race"):
		_toast.text = "CHECKPOINT %d/%d" % [stage + 1, objs.size() - 1]
	else:
		_toast.text = "DELIVERED  ·  %d of %d cups" % [stage + 1, objs.size()]
	_toast.visible = true
	_toast_t = 1.2


func _complete_mission() -> void:
	var def: Dictionary = _active["def"]
	var reward := int(def["reward"])
	cash += reward
	_cash_hud.text = "Rs %d" % cash
	var id := String(def["id"])
	completed[id] = int(completed.get(id, 0)) + 1
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
	_clear_marker()
	for r in _racers:
		r["node"].queue_free()
	_racers.clear()
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
	_clear_marker()
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


func _clear_marker() -> void:
	if _obj_ring != null:
		_obj_ring.queue_free()
		_obj_ring = null
	if _obj_beam != null:
		_obj_beam.queue_free()
		_obj_beam = null


func _spawn_racers(def: Dictionary) -> void:
	## Two rival rickshaws lap the circuit analytically, corner to corner
	## along the road ring — kinematic, like traffic, so they never get
	## stuck on geometry.
	var race: Dictionary = def["race"]
	var corners: Array = race["corners"]
	var from: Vector3 = corners[0]
	var to: Vector3 = corners[1]
	var lane := (to - from).normalized().cross(Vector3.UP)
	for i in range(race["rivals"].size()):
		var node := Node3D.new()
		_build_racer_visual(node, RACER_CANOPIES[i % RACER_CANOPIES.size()])
		add_child(node)
		node.position = from + lane * (2.8 * i - 1.4)
		node.look_at(node.position + (to - from), Vector3.UP)
		_racers.append({
			"node": node,
			"corners": corners,
			"at": 0,
			"remain": from.distance_to(to),
			"speed": float(race["rivals"][i]),
			"legs": 0,
		})


func _tick_racers(delta: float) -> bool:
	## Advances every rival; returns true once one has finished the lap.
	var won := false
	for r in _racers:
		if bool(r.get("done", false)):
			continue
		r["remain"] = float(r["remain"]) - float(r["speed"]) * delta
		var corners: Array = r["corners"]
		var at := int(r["at"])
		var from: Vector3 = corners[at]
		var to: Vector3 = corners[(at + 1) % corners.size()]
		var dir := (to - from).normalized()
		r["node"].position = to - dir * maxf(float(r["remain"]), 0.0)
		r["node"].look_at(r["node"].position + dir, Vector3.UP)
		while float(r["remain"]) <= 0.0:
			r["legs"] = int(r["legs"]) + 1
			if int(r["legs"]) >= corners.size():
				r["done"] = true
				r["node"].position = to
				won = true
				break
			var overshoot := -float(r["remain"])
			r["at"] = (at + 1) % corners.size()
			from = corners[int(r["at"])]
			to = corners[(int(r["at"]) + 1) % corners.size()]
			r["remain"] = from.distance_to(to) - overshoot
			dir = (to - from).normalized()
			r["node"].position = to - dir * maxf(float(r["remain"]), 0.0)
			r["node"].look_at(r["node"].position + dir, Vector3.UP)
	return won


func _build_racer_visual(parent: Node3D, canopy: Color) -> void:
	parent.add_child(_rbox(Vector3(2.4, 1.3, 3.4), Color(0.18, 0.55, 0.20), Vector3(0, 1.0, 0)))
	parent.add_child(_rbox(Vector3(2.4, 1.4, 2.2), canopy, Vector3(0, 2.2, 0.2)))
	parent.add_child(_rbox(Vector3(1.6, 1.1, 0.9), canopy, Vector3(0, 1.35, -1.9)))
	for spec in [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.4
		cm.material = _omat(Color(0.1, 0.11, 0.13))
		w.mesh = cm
		w.rotation.z = PI / 2.0
		w.position = spec
		parent.add_child(w)


func _rbox(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _omat(color)
	m.mesh = bm
	m.position = pos
	return m


func _omat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


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
	var objs: Array = def["objs"]
	var line := ""
	if def.has("race"):
		line = "%d checkpoints + finish  ·  %d rivals" % [objs.size() - 1, def["race"]["rivals"].size()]
	elif objs.size() > 1:
		line = "%d stops across town" % objs.size()
	else:
		line = String(objs[0]["label"])
	if float(def["time"]) > 0.0:
		line += "  ·  %d s" % int(def["time"])
	line += "  ·  pays Rs %d" % int(def["reward"])
	_brief_obj.text = line
	_brief.visible = true
