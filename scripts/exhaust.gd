extends Node3D
## Idle exhaust puffs (issue #166): a small pool of billboarded quads in
## one MultiMesh — each puff is born at a tailpipe, drifts on the breeze,
## grows and fades via its instance-color alpha. One pool serves the
## driven vehicle and ambient traffic alike; fully procedural, no
## textures and no particle nodes.

const POOL := 24
const PUFF_R := 0.70
const PUFF_G := 0.70
const PUFF_B := 0.73

var _mm: MultiMesh
var _data: Array[Dictionary] = []
var _cursor := 0


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = quad
	# Colors must be enabled before the instance count is raised off zero.
	_mm.use_colors = true
	_mm.instance_count = POOL
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in POOL:
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0.0, -500.0, 0.0)))
		_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
		_data.append({"t": 1.0, "life": 1.0, "pos": Vector3.ZERO,
				"vel": Vector3.ZERO, "size": 0.3})


func spawn(pos: Vector3, vel: Vector3, size := 0.22, life := 1.6) -> void:
	## One puff: born at `pos`, drifting with `vel`, swelling from
	## `size` over `life` seconds. The pool wraps, so the oldest puff
	## fades the moment a new one needs the slot.
	var p := _data[_cursor]
	p["t"] = 0.0
	p["life"] = life
	p["pos"] = pos
	p["vel"] = vel
	p["size"] = size
	_cursor = (_cursor + 1) % POOL


func _process(delta: float) -> void:
	for i in POOL:
		var p := _data[i]
		var t := float(p["t"])
		if t >= float(p["life"]):
			continue
		t += delta
		p["t"] = t
		var u := clampf(t / float(p["life"]), 0.0, 1.0)
		var s := float(p["size"]) * (0.5 + 2.2 * u)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)),
				p["pos"] + p["vel"] * t))
		# Quick birth, slow death: alpha peaks just after leaving the
		# pipe and melts away as the puff swells.
		var a := 0.34 * (1.0 - u) * smoothstep(0.0, 0.18, u)
		_mm.set_instance_color(i, Color(PUFF_R, PUFF_G, PUFF_B, a))
		if u >= 1.0:
			_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0.0, -500.0, 0.0)))
			_mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
