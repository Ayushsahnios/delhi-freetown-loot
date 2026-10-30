extends Node
## Monsoon street dressing (issue #225) — the rain leaves marks on the
## street itself. Three pooled layers, each one MultiMesh draw call:
##   1. Puddles: hash-deterministic pools on the road lows that swell
##      and turn mirror-flat while it pours, then shrink away as the
##      tarmac dries (dark disc + metallic reflection cheat).
##   2. Awning drips: thin falling streaks from shopfront eaves near
##      the camera; cadence tightens with rain intensity, gone when dry.
##   3. Wheel spray: brief mist fans off the rear of anything moving
##      fast on soaked roads (ambient fleet + the player's vehicle).
## All instance buffers are pre-sized in setup(); tick() only writes
## transforms and colors — no per-frame allocations.

const PUDDLE_COUNT := 48
const PUDDLE_Y := 0.125            # sits just above the static road decals
const PUDDLE_MIN_WET := 0.12       # pools start forming past "damp"
const PUDDLE_FULL_WET := 0.75      # fully swelled
const DRIP_COUNT := 64
const DRIP_ANCHOR_STEP := 9.0      # metres between eave anchors per side
const AWNING_H := 3.1              # shop-eave height drips fall from
const DRIP_FALL_H := 2.9           # fall distance to the kerb
const DRIP_SPEED := 6.5            # m/s — a fat drop in free fall
const DRIP_MIN_INTENSITY := 0.05
const RESELECT_EVERY := 2.0        # seconds between nearest-anchor passes
const SPRAY_COUNT := 32
const SPRAY_MIN_WET := 0.35        # roads must be soaked before spray flies
const SPRAY_MIN_SPEED := 6.0
const SPRAY_RADIUS := 95.0
const SPRAY_LIFE := 0.45
const SPRAY_RATE := 2.4            # puffs per second per source
const SRC_MAX := 64                # spray-source buffer size

var spray_emitted := 0             # monotonic counter — the gate reads it

var _puddles: MultiMesh
var _drips: MultiMesh
var _spray: MultiMesh
var _anchors := PackedVector3Array()
var _nearest := PackedInt32Array()       # reused nearest-anchor scratch
var _src_buf: Array = []                 # reused spray-source buffer
var _src_n := 0
var _drip_anchor := PackedInt32Array()   # anchor index per drip slot
var _drip_prog := PackedFloat32Array()   # 0..1 fall progress
var _drip_gap := PackedFloat32Array()    # seconds until the next drop
var _drip_shown := false
var _drips_shown := false
var _drips_active := 0
var _puff_x := PackedFloat32Array()
var _puff_z := PackedFloat32Array()
var _puff_age := PackedFloat32Array()    # < 0 means the slot is free
var _puff_cursor := 0
var _spray_live := 0
var _player: Node3D = null
var _traffic_node: Node = null
var _player_prev := Vector3.ZERO
var _player_prev_ok := false
var _last_puddle_vis := 0.0
var _reselect_t := 0.0
var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------- setup

func setup(world: float, pitch: float, road_w: float, count: int) -> void:
	_rng.randomize()
	_src_buf.resize(SRC_MAX)
	_nearest.resize(DRIP_COUNT)
	_puff_x.resize(SPRAY_COUNT)
	_puff_z.resize(SPRAY_COUNT)
	_puff_age.resize(SPRAY_COUNT)
	for i in SPRAY_COUNT:
		_puff_age[i] = -1.0
	_drip_anchor.resize(DRIP_COUNT)
	_drip_prog.resize(DRIP_COUNT)
	_drip_gap.resize(DRIP_COUNT)
	for i in DRIP_COUNT:
		_drip_prog[i] = 1.0
		_drip_gap[i] = _rng.randf_range(0.1, 2.4)
	_build_anchors(world, pitch, road_w, count)
	_puddles = _new_mm(_disc_mesh(1.0), PUDDLE_COUNT)
	_drips = _new_mm(_streak_mesh(), DRIP_COUNT)
	_spray = _new_mm(_puff_mesh(), SPRAY_COUNT)
	_place_puddles(world, pitch, road_w, count)
	_hide_all(_drips, DRIP_COUNT)
	_hide_all(_spray, SPRAY_COUNT)


func _hide_all(mm: MultiMesh, n: int) -> void:
	## Pooled instances start parked at zero scale — nothing floats
	## visibly at the origin before the first rain.
	var tiny := Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)),
			Vector3.ZERO)
	for i in n:
		mm.set_instance_transform(i, tiny)
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))


func register_player(p: Node3D) -> void:
	_player = p
	_player_prev_ok = false


