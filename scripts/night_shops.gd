extends Node
## Night dressing for every enterable shop (issue #265): warm doorway
## spill, shop-name neon boards (bilingual where names exist) and
## hanging bulb strings at the dhaba/paan/kirana corners. Emissive
## materials only — zero new real lights — ramping on the same dusk
## curve as the windows and street lamps (main.gd _update_day calls
## set_night every frame). The station platform lamp evenness pass
## rides railway.gd (three even lamps now).

const MeshTools := preload("res://scripts/meshtools.gd")
const Roads := preload("res://scripts/roads.gd")
const HINDI := preload("res://assets/fonts/NotoSansDevanagari-Bold.ttf")

## Neon palette (same family as the world-clutter tube strips).
const NEON := [
	Color(0.98, 0.16, 0.14), Color(0.16, 0.90, 0.28),
	Color(1.00, 0.68, 0.16), Color(0.20, 0.55, 1.00),
]
const SPILL_COL := Color(1.0, 0.80, 0.45)
const BULB_COL := Color(1.0, 0.88, 0.62)
const BOARD := Color(0.10, 0.10, 0.11)
const POST := Color(0.16, 0.16, 0.17)
const WIRE := Color(0.16, 0.16, 0.17)

var _spill_mat: StandardMaterial3D = null
var _bulb_mat: StandardMaterial3D = null
var _neon_mats: Array[StandardMaterial3D] = []


