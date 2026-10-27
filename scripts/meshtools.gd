extends RefCounted
## Performance-pass helpers. Static city visuals merge into one mesh per
## district (one surface per colour), and repeated props / vehicles / crowds
## draw through MultiMeshes — the whole city renders in a small fraction of
## the old node and draw-call count. Purely procedural, no assets.

const Pbr := preload("res://scripts/pbr.gd")


## One shared material per colour for everything that asks — fewer material
## swaps between draws. Since issue 130 every shared surface carries
## procedural grime / roughness / normal detail (see pbr.gd).
static func shared_material(color: Color) -> StandardMaterial3D:
	return Pbr.surface_material(color)


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


func add_box(size: Vector3, center: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	add_mesh(bm, Transform3D(Basis(), center), color)


## Appends one transformed primitive into this builder's colour bucket.
## UVs ride along (the PBR detail maps need them); tangents too, unless a
## contributor has none, in which case the bucket drops them — its normal
## map then falls back to flat shading, which is harmless for grime noise.
func add_mesh(mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var key := color.to_html()
	var b: Dictionary = _buckets.get(key, {})
	if b.is_empty():
		b = {"color": color, "pos": PackedVector3Array(),
			"nrm": PackedVector3Array(), "idx": PackedInt32Array(),
			"uv": PackedVector2Array(), "tan": PackedFloat32Array(),
			"tan_ok": true}
		_buckets[key] = b
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var src_tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var src_idx = arrays[Mesh.ARRAY_INDEX]
	var pos: PackedVector3Array = b["pos"]
	var nrm: PackedVector3Array = b["nrm"]
	var idx: PackedInt32Array = b["idx"]
	var uv: PackedVector2Array = b["uv"]
	var tan: PackedFloat32Array = b["tan"]
	var base := pos.size()
	for v in verts:
		pos.append(xf.basis * v + xf.origin)
	for n in norms:
		nrm.append((xf.basis * n).normalized())
	for k in verts.size():
		if src_uvs != null and not src_uvs.is_empty():
			uv.append(src_uvs[k])
		else:
			var v := verts[k]
			uv.append(Vector2((v.x + v.z) * 0.25, (v.y + v.z) * 0.25))
	var has_tans := src_tans != null and not src_tans.is_empty()
	if has_tans and b["tan_ok"]:
		for k in verts.size():
			var t := xf.basis * Vector3(src_tans[k * 4], src_tans[k * 4 + 1],
				src_tans[k * 4 + 2]).normalized()
			tan.append(t.x)
			tan.append(t.y)
			tan.append(t.z)
			tan.append(src_tans[k * 4 + 3])
	elif not has_tans:
		b["tan_ok"] = false
		tan.resize(0)
	if src_idx == null or src_idx.is_empty():
		for i in verts.size():
			idx.append(base + i)
	else:
		for i in src_idx:
			idx.append(base + int(i))
	b["pos"] = pos
	b["nrm"] = nrm
	b["idx"] = idx
	b["uv"] = uv
	b["tan"] = tan


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
		arrays[Mesh.ARRAY_TEX_UV] = b["uv"]
		if b["tan_ok"]:
			arrays[Mesh.ARRAY_TANGENT] = b["tan"]
		arrays[Mesh.ARRAY_INDEX] = b["idx"]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(am.get_surface_count() - 1, shared_material(b["color"]))
	return am


## One MeshInstance3D node holding the whole merged batch.
func build_node() -> MeshInstance3D:
	if _buckets.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh()
	return mi
