extends Node
## Monsoon crowd gear (issue #221): when rain falls, the walkers
## adapt. A share of near pedestrians carry procedural umbrellas — a
## faceted gore canopy on a slim stem, color-varied per identity —
## others shrug on rain-jacket shells, and every walker's fabrics
## soak: the palette darkens with a wet sheen while it pours, then
## dries back to the rolled palette shortly after the shower passes.
## Umbrellas and jackets stay inside the near ring so the perf budget
## holds (far walkers stay gear-free); all meshes procedural, in the
## PS2-era vocabulary — faceted planes, no toon outlines.

const GEAR_RADIUS := 65.0      # near-LOD gate: umbrellas/jackets only
const RAIN_ON := 0.12          # rain intensity where gear comes out
const RAIN_OFF := 0.04         # intensity where gear packs away
const WET_STEP := 0.05         # soak steps that re-tint fabrics
const WET_DARK := 0.32         # albedo darkening at full soak
const WET_SHEEN := 0.45        # roughness drop at full soak
const DRY_LEVEL := 0.02        # below this the street has dried out
const ROLL_UMBRELLA := 45      # % of walkers carrying one
const ROLL_JACKET := 75        # % ceiling for the jacket-only roll

## Muted street palette (auto-picked from the art-ref vocabulary —
## drenched-day cloth reads in dark saturations, never candy; veto
## anytime): canopies in deep cloth tones, shells in raincoat shades.
const CANOPY_COLORS := [
	Color(0.16, 0.20, 0.30), Color(0.34, 0.12, 0.13), Color(0.10, 0.22, 0.16),
	Color(0.12, 0.12, 0.14), Color(0.30, 0.24, 0.10), Color(0.13, 0.24, 0.28),
]
const JACKET_COLORS := [
	Color(0.10, 0.12, 0.16), Color(0.16, 0.20, 0.13), Color(0.20, 0.08, 0.10),
	Color(0.26, 0.20, 0.07), Color(0.09, 0.16, 0.20),
]

const PED_HEIGHT := 1.68       # mirrors pedestrians.gd PED_HEIGHT
const CANOPY_R := 0.46         # metres — a real street umbrella
const CANOPY_DOME := 0.30      # crown height above the rim
const CANOPY_SEGMENTS := 8     # gores — the PS2 facet count

var _peds: Node = null
var _raining := false
var _umbrellas := 0
var _jackets := 0


func setup(peds: Node) -> void:
	_peds = peds


func tick(_delta: float, intensity: float, wetness: float,
		cam: Camera3D) -> void:
	if _peds == null or not _peds.has_method("walker_list"):
		return
	if not _raining and intensity >= RAIN_ON:
		_raining = true
	elif _raining and intensity < RAIN_OFF:
		_raining = false
	var list: Array = _peds.walker_list()
	for v in list:
		var node: Node3D = v.get("node")
		if node == null:
			continue
		var shown := bool(v.get("visible", false))
		# Gear: built once per walker (identity roll), carried hidden
		# between showers, and only shown inside the near ring.
		var gear: Node3D = v.get("gear_node")
		if gear == null and v.get("gear_none", false):
			continue
		if shown and cam != null:
			var near := node.global_position.distance_to(
					cam.global_position) <= GEAR_RADIUS
			if gear == null and _raining and near:
				gear = _build_gear(v, node)
			if gear != null:
				gear.visible = _raining and near
		elif gear != null:
			gear.visible = false
		# Soak tint: applied to every VISIBLE walker near or far —
		# crowds across the street read soaked too, and the write only
		# happens when the soak step actually changes.
		if shown and wetness > DRY_LEVEL:
			_apply_soak(v, wetness)
	# Dry-out: restore every walker's palette exactly — including
	# sleepers — once the shower has passed and the streets drained.
	if wetness <= DRY_LEVEL:
		for v in list:
			_apply_soak(v, 0.0)