func setup(world: float, pitch: float, road_w: float) -> void:
	## Block math mirrors interiors.gd / interiors2.gd / interiors3.gd /
	## delhi_dressing3.gd so the night layer never drifts off the shops.
	var cc := Vector2(-world / 2.0 + 4.0 * pitch + road_w / 2.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var pd := Vector2(-world / 2.0 + 3.0 * pitch + road_w / 2.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var cp := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var ps := Vector2(-world / 2.0 + 7.0 * pitch + road_w / 2.0,
			-world / 2.0 + 5.0 * pitch + road_w / 2.0)
	var pk := Vector2(-world / 2.0 + 8.0 * pitch + road_w / 2.0,
			-world / 2.0 + 2.0 * pitch + road_w / 2.0)
	var ig := Vector2(-world / 2.0 + 5.0 * pitch + road_w / 2.0,
			-world / 2.0 + 3.0 * pitch + road_w / 2.0)

	## One entry per enterable shop: doorway (open corners use the
	## roofed edge), name lines, neon color index, bulb-string flag.
	## Facing +X = yaw PI/2, facing -X = yaw -PI/2 (signage convention).
	var sites := [
		{"p": Vector3(cc.x - 5.0 + 1.55, Roads.CURB_H, cc.y + 4.0),
				"yaw": PI / 2.0, "door": true, "col": 2,
				"hi": "मिठाई भंडार", "en": "MITHAI", "bulbs": false},
		{"p": Vector3(pd.x + 9.5 - 1.9, Roads.CURB_H, pd.y - 9.5),
				"yaw": -PI / 2.0, "door": false, "col": 1,
				"hi": "ढाबा", "en": "DHABA", "bulbs": true},
		{"p": Vector3(cp.x - 13.0 + 2.03, Roads.CURB_H, cp.y - 12.0),
				"yaw": PI / 2.0, "door": true, "col": 3,
				"hi": "किराना", "en": "KIRANA", "bulbs": true},
		{"p": Vector3(ps.x + 10.0 + 1.43, Roads.CURB_H, ps.y - 12.0),
				"yaw": PI / 2.0, "door": true, "col": 0,
				"hi": "पान", "en": "PAAN", "bulbs": true},
		{"p": Vector3(pk.x - 12.0 + 2.03, Roads.CURB_H, pk.y + 10.0),
				"yaw": PI / 2.0, "door": true, "col": 2,
				"hi": "पुरानी किताबें", "en": "OLD BOOKS", "bulbs": false},
		{"p": Vector3(ig.x - 10.5 + 1.555, Roads.CURB_H, ig.y + 9.5),
				"yaw": PI / 2.0, "door": true, "col": 1,
				"hi": "दवाखाना", "en": "CHEMIST", "bulbs": true},
		{"p": Vector3(ps.x + 7.0 - 1.9, Roads.CURB_H, ps.y + 9.0),
				"yaw": -PI / 2.0, "door": false, "col": 0,
				"hi": "चाय ढाबा", "en": "CHAI DHABA", "bulbs": true},
	]

	var statics := MeshTools.new()
	var spill := MeshTools.new()
	var bulbs := MeshTools.new()
	var tubes: Array[MeshTools] = []
	for i in NEON.size():
		tubes.append(MeshTools.new())
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	ball.radial_segments = 6
	ball.rings = 4

	for s: Dictionary in sites:
		var base: Vector3 = s["p"]
		var yaw: float = s["yaw"]
		var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
		var across := fwd.cross(Vector3.UP)
		var col: int = s["col"]
		# Doorway spill: a warm panel filling the open doorway, read as
		# light leaking from the lit interior (walled shops only).
		if s["door"]:
			spill.add_box(Vector3(0.06, 1.95, 1.05), base + fwd * 0.0
					+ Vector3(0, 1.0, 0), Color.WHITE)
		# Name board: dark backboard just above the doorway/roof edge
		# with twin neon tubes in front and painted type over them.
		var board_y := 2.5 if s["door"] else 2.45
		var bw := 1.35 if s["door"] else 1.7
		var bp := base + fwd * 0.20 + Vector3(0, board_y, 0)
		statics.add_box(_span(across, fwd, bw + 0.16, 0.62, 0.07), bp, BOARD)
		var tube := BoxMesh.new()
		tube.size = _span(across, fwd, bw - 0.22, 0.07, 0.07)
		for v_off in [-0.16, 0.16]:
			tubes[col].add_mesh(tube,
					Transform3D(Basis(), bp + fwd * 0.10
					+ Vector3(0, v_off, 0)), Color.WHITE)
		# Open-corner boards hang from a slim post down to counter height.
		if not s["door"]:
			var post := BoxMesh.new()
			post.size = Vector3(0.06, 0.9, 0.06)
			for end in [-1.0, 1.0]:
				statics.add_mesh(post, Transform3D(Basis(),
						bp + Vector3(0, -0.6, 0) + across * end * 0.6), POST)
		_hi_en_labels(s, bp, fwd, NEON[col])
		# Hanging bulb strings: two sagging strings of warm bulbs under
		# the awning/roof edge, wire chord plus 7 bulbs each.
		if s["bulbs"]:
			var top_y := 2.15 if s["door"] else 2.25
			for z_end: float in [-1.0, 1.0]:
				var a := base + across * (z_end * 1.3) + fwd * 0.35 \
						+ Vector3(0, top_y, 0)
				var bpt := base + across * (-z_end * 1.3) + fwd * 0.35 \
						+ Vector3(0, top_y, 0)
				var chord := BoxMesh.new()
				chord.size = _chord(a, bpt)
				statics.add_mesh(chord, Transform3D(Basis(),
						(a + bpt) * 0.5), WIRE)
				for k in 7:
					var t := k / 6.0
					var sag := 0.16 * sin(PI * t)
					bulbs.add_mesh(ball, Transform3D(Basis(),
							a.lerp(bpt, t) + Vector3(0, -0.06 - sag, 0)),
							Color.WHITE)

	_spill_mat = _emissive(SPILL_COL)
	_bulb_mat = _emissive(BULB_COL)
	_attach(self, spill, _spill_mat, "ShopSpill")
	_attach(self, bulbs, _bulb_mat, "ShopBulbs")
	for i in NEON.size():
		var m := _emissive(NEON[i])
		_neon_mats.append(m)
		_attach(self, tubes[i], m, "ShopNeon%d" % i)
	var smi := statics.build_node()
	smi.name = "ShopNightStatics"
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)
	set_night(0.0)


func set_night(glow: float) -> void:
	## Dusk curve driver: 0 at noon, 1 deep night — same expression the
	## windows/lamps use, applied per frame by main.gd.
	if _spill_mat != null:
		_spill_mat.emission_energy_multiplier = 1.7 * glow
	if _bulb_mat != null:
		_bulb_mat.emission_energy_multiplier = 1.9 * glow
	for m in _neon_mats:
		m.emission_energy_multiplier = 2.4 * glow


func energies() -> Dictionary:
	## Headless night_check probe: current emissive energies.
	return {"spill": _spill_mat.emission_energy_multiplier
			if _spill_mat != null else 0.0,
			"bulbs": _bulb_mat.emission_energy_multiplier
			if _bulb_mat != null else 0.0,
			"neon": _neon_mats[0].emission_energy_multiplier
			if not _neon_mats.is_empty() else 0.0}


func _hi_en_labels(s: Dictionary, bp: Vector3, fwd: Vector3,
		neon: Color) -> void:
	## Painted type over the board: Devanagari line over the English
	## line, tinted toward the tube color so it reads lit at night.
	var hi := Label3D.new()
	hi.text = s["hi"]
	hi.font = HINDI
	hi.font_size = 46
	hi.modulate = neon.lightened(0.25)
	hi.pixel_size = 0.005
	hi.rotation = Vector3(0, float(s["yaw"]), 0)
	hi.position = bp + fwd * 0.22 + Vector3(0, 0.09, 0)
	add_child(hi)
	var en := Label3D.new()
	en.text = s["en"]
	en.font_size = 22
	en.modulate = Color(1.0, 0.97, 0.90)
	en.pixel_size = 0.005
	en.rotation = Vector3(0, float(s["yaw"]), 0)
	en.position = bp + fwd * 0.22 + Vector3(0, -0.14, 0)
	add_child(en)


func _span(across: Vector3, fwd: Vector3, w: float, h: float,
		thick: float) -> Vector3:
	return Vector3(absf(across.x) * w + absf(fwd.x) * thick, h,
			absf(across.z) * w + absf(fwd.z) * thick)


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
