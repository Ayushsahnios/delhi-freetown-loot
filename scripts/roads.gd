extends RefCounted
## Road & ground dressing (issue #56): the road grid gets procedural
## asphalt with lane wear, painted center dashes and edge lines, tiled
## sidewalks with curb faces at every block edge, and zebra crossings at
## each intersection — one merged mesh, three surfaces. All textures are
## generated at load (deterministic hash noise), no assets, no imports.

const TILE_U := 8.0  ## meters of road per asphalt texture repeat (along)
const WALK_TILE := 2.2  ## meters per sidewalk texture repeat
const CURB_H := 0.14  ## sidewalk top height
const ROAD_Y := 0.08  ## asphalt surface height (matches the old strips)
const PAINT_Y := 0.084  ## zebra quads, a hair above the asphalt
const ZEBRA_LEN := 3.15  ## crossing band depth (along traffic direction)
const ZEBRA_W := 0.62  ## one stripe width
const ZEBRA_PITCH_V := 1.08  ## spacing between stripes (across the road)

static var _asphalt_tex: ImageTexture = null
static var _walk_tex: ImageTexture = null
static var _paint_tex: ImageTexture = null
static var _walk_mat: StandardMaterial3D = null
static var _paint_mat: StandardMaterial3D = null


# ------------------------------------------------------------ textures

