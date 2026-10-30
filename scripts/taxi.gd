extends Node3D
## Rickshaw taxi hustle (issue #99, part 1). Drive the parked auto-rickshaw,
## pull up next to a raised hand on any roadside, hold still a beat to pick
## the passenger up, then run the meter to their landmark and stop to drop
## them off for cash. Fares pay into the mission wallet and persist with the
## save; step out mid-fare and the passenger waits briefly, then walks.
## Passengers, raised-arm hails and floating markers are procedural — no assets.

const MeshTools := preload("res://scripts/meshtools.gd")

## Economy pass (issue #210): base + per-metre tuned so a clean median
## ride (≈200 m) banks ~Rs 130 + tip, holding the ~20-min
## first-upgrade target on the tuned curve.
const BASE_FARE := 20
const RATE_PER_M := 0.55
const BOARD_R := 5.5
const DROP_R := 17.0
const STOP_SPEED := 2.2
const DWELL := 0.6
const GRACE := 15.0
const HAIL_COOLDOWN := 45.0
const MIN_TRIP := 70.0
const SHOW_R := 95.0
const MAX_SHOWN := 2
## Tip tiers + ride grading (issue #203 part 2): par time is the
## straight-line run at a cruise pace plus pickup/drop slack; a clean
## (crash-free) AND fast ride earns GOLD, either alone earns SILVER.
const PAR_SPEED := 9.0
const PAR_PAD := 6.0
const TIP_GOLD := 0.30
const TIP_SILVER := 0.15
## Three hard knocks mid-fare and the passenger bails without paying.
const BAIL_CRASHES := 3
## Idle radio calls (issue #203): quiet cruising gets pinged toward the
## nearest roadside hail so the hustle never stalls for lack of a fare.
const RADIO_EVERY := 22.0

const KURTA := Color(0.92, 0.72, 0.25)
const PANTS := Color(0.2, 0.22, 0.28)
const SKIN := Color(0.62, 0.42, 0.30)
const MARKER := Color(1.0, 0.85, 0.2)

## Roadside hail spots, same clearance pattern as the parked vehicles:
## sidewalk edge beside the road grid, spread across the whole map.
const SPOTS := [
	Vector3(ROAD_EDGE, 1.0, 2.0 * PITCH - 14.0),
	Vector3(-ROAD_EDGE, 1.0, PITCH - 6.0),
	Vector3(ROAD_EDGE, 1.0, -2.0 * PITCH + 12.0),
	Vector3(-ROAD_EDGE, 1.0, -3.0 * PITCH + 18.0),
	Vector3(2.0 * PITCH - 8.0, 1.0, ROAD_EDGE),
	Vector3(-2.0 * PITCH + 14.0, 1.0, ROAD_EDGE),
	Vector3(3.0 * PITCH - 6.0, 1.0, -ROAD_EDGE),
	Vector3(-PITCH + 10.0, 1.0, -ROAD_EDGE),
	Vector3(PITCH - 8.0, 1.0, ROAD_EDGE),
	Vector3(4.0 * PITCH - 12.0, 1.0, ROAD_EDGE),
	Vector3(-3.0 * PITCH + 8.0, 1.0, -ROAD_EDGE),
	Vector3(ROAD_EDGE, 1.0, -PITCH + 16.0),
]
const ROAD_EDGE := 12.0 / 2.0 + 1.3
const PITCH := 34.0 + 12.0

var _landmarks: Array[Dictionary] = []
var _player: CharacterBody3D = null
var _missions = null
var _hails: Array[Dictionary] = []
## Active fare: "dest" (Dictionary), "trip_m", "grace".
var _fare: Dictionary = {}
var _board_t := 0.0
var _drop_t := 0.0
var _t := 0.0
var _radio_t := 0.0

var _prompt: Label
var _toast: Label
var _toast_tween: Tween


func setup(landmarks: Array[Dictionary]) -> void:
	_landmarks = landmarks
	for spot in SPOTS:
		var node := _build_passenger()
		node.position = spot
		add_child(node)
		_hails.append({"node": node, "pos": spot, "cool": 0.0})
	_build_ui()


func register(p: CharacterBody3D, missions) -> void:
	_player = p
	_missions = missions


## Public: drop a fare without pay (death / arrest reset).
func drop_fare(reason: String) -> void:
	if _fare.is_empty():
		return
	_fare = {}
	_grace_reset()
	_prompt.visible = false
	_show_toast("Fare walked off — %s" % reason)


