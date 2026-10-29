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
					n = _pnoise(u, v, 8, 11) * 0.45 + _pnoise(u, v, 22, 12) * 0.28
					n += _pnoise(u, v, 44, 23) * 0.12  # close-range weave octave
					n += _hash(x, y, 13) * 0.15
				"denim":
					# Twill diagonal ridges over a knit mottle.
					var tw := 0.5 + 0.5 * sin((u * S + v * S * 2.0) * TAU / 9.0)
					n = tw * 0.40 + _pnoise(u, v, 20, 14) * 0.30
					n += _pnoise(u, v, 44, 24) * 0.12  # close-range twill pick
					n += _hash(x, y, 15) * 0.18
				"skin":
					n = _pnoise(u, v, 5, 16) * 0.55 + _pnoise(u, v, 16, 26) * 0.15
					n += _hash(x, y, 17) * 0.30
				"hair":
					# Vertical strand streaks: per-column variation over
					# a slow mass mottle, reading as combed hair masses.
					var col := _hash(x, 0, 18)
					n = col * 0.50 + _pnoise(u, v, 9, 19) * 0.26
					n += _pnoise(u, v, 36, 25) * 0.10  # close-range strand flock
					n += _hash(x, y, 20) * 0.14
				"wrap":
					# Turban fold bands: wide soft bands crossing the tile
					# over a cloth mottle — wrapped cloth layers, not
					# smooth solid rings.
					var fb := 0.5 + 0.5 * sin(v * TAU * 6.0
							+ _pnoise(u, v, 4, 27) * 2.5)
					n = fb * 0.55 + _pnoise(u, v, 12, 28) * 0.28
					n += _hash(x, y, 29) * 0.17
				_:
					n = 1.0
			# Issue 158: amplitude raised so the weave reads in portrait
			# closeups; the finest octaves and tighter UV repeats mip away
			# to a near-flat average at gameplay distance, keeping the
			# street read calm. Skin stays the subtlest (its depth cue is
			# sculpted shading, not grain).
			var amp: float = {"cotton": 0.22, "denim": 0.27, "skin": 0.10, "hair": 0.27, "wrap": 0.24}.get(kind, 0.0)
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
	var base: float = {"cotton": 0.94, "denim": 0.88, "skin": 0.72, "hair": 0.52, "wrap": 0.93}.get(kind, 0.95)
	var swing: float = {"cotton": 0.10, "denim": 0.14, "skin": 0.06, "hair": 0.18, "wrap": 0.10}.get(kind, 0.0)
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
	apply_kind(m, kind, {"shirt": 9.0, "pants": 9.0, "hair": 8.0, "skin": 5.0}.get(role, 6.0))


static func apply_kind(m: StandardMaterial3D, kind: String, repeats := 4.0) -> void:
	## Full fabric treatment for an explicit kind (procedural meshes
	## whose material carries no authored role name): woven or folded
	## albedo detail that multiplies the tint, plus matching roughness
	## modulation, tiled `repeats` times across the surface.
	if not _albedo_cache.has(kind):
		_albedo_cache[kind] = _albedo(kind)
	if not _rough_cache.has(kind):
		_rough_cache[kind] = _rough(kind)
	m.albedo_texture = _albedo_cache[kind]
	m.roughness = 1.0
	m.roughness_texture = _rough_cache[kind]
	m.uv1_scale = Vector3(repeats, repeats, repeats)


static func apply_detail(m: StandardMaterial3D, kind: String, repeats := 4.0) -> void:
	## Albedo grain only, keeping the material's authored roughness —
	## glossy finishes (slicked-back hair) get the strand detail
	## without losing their sheen.
	if not _albedo_cache.has(kind):
		_albedo_cache[kind] = _albedo(kind)
	m.albedo_texture = _albedo_cache[kind]
	m.uv1_scale = Vector3(repeats, repeats, repeats)


# =============================================================== prints
# Issue 182: garment prints OVER the fabric system. The weave textures
# above modulate brightness; prints BAKE the garment tint plus
# contrast tones into a colored tile — gingham checks, plaid bands,
# tee stripes — or an edge-band layout (zari-style drape borders),
# with the same woven grain folded in so every pattern still reads as
# cloth. The kind/variant roll lives in characters.gd's identity()
# (deterministic per seed); the bake here depends only on
# (kind, variant, base color), so the cache stays small.

const PRINT_CHECKS := 1
const PRINT_PLAID := 2
const PRINT_STRIPES := 3

const PRINT_CREAM := Color(0.96, 0.94, 0.90)


static func _weave_shade(x: int, y: int, amp: float) -> float:
	## Subtle brightness wobble so baked prints keep a cloth grain.
	var n := _hash(x, y, 31) * 0.6 + _pnoise(float(x) / S, float(y) / S, 16, 32) * 0.4
	return 1.0 - amp * n


static func print_repeats(kind: int, variant: int) -> float:
	## UV repeats across the torso per print: bold cells tile fewer
	## times so a check reads as a check at gameplay distance instead
	## of static. Issue 182 acceptance: patterns must read in the
	## lineup capture, so scales stay COARSE — a handful of checks or
	## bands across a torso, not dozens.
	if kind == PRINT_STRIPES:
		return 1.0 if variant == 0 else 1.5
	return 1.0 if variant == 0 else 1.5


