extends RefCounted
## Performance-pass helpers. Static city visuals merge into one mesh per
## district (one surface per color), and repeated props / vehicles / crowds
## draw through MultiMeshes — the whole city renders in a small fraction of
## the old node and draw-call count. Purely procedural, no assets.

const PBRTextures := preload("res://scripts/pbr_textures.gd")

## Material finish steps (issue #166): matte keeps the full weathering
## pass, satin halves the relief, gloss drops it entirely for clean
## paint, glass and chrome — the matte-vs-gloss read that separates a
## toy from a vehicle at street distance.
const FINISH_MATTE := 0
const FINISH_SATIN := 1
const FINISH_GLOSS := 2

static var _mat_cache := {}


## One shared material per color+finish for everything that asks — fewer
## material swaps between draws. Matte finishes carry the procedural
## weathering pass (roughness mottle + grit normal, triplanar) so the
## merged city stops reading as flat plastic (issue #130).
static func shared_material(color: Color, finish := FINISH_MATTE) -> StandardMaterial3D:
	var key := "%s|%d" % [color.to_html(), finish]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		match finish:
			FINISH_GLOSS:
				m.roughness = 0.30
				m.metallic = 0.10
				m.clearcoat_enabled = true
				m.clearcoat = 0.55
				m.clearcoat_roughness = 0.35
			FINISH_SATIN:
				PBRTextures.apply_weathering(m, 0.5)
				m.roughness = 0.62
			_:
				PBRTextures.apply_weathering(m)
		_mat_cache[key] = m
	return _mat_cache[key]


## One MultiMeshInstance3D drawing `mesh` once per transform. Returns null
## when there is nothing to draw.
static func make_multimesh(mesh: PrimitiveMesh, xfs: Array) -> MultiMeshInstance3D:
	if xfs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi


var _buckets := {}


func add_box(size: Vector3, center: Vector3, color: Color, finish := FINISH_MATTE) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	add_mesh(bm, Transform3D(Basis(), center), color, finish)


## Chamfered (octagonal) rectangle footprint for de-boxed building masses
## (issue #235): every 90-degree corner becomes a 45-degree cut of depth
## `c`, so towers stop reading as pure boxes. Points come out
## counter-clockwise, ready for add_prism().
static func chamfer_footprint(half_w: float, half_d: float,
		c: float) -> PackedVector2Array:
	var cx: float = minf(c, half_w * 0.45)
	var cz: float = minf(c, half_d * 0.45)
	var pts := PackedVector2Array([
		Vector2(-half_w + cx, -half_d),
		Vector2(half_w - cx, -half_d),
		Vector2(half_w, -half_d + cz),
		Vector2(half_w, half_d - cz),
		Vector2(half_w - cx, half_d),
		Vector2(-half_w + cx, half_d),
		Vector2(-half_w, half_d - cz),
		Vector2(-half_w, -half_d + cz),
	])
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b2 := pts[(i + 1) % pts.size()]
		area += a.x * b2.y - b2.x * a.y
	if area < 0.0:
		pts.reverse()
	return pts


## Extruded convex profile (issue #235): sides with flat outward normals
## plus a top cap, no bottom cap (prisms sit on the ground). `profile` is
## centred on the origin in the XZ plane and gets offset by `center.x/z`;
## `y0`/`y1` are absolute world heights. Folds into the color bucket like
## any other primitive.
func add_prism(profile: PackedVector2Array, center: Vector3, y0: float,
		y1: float, color: Color, finish := FINISH_MATTE) -> void:
	if profile.size() < 3 or y1 <= y0:
		return
	var pts := profile.duplicate()
	var area := 0.0
	for i in pts.size():
		var pa := pts[i]
		var pb := pts[(i + 1) % pts.size()]
		area += pa.x * pb.y - pb.x * pa.y
	if area < 0.0:
		pts.reverse()
	var cx := 0.0
	var cz := 0.0
	for p in pts:
		cx += p.x
		cz += p.y
	cx /= float(pts.size())
	cz /= float(pts.size())
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var a := Vector3(pts[i].x + center.x, 0.0, pts[i].y + center.z)
		var b := Vector3(pts[(i + 1) % pts.size()].x + center.x, 0.0,
				pts[(i + 1) % pts.size()].y + center.z)
		var dir := b - a
		var n := Vector3(dir.z, 0.0, -dir.x).normalized()
		# Convex CCW profile: interior sits opposite this outward edge normal.
		var mid := (a + b) * 0.5
		if (mid - Vector3(center.x, 0.0, center.z)).dot(n) < 0.0:
			continue
		var base := verts.size()
		verts.append(Vector3(a.x, y1, a.z))
		verts.append(Vector3(b.x, y1, b.z))
		verts.append(Vector3(b.x, y0, b.z))
		verts.append(Vector3(a.x, y0, a.z))
		for _k in 4:
			norms.append(n)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2,
				base, base + 2, base + 3]))
	# Top cap: fan around the profile centroid, wound for +Y.
	var cbase := verts.size()
	verts.append(Vector3(cx + center.x, y1, cz + center.z))
	norms.append(Vector3.UP)
	for p in pts:
		verts.append(Vector3(p.x + center.x, y1, p.y + center.z))
		norms.append(Vector3.UP)
	for i in pts.size():
		var i0 := cbase + 1 + i
		var i1 := cbase + 1 + (i + 1) % pts.size()
		idx.append_array(PackedInt32Array([cbase, i1, i0]))
	_add_arrays(verts, norms, idx, color, finish)


