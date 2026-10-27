extends RefCounted
## Procedural PBR detail textures (issue #130): roughness mottle and grit
## normal maps generated from deterministic value noise, so the city reads
## weathered instead of plastic — with zero shipped binary assets.
## Roads keep their own tailored variants in roads.gd; everything drawn
## through MeshTools shared materials gets the triplanar weathering pass.

const S := 256  # detail-texture size, one tile covers a few metres

static var _weather_tex: ImageTexture = null
static var _grit_normal_tex: ImageTexture = null
static var _asphalt_rough_tex: ImageTexture = null


# ------------------------------------------------------------ helpers

static func _hash(x: int, y: int, seed: int) -> float:
	## Deterministic 2D hash to [0, 1] (same scheme as roads.gd).
	var h := x * 374761393 + y * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static func _phash(x: int, y: int, period: int, seed: int) -> float:
	## Periodic variant of _hash: the lattice wraps every `period` cells,
	## so noise generated from it tiles seamlessly.
	var wx := ((x % period) + period) % period
	var wy := ((y % period) + period) % period
	var h := wx * 374761393 + wy * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static func _pnoise(u: float, v: float, cells: int, seed: int) -> float:
	## Smooth value noise on a seamless `cells`-across lattice covering the
	## whole [0, 1] tile — soft mottle with no visible tiling seam.
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


# ---------------------------------------------------------- textures

static func weathering_roughness() -> ImageTexture:
	## Grey-scale roughness mottle: broad washed/worn blotches against
	## fine grain, all values near 1.0 so it only modulates the base
	## roughness (and keeps weather-driven gloss working multiplicatively).
	if _weather_tex != null:
		return _weather_tex
	var data := PackedByteArray()
	data.resize(S * S * 3)
	for y in S:
		for x in S:
			var u := float(x) / S
			var v := float(y) / S
			var n := _pnoise(u, v, 4, 101) * 0.60
			n += _pnoise(u, v, 11, 102) * 0.28
			n += _hash(x, y, 103) * 0.12
			var rough := 1.0 - 0.38 * clampf(n * 1.35 - 0.35, 0.0, 1.0)
			var i := (y * S + x) * 3
			var g := clampi(int(rough * 255.0), 0, 255)
			data[i] = g
			data[i + 1] = g
			data[i + 2] = g
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_weather_tex = ImageTexture.create_from_image(img)
	return _weather_tex


static func grit_normal() -> ImageTexture:
	## Tangent-space normal map for micro-relief: a deterministic height
	## field (two noise octaves + grain) converted with wrapped central
	## differences, so the tile is seamless.
	if _grit_normal_tex != null:
		return _grit_normal_tex
	var height := PackedFloat32Array()
	height.resize(S * S)
	for y in S:
		for x in S:
			var u := float(x) / S
			var v := float(y) / S
			var h := _pnoise(u, v, 26, 201) * 0.62
			h += _pnoise(u, v, 48, 202) * 0.27
			h += _hash(x, y, 203) * 0.11
			height[y * S + x] = h
	var data := PackedByteArray()
	data.resize(S * S * 3)
	for y in S:
		for x in S:
			var xm := (x + S - 1) % S
			var xp := (x + 1) % S
			var ym := (y + S - 1) % S
			var yp := (y + 1) % S
			var dx := (height[y * S + xp] - height[y * S + xm]) * 2.6
			var dy := (height[yp * S + x] - height[ym * S + x]) * 2.6
			var n := Vector3(-dx, -dy, 1.0).normalized()
			var i := (y * S + x) * 3
			data[i] = clampi(int((n.x * 0.5 + 0.5) * 255.0), 0, 255)
			data[i + 1] = clampi(int((n.y * 0.5 + 0.5) * 255.0), 0, 255)
			data[i + 2] = clampi(int((n.z * 0.5 + 0.5) * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_grit_normal_tex = ImageTexture.create_from_image(img)
	return _grit_normal_tex


static func asphalt_roughness() -> ImageTexture:
	## Road-tile-aligned roughness: matte asphalt (1.0), traffic-polished
	## wheel bands and the oil-stain blobs of the albedo tile glossier, so
	## the sheen lands exactly where the darkening is. Same band and stain
	## maths as the albedo generator in roads.gd.
	if _asphalt_rough_tex != null:
		return _asphalt_rough_tex
	var bands := PackedFloat32Array(
			[0.5 - 3.65 / 12.0, 0.5 - 1.95 / 12.0,
			0.5 + 1.95 / 12.0, 0.5 + 3.65 / 12.0])
	var data := PackedByteArray()
	data.resize(S * S * 3)
	for y in S:
		var v := float(y) / S
		for x in S:
			var rough := 0.92 + (_hash(x, y, 301) - 0.5) * 0.10
			rough -= 0.16 * _pnoise(float(x) / S, v, 9, 302)  # aged patches
			for bc: float in bands:
				var f := clampf(1.0 - absf(v - bc) / 0.045, 0.0, 1.0)
				rough = lerpf(rough, 0.62, f)  # polished by traffic
			for st in 6:
				var scx := _hash(st, 11, 7) * S
				var scy := _hash(st, 23, 7) * S
				var rad := 5.0 + _hash(st, 31, 7) * 9.0
				var ds := Vector2(x - scx, y - scy).length()
				if ds < rad:
					var f2 := 1.0 - ds / rad
					rough = lerpf(rough, 0.45, f2)  # oil sheen
			var i := (y * S + x) * 3
			var g := clampi(int(rough * 255.0), 0, 255)
			data[i] = g
			data[i + 1] = g
			data[i + 2] = g
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_asphalt_rough_tex = ImageTexture.create_from_image(img)
	return _asphalt_rough_tex


# ----------------------------------------------------------- apply

static func apply_weathering(m: StandardMaterial3D, strength := 1.0) -> void:
	## Roughness mottle + micro-relief normal on a flat-color material,
	## mapped world-space triplanar — the merged district meshes carry no
	## UVs, so texture coordinates come from position instead.
	m.roughness = 1.0
	m.roughness_texture = weathering_roughness()
	m.normal_enabled = true
	m.normal_texture = grit_normal()
	m.normal_scale = 0.4 * strength
	m.uv1_triplanar_enabled = true
	m.uv1_scale = Vector3(0.33, 0.33, 0.33)