func stats() -> Dictionary:
	## Read-back for gates/reports: how the crowd is geared right now.
	return {"raining": _raining, "umbrellas": _umbrellas,
			"jackets": _jackets}


# ------------------------------------------------------------------ gear

func _build_gear(v: Dictionary, node: Node3D) -> Node3D:
	## One gear node per walker, rolled from the identity seed so a
	## walker keeps its monsoon habit across showers and recycles:
	## umbrella, jacket, or bare-headed stalwart. Holder-fixed world
	## units (the wardrobe pattern) — no bone dependency, fits every
	## rig alike.
	var id: Dictionary = v.get("id", {})
	var seed := absi(int(id.get("seed", 0)))
	var roll := seed % 100
	var gear := Node3D.new()
	gear.name = "RainGear"
	node.add_child(gear)
	var h := PED_HEIGHT * float(id.get("height", 1.0))
	if roll < ROLL_UMBRELLA:
		_build_umbrella(gear, h, (seed / 7) % CANOPY_COLORS.size())
		_umbrellas += 1
	elif roll < ROLL_JACKET:
		_build_jacket(gear, h, (seed / 11) % JACKET_COLORS.size())
		_jackets += 1
	else:
		v["gear_none"] = true
	v["gear_node"] = gear
	return gear


func _build_umbrella(gear: Node3D, h: float, ci: int) -> void:
	## Carried umbrella: faceted gore canopy + slim stem + finial tip,
	## tilted in over the carry shoulder. 74 triangles total.
	var u := Node3D.new()
	u.transform = Transform3D(
			Basis(Vector3(0.0, 0.0, 1.0), -0.10)
					* Basis(Vector3.RIGHT, 0.06),
			Vector3(0.075 * h, 0.0, 0.0))
	gear.add_child(u)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = CANOPY_COLORS[ci]
	cloth.roughness = 0.55
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_canopy(u, cloth, h)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.008
	sm.bottom_radius = 0.011
	sm.height = 0.46 * h
	sm.radial_segments = 6
	sm.cap_top = false
	sm.cap_bottom = false
	stem.mesh = sm
	stem.material_override = _dark_metal()
	stem.transform = Transform3D(Basis(), Vector3(0.0, 0.83 * h, 0.0))
	u.add_child(stem)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.014
	tm.height = 0.05
	tm.radial_segments = 6
	tip.mesh = tm
	tip.material_override = _dark_metal()
	tip.transform = Transform3D(Basis(), Vector3(0.0, 1.085 * h, 0.0))
	u.add_child(tip)