func register_traffic(t: Node) -> void:
	## The fleet knows where the fast movers are; monsoon reads them
	## through spray_sources() into its own reused buffer.
	_traffic_node = t


# -------------------------------------------------------------- tick

func tick(delta: float, intensity: float, wetness: float,
		cam: Camera3D, auto: Node3D) -> void:
	_update_puddles(wetness)
	_update_drips(delta, intensity, cam)
	_update_spray(delta, wetness, cam, auto)


func stats() -> Dictionary:
	## Snapshot for the headless squall gate (issue #225 assertions).
	return {"puddle": _last_puddle_vis, "drips": _drips_active,
			"spray_live": _spray_live, "spray": spray_emitted}


# ----------------------------------------------------------- puddles

func _update_puddles(wetness: float) -> void:
	## Pools swell on a fast-in / slow-out curve of the wetness itself,
	## and the material keeps the reflection cheat roads.gd established.
	var vis := smoothstep(PUDDLE_MIN_WET, PUDDLE_FULL_WET, wetness)
	if absf(vis - _last_puddle_vis) < 0.02:
		return
	_last_puddle_vis = vis
	var alpha := lerpf(0.0, 0.85, vis)
	var col := Color(1.0, 1.0, 1.0, alpha)
	var s := lerpf(0.15, 1.0, vis)
	for i in PUDDLE_COUNT:
		var xf: Transform3D = _puddles.get_instance_transform(i)
		# Base ellipse radii were baked at placement; the vis factor
		# rides on top so pools grow out of the tarmac lows.
		var r := _base[i] if i < _base.size() else Vector2.ONE
		xf.basis = Basis(Vector3(r.x * s, 0.0, 0.0), Vector3.UP,
				Vector3(0.0, 0.0, r.y * s))
		_puddles.set_instance_transform(i, xf)
		_puddles.set_instance_color(i, col)
	_puddle_mat().roughness = lerpf(0.55, 0.06, vis)
	_puddle_mat().metallic = lerpf(0.05, 0.6, vis)


var _base := PackedVector2Array()  # per-puddle ellipse radii baked at setup


func _place_puddles(world: float, pitch: float, road_w: float, count: int) -> void:
	## Hash-deterministic pools in the road lows: along every span, at
	## the kerb-side dips where water actually gathers on a crowned
	## street. One pass collects candidates, then a stride picks a
	## well-spread PUDDLE_COUNT across the whole map.
	_base.resize(PUDDLE_COUNT)
	var cands: Array[Vector3] = []
	var half := road_w / 2.0
	var edge := world / 2.0
	var block_half := (pitch - road_w) / 2.0
	for along_x in [true, false]:
		for i in count:
			var rc := -world / 2.0 + i * pitch - block_half
			var key := int(round(rc * 4.0)) + (977 if along_x else 311)
			var t := -edge + 6.0
			var k := 0
			while t < edge - 6.0:
				var lane := (4.1 if _hash(key, k, 91) < 0.5 else -4.1) \
						+ (_hash(key, k, 92) - 0.5) * 0.9
				var c := rc + clampf(lane, -(half - 0.9), half - 0.9)
				if along_x:
					cands.append(Vector3(t, PUDDLE_Y, c))
				else:
					cands.append(Vector3(c, PUDDLE_Y, t))
				t += 11.0 + _hash(key, k, 93) * 7.0
				k += 1
	for i in PUDDLE_COUNT:
		var ci := int(float(i) * float(cands.size()) / float(PUDDLE_COUNT))
		var p: Vector3 = cands[ci]
		var rx := 0.8 + _hash(i, 1, 94) * 0.9
		var rz := 0.6 + _hash(i, 2, 95) * 0.6
		_base[i] = Vector2(rx, rz)
		_puddles.set_instance_transform(i, Transform3D(
				Basis(Vector3(0.15 * rx, 0.0, 0.0), Vector3.UP,
						Vector3(0.0, 0.0, 0.15 * rz)), p))
		_puddles.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))


# ------------------------------------------------------------- drips