static func _print_rgb(kind: int, variant: int, base: Color) -> ImageTexture:
	## Colored print tile: tint, cream and a darkened tint woven into
	## checks / plaid / stripes. Cell sizes divide the tile so the
	## pattern stays seamless.
	var data := PackedByteArray()
	data.resize(S * S * 3)
	var deep := base.darkened(0.45)
	var mid := base.darkened(0.22)
	for y in S:
		for x in S:
			var c := base
			match kind:
				PRINT_CHECKS:
					# Gingham: crossing translucent stripes — cream,
					# tint, and the darker overlap quadrant. Giant cells
					# (two checks across a torso) so it reads far away.
					var cell := 64 if variant == 0 else 32
					var sx := (x / cell) % 2 == 0
					var sy := (y / cell) % 2 == 0
					if sx and sy:
						c = deep
					elif sx or sy:
						c = base
					else:
						c = PRINT_CREAM
				PRINT_PLAID:
					# Tartan-ish: wide tone bands crossing on the tint,
					# cream hairlines at the half-cell edges.
					var bw := 20 if variant == 0 else 12
					var inx := (x % 64) < bw
					var iny := (y % 64) < bw
					if inx and iny:
						c = deep
					elif inx or iny:
						c = mid
					if (x % 32) < 2 or (y % 32) < 2:
						c = PRINT_CREAM.lerp(base, 0.25)
				PRINT_STRIPES:
					# Tee stripes: bold tint/cream bands (variant 0)
					# or cream pinstripes (variant 1).
					if variant == 0:
						c = base if (y / 32) % 2 == 0 else PRINT_CREAM
					else:
						c = base if (y % 32) >= 5 else PRINT_CREAM
			var sh := _weave_shade(x, y, 0.07)
			var i := (y * S + x) * 3
			data[i] = clampi(int(c.r * sh * 255.0), 0, 255)
			data[i + 1] = clampi(int(c.g * sh * 255.0), 0, 255)
			data[i + 2] = clampi(int(c.b * sh * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _border_rgb(variant: int, base: Color, accent: Color) -> ImageTexture:
	## Drape fabric with zari-style edge bands (saree pallu, lungi
	## hem): body carries a faint self-stripe over weave mottle; the
	## bottom band carries the accent with woven motifs and a dark
	## edge line, plus a hairline at the tile's top so a hem band shows
	## whichever way cylinder UVs orient.
	var data := PackedByteArray()
	data.resize(S * S * 3)
	var band := 16 + variant * 4           # 16 / 20 / 24 px
	var motif := 8 if variant < 2 else 0   # variant 2: plain double line
	var dark := accent.darkened(0.38)
	for y in S:
		for x in S:
			var c := base
			var sh := _weave_shade(x, y, 0.09) * (0.97 if (x % 16) < 8 else 1.03)
			if y < 5:
				c = accent.darkened(0.12)
				sh = _weave_shade(x, y, 0.09)
			if variant == 1 and y >= S - band - 5 and y < S - band:
				c = accent.darkened(0.20)
				sh = 0.95
			if y >= S - band:
				c = accent
				if y >= S - 5:
					c = dark
				elif motif > 0 and (x % motif) < (motif / 2) and (y % 4) < 2:
					c = dark
				sh = 0.92 + 0.08 * _hash(x, y, 33)
			var i := (y * S + x) * 3
			data[i] = clampi(int(c.r * sh * 255.0), 0, 255)
			data[i + 1] = clampi(int(c.g * sh * 255.0), 0, 255)
			data[i + 2] = clampi(int(c.b * sh * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _border_rough(variant: int) -> ImageTexture:
	## Roughness pair for the border bake: matte cloth body, with the
	## zari band carrying a metallic-thread sheen and occasional
	## sparkle threads.
	var data := PackedByteArray()
	data.resize(S * S)
	var band := 12 + variant * 3
	for y in S:
		for x in S:
			var n := _hash(x, y, 34)
			var r := 0.94 + (n - 0.5) * 0.12
			if y >= S - band or y < 5 or (variant == 1 and y >= S - band - 5):
				r = 0.52 + (n - 0.5) * 0.18
				if n > 0.88:
					r = 0.42
			data[y * S + x] = clampi(int(r * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_L8, data)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static var _print_cache := {}
static var _border_cache := {}
static var _border_rough_cache := {}


static func apply_print(m: StandardMaterial3D, kind: int, variant: int,
		base: Color, repeats := -1.0) -> void:
	## Patterned top: the print bake replaces the weave as the albedo
	## (color lives in the texture, albedo resets to white) while the
	## cotton roughness map keeps the matte cloth read.
	var key := "%d:%d:%s" % [kind, variant, base.to_html(false)]
	if not _print_cache.has(key):
		_print_cache[key] = _print_rgb(kind, variant, base)
	if not _rough_cache.has("cotton"):
		_rough_cache["cotton"] = _rough("cotton")
	m.albedo_color = Color.WHITE
	m.albedo_texture = _print_cache[key]
	m.roughness = 1.0
	m.roughness_texture = _rough_cache["cotton"]
	if repeats < 0.0:
		repeats = print_repeats(kind, variant)
	m.uv1_scale = Vector3(repeats, repeats, repeats)


static func apply_border(m: StandardMaterial3D, variant: int,
		base: Color, accent: Color) -> void:
	## Zari-bordered drape (saree skirt + pallu, lungi wrap): one tile
	## wraps the garment exactly once (uv1_scale 1) so the band reads
	## as a single hem band, not repeating stripes.
	var key := "%d:%s:%s" % [variant, base.to_html(false), accent.to_html(false)]
	if not _border_cache.has(key):
		_border_cache[key] = _border_rgb(variant, base, accent)
	if not _border_rough_cache.has(variant):
		_border_rough_cache[variant] = _border_rough(variant)
	m.albedo_color = Color.WHITE
	m.albedo_texture = _border_cache[key]
	m.roughness = 1.0
	m.roughness_texture = _border_rough_cache[variant]
	m.uv1_scale = Vector3.ONE