func _canopy(parent: Node3D, cloth: StandardMaterial3D, h: float) -> void:
	## Faceted gore dome: 8 flat-shaded panels off a lathe profile
	## whose rim droops like a tensioned canopy. Flat shading comes
	## from unique vertices per triangle (nothing shared), so the gores
	## read separately with zero toon outlining.
	var profile := PackedVector2Array([
		Vector2(0.00, 0.95), Vector2(0.38, 0.80), Vector2(0.72, 0.52),
		Vector2(0.96, 0.18), Vector2(1.00, 0.02),
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in CANOPY_SEGMENTS:
		var a0 := TAU * float(seg) / CANOPY_SEGMENTS
		var a1 := TAU * float(seg + 1) / CANOPY_SEGMENTS
		for r in profile.size() - 1:
			var lo: Vector2 = profile[r]
			var hi: Vector2 = profile[r + 1]
			if r == 0:
				# Center ring collapses to a single fan triangle.
				_add_tri(st, _gore_pt(lo, a0), _gore_pt(hi, a1),
						_gore_pt(hi, a0))
			else:
				var a := _gore_pt(lo, a0)
				var b := _gore_pt(lo, a1)
				var c := _gore_pt(hi, a1)
				var d := _gore_pt(hi, a0)
				_add_tri(st, a, b, c)
				_add_tri(st, a, c, d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = cloth
	mi.transform = Transform3D(Basis(), Vector3(0.0, 1.02 * h, 0.0))
	parent.add_child(mi)


func _gore_pt(p: Vector2, ang: float) -> Vector3:
	return Vector3(cos(ang) * p.x * CANOPY_R, p.y * CANOPY_DOME,
			sin(ang) * p.x * CANOPY_R)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _build_jacket(gear: Node3D, h: float, ci: int) -> void:
	## Rain-jacket shell: a smooth waist-to-shoulder wrap in raincoat
	## cloth with a wet sheen, stand collar, and a hood lump resting
	## between the shoulder blades. ~88 triangles total.
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = JACKET_COLORS[ci]
	cloth.roughness = 0.38
	var shell := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 0.105 * h
	shm.bottom_radius = 0.115 * h
	shm.height = 0.28 * h
	shm.radial_segments = 10
	shm.cap_top = false
	shm.cap_bottom = false
	shell.mesh = shm
	shell.material_override = cloth
	shell.transform = Transform3D(Basis(), Vector3(0.0, 0.64 * h, 0.0))
	gear.add_child(shell)
	var collar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055 * h
	cm.bottom_radius = 0.062 * h
	cm.height = 0.05 * h
	cm.radial_segments = 10
	collar.mesh = cm
	collar.material_override = cloth
	collar.transform = Transform3D(Basis(), Vector3(0.0, 0.80 * h, 0.0))
	gear.add_child(collar)
	var hood := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.055 * h
	hm.height = 0.11 * h
	hm.radial_segments = 8
	hm.rings = 4
	hood.mesh = hm
	hood.material_override = cloth
	hood.transform = Transform3D(
			Basis().scaled(Vector3(1.0, 0.7, 0.8)),
			Vector3(0.0, 0.80 * h, 0.062 * h))
	gear.add_child(hood)


func _dark_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.09, 0.10)
	m.roughness = 0.4
	m.metallic = 0.3
	return m


# ------------------------------------------------------------------ soak

func _apply_soak(v: Dictionary, wetness: float) -> void:
	## Darken garment fabrics toward a soaked read with a wet sheen,
	## in steps — the tint, wardrobe meshes, hair and skin all soak a
	## touch, exactly what a monsoon downpour does. Stepping means the
	## material writes happen a dozen times per shower per walker, not
	## per frame; step 0 restores the exact dry palette.
	var step := int(round(wetness / WET_STEP))
	if step == int(v.get("wet_step", -1)):
		return
	v["wet_step"] = step
	var node: Node3D = v.get("node")
	if node == null:
		return
	if not v.has("wet_mats"):
		_stash_materials(v, node)
	var wet := clampf(float(step) * WET_STEP, 0.0, 1.0)
	for e in v["wet_mats"]:
		var m: StandardMaterial3D = e[0]
		m.albedo_color = (e[1] as Color).darkened(WET_DARK * wet)
		m.roughness = float(e[2]) * (1.0 - WET_SHEEN * wet)


func _stash_materials(v: Dictionary, node: Node3D) -> void:
	## Remember every walker-specific material and its dry values once,
	## so soaking is a multiply and drying restores exactly. Body
	## garment materials are per-instance duplicates (characters.gd
	## tint) and wardrobe meshes carry fresh overrides, so no material
	## is ever shared between walkers. The raingear subtree itself is
	## skipped — umbrellas and shells keep their own wet sheen.
	var gear: Node3D = v.get("gear_node")
	var mats: Array = []
	for mi_node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if gear != null and gear.is_ancestor_of(mi):
			continue
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(s)
				if m != null and m is StandardMaterial3D:
					mats.append([m, m.albedo_color, m.roughness])
		var ov = mi.material_override
		if ov != null and ov is StandardMaterial3D:
			mats.append([ov, ov.albedo_color, ov.roughness])
	v["wet_mats"] = mats