func _update_drips(delta: float, intensity: float, cam: Camera3D) -> void:
	## Falling streaks from the nearest shopfront eaves. Dry streets:
	## every streak is parked at scale zero after one hiding pass.
	if intensity < DRIP_MIN_INTENSITY:
		if _drips_shown:
			for i in DRIP_COUNT:
				var xf := _drips.get_instance_transform(i)
				xf.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
				_drips.set_instance_transform(i, xf)
			_drips_shown = false
			_drips_active = 0
		return
	if not _drips_shown:
		_drips_shown = true
	_reselect_t -= delta
	if _reselect_t <= 0.0 and cam != null:
		_reselect_t = RESELECT_EVERY
		_pick_nearest_anchors(cam.global_position)
	var alpha := clampf(intensity * 1.6, 0.0, 0.6)
	var col := Color(1.0, 1.0, 1.0, alpha)
	var active := 0
	for i in DRIP_COUNT:
		if _drip_gap[i] > 0.0:
			_drip_gap[i] -= delta
			if _drip_gap[i] <= 0.0:
				_drip_gap[i] = 0.0
				_drip_prog[i] = 0.0
		elif _drip_prog[i] < 1.0:
			_drip_prog[i] += delta * DRIP_SPEED / DRIP_FALL_H
		if _drip_prog[i] >= 1.0 and _drip_gap[i] <= 0.0:
			_drip_gap[i] = lerpf(2.2, 0.12, intensity) \
					* _rng.randf_range(0.35, 1.65)
		if _drip_prog[i] < 1.0 and _drip_gap[i] <= 0.0:
			active += 1
			var a: Vector3 = _anchors[_drip_anchor[i]]
			var fall := _drip_prog[i] * DRIP_FALL_H
			_drips.set_instance_transform(i, Transform3D(Basis(),
					Vector3(a.x, AWNING_H - fall - 0.28, a.z)))
			_drips.set_instance_color(i, col)
		else:
			var xf := _drips.get_instance_transform(i)
			xf.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
			_drips.set_instance_transform(i, xf)
	_drips_active = active


func _pick_nearest_anchors(pos: Vector3) -> void:
	## Fill _nearest with the DRIP_COUNT anchor indices closest to pos.
	## Insertion into the pre-sized buffer — no allocations.
	var used := 0
	for ai in _anchors.size():
		var a: Vector3 = _anchors[ai]
		var d := (a.x - pos.x) * (a.x - pos.x) + (a.z - pos.z) * (a.z - pos.z)
		if used < DRIP_COUNT:
			# Insertion sort into the growing tail.
			var j := used
			_nearest[j] = ai
			var dj := d
			while j > 0:
				var prev: int = _nearest[j - 1]
				var pd := _anchors[prev].distance_squared_to(pos)
				if pd <= dj:
					break
				_nearest[j] = prev
				_nearest[j - 1] = ai
				j -= 1
			used += 1
		else:
			# Only beats the current farthest if clearly closer.
			var far := 0
			var fd := -1.0
			for j in DRIP_COUNT:
				var pj: int = _nearest[j]
				var pd := _anchors[pj].distance_squared_to(pos)
				if pd > fd:
					fd = pd
					far = j
			if d < fd:
				_nearest[far] = ai
	for i in DRIP_COUNT:
		_drip_anchor[i] = _nearest[i]


func _build_anchors(world: float, pitch: float, road_w: float, count: int) -> void:
	## Drip anchors run along the shopfront faces lining every street —
	## one row per side, at eave height, on a fixed step.
	var edge := world / 2.0
	var block_half := (pitch - road_w) / 2.0
	var face := road_w / 2.0 + 2.2 + 0.35
	for along_x in [true, false]:
		for i in count:
			var rc := -world / 2.0 + i * pitch - block_half
			for side: float in [-1.0, 1.0]:
				var t := -edge + 4.5
				while t < edge - 4.5:
					if along_x:
						_anchors.append(Vector3(t, AWNING_H, rc + side * face))
					else:
						_anchors.append(Vector3(rc + side * face, AWNING_H, t))
					t += DRIP_ANCHOR_STEP


# ------------------------------------------------------------- spray

func _update_spray(delta: float, wetness: float, cam: Camera3D, auto: Node3D) -> void:
	## Mist fans behind fast movers on soaked tarmac. Sources come from
	## the traffic fleet (buffer fill, no allocation) plus the player's
	## own vehicle; puffs live in a fixed ring buffer.
	var src_count := 0
	if wetness >= SPRAY_MIN_WET and cam != null:
		if _traffic_node != null and _traffic_node.has_method("spray_sources"):
			src_count = _traffic_node.spray_sources(_src_buf,
					cam.global_position, SPRAY_RADIUS, SPRAY_MIN_SPEED)
		if auto != null and _player != null:
			var speed := 0.0
			if auto.has_method("current_speed"):
				speed = auto.current_speed()
			if speed >= SPRAY_MIN_SPEED:
				var p := auto.global_position
				var dir := Vector3.FORWARD
				if _player_prev_ok:
					var moved := p - _player_prev
					moved.y = 0.0
					if moved.length_squared() > 0.04:
						dir = moved.normalized()
				if src_count < SRC_MAX:
					_src_buf[src_count] = p - dir * 1.5
					src_count += 1
				_player_prev = p
				_player_prev_ok = true
		else:
			_player_prev_ok = false
		for si in src_count:
			if _rng.randf() < delta * SPRAY_RATE * wetness:
				_spawn_puff(_src_buf[si])
	# Advance the ring whether or not new puffs spawned.
	var live := 0
	for i in SPRAY_COUNT:
		if _puff_age[i] < 0.0:
			continue
		_puff_age[i] += delta
		var t := _puff_age[i] / SPRAY_LIFE
		if t >= 1.0:
			_puff_age[i] = -1.0
			var xf := _spray.get_instance_transform(i)
			xf.basis = Basis().scaled(Vector3(0.001, 0.001, 0.001))
			_spray.set_instance_transform(i, xf)
			continue
		live += 1
		var x := _puff_x[i]
		var z := _puff_z[i]
		var s := lerpf(0.35, 1.15, t)
		_spray.set_instance_transform(i, Transform3D(
				Basis().scaled(Vector3(s, s, s)),
				Vector3(x, 0.22 + t * 0.6, z)))
		_spray.set_instance_color(i, Color(1.0, 1.0, 1.0, (1.0 - t) * 0.42))
	_spray_live = live


