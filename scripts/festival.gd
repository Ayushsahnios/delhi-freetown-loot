extends Node
## Diwali festival dressing (issue #263): fairy-string lights over the
## landmark blocks and every shopfront, diya clusters glowing at the
## thresholds and the ghat head-steps, and occasional firework bursts
## over the Yamuna water at night. Window: Nov 1-14 each year, forced
## year-round with the --festival cmdline arg (captures, perf gate).
## All procedural, all glow is emissive materials riding the same dusk
## curve as the shop neons (main.gd _update_day) — zero new real lights.

const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")

## Festival bulb palette: saffron, magenta, green, gold.
const FEST := [
	Color(1.00, 0.55, 0.12), Color(0.95, 0.20, 0.55),
	Color(0.25, 0.85, 0.35), Color(1.00, 0.80, 0.25),
]
const FLAME := Color(1.00, 0.62, 0.18)   # diya flame
const CLAY := Color(0.72, 0.40, 0.22)    # diya cup
const WIRE := Color(0.16, 0.16, 0.17)

## Diya cup profile (radius, height): wide clay foot, pinched rim.
var _diya_profile := PackedVector2Array([
	Vector2(0.012, 0.0), Vector2(0.075, 0.0), Vector2(0.088, 0.02),
	Vector2(0.062, 0.052), Vector2(0.058, 0.06)])

var _string_mats: Array[StandardMaterial3D] = []
var _diya_mat: StandardMaterial3D = null
var _bursts: Array = []   # {mi, mat, t, dur, origin}
var _burst_idx := 0
var _fuse := 5.0          # seconds to the next launch
var _river := Vector3.ZERO
var _night := 0.0


static func is_festival() -> bool:
	## Nov 1-14 window, or forced via --festival for captures/gates.
	for a in OS.get_cmdline_user_args():
		if a == "--festival":
			return true
	var d := Time.get_date_dict_from_system()
	return d.get("month", 0) == 11 and d.get("day", 0) >= 1 \
			and d.get("day", 0) <= 14