## Beveled box (issue #236): a chamfered prism sized like a box, so
## crates and counters stop reading as sharp-edged cubes. `bevel` is
## the 45-degree cut depth, clamped to keep the profile valid.
func add_bev_box(size: Vector3, center: Vector3, bevel: float,
	color: Color, yaw := 0.0, finish := FINISH_MATTE) -> void:
	var c := clampf(bevel, 0.02, minf(size.x, size.z) * 0.2)
	var pts := chamfer_footprint(size.x * 0.5, size.z * 0.5, c)
	if yaw != 0.0:
		var ca := cos(yaw)
		var sa := sin(yaw)
		for i in pts.size():
			pts[i] = Vector2(pts[i].x * ca - pts[i].y * sa,
					pts[i].x * sa + pts[i].y * ca)
	add_prism(pts,
			Vector3(center.x, 0.0, center.z), center.y - size.y * 0.5,
			center.y + size.y * 0.5, color, finish)


## Lathe-revolved profile (issue #236): `profile` is Vector2(radius, y)
## points revolved around the vertical axis through `center.x/z`.
## Kettles, pots, planters and bins — the round-prop vocabulary the
## de-box directive asks for. `segments` radial faces, flat normals.
func add_lathe(profile: PackedVector2Array, center: Vector3,
	color: Color, finish := FINISH_MATTE, segments := 10) -> void:
	if profile.size() < 2 or segments < 3:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in segments + 1:
		var ang := TAU * float(s) / float(segments)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		for pt in profile:
			verts.append(Vector3(center.x + dir.x * pt.x, center.y + pt.y,
					center.z + dir.z * pt.x))
			norms.append(dir)
	var n := profile.size()
	for s in segments:
		for i in n - 1:
			var a0 := s * n + i
			var b0 := (s + 1) * n + i
			idx.append_array(PackedInt32Array([
					a0, b0 + 1, b0, a0, a0 + 1, b0 + 1]))
	_add_arrays(verts, norms, idx, color, finish)


