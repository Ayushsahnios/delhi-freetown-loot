extends RefCounted
## Street-facing facade detail pass (issue #162): the art-ref bar asks for
## depth on every street wall — window grids get real frames with sills and
## lintel ledges, mid-floor concrete balconies appear on a subset of
## towers, hut shopfronts get roll-down corrugated shutters (some open
## into dark recesses), and each building's plaster tint varies slightly
## so blocks stop reading as one flat colour. Purely procedural: panes and
## shutters draw as textured MultiMesh units, frames/balconies/trim as
## merged ArrayMesh units, plinths fold into the district mesh.

const MeshTools := preload("res://scripts/meshtools.gd")

## Shared street-plinth tone: one extra district surface for the whole city.
const GRIME_SKIRT := Color(0.34, 0.29, 0.24)

## Pane grid (kept identical to the old _add_windows pass so night-lit
## ratios and sight-lines stay put).
const PANE_STEP_U := 3.0
const PANE_STEP_Y := 3.6
const PANE_BASE_Y := 2.6


static func _seed_for(pos: Vector3, size: Vector3) -> int:
	## Deterministic per-building seed — facade rolls never change between
	## runs for the same generated layout.
	var s := hash(pos) ^ hash(size)
	return int(s) if s != 0 else 1


static func dress_building(pos: Vector3, size: Vector3, outward: Vector3,
		base: Color) -> Dictionary:
	## One facade pass for one building. Returns transform lists for panes,
	## lit panes, frames, balconies, shutters, interiors and shopfront trim,
	## plus the building's plaster variant and whether it wears a plinth.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(pos, size)

	var variant := rng.randf() < 0.5
	var plaster := base.darkened(0.07) if variant else base.lightened(0.04)

	var panes: Array[Transform3D] = []
	var lit: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var balconies: Array[Transform3D] = []
	var shutters: Array[Transform3D] = []
	var interiors: Array[Transform3D] = []
	var trim: Array[Transform3D] = []

	if size.y < 9.0:
		# Huts read as shops: no upper glazing, street-facing shutters
		# instead (a closed corrugated roll-down or an open dark recess).
		var nrm := Vector3(0.0, 0.0, 1.0) if outward == Vector3.ZERO \
				else outward.normalized()
		var theta := atan2(nrm.x, nrm.z)
		var across := Vector3(nrm.z, 0.0, -nrm.x)
		var wall_len: float = nrm.z * size.x + nrm.x * size.z
		var half_out: float = (absf(nrm.x) * size.x
				+ absf(nrm.z) * size.z) * 0.5
		var count := clampi(int(wall_len / 9.0), 1, 2)
		for k in count:
			var u := 0.0 if count == 1 \
					else (2.6 if k == 0 else -2.6)
			var basis := Basis(Vector3.UP, theta)
			var at := pos + Vector3(0.0, 1.35, 0.0) + across * u \
					+ nrm * (half_out + 0.02)
			var xf := Transform3D(basis, at)
			trim.append(xf)
			if rng.randf() < 0.58:
				shutters.append(xf)
			else:
				interiors.append(xf)
		return {
			"plaster": plaster, "skirt": false, "panes": panes, "lit": lit,
			"frames": frames, "balconies": balconies, "shutters": shutters,
			"interiors": interiors, "trim": trim,
		}

	# Towers: keep the glazing grid, add a frame unit per pane.
	for side in 4:
		var theta := float(side) * PI / 2.0
		var nrm := Vector3(sin(theta), 0.0, cos(theta))
		var across := Vector3(nrm.z, 0.0, -nrm.x)
		var wall_len: float = nrm.z * size.x + nrm.x * size.z
		var cols := int((wall_len - 4.0) / PANE_STEP_U)
		var rows := int((size.y - 5.0) / PANE_STEP_Y)
		if cols < 1 or rows < 1:
			continue
		var half_out: float = (absf(nrm.x) * size.x
				+ absf(nrm.z) * size.z) * 0.5
		for r in rows:
			for c in cols:
				var u: float = (float(c) + 0.5 - cols * 0.5) * PANE_STEP_U
				var at := pos + Vector3(0.0, PANE_BASE_Y + float(r)
						* PANE_STEP_Y, 0.0) + across * u \
						+ nrm * (half_out + 0.06)
				var xf := Transform3D(Basis(Vector3.UP, theta), at)
				panes.append(xf)
				frames.append(xf)
				if rng.randf() < 0.42:
					lit.append(xf.translated(nrm * 0.06))

	# Occasional concrete balcony between glazing rows — the art-ref's
	# overlapping planes: slab, parapet and coping in front of the wall.
	if size.y >= 12.0 and rng.randf() < 0.32:
		var side := rng.randi_range(0, 3)
		var theta := float(side) * PI / 2.0
		var nrm := Vector3(sin(theta), 0.0, cos(theta))
		var across := Vector3(nrm.z, 0.0, -nrm.x)
		var wall_len: float = nrm.z * size.x + nrm.x * size.z
		var cols := int((wall_len - 4.0) / PANE_STEP_U)
		var rows := int((size.y - 5.0) / PANE_STEP_Y)
		var half_out: float = (absf(nrm.x) * size.x
				+ absf(nrm.z) * size.z) * 0.5
		var u := 0.0
		if cols >= 2:
			var c := rng.randi_range(0, cols - 2)
			u = clampf((float(c) + 1.0 - cols * 0.5) * PANE_STEP_U,
					-(wall_len / 2.0 - 2.2), wall_len / 2.0 - 2.2)
		var r := 0 if rows < 2 else rng.randi_range(0, rows - 2)
		var y := PANE_BASE_Y + (float(r) + 1.0) * PANE_STEP_Y - 1.35
		var at := pos + Vector3(0.0, y, 0.0) + across * u \
				+ nrm * (half_out - 0.05)
		balconies.append(Transform3D(Basis(Vector3.UP, theta), at))

	return {
		"plaster": plaster, "skirt": rng.randf() < 0.65, "panes": panes,
		"lit": lit, "frames": frames, "balconies": balconies,
		"shutters": shutters, "interiors": interiors, "trim": trim,
	}