func _spawn_puff(pos: Vector3) -> void:
	for step in SPRAY_COUNT:
		var i := (_puff_cursor + step) % SPRAY_COUNT
		if _puff_age[i] < 0.0:
			_puff_cursor = (i + 1) % SPRAY_COUNT
			_puff_age[i] = 0.0
			_puff_x[i] = pos.x + _rng.randf_range(-0.3, 0.3)
			_puff_z[i] = pos.z + _rng.randf_range(-0.3, 0.3)
			spray_emitted += 1
			return


# ------------------------------------------------------ mesh helpers

func _new_mm(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var span := 1200.0  # covers the whole city grid from any corner
	mi.custom_aabb = AABB(Vector3(-span * 0.5, -20.0, -span * 0.5),
			Vector3(span, 40.0, span))
	add_child(mi)
	return mm


func _hash(x: int, y: int, seed: int) -> float:
	## Same deterministic hash family as roads.gd.
	var h := x * 374761393 + y * 668265263 + seed * 981039481
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777215.0


static var _disc_tex: ImageTexture = null


static func _disc_texture() -> ImageTexture:
	## Soft radial disc — shapes puddles and spray puffs.
	if _disc_tex != null:
		return _disc_tex
	const S := 64
	var data := PackedByteArray()
	data.resize(S * S * 4)
	for y in S:
		for x in S:
			var d := Vector2(float(x) / S - 0.5, float(y) / S - 0.5).length() * 2.0
			var al := clampf((0.92 - d) * 5.0, 0.0, 1.0)
			var i := (y * S + x) * 4
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = clampi(int(al * 255.0), 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex


var _puddle_material: StandardMaterial3D = null


func _puddle_mat() -> StandardMaterial3D:
	if _puddle_material == null:
		_puddle_material = StandardMaterial3D.new()
		_puddle_material.albedo_texture = _disc_texture()
		_puddle_material.albedo_color = Color(0.13, 0.16, 0.22)
		_puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puddle_material.roughness = 0.55
		_puddle_material.metallic = 0.05
		_puddle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _puddle_material


func _disc_mesh(_size: float) -> ArrayMesh:
	## One flat up-facing quad; the disc texture rounds it into a pool.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-0.5, 0.0, -0.5))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(Vector3(0.5, 0.0, -0.5))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(0.5, 0.0, 0.5))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(-0.5, 0.0, -0.5))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(0.5, 0.0, 0.5))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(-0.5, 0.0, 0.5))
	st.generate_normals()
	st.set_material(_puddle_mat())
	return st.commit()


func _streak_mesh() -> ArrayMesh:
	## Two crossed thin vertical quads — a falling drop reads from any
	## angle without billboarding.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.8, 0.92, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cross(st, Vector3(1.0, 0.0, 0.0))
	_cross(st, Vector3(0.0, 0.0, 1.0))
	st.set_material(m)
	return st.commit()


func _cross(st: SurfaceTool, side: Vector3) -> void:
	## One thin quad centered on the origin, 0.05 wide by 0.55 tall.
	var hw := side * 0.025
	var top := Vector3(0.0, 0.275, 0.0)
	var bot := Vector3(0.0, -0.275, 0.0)
	st.add_vertex(bot - hw)
	st.add_vertex(bot + hw)
	st.add_vertex(top + hw)
	st.add_vertex(bot - hw)
	st.add_vertex(top + hw)
	st.add_vertex(top - hw)


func _puff_mesh() -> Mesh:
	## Soft billboarded mist disc.
	var m := StandardMaterial3D.new()
	m.albedo_texture = _disc_texture()
	m.albedo_color = Color(0.75, 0.8, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.material = m
	return q