## Curved canopy band (issue #236): a shallow arc shell — the
## "cylinder shell segment" tarp vocabulary. Extruded `length` along
## local X, arcing over `span` along local Z with the crown rising
## `rise` above the edges. Double-skinned (outer + inner faces plus
## end skirts) so cloth reads from above and below.
func add_arc_shell(length: float, span: float, rise: float,
		center: Vector3, color: Color, finish := FINISH_MATTE,
		segs := 6) -> void:
	if length <= 0.0 or span <= 0.0 or segs < 2:
		return
	var th := 0.04  ## shell thickness
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		## Parabola crown: y = rise * (1 - (2t-1)^2).
		var z0 := -span * 0.5 + t0 * span
		var z1 := -span * 0.5 + t1 * span
		var y0 := rise * (1.0 - pow(2.0 * t0 - 1.0, 2.0))
		var y1 := rise * (1.0 - pow(2.0 * t1 - 1.0, 2.0))
		var dy := y1 - y0
		var dz := z1 - z0
		var n := Vector3(0.0, dz, -dy).normalized()
		var base := verts.size()
		## Outer skin (crown side) then inner skin offset by thickness.
		verts.append(Vector3(-length * 0.5, y0, z0))
		verts.append(Vector3(length * 0.5, y0, z0))
		verts.append(Vector3(length * 0.5, y1, z1))
		verts.append(Vector3(-length * 0.5, y1, z1))
		for _k in 4:
			norms.append(n)
		verts.append(Vector3(-length * 0.5, y0 - th * n.y, z0 - th * n.z))
		verts.append(Vector3(length * 0.5, y0 - th * n.y, z0 - th * n.z))
		verts.append(Vector3(length * 0.5, y1 - th * n.y, z1 - th * n.z))
		verts.append(Vector3(-length * 0.5, y1 - th * n.y, z1 - th * n.z))
		for _k in 4:
			norms.append(-n)
		idx.append_array(PackedInt32Array([
				base, base + 2, base + 1, base, base + 3, base + 2,
				base + 4, base + 5, base + 6, base + 4, base + 6, base + 7]))
		## End skirts close the shell so edges never read paper-thin.
		verts.append(Vector3(-length * 0.5, y0, z0))
		verts.append(Vector3(-length * 0.5, y1, z1))
		verts.append(Vector3(-length * 0.5, y1 - th * n.y, z1 - th * n.z))
		verts.append(Vector3(-length * 0.5, y0 - th * n.y, z0 - th * n.z))
		for _k in 4:
			norms.append(Vector3.LEFT)
		verts.append(Vector3(length * 0.5, y0, z0))
		verts.append(Vector3(length * 0.5, y1, z1))
		verts.append(Vector3(length * 0.5, y1 - th * n.y, z1 - th * n.z))
		verts.append(Vector3(length * 0.5, y0 - th * n.y, z0 - th * n.z))
		for _k in 4:
			norms.append(Vector3.RIGHT)
		idx.append_array(PackedInt32Array([
				base + 8, base + 9, base + 10, base + 8, base + 10, base + 11,
				base + 12, base + 14, base + 13, base + 12, base + 15, base + 14]))
	for v in verts.size():
		verts[v] += center
	_add_arrays(verts, norms, idx, color, finish)


## Raw triangle soup into this builder's color bucket — shared by the
## primitive path and the prism extruder above.
func _add_arrays(pos: PackedVector3Array, nrm: PackedVector3Array,
		idx: PackedInt32Array, color: Color, finish := FINISH_MATTE) -> void:
	var key := "%s|%d" % [color.to_html(), finish]
	var b: Dictionary = _buckets.get(key, {})
	if b.is_empty():
		b = {"color": color, "finish": finish, "pos": PackedVector3Array(),
			"nrm": PackedVector3Array(), "idx": PackedInt32Array()}
		_buckets[key] = b
	var bucket_pos: PackedVector3Array = b["pos"]
	var bucket_nrm: PackedVector3Array = b["nrm"]
	var bucket_idx: PackedInt32Array = b["idx"]
	var base := bucket_pos.size()
	bucket_pos.append_array(pos)
	bucket_nrm.append_array(nrm)
	for i in idx:
		bucket_idx.append(base + i)
	b["pos"] = bucket_pos
	b["nrm"] = bucket_nrm
	b["idx"] = bucket_idx


## Appends one transformed primitive into this builder's color bucket.
func add_mesh(mesh: PrimitiveMesh, xf: Transform3D, color: Color, finish := FINISH_MATTE) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_idx = arrays[Mesh.ARRAY_INDEX]
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	for v in verts:
		pos.append(xf.basis * v + xf.origin)
	for n in norms:
		nrm.append((xf.basis * n).normalized())
	if src_idx == null or src_idx.is_empty():
		for i in verts.size():
			idx.append(i)
	else:
		for i in src_idx:
			idx.append(int(i))
	_add_arrays(pos, nrm, idx, color, finish)


## Every accumulated surface (one per color) packed into a single ArrayMesh.
func build_mesh() -> ArrayMesh:
	var am := ArrayMesh.new()
	for key in _buckets:
		var b: Dictionary = _buckets[key]
		if b["idx"].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b["pos"]
		arrays[Mesh.ARRAY_NORMAL] = b["nrm"]
		arrays[Mesh.ARRAY_INDEX] = b["idx"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(am.get_surface_count() - 1,
				shared_material(b["color"], b["finish"]))
	return am


## One MeshInstance3D node holding the whole merged batch.
func build_node() -> MeshInstance3D:
	if _buckets.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh()
	return mi
