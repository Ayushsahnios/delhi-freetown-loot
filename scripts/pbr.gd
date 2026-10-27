extends RefCounted
## Procedural PBR detail library (issue 130). Every flat colour handed to
## MeshTools.shared_material gets a generated grime albedo multiplier, a
## roughness map and a normal map, so walls, concrete, painted metal and
## wood stop reading as plastic. Zero external assets: everything is
## wrapped-lattice value noise baked once per surface kind at startup and
## cached — one grime tile per kind shared by every colour that maps to it.

enum Kind { PLASTER, CONCRETE, METAL, WOOD }

const S := 256  ## Tile size. Lattice cell counts below must divide this.

static var _sets: Array[Dictionary] = [{}, {}, {}, {}]
static var _mat_cache := {}


## Deterministic colour -> surface-kind classifier. Reads the intent of
## the palette constants across main.gd / street_furniture.gd: grays are
## concrete or painted steel, dark browns are wood, everything else is
## rendered plaster.
static func classify(color: Color) -> int:
	var lum := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var mx := maxf(color.r, maxf(color.g, color.b))
	var mn := minf(color.r, minf(color.g, color.b))
	var sat := 0.0 if mx <= 0.0 else (mx - mn) / mx
	if color.r > color.g and color.g > color.b and color.r - color.b >= 0.08 \
			and lum < 0.45 and sat >= 0.25:
		return Kind.WOOD
	if sat < 0.18 and lum >= 0.28 and lum <= 0.82:
		return Kind.CONCRETE
	if sat < 0.30 and lum < 0.28:
		return Kind.METAL
	return Kind.PLASTER


