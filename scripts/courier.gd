extends Node3D
## Courier empire hustle (issue #99, part 2). Crates wait at depot corners
## beside the city landmarks — walk or ride through one to grab the run,
## then beat the countdown to the drop landmark. Quick hands build a
## delivery streak that multiplies every payout; an expired run, a knockout
## or a bust drops the parcel and resets the streak. Pay lands in the
## mission wallet, so it persists with the save. All props procedural.

const MeshTools := preload("res://scripts/meshtools.gd")

const BASE_PAY := 25
const PER_M := 0.45
const PICK_R := 3.4
const DROP_R := 16.0
const MIN_TRIP := 60.0
const BASE_TIME := 14.0
const TIME_PER_M := 0.5
const FAST_CUT := 0.4
const FAST_BONUS := 0.3
const STREAK_STEP := 0.12
const STREAK_CAP := 6
const RESTOCK := 25.0
const SHOW_R := 110.0
const MAX_SHOWN := 2
const DEPOT_OFF := Vector3(6.0, 0.0, 6.0)

const CRATE := Color(0.72, 0.5, 0.26)
const TAPE := Color(0.92, 0.88, 0.78)
const MARKER := Color(0.35, 0.8, 1.0)

var _landmarks: Array[Dictionary] = []
var _player: CharacterBody3D = null
var _missions = null
var _depots: Array[Dictionary] = []
## Active run: "dest" (Dictionary), "dist", "time", "total" (float).
var _run: Dictionary = {}
var _streak := 0
var _t := 0.0

var _prompt: Label
var _toast: Label
var _toast_tween: Tween


func setup(landmarks: Array[Dictionary]) -> void:
	_landmarks = landmarks
	for lm in _landmarks:
		if bool(lm.get("police", false)):
			continue
		var pos: Vector3 = lm["spawn"] + DEPOT_OFF
		var node := _build_crate()
		node.position = pos
		add_child(node)
		_depots.append({"node": node, "pos": pos, "cool": 0.0})
	_build_ui()


func register(p: CharacterBody3D, missions) -> void:
	_player = p
	_missions = missions


## Public: drop the run without pay (death / arrest reset).
func drop_parcel(reason: String) -> void:
	if _run.is_empty():
		return
	_run = {}
	_streak = 0
	_prompt.visible = false
	_show_toast("Parcel lost — %s, streak reset" % reason)


# ---------------------------------------------------------------- loop

func tick(delta: float, player: CharacterBody3D) -> void:
	_t += delta
	for d in _depots:
		if float(d["cool"]) > 0.0:
			d["cool"] = maxf(float(d["cool"]) - delta, 0.0)
	var pos: Vector3 = player.global_position
	if _run.is_empty():
		_tick_open(pos)
	else:
		_tick_run(delta, pos)


func _tick_open(pos: Vector3) -> void:
	var shown := 0
	var near := false
	for d in _depots:
		var node: Node3D = d["node"]
		if float(d["cool"]) > 0.0:
			node.visible = false
			continue
		var dist := _flat(pos, d["pos"])
		if dist < PICK_R:
			_grab(d, pos)
			return
		if dist < SHOW_R and shown < MAX_SHOWN:
			node.visible = true
			_bob_marker(node)
			shown += 1
			if dist < 34.0:
				near = true
		else:
			node.visible = false
	_prompt.visible = near
	if near:
		_prompt.text = "COURIER · run or ride through a crate to grab a delivery"


func _tick_run(delta: float, pos: Vector3) -> void:
	var dest: Dictionary = _run["dest"]
	_run["time"] = float(_run["time"]) - delta
	var left := float(_run["time"])
	if left <= 0.0:
		_expire()
		return
	var dist := _flat(pos, dest["center"])
	_prompt.text = "PARCEL → %s %s %dm · %ds left · streak %d — reach the drop" % [
		String(dest["name"]), _compass(pos, dest["center"]), int(dist), int(ceilf(left)), _streak]
	_prompt.visible = true
	if dist < DROP_R:
		_deliver()


# ---------------------------------------------------------------- events

func _grab(depot: Dictionary, from: Vector3) -> void:
	var options: Array[Dictionary] = []
	for lm in _landmarks:
		if _flat(from, lm["center"]) >= MIN_TRIP:
			options.append(lm)
	if options.is_empty():
		options = _landmarks
	var dest: Dictionary = options[randi() % options.size()]
	var dist := _flat(from, dest["center"])
	var total := BASE_TIME + dist * TIME_PER_M
	_run = {"dest": dest, "dist": dist, "time": total, "total": total}
	depot["node"].visible = false
	depot["cool"] = RESTOCK
	_show_toast("RUN GRABBED → %s — move it!" % String(dest["name"]))


func _deliver() -> void:
	var dest: Dictionary = _run["dest"]
	var dist := float(_run["dist"])
	var pay := (BASE_PAY + dist * PER_M) * (1.0 + STREAK_STEP * minf(_streak, STREAK_CAP))
	if float(_run["time"]) > FAST_CUT * float(_run["total"]):
		pay *= 1.0 + FAST_BONUS
	var rounded := int(roundf(pay / 5.0) * 5.0)
	_streak += 1
	_run = {}
	_missions.earn(rounded)
	_show_toast("DELIVERED · +Rs %d at %s — streak %d" % [rounded, String(dest["name"]), _streak])
	_prompt.visible = false


func _expire() -> void:
	_run = {}
	_streak = 0
	_prompt.visible = false
	_show_toast("RUN EXPIRED — parcel gone, streak reset")


# ---------------------------------------------------------------- helpers

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _compass(from: Vector3, to: Vector3) -> String:
	var ang := atan2(to.x - from.x, to.z - from.z)
	var oct := int(roundf(ang / (PI / 4.0))) % 8
	match absi(oct):
		0:
			return "S"
		1:
			return ("SW" if ang < 0.0 else "SE")
		2:
			return ("W" if ang < 0.0 else "E")
		_:
			return ("NW" if ang < 0.0 else "NE")


func _bob_marker(node: Node3D) -> void:
	var marker := node.get_node_or_null("Marker")
	if marker != null:
		marker.position.y = 1.9 + sin(_t * 3.2 + node.position.z) * 0.2
		marker.rotate_y(0.05)


# ---------------------------------------------------------------- visuals

func _build_crate() -> Node3D:
	var root := Node3D.new()
	var b := MeshTools.new()
	# Taped packing crate on the pavement, gem marker floating above.
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.7, 0.9)
	b.add_mesh(box, Transform3D(Basis(), Vector3(0, 0.35, 0)), CRATE)
	var band := BoxMesh.new()
	band.size = Vector3(0.96, 0.16, 0.96)
	b.add_mesh(band, Transform3D(Basis(), Vector3(0, 0.35, 0)), TAPE)
	var body := MeshInstance3D.new()
	body.mesh = b.build_mesh()
	root.add_child(body)
	var marker := Node3D.new()
	marker.name = "Marker"
	root.add_child(marker)
	var gem := BoxMesh.new()
	gem.size = Vector3(0.42, 0.42, 0.42)
	var mi := MeshInstance3D.new()
	mi.mesh = gem
	marker.add_child(mi)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARKER
	mat.emission_enabled = true
	mat.emission = MARKER
	mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	var label := Label3D.new()
	label.text = "COURIER"
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.75, 0.95, 1.0)
	label.position = Vector3(0, 0.5, 0)
	marker.add_child(label)
	return root


# ---------------------------------------------------------------- ui

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_bottom = -148.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -190.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