func setup(world: float, pitch: float, road_w: float,
		river: Vector3) -> void:
	## river = Yamuna ghat block center; bursts pop over the water east
	## of the steps. Block math mirrors night_shops.gd so the festival
	## layer never drifts off the shops.
	_river = river
	var cc := Vector3(-world / 2.0 + 4.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var pd := Vector3(-world / 2.0 + 3.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var cp := Vector3(-world / 2.0 + 5.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var ps := Vector3(-world / 2.0 + 7.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var pk := Vector3(-world / 2.0 + 8.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 2.0 * pitch + road_w / 2.0)
	var ig := Vector3(-world / 2.0 + 5.0 * pitch + road_w / 2.0, 0.0,
			-world / 2.0 + 3.0 * pitch + road_w / 2.0)

	## One entry per enterable shop (same bases as the #265 neon pass):
	## threshold diya row plus twin fairy strings under the awning.
	var sites := [
		{"p": cc + Vector3(-5.0 + 1.55, Roads.CURB_H, 4.0),
				"yaw": PI / 2.0},
		{"p": pd + Vector3(9.5 - 1.9, Roads.CURB_H, -9.5),
				"yaw": -PI / 2.0},
		{"p": cp + Vector3(-13.0 + 2.03, Roads.CURB_H, -12.0),
				"yaw": PI / 2.0},
		{"p": ps + Vector3(10.0 + 1.43, Roads.CURB_H, -12.0),
				"yaw": PI / 2.0},
		{"p": pk + Vector3(-12.0 + 2.03, Roads.CURB_H, 10.0),
				"yaw": PI / 2.0},
		{"p": ig + Vector3(-10.5 + 1.555, Roads.CURB_H, 9.5),
				"yaw": PI / 2.0},
		{"p": ps + Vector3(7.0 - 1.9, Roads.CURB_H, 9.0),
				"yaw": -PI / 2.0},
	]

	var statics := MeshTools.new()
	var bulbs: Array = []
	for i in FEST.size():
		bulbs.append(MeshTools.new())
	var cups := MeshTools.new()
	var flames := MeshTools.new()

	var ball := SphereMesh.new()
	ball.radius = 0.048
	ball.height = 0.096
	ball.radial_segments = 6
	ball.rings = 4
	var flame := SphereMesh.new()
	flame.radius = 0.02
	flame.height = 0.062
	flame.radial_segments = 5
	flame.rings = 3

	for s in sites:
		var base: Vector3 = s["p"]
		var yaw: float = s["yaw"]
		var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
		var across := Vector3(cos(yaw), 0.0, -sin(yaw))
		# Twin fairy strings across the storefront, under the neon board.
		for layer in 2:
			var top := 2.95 - 0.33 * float(layer)
			var a := base + across * 2.3 + fwd * (0.30 + 0.22 * float(layer)) \
					+ Vector3(0, top, 0)
			var b := base - across * 2.3 + fwd * (0.30 + 0.22 * float(layer)) \
					+ Vector3(0, top, 0)
			_strand(a, b, 0.22, 11, statics, bulbs, ball)
		# Threshold diya row: three clay lamps at the doorstep.
		for off in [-0.75, 0.0, 0.65]:
			var pos: Vector3 = base + fwd * 0.55 + across * off \
					+ Vector3(0, 0.02, 0)
			_diya(pos, cups, flames, flame)

	# Landmark blocks (CP, India Gate, Chandni Chowk, Purani Dilli) get
	# one long catenary over the road on their west kerb — the classic
	# cross-street festival string, clear of traffic and lamp arms.
	for lm in [cp, ig, cc, pd]:
		_strand(Vector3(lm.x - pitch * 0.5, 5.8, lm.z - 10.0),
				Vector3(lm.x - pitch * 0.5, 5.8, lm.z + 10.0),
				0.55, 13, statics, bulbs, ball)

	# Ghat head-step aarti row: six diyas along the top Yamuna step.
	for k in 6:
		_diya(river + Vector3(-11.0, 1.28, -10.0 + 4.0 * k),
				cups, flames, flame)

	# Firework pool: three reusable bursts of 40 sparks each (unit
	# sphere, fibonacci spread); the whole multimesh scales outward and
	# fades on its own emissive material — never a real light.
	var spark := SphereMesh.new()
	spark.radius = 0.16
	spark.height = 0.32
	spark.radial_segments = 5
	spark.rings = 3
	var golden := PI * (3.0 - sqrt(5.0))
	var xfs: Array = []
	for k in 40:
		var yy := 1.0 - 2.0 * float(k) / 39.0
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var th := golden * float(k)
		xfs.append(Transform3D(Basis(),
				Vector3(cos(th) * rr, yy, sin(th) * rr)))
	for i in 3:
		var mat := _emissive(Color.WHITE)
		var mi := MeshTools.make_multimesh(spark, xfs)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_bursts.append({"mi": mi, "mat": mat, "t": 1.0, "dur": 1.0,
				"origin": Vector3.ZERO})

	_attach(self, statics, MeshTools.shared_material(WIRE), "FestWire")
	for i in FEST.size():
		var m := _emissive(FEST[i])
		_string_mats.append(m)
		_attach(self, bulbs[i], m, "FestBulbs%d" % i)
	_attach(self, cups, MeshTools.shared_material(CLAY), "FestDiyas")
	_diya_mat = _emissive(FLAME)
	_attach(self, flames, _diya_mat, "FestFlames")
	set_night(0.0)


func set_night(glow: float) -> void:
	## Dusk curve driver: 0 at noon, 1 deep night — same expression the
	## windows/lamps/neons use, applied per frame by main.gd.
	for m in _string_mats:
		m.emission_energy_multiplier = 2.2 * glow
	if _diya_mat != null:
		_diya_mat.emission_energy_multiplier = 2.1 * glow


func tick(delta: float, night: float) -> void:
	## Firework loop: bursts only fire after dark, over the river water.
	_night = night
	for b in _bursts:
		if b["t"] >= b["dur"]:
			if b["mi"].visible:
				b["mi"].visible = false
			continue
		b["t"] += delta
		var t01 := clampf(b["t"] / b["dur"], 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - t01, 2.0)
		b["mi"].scale = Vector3.ONE * (0.6 + 8.4 * ease_out)
		b["mi"].position = b["origin"] - Vector3(0, 2.2 * t01 * t01, 0)
		b["mat"].emission_energy_multiplier = \
				pow(sin(PI * minf(t01 * 1.15, 1.0)), 0.7) * 3.4 * night
	if night > 0.45:
		_fuse -= delta
		if _fuse <= 0.0:
			_fire()
			_fuse = randf_range(7.0, 16.0)


func energies() -> Dictionary:
	## Headless probe: current emissive energies (checks/night capture).
	return {"strings": _string_mats[0].emission_energy_multiplier
			if not _string_mats.is_empty() else 0.0,
			"diyas": _diya_mat.emission_energy_multiplier
			if _diya_mat != null else 0.0,
			"firework": _bursts[0]["mat"].emission_energy_multiplier
			if not _bursts.is_empty() else 0.0}


func _fire() -> void:
	## Launch the next pooled burst over the Yamuna water edge.
	var b: Dictionary = _bursts[_burst_idx % _bursts.size()]
	_burst_idx += 1
	b["origin"] = _river + Vector3(10.0 + randf() * 6.0,
			24.0 + randf() * 10.0, -14.0 + randf() * 28.0)
	b["mat"].emission = FEST[_burst_idx % FEST.size()]
	b["t"] = 0.0
	b["dur"] = 1.2 + randf() * 0.4
	b["mi"].position = b["origin"]
	b["mi"].visible = true


func _strand(a: Vector3, b: Vector3, sag: float, n: int,
		statics: MeshTools, bulbs: Array, ball: SphereMesh) -> void:
	## One sagging string: thin wire chord plus n multicolor bulbs.
	var chord := BoxMesh.new()
	chord.size = _chord(a, b)
	statics.add_mesh(chord, Transform3D(Basis(), (a + b) * 0.5), WIRE)
	for k in n:
		var t := float(k) / float(n - 1)
		var drop := sag * sin(PI * t)
		bulbs[k % bulbs.size()].add_mesh(ball, Transform3D(Basis(),
				a.lerp(b, t) - Vector3(0, 0.05 + drop, 0)), Color.WHITE)


func _diya(pos: Vector3, cups: MeshTools, flames: MeshTools,
		flame: SphereMesh) -> void:
	## Clay lamp: lathe cup plus a tiny emissive flame tongue.
	cups.add_lathe(_diya_profile, pos, CLAY, MeshTools.FINISH_MATTE, 8)
	flames.add_mesh(flame, Transform3D(Basis(),
			pos + Vector3(0, 0.085, 0)), Color.WHITE)


func _chord(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	return Vector3(absf(d.x) + 0.02, 0.03, absf(d.z) + 0.02)


func _emissive(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.0
	m.roughness = 0.4
	return m


func _attach(parent: Node, b: MeshTools, m: StandardMaterial3D,
		name: String) -> void:
	var mesh := b.build_mesh()
	if mesh.get_surface_count() == 0:
		return
	for surf in mesh.get_surface_count():
		mesh.surface_set_material(surf, m)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