## Cached PBR material for one colour (auto-classified when kind < 0).
static func surface_material(color: Color, kind: int = -1) -> StandardMaterial3D:
	if kind < 0:
		kind = classify(color)
	var key := "%d|%s" % [kind, color.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if _sets[kind].is_empty():
		_sets[kind] = _build_set(kind)
	var set: Dictionary = _sets[kind]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = set["grime"]
	m.roughness = 1.0
	m.roughness_texture = set["rough"]
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.normal_enabled = true
	m.normal_texture = set["normal"]
	m.normal_scale = set["normal_scale"]
	var sc: float = set["uv_scale"]
	m.uv1_scale = Vector3(sc, sc, sc)
	_mat_cache[key] = m
	return m


static func _hash(x: int, y: int, seed: int) -> float:
	var n := x * 374761393 + y * 668265263 + seed * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 1073741823.0


## Tileable value noise: the lattice wraps every `cells` cells, so the
## tile repeats with no seam.
static func _wn(x: float, y: float, cells: int, seed: int) -> float:
	var fx := x / S * cells
	var fy := y / S * cells
	var x0 := int(fx) % cells
	var y0 := int(fy) % cells
	var x1 := (x0 + 1) % cells
	var y1 := (y0 + 1) % cells
	var tx := fx - floorf(fx)
	var ty := fy - floorf(fy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(x0, y0, seed)
	var b := _hash(x1, y0, seed)
	var c := _hash(x0, y1, seed)
	var d := _hash(x1, y1, seed)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Anisotropic variant — independent lattice density per axis, for rain
## streaks (sparse in x, dense in y) and wood grain (dense in x only).
static func _wn2(x: float, y: float, cx: int, cy: int, seed: int) -> float:
	var fx := x / S * cx
	var fy := y / S * cy
	var x0 := int(fx) % cx
	var y0 := int(fy) % cy
	var x1 := (x0 + 1) % cx
	var y1 := (y0 + 1) % cy
	var tx := fx - floorf(fx)
	var ty := fy - floorf(fy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(x0 + y0 * 97, 0, seed)
	var b := _hash(x1 + y0 * 97, 0, seed + 1)
	var c := _hash(x0 + y1 * 97, 0, seed + 2)
	var d := _hash(x1 + y1 * 97, 0, seed + 3)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


## Bakes one kind's grime / roughness / normal tile set from a coherent
## height field, then packs the three ImageTextures.
static func _build_set(kind: int) -> Dictionary:
	var seed := 100 + kind * 17
	var height := PackedFloat32Array()
	height.resize(S * S)
	for y in S:
		for x in S:
			var h := 0.0
			match kind:
				Kind.PLASTER:
					h = _wn(x, y, 8, seed) * 0.55 + _wn(x, y, 32, seed + 1) * 0.25 \
						+ _wn2(x, y, 64, 6, seed + 2) * 0.20  # vertical streaks
				Kind.CONCRETE:
					h = _wn(x, y, 8, seed) * 0.40 + _wn(x, y, 16, seed + 1) * 0.35 \
						+ _wn(x, y, 64, seed + 2) * 0.25  # trowel + pits
				Kind.METAL:
					h = _wn(x, y, 16, seed) * 0.5 + _wn(x, y, 64, seed + 1) * 0.5
				Kind.WOOD:
					h = _wn2(x, y, 3, 64, seed) * 0.7 + _wn(x, y, 64, seed + 1) * 0.3
			height[y * S + x] = h

	var alb := PackedByteArray()
	alb.resize(S * S * 3)
	var rgh := PackedByteArray()
	rgh.resize(S * S)
	var nrm := PackedByteArray()
	nrm.resize(S * S * 3)
	var strength := 2.2
	var rough := 0.7
	var base_rough := 0.7
	var grime := Vector3(1.0, 0.99, 0.96)  # warm dust bias in the multiplier
	match kind:
		Kind.PLASTER:
			strength = 1.6
			base_rough = 0.70
			grime = Vector3(1.0, 0.965, 0.90)
		Kind.CONCRETE:
			strength = 2.6
			base_rough = 0.78
			grime = Vector3(0.985, 0.975, 0.955)
		Kind.METAL:
			strength = 1.2
			base_rough = 0.42
			grime = Vector3(1.0, 1.0, 1.0)
		Kind.WOOD:
			strength = 1.8
			base_rough = 0.72
			grime = Vector3(1.0, 0.97, 0.92)

	for y in S:
		for x in S:
			var i := y * S + x
			var h := height[i]
			var gv := 0.84 + (h - 0.5) * 0.34  # grime multiplier around 1
			rough = base_rough + (_wn(x, y, 16, seed + 5) - 0.5) * 0.30
			if kind == Kind.PLASTER:
				# Rain streaks gloss the wall where water ran.
				var streak := _wn2(x, y, 64, 6, seed + 2)
				rough = lerpf(rough, 0.55, clampf((streak - 0.55) * 2.2, 0.0, 1.0))
			elif kind == Kind.CONCRETE:
				# Dark blotches: old oil and paan drops, rougher than the slab.
				var stain := _wn(x, y, 4, seed + 6)
				if stain > 0.66:
					var f := clampf((stain - 0.66) * 4.0, 0.0, 1.0)
					gv *= 1.0 - 0.22 * f
					rough = lerpf(rough, 0.9, f)
			elif kind == Kind.METAL:
				# Rust blooms through the paint where low-freq noise peaks;
				# rust is rough, surviving paint stays glossy.
				var rust := _wn(x, y, 4, seed + 7)
				if rust > 0.60:
					var f := clampf((rust - 0.60) * 3.2, 0.0, 1.0)
					gv = lerpf(gv, gv * 0.62, f)
					rough = lerpf(rough, 0.94, f)
			elif kind == Kind.WOOD:
				rough = base_rough + (h - 0.5) * 0.22
			var j := i * 3
			alb[j] = clampi(int(gv * grime.x * 255.0), 0, 255)
			alb[j + 1] = clampi(int(gv * grime.y * 255.0), 0, 255)
			alb[j + 2] = clampi(int(gv * grime.z * 255.0), 0, 255)
			rgh[i] = clampi(int(clampf(rough, 0.05, 1.0) * 255.0), 0, 255)
			# Wrapped central-difference normal from the height field.
			var hl := height[y * S + (x + S - 1) % S]
			var hr := height[y * S + (x + 1) % S]
			var hd := height[((y + S - 1) % S) * S + x]
			var hu := height[((y + 1) % S) * S + x]
			var nx := (hl - hr) * strength
			var ny := (hd - hu) * strength
			var inv := 1.0 / sqrt(nx * nx + ny * ny + 1.0)
			nrm[j] = clampi(int((nx * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[j + 1] = clampi(int((ny * inv * 0.5 + 0.5) * 255.0), 0, 255)
			nrm[j + 2] = clampi(int(inv * 255.0), 0, 255)

	var set := {}
	var gimg := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, alb)
	gimg.generate_mipmaps()
	set["grime"] = ImageTexture.create_from_image(gimg)
	var rimg := Image.create_from_data(S, S, false, Image.FORMAT_R8, rgh)
	rimg.generate_mipmaps()
	set["rough"] = ImageTexture.create_from_image(rimg)
	var nimg := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, nrm)
	nimg.generate_mipmaps()
	set["normal"] = ImageTexture.create_from_image(nimg)
	var n_scale := 1.0
	var uv_sc := 2.0
	if kind == Kind.CONCRETE:
		uv_sc = 3.0
		n_scale = 1.2
	elif kind == Kind.METAL:
		uv_sc = 4.0
		n_scale = 0.8
	set["normal_scale"] = n_scale
	set["uv_scale"] = uv_sc
	return set