# ------------------------------------------------------------- unit meshes

static func window_frame_mesh() -> ArrayMesh:
	## Frame bars + sill + lintel ledge around one pane; local +Z is the
	## outward normal, the pane centre sits at the local origin.
	var b := MeshTools.new()
	var bar := Color(0.36, 0.32, 0.27)
	var conc := Color(0.78, 0.74, 0.66)
	b.add_box(Vector3(1.74, 0.14, 0.10), Vector3(0.0, 1.02, 0.0), bar)
	b.add_box(Vector3(1.74, 0.14, 0.10), Vector3(0.0, -1.02, 0.0), bar)
	b.add_box(Vector3(0.14, 1.90, 0.10), Vector3(-0.81, 0.0, 0.0), bar)
	b.add_box(Vector3(0.14, 1.90, 0.10), Vector3(0.81, 0.0, 0.0), bar)
	b.add_box(Vector3(1.98, 0.10, 0.30), Vector3(0.0, -1.13, 0.12), conc)
	b.add_box(Vector3(1.86, 0.09, 0.22), Vector3(0.0, 1.15, 0.09), conc)
	return b.build_mesh()


static func balcony_mesh() -> ArrayMesh:
	## Concrete slab + parapet + coping; local origin at the wall face,
	## +Z protruding, floor line at local y = 0.
	var b := MeshTools.new()
	var slab := Color(0.74, 0.70, 0.63)
	var rail := Color(0.66, 0.62, 0.56)
	b.add_box(Vector3(3.4, 0.16, 1.15), Vector3(0.0, 0.0, 0.52), slab)
	b.add_box(Vector3(3.4, 0.85, 0.08), Vector3(0.0, 0.51, 1.06), rail)
	b.add_box(Vector3(0.08, 0.85, 1.05), Vector3(-1.66, 0.51, 0.50), rail)
	b.add_box(Vector3(0.08, 0.85, 1.05), Vector3(1.66, 0.51, 0.50), rail)
	b.add_box(Vector3(3.56, 0.07, 0.20), Vector3(0.0, 0.97, 1.04), rail)
	return b.build_mesh()


static func shopfront_trim_mesh() -> ArrayMesh:
	## Jambs + lintel boxing a 3.0 x 2.25 opening; local origin at the
	## opening centre on the wall plane.
	var b := MeshTools.new()
	var tone := Color(0.82, 0.78, 0.70)
	b.add_box(Vector3(0.18, 2.60, 0.40), Vector3(-1.68, 0.0, 0.10), tone)
	b.add_box(Vector3(0.18, 2.60, 0.40), Vector3(1.68, 0.0, 0.10), tone)
	b.add_box(Vector3(3.72, 0.38, 0.34), Vector3(0.0, 1.42, 0.10), tone)
	return b.build_mesh()


static func shutter_mesh() -> BoxMesh:
	## Closed corrugated roll-down shutter filling the trim opening.
	var m := BoxMesh.new()
	m.size = Vector3(3.0, 2.25, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _corrugation()
	mat.albedo_color = Color(0.55, 0.58, 0.62)
	mat.metallic = 0.25
	mat.roughness = 0.55
	mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
	m.material = mat
	return m


static func interior_mesh() -> BoxMesh:
	## Open shopfront: a near-black plate just off the wall inside the
	## trim frame — from the street it reads as unlit interior depth.
	var m := BoxMesh.new()
	m.size = Vector3(2.98, 2.23, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.028)
	mat.roughness = 1.0
	m.material = mat
	return m


static func _corrugation() -> ImageTexture:
	## Vertical ridge shading for roll-down shutters — sixteen stripes per
	## tile with dust mottle, no shipped binary asset.
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var wave := absf(sin(float(x) / float(s) * PI * 16.0))
			var shade := 0.55 + 0.45 * pow(wave, 0.8)
			var h := (x * 374761393 + y * 668265263 + 55 * 981039481)
			h = (h ^ (h >> 13)) * 1274126177
			h = h ^ (h >> 16)
			var dust := float(h & 0xFF) / 255.0 * 0.10
			img.set_pixel(x, y, Color(shade + dust, shade + dust,
					shade + dust))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