# ---------------------------------------------------------------- loop

func tick(delta: float, current_auto, player: CharacterBody3D) -> void:
	_t += delta
	for h in _hails:
		if float(h["cool"]) > 0.0:
			h["cool"] = maxf(float(h["cool"]) - delta, 0.0)
	var driving := current_auto != null and String(current_auto.kind) == "auto"
	if _fare.is_empty():
		_tick_cruising(delta, current_auto, driving)
		return
	_tick_fare(delta, current_auto, driving)


func _tick_cruising(delta: float, current_auto, driving: bool) -> void:
	_board_t = 0.0
	_drop_t = 0.0
	if not driving:
		for h in _hails:
			h["node"].visible = false
		_prompt.visible = false
		_radio_t = 0.0
		return
	var pos: Vector3 = current_auto.global_position
	var shown := 0
	var nearest: Dictionary = {}
	var nearest_d := BOARD_R
	for h in _hails:
		var node: Node3D = h["node"]
		if float(h["cool"]) > 0.0:
			node.visible = false
			continue
		var d := _flat(pos, h["pos"])
		if d < SHOW_R and shown < MAX_SHOWN:
			node.visible = true
			_bob_marker(node)
			shown += 1
			if d < nearest_d:
				nearest_d = d
				nearest = h
		else:
			node.visible = false
	if nearest.is_empty():
		_prompt.visible = false
		# Radio call (issue #203): nothing waving nearby, so dispatch
		# points the driver at the closest roadside hail on the map.
		_radio_t += delta
		if _radio_t >= RADIO_EVERY:
			_radio_t = 0.0
			var spot: Dictionary = {}
			var spot_d := INF
			for h in _hails:
				var d := _flat(pos, h["pos"])
				if d < spot_d:
					spot_d = d
					spot = h
			if not spot.is_empty() and float(spot["cool"]) > 0.0:
				spot["cool"] = 0.0
			_show_toast("RADIO · hail waving %s of you, %dm — go get it" % [
				_compass(pos, spot["pos"]), int(spot_d)])
		return
	_radio_t = 0.0
	_prompt.text = "TAXI · stop by the raised hand to pick up"
	_prompt.visible = true
	if current_auto.current_speed() < STOP_SPEED:
		_board_t += delta
		if _board_t >= DWELL:
			_board(nearest, current_auto)
	else:
		_board_t = 0.0


func _tick_fare(delta: float, current_auto, driving: bool) -> void:
	var dest: Dictionary = _fare["dest"]
	if driving:
		_fare["grace"] = GRACE
		var pos: Vector3 = current_auto.global_position
		_fare["trip_m"] = float(_fare["trip_m"]) + current_auto.current_speed() * delta
		var knocks := _knocks(current_auto)
		if knocks >= BAIL_CRASHES:
			drop_fare("too rough a ride")
			return
		var d := _flat(pos, dest["center"])
		var meter := _meter()
		var ride := "clean" if knocks == 0 else "%d knocks" % knocks
		_prompt.text = "FARE → %s %s %dm  ·  meter Rs %d · %s — stop at the drop" % [
			String(dest["name"]), _compass(pos, dest["center"]), int(d), meter, ride]
		_prompt.visible = true
		if d < DROP_R and current_auto.current_speed() < STOP_SPEED:
			_drop_t += delta
			if _drop_t >= DWELL:
				_drop_off(current_auto)
		else:
			_drop_t = 0.0
	else:
		_drop_t = 0.0
		_fare["grace"] = float(_fare["grace"]) - delta
		_prompt.text = "Fare waiting in the rickshaw · %ds to walk off" % int(ceilf(float(_fare["grace"])))
		_prompt.visible = true
		if float(_fare["grace"]) <= 0.0:
			drop_fare("kept waiting")


# ---------------------------------------------------------------- events

func _board(hail: Dictionary, current_auto) -> void:
	var from: Vector3 = hail["pos"]
	var options: Array[Dictionary] = []
	for lm in _landmarks:
		if _flat(from, lm["center"]) >= MIN_TRIP:
			options.append(lm)
	if options.is_empty():
		options = _landmarks
	var dest: Dictionary = options[randi() % options.size()]
	var crash0 := 0
	if current_auto != null:
		crash0 = int(current_auto.crash_count())
	var par := _flat(from, dest["center"]) / PAR_SPEED + PAR_PAD
	_fare = {"dest": dest, "trip_m": 0.0, "grace": GRACE, "t0": _t, "crash0": crash0, "par": par}
	hail["node"].visible = false
	hail["cool"] = HAIL_COOLDOWN
	_board_t = 0.0
	_show_toast("FARE ABOARD · %s — run the meter" % String(dest["name"]))