static func _hash(x: int, y: int, seed: int) -> float:
	## Deterministic 2D hash to [0, 1].
	var h := x * 374761393 + y * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static func _vnoise(x: int, y: int, cell: int, seed: int) -> float:
	## Smooth value noise on a `cell`-pixel grid — soft mottling.
	var gx := float(x) / float(cell)
	var gy := float(y) / float(cell)
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := smoothstep(0.0, 1.0, gx - x0)
	var fy := smoothstep(0.0, 1.0, gy - y0)
	var a := _hash(x0, y0, seed)
	var b := _hash(x0 + 1, y0, seed)
	var c := _hash(x0, y0 + 1, seed)
	var d := _hash(x0 + 1, y0 + 1, seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func make_asphalt_material() -> StandardMaterial3D:
	## Shared asphalt material; main.gd drives its tint with the weather.
	var m := StandardMaterial3D.new()
	m.albedo_texture = asphalt_texture()
	m.albedo_color = Color(1.0, 1.0, 1.0)
	m.roughness = 1.0
	m.metallic = 0.0
	return m


static func asphalt_texture() -> ImageTexture:
	## One TILE_U x road-width tile: speckled asphalt, polished wheel-path
	## bands where traffic runs, oil stains, a worn center dash and edge
	## lines. Traffic lanes sit at +-LANE (2.8 m) of the road center.
	if _asphalt_tex != null:
		return _asphalt_tex
	const S := 256
	var data := PackedByteArray()
	data.resize(S * S * 3)
	# Wheel-track v offsets (across the road) for lanes at +-2.8 m, wheel
	# pairs 0.85 m either side of each lane center, on a 12 m-wide road.
	var bands := PackedFloat32Array(
			[0.5 - 3.65 / 12.0, 0.5 - 1.95 / 12.0,
			0.5 + 1.95 / 12.0, 0.5 + 3.65 / 12.0])
	for y in S:
		var v := float(y) / S
		for x in S:
			var u := float(x) / S
			var lum := 0.185
			lum += (_vnoise(x, y, 16, 1) - 0.5) * 0.045
			lum += (_vnoise(x, y, 4, 2) - 0.5) * 0.035
			var speck := (_hash(x, y, 3) - 0.5) * 0.085
			for bc: float in bands:
				var f := clampf(1.0 - absf(v - bc) / 0.032, 0.0, 1.0)
				lum *= 1.0 - 0.11 * f
				speck *= 1.0 - 0.6 * f
			for st in 6:
				var scx := _hash(st, 11, 7) * S
				var scy := _hash(st, 23, 7) * S
				var rad := 5.0 + _hash(st, 31, 7) * 9.0
				var ds := Vector2(x - scx, y - scy).length()
				if ds < rad:
					lum *= 1.0 - 0.22 * (1.0 - ds / rad)
			var r := lum + speck * 0.97
			var g := lum + speck * 0.99
			var b := lum + speck * 1.03
			# Worn center dash (u 0.10..0.46 of the tile) and edge lines,
			# eroded by noise so the paint reads chipped.
			var dash := u > 0.10 and u < 0.46 and absf(v - 0.5) < 0.0065
			var edge := absf(v - 0.0583) < 0.0065 or absf(v - 0.9417) < 0.0065
			if (dash or edge) and _hash(x, y, 9) > 0.32:
				var pr := 0.72 if dash else 0.78
				var wear := 0.55 + _hash(x, y, 10) * 0.2
				r = lerpf(r, pr * 0.98, wear)
				g = lerpf(g, pr * 0.9 if dash else pr, wear)
				b = lerpf(b, pr * 0.62 if dash else pr * 0.97, wear)
			var i := (y * S + x) * 3
			data[i] = clampi(int(r * 255.0), 0, 255)
			data[i + 1] = clampi(int(g * 255.0), 0, 255)
			data[i + 2] = clampi(int(b * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_asphalt_tex = ImageTexture.create_from_image(img)
	return _asphalt_tex


static func walk_texture() -> ImageTexture:
	## Concrete pavers: a 4x4 grid of 0.55 m tiles with grout seams,
	## per-tile tint jitter and soft mottle.
	if _walk_tex != null:
		return _walk_tex
	const S := 256
	var data := PackedByteArray()
	data.resize(S * S * 3)
	for y in S:
		for x in S:
			var lum := 0.70 + _hash(x / 64, y / 64, 11) * 0.10
			lum *= 0.95 + _vnoise(x, y, 8, 12) * 0.10
			lum += (_hash(x, y, 13) - 0.5) * 0.05
			var lx := x % 64
			var ly := y % 64
			if lx < 2 or lx > 63 or ly < 2 or ly > 63:
				lum = 0.48 + _hash(x, y, 14) * 0.06  # grout seam
			elif lx < 5 or lx > 60 or ly < 5 or ly > 60:
				lum *= 0.93  # worn chamfer
			var i := (y * S + x) * 3
			data[i] = clampi(int(lum * 1.02 * 255.0), 0, 255)
			data[i + 1] = clampi(int(lum * 255.0), 0, 255)
			data[i + 2] = clampi(int(lum * 0.95 * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_walk_tex = ImageTexture.create_from_image(img)
	return _walk_tex


static func paint_texture() -> ImageTexture:
	## Road-paint white with speckle and scuffed patches.
	if _paint_tex != null:
		return _paint_tex
	const S := 128
	var data := PackedByteArray()
	data.resize(S * S * 3)
	for y in S:
		for x in S:
			var lum := 0.86 + (_hash(x, y, 21) - 0.5) * 0.14
			if _vnoise(x, y, 6, 22) < 0.24:
				lum *= 0.72  # scuffed
			var i := (y * S + x) * 3
			data[i] = clampi(int(lum * 255.0), 0, 255)
			data[i + 1] = clampi(int(lum * 253.0), 0, 255)
			data[i + 2] = clampi(int(lum * 240.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_paint_tex = ImageTexture.create_from_image(img)
	return _paint_tex


static func _walk_material() -> StandardMaterial3D:
	if _walk_mat == null:
		_walk_mat = StandardMaterial3D.new()
		_walk_mat.albedo_texture = walk_texture()
		_walk_mat.roughness = 1.0
		_walk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _walk_mat


static func _paint_material() -> StandardMaterial3D:
	if _paint_mat == null:
		_paint_mat = StandardMaterial3D.new()
		_paint_mat.albedo_texture = paint_texture()
		_paint_mat.roughness = 0.9
	return _paint_mat


# -------------------------------------------------------------- mesh

func _bucket() -> Dictionary:
	return {"pos": PackedVector3Array(), "nrm": PackedVector3Array(),
		"uv": PackedVector2Array(), "idx": PackedInt32Array()}


func _quad_up(b: Dictionary, x0: float, z0: float, x1: float, z1: float,
		y: float, ua: float, va: float, ub: float, vb: float) -> void:
	## Horizontal quad, up-facing. UV corners: (x0,z0)->(ua,va),
	## (x1,z1)->(ub,vb), linear across the quad.
	var base: int = b["pos"].size()
	for corner in 4:
		match corner:
			0:
				b["pos"].append(Vector3(x0, y, z0))
				b["uv"].append(Vector2(ua, va))
			1:
				b["pos"].append(Vector3(x1, y, z0))
				b["uv"].append(Vector2(ub, va))
			2:
				b["pos"].append(Vector3(x1, y, z1))
				b["uv"].append(Vector2(ub, vb))
			3:
				b["pos"].append(Vector3(x0, y, z1))
				b["uv"].append(Vector2(ua, vb))
		b["nrm"].append(Vector3.UP)
	b["idx"].append_array(PackedInt32Array(
			[base, base + 2, base + 1, base, base + 3, base + 2]))


func _wall_z(b: Dictionary, x0: float, x1: float, z: float, y0: float,
		y1: float, nrm_x: float) -> void:
	## Vertical quad in a constant-z plane (curb faces of X-running roads).
	var base: int = b["pos"].size()
	var nrm := Vector3(0.0, 0.0, nrm_x)
	var pts := [Vector3(x0, y0, z), Vector3(x1, y0, z),
		Vector3(x1, y1, z), Vector3(x0, y1, z)]
	for p in pts:
		b["pos"].append(p)
		b["nrm"].append(nrm)
		b["uv"].append(Vector2(p.x / WALK_TILE, p.y / WALK_TILE))
	b["idx"].append_array(PackedInt32Array(
			[base, base + 2, base + 1, base, base + 3, base + 2]))


func _wall_x(b: Dictionary, z0: float, z1: float, x: float, y0: float,
		y1: float, nrm_z: float) -> void:
	## Vertical quad in a constant-x plane (curb faces of Z-running roads).
	var base: int = b["pos"].size()
	var nrm := Vector3(nrm_z, 0.0, 0.0)
	var pts := [Vector3(x, y0, z0), Vector3(x, y0, z1),
		Vector3(x, y1, z1), Vector3(x, y1, z0)]
	for p in pts:
		b["pos"].append(p)
		b["nrm"].append(nrm)
		b["uv"].append(Vector2(p.z / WALK_TILE, p.y / WALK_TILE))
	b["idx"].append_array(PackedInt32Array(
			[base, base + 2, base + 1, base, base + 3, base + 2]))


static func build(world: float, pitch: float, road_w: float, count: int,
		asphalt_mat: StandardMaterial3D) -> MeshInstance3D:
	## The whole road network: asphalt strips segmented around intersection
	## tiles, sidewalk bands with curb faces, corner pads and zebra
	## crossings — merged into one three-surface mesh.
	var r := new()
	var hw := road_w / 2.0
	var sw := WALK_TILE
	var edge := world / 2.0
	var block_half := (pitch - road_w) / 2.0
	var asphalt := r._bucket()
	var walk := r._bucket()
	var paint := r._bucket()
	var lines: Array[float] = []
	for i in count:
		lines.append(-world / 2.0 + i * pitch - block_half)
	# Crossings exist only where both strips actually overlap the world.
	var cross: Array[float] = []
	for c in lines:
		if absf(c) <= edge - hw:
			cross.append(c)

	for along_x in [true, false]:
		for rc: float in lines:
			# Asphalt spans between crossings (plus world-edge stubs).
			var prev := -edge
			var spans: Array[Vector2] = []
			for c in cross:
				if c - hw - prev > 0.05:
					spans.append(Vector2(prev, c - hw))
				prev = c + hw
			if edge - prev > 0.05:
				spans.append(Vector2(prev, edge))
			for spn: Vector2 in spans:
				var a := spn.x
				var bnd := spn.y
				var wa := a + (sw if a > -edge else 0.0)
				var wb := bnd - (sw if bnd < edge else 0.0)
				for side: float in [-1.0, 1.0]:
					var s0 := rc + side * hw
					var s1 := rc + side * (hw + sw)
					if wb - wa > 0.05:
						if along_x:
							r._quad_up(walk, wa, s0, wb, s1, CURB_H,
									wa / WALK_TILE, s0 / WALK_TILE,
									wb / WALK_TILE, s1 / WALK_TILE)
							r._wall_z(walk, wa, wb, s0, ROAD_Y, CURB_H, -side)
							r._wall_z(walk, wa, wb, s1, 0.0, CURB_H, side)
						else:
							r._quad_up(walk, s0, wa, s1, wb, CURB_H,
									s0 / WALK_TILE, wa / WALK_TILE,
									s1 / WALK_TILE, wb / WALK_TILE)
							r._wall_x(walk, wa, wb, s0, ROAD_Y, CURB_H, -side)
							r._wall_x(walk, wa, wb, s1, 0.0, CURB_H, side)
					# Asphalt strip: u tiles along the road, v spans 0..1.
					if along_x:
						r._quad_up(asphalt, a, rc - hw, bnd, rc + hw, ROAD_Y,
								a / TILE_U, 0.0, bnd / TILE_U, 1.0)
					else:
						r._quad_up(asphalt, rc - hw, a, rc + hw, bnd, ROAD_Y,
								a / TILE_U, 0.0, bnd / TILE_U, 1.0)

	# Intersection tiles, corner pads and zebra crossings.
	for cx: float in cross:
		for cz: float in cross:
			# v mapped into a dash-free band so paint never crosses junctions.
			r._quad_up(asphalt, cx - hw, cz - hw, cx + hw, cz + hw, ROAD_Y,
					cx / TILE_U, 0.06, cx / TILE_U, 0.44)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var px0 := cx + (hw if sx > 0.0 else -(hw + sw))
					var px1 := cx + (hw + sw if sx > 0.0 else -hw)
					var pz0 := cz + (hw if sz > 0.0 else -(hw + sw))
					var pz1 := cz + (hw + sw if sz > 0.0 else -hw)
					r._quad_up(walk, minf(px0, px1), minf(pz0, pz1),
							maxf(px0, px1), maxf(pz0, pz1), CURB_H,
							px0 / WALK_TILE, pz0 / WALK_TILE,
							px1 / WALK_TILE, pz1 / WALK_TILE)
			# Four zebra crossings, one per approach.
			for d: float in [-1.0, 1.0]:
				var q0 := d * (hw + 0.8)
				var q1 := q0 + d * ZEBRA_LEN
				var k := 0
				var zpos := cz - 4.85
				while zpos < cz + 4.4:
					r._quad_up(paint, minf(cx + q0, cx + q1), zpos,
							maxf(cx + q0, cx + q1), zpos + ZEBRA_W, PAINT_Y,
							0.0, float(k & 3) * 0.25, ZEBRA_LEN / 1.2,
							ZEBRA_W / 0.9)
					zpos += ZEBRA_PITCH_V
					k += 1
				zpos = cx - 4.85
				k = 0
				while zpos < cx + 4.4:
					r._quad_up(paint, zpos, minf(cz + q0, cz + q1),
							zpos + ZEBRA_W, maxf(cz + q0, cz + q1), PAINT_Y,
							float(k & 3) * 0.25, 0.0, ZEBRA_W / 0.9,
							ZEBRA_LEN / 1.2)
					zpos += ZEBRA_PITCH_V
					k += 1

	var am := ArrayMesh.new()
	r._surface(am, asphalt, asphalt_mat)
	r._surface(am, walk, _walk_material())
	r._surface(am, paint, _paint_material())
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _surface(am: ArrayMesh, b: Dictionary, mat: Material) -> void:
	if b["idx"].is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b["pos"]
	arrays[Mesh.ARRAY_NORMAL] = b["nrm"]
	arrays[Mesh.ARRAY_TEX_UV] = b["uv"]
	arrays[Mesh.ARRAY_INDEX] = b["idx"]
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(am.get_surface_count() - 1, mat)
