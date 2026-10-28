extends RefCounted
## Procedural fabric textures (issue #153): the flat-color cartoon read
## came from untextured garment slots — every surface a single solid
## albedo. This factory bakes small seamless grayscale textures per
## garment kind (cotton weave, denim twill, skin mottle, hair strands)
## that MULTIPLY the tint color, so a kurta keeps its shade but gains
## woven grain, exactly how PS2-era models faked realism: texture detail
## carrying the load at chunky poly counts. Same deterministic noise
## scheme as pbr_textures.gd — zero shipped binary assets.

const S := 128  # fabric tile size; tiles a few times per garment


static func _hash(x: int, y: int, seed: int) -> float:
	var h := x * 374761393 + y * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static func _phash(x: int, y: int, period: int, seed: int) -> float:
	var wx := ((x % period) + period) % period
	var wy := ((y % period) + period) % period
	var h := wx * 374761393 + wy * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static func _pnoise(u: float, v: float, cells: int, seed: int) -> float:
	var gx := u * cells
	var gy := v * cells
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := smoothstep(0.0, 1.0, gx - x0)
	var fy := smoothstep(0.0, 1.0, gy - y0)
	var a := _phash(x0, y0, cells, seed)
	var b := _phash(x0 + 1, y0, cells, seed)
	var c := _phash(x0, y0 + 1, cells, seed)
	var d := _phash(x0 + 1, y0 + 1, cells, seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


# ------------------------------------------------------------ generators

static func _albedo(kind: String) -> ImageTexture:
	## Grayscale near-white detail that multiplies the tint color:
	## kind selects weave amplitude and pattern. Values live in
	## 0.86..1.0 so texture darkens and modulates, never tints hue.
	var data := PackedByteArray()
	data.resize(S * S)
	for y in S:
		for x in S:
			var u := float(x) / S
			var v := float(y) / S
			var n := 0.0
			match kind:
				"cotton":
					n = _pnoise(u, v, 8, 11) * 0.55 + _pnoise(u, v, 22, 12) * 0.30
					n += _hash(x, y, 13) * 0.15
				"denim":
					# Twill diagonal ridges over a knit mottle.
					var tw := 0.5 + 0.5 * sin((u * S + v * S * 2.0) * TAU / 9.0)
					n = tw * 0.45 + _pnoise(u, v, 20, 14) * 0.35
					n += _hash(x, y, 15) * 0.20
				"skin":
					n = _pnoise(u, v, 5, 16) * 0.6 + _hash(x, y, 17) * 0.4
				"hair":
					# Vertical strand streaks: per-column variation over
					# a slow mass mottle, reading as combed hair masses.
					var col := _hash(x, 0, 18)
					n = col * 0.55 + _pnoise(u, v, 9, 19) * 0.30
					n += _hash(x, y, 20) * 0.15
				_:
					n = 1.0
			var amp: float = {"cotton": 0.16, "denim": 0.20, "skin": 0.08, "hair": 0.22}.get(kind, 0.0)
			var g := clampf(1.0 - amp * n, 0.0, 1.0)
			data[y * S + x] = clampi(int(g * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_L8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _rough(kind: String) -> ImageTexture:
	## Roughness modulation: cloth matte with worn polish, skin matte-
	## smooth, hair carrying a painted sheen (the art-ref vocabulary).
	var data := PackedByteArray()
	data.resize(S * S)
	var base: float = {"cotton": 0.94, "denim": 0.88, "skin": 0.72, "hair": 0.52}.get(kind, 0.95)
	var swing: float = {"cotton": 0.10, "denim": 0.14, "skin": 0.06, "hair": 0.18}.get(kind, 0.0)
	for y in S:
		for x in S:
			var u := float(x) / S
			var v := float(y) / S
			var n := _pnoise(u, v, 10, 21) * 0.7 + _hash(x, y, 22) * 0.3
			var r := clampf(base + (n - 0.5) * 2.0 * swing, 0.0, 1.0)
			data[y * S + x] = clampi(int(r * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_L8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static var _albedo_cache := {}
static var _rough_cache := {}


# ------------------------------------------------------------------ apply

static func apply(m: StandardMaterial3D, role: String) -> void:
	## Dress a tinted garment material with its fabric kind. Roles map to
	## garment kinds; anything unknown stays untouched.
	var kind: String = {"shirt": "cotton", "pants": "denim", "skin": "skin", "hair": "hair"}.get(role, "")
	if kind == "":
		return
	if not _albedo_cache.has(kind):
		_albedo_cache[kind] = _albedo(kind)
	if not _rough_cache.has(kind):
		_rough_cache[kind] = _rough(kind)
	m.albedo_texture = _albedo_cache[kind]
	m.roughness = 1.0
	m.roughness_texture = _rough_cache[kind]
	# The authored garment UVs span roughly one tile per body part;
	# scaling up repeats the weave so grain reads at gameplay scale.
	m.uv1_scale = Vector3(6.0, 6.0, 6.0)