func _drop_off(current_auto) -> void:
	var dest: Dictionary = _fare["dest"]
	var fare := _meter()
	var knocks := _knocks(current_auto)
	var clean := knocks == 0
	var fast := _t - float(_fare["t0"]) <= float(_fare["par"])
	var tip := 0
	var note := "no tip — keep it smooth"
	if clean and fast:
		tip = _round5(fare * TIP_GOLD)
		note = "GOLD tip Rs %d — clean and fast" % tip
	elif clean:
		tip = _round5(fare * TIP_SILVER)
		note = "SILVER tip Rs %d — clean ride" % tip
	elif fast:
		tip = _round5(fare * TIP_SILVER)
		note = "SILVER tip Rs %d — fast run" % tip
	_fare = {}
	_drop_t = 0.0
	_missions.earn(fare + tip, "fares")
	_show_toast("FARE PAID · +Rs %d at %s · %s" % [fare + tip, String(dest["name"]), note])
	_prompt.visible = false


# ---------------------------------------------------------------- helpers

func _meter() -> int:
	var raw := BASE_FARE + float(_fare["trip_m"]) * RATE_PER_M
	return _round5(raw)


func _round5(v: float) -> int:
	return int(roundf(v / 5.0) * 5.0)


func _knocks(current_auto) -> int:
	## Crashes landed since boarding — the ride's cleanliness grade.
	if current_auto == null or _fare.is_empty():
		return 0
	return maxi(int(current_auto.crash_count()) - int(_fare["crash0"]), 0)


func _grace_reset() -> void:
	_board_t = 0.0
	_drop_t = 0.0


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
		marker.position.y = 2.9 + sin(_t * 3.0 + node.position.x) * 0.22
		marker.rotate_y(0.04)


# ---------------------------------------------------------------- visuals

func _build_passenger() -> Node3D:
	var root := Node3D.new()
	var b := MeshTools.new()
	# Stylised hail (de-boxed, issue #238): standing figure with a
	# capsule-tapered leg column, elliptic capsule torso, stub neck,
	# ball head, one tapered arm raised on a ball shoulder.
	b.add_round_lathe(MeshTools.capsule_profile(0.20, 0.16, 0.85),
			Transform3D(Basis(), Vector3(0, 0.005, 0)), PANTS)
	b.add_round_lathe(PackedVector2Array([
				Vector2(0.05, 0.0), Vector2(0.21, 0.06), Vector2(0.20, 0.24),
				Vector2(0.225, 0.55), Vector2(0.19, 0.66), Vector2(0.06, 0.72)]),
			Transform3D(Basis(), Vector3(0, 0.84, 0)), KURTA,
			MeshTools.FINISH_MATTE, 10, 0.62)
	b.add_round_lathe(MeshTools.capsule_profile(0.05, 0.055, 0.12),
			Transform3D(Basis(), Vector3(0, 1.56, 0)), SKIN)
	b.add_round_lathe(MeshTools.ball_profile(0.15, 3),
			Transform3D(Basis(), Vector3(0, 1.59, 0)), SKIN,
			MeshTools.FINISH_MATTE, 10, 0.95)
	b.add_round_lathe(MeshTools.capsule_profile(0.065, 0.052, 0.72),
			Transform3D(Basis(Vector3(0, 0, 1), PI * 0.42), Vector3(0.3, 1.55, 0)), SKIN)
	b.add_round_lathe(MeshTools.ball_profile(0.075, 3),
			Transform3D(Basis(), Vector3(0.27, 1.5, 0)), SKIN)
	var body := MeshInstance3D.new()
	body.mesh = b.build_mesh()
	root.add_child(body)
	var marker := Node3D.new()
	marker.name = "Marker"
	root.add_child(marker)
	var flag := BoxMesh.new()
	flag.size = Vector3(0.55, 0.4, 0.06)
	var mi := MeshInstance3D.new()
	mi.mesh = flag
	mi.position = Vector3(0, 0.0, 0)
	marker.add_child(mi)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MARKER
	mat.emission_enabled = true
	mat.emission = MARKER
	mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	var label := Label3D.new()
	label.text = "TAXI"
	label.font_size = 64
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.6)
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
	_prompt.offset_bottom = -62.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -110.0
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
