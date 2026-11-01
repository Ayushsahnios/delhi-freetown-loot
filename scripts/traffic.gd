extends Node
## Traffic AI: ambient fleet lane-following the road grid — e-rickshaws,
## hatchbacks, scooters and (issue #269) the heavy three: shared
## passenger tempos, flatbed trucks and a water tanker.
## Purely kinematic movers (no physics bodies): vehicles stay at road level
## on fixed lanes that never intersect building blocks, so nothing can fall
## through the ground or tunnel through geometry.
## The whole fleet renders through a handful of MultiMeshes (one merged
## mesh per vehicle style), so full traffic costs only a few draw calls.
## Traffic rhythm (issue #268): the fleet breathes with the commute —
## rush windows roll extra vehicles in near the player, midday holds the
## baseline, and the late-night quiet band lets the far side of the city
## empty out while the streets near the player keep a light flow.

const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const Exhaust := preload("res://scripts/exhaust.gd")
const Ambulance := preload("res://scripts/ambulance.gd")
const Breakdown := preload("res://scripts/breakdown.gd")

const COUNT := 22
const LANE := 2.8
const WRAP_MARGIN := 24.0
const ACCEL := 9.0
const BRAKE := 22.0

# Commute wave (issue #268): every style's MultiMesh is sized for the
# rush ceiling (COUNT * 1.45 ≈ 32). The baseline fleet is COUNT; the
# wave target moves between the night floor and that ceiling.
const PEAK_COUNT := 32
const MIN_FLEET := 6
const WAVE_SPAWN_S := 0.2   ## roll-in spacing: a rush builds over ~2 s
const WITNESS_M := 90.0     ## surplus beyond this range may leave early
const RETIRE_GRACE_S := 6.0 ## surplus near the player still leaves after this

# The commute curve (issue #268): two rush plateaus at ~1.45x with
# half-hour shoulders, a softer midday lull, and the late-night quiet
# band at 0.6x. Everything derives from the sun-aligned clock hours
# daily_life.gd already computes for the crowd.
const RUSH_WINDOWS := [Vector2(8.0, 10.0), Vector2(17.5, 19.5)]
const RUSH_MULT := 1.45
const LULL_MULT := 0.85
const NIGHT_MULT := 0.6
const BAND_EDGE_H := 0.5    ## soft shoulder width, clock hours

## Graphics preset tie-in (issues 270 + 268): LOW trims the wave ceiling
## the same way pedestrians.gd crowd_scale trims the crowd — set by
## main.gd before setup and on every live preset switch.
static var density_scale := 1.0

# Ambulance street event (issue #215): one van sweeps a lane every
# 2-4 min, faster than the flow; nearby AI eases aside until it passes.
const AMB_FIRST_GAP := Vector2(35.0, 80.0)
const AMB_GAP := Vector2(120.0, 240.0)
const AMB_YIELD_M := 16.0   # AI within this radius pulls toward the kerb
const AMB_KERB := 1.3       # metres of pull-in while yielding
const AMB_EASE := 2.2       # ease-in / merge-back rate (m/s)
const AMB_SLOW := 0.65      # yielders also lift off the throttle

# Kerbside breakdowns (issue #216): a rare dead-vehicle event. One at a
# time; the pull-in target sits at the road edge, well outside the
# ±LANE flow, so ambient AI never has reason to queue behind it.
const BD_FIRST_GAP := Vector2(50.0, 110.0)
const BD_GAP := Vector2(170.0, 340.0)
const BD_KERB_IN := 0.45    # metres in from the kerb line — half on, half off

var _vehicles: Array[Dictionary] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _next_id := 0
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _auto_mm: MultiMesh = null
var _car_mms: Array[MultiMesh] = []
var _scooter_mms: Array[MultiMesh] = []
var _tempo_mms: Array[MultiMesh] = []
var _truck_mms: Array[MultiMesh] = []
var _tanker_mm: MultiMesh = null
var _mm_used := {}
var _mm_free := {}
var _bumps: Array = []
var _puffs: Node3D = null
var _puff_t := 0.0
var _amb = null
var _amb_timer := 60.0
var _bd: Node3D = null
var _bd_timer := 90.0
var _density_mult := 1.0
var _target_n := COUNT
var _wave_cd := 0.0
var _hours := 12.0


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	_auto_mm = _new_mm(_auto_mesh())
	for paint in Vehicles.PAINTS:
		_car_mms.append(_new_mm(_car_mesh(paint)))
	for paint in [Vehicles.PAINTS[0], Vehicles.PAINTS[1]]:
		_scooter_mms.append(_new_mm(_scooter_mesh(paint)))
	# Fleet variety (issue #269): tempo, flatbed truck, water tanker —
	# rarer than the core flow, each still one MultiMesh per style.
	for paint in [Vehicles.PAINTS[2], Vehicles.PAINTS[5]]:
		_tempo_mms.append(_new_mm(_tempo_mesh(paint)))
	for paint in [Vehicles.PAINTS[0], Vehicles.PAINTS[4]]:
		_truck_mms.append(_new_mm(_truck_mesh(paint)))
	_tanker_mm = _new_mm(_tanker_mesh())
	_wave_target()
	for _i in range(_target_n):
		_vehicles.append(_spawn())
	# Idle exhaust (issue #166): one shared puff pool for the fleet; the
	# traffic node sits at the origin, so pool space is world space.
	_puffs = Exhaust.new()
	add_child(_puffs)
	_amb_timer = _rng.randf_range(AMB_FIRST_GAP.x, AMB_FIRST_GAP.y)
	# Test hook: `godot . -- --amb-now` forces the first run almost
	# immediately so headless checks can exercise spawn/yield/despawn.
	if "amb-now" in OS.get_cmdline_user_args():
		_amb_timer = 0.5
	_bd_timer = _rng.randf_range(BD_FIRST_GAP.x, BD_FIRST_GAP.y)
	# Test hook: `godot . -- --bd-now` forces the first breakdown at
	# once so headless checks can exercise pull-in/dwell/despawn.
	if "bd-now" in OS.get_cmdline_user_args():
		_bd_timer = 0.5


func register_player(p: Node3D) -> void:
	_player = p


func set_hours(h: float) -> void:
	## Day-clock input (issue #268): fanned out every frame by
	## daily_life.gd, the same tick that drives the crowd pattern.
	## The target recomputes here (process frame) so a headless probe
	## reads the hour's number before any physics beat; fleet movement
	## still converges on the physics tick in _tick_wave.
	_hours = h
	_wave_target()


func wave_debug() -> Dictionary:
	## Read-back for the headless gate (daily_life_check.gd): the same
	## numbers the wave follows.
	return {"hours": _hours, "mult": _density_mult, "target": _target_n,
			"fleet": _vehicles.size(), "baseline": COUNT, "peak": PEAK_COUNT,
			"scale": density_scale}


func set_speed_bumps(bumps: Array) -> void:
	## Street furniture (issue #69): ambient traffic brakes for the
	## raised strips and bobs as its wheels take them.
	_bumps = bumps


func _spawn(roll_in := false) -> Dictionary:
	var along_z := _rng.randf() < 0.5
	var road_i := _rng.randi_range(0, _roads - 1)
	var road := -_world / 2.0 + road_i * _pitch - (_pitch - _road_w) / 2.0
	var dir := 1 if _rng.randf() < 0.5 else -1
	var t := _rng.randf_range(-_world / 2.0, _world / 2.0)
	# Rush roll-in (issue #268): the surplus joins near the player so a
	# rush reads as extra traffic on YOUR street, not a distant hum.
	if roll_in and _player != null:
		var pc := _player.global_position.z if along_z \
				else _player.global_position.x
		t = clampf(pc + _rng.randf_range(-70.0, 70.0),
				-_world / 2.0, _world / 2.0)
	var roll := _rng.randf()
	var kind := "auto"
	var cruise := _rng.randf_range(8.0, 11.0)
	var mm := _auto_mm
	# Fleet variety (issue #269): mostly e-rickshaws and cars; a fifth of
	# the flow is the heavy three — tempo, flatbed truck, water tanker —
	# big, slow and each in its own register.
	if roll >= 0.95:
		kind = "tanker"
		cruise = _rng.randf_range(6.0, 8.0)
		mm = _tanker_mm
	elif roll >= 0.90:
		kind = "truck"
		cruise = _rng.randf_range(6.5, 8.5)
		mm = _truck_mms[_rng.randi_range(0, _truck_mms.size() - 1)]
	elif roll >= 0.82:
		kind = "tempo"
		cruise = _rng.randf_range(9.0, 12.0)
		mm = _tempo_mms[_rng.randi_range(0, _tempo_mms.size() - 1)]
	elif roll >= 0.8:
		kind = "scooter"
		cruise = _rng.randf_range(13.0, 16.0)
		mm = _scooter_mms[_rng.randi_range(0, _scooter_mms.size() - 1)]
	elif roll >= 0.55:
		kind = "car"
		cruise = _rng.randf_range(12.0, 15.0)
		mm = _car_mms[_rng.randi_range(0, _car_mms.size() - 1)]
	_next_id += 1
	var v := {
		"id": _next_id, "mm": mm, "idx": _alloc(mm), "pos": Vector3.ZERO,
		"heading": 0.0, "along_z": along_z, "road": road, "dir": dir,
		"kind": kind,
		"t": t, "speed": cruise, "cruise": cruise, "bob": 0.0,
		"kerb_n": 0.0, "amb_yield": false, "leave_s": 0.0,
	}
	_apply_transform(v)
	return v


func _physics_process(delta: float) -> void:
	_tick_wave(delta)
	for v in _vehicles:
		var target: float = minf(v.cruise, _player_limit(v))
		target = minf(target, _traffic_limit(v))
		target = minf(target, _bump_limit(v))
		if v.amb_yield:
			target = minf(target, v.cruise * AMB_SLOW)
		v.bob = maxf(v.bob - delta / 0.5, 0.0)
		var rate := BRAKE if target < v.speed else ACCEL
		v.speed = move_toward(v.speed, target, rate * delta)
		v.t += v.dir * v.speed * delta
		var edge := _world / 2.0 + WRAP_MARGIN
		if v.t > edge:
			v.t = -edge
		elif v.t < -edge:
			v.t = edge
		_apply_transform(v)
	_idle_exhaust(delta)
	_tick_ambulance(delta)
	_tick_breakdown(delta)


func _tick_wave(delta: float) -> void:
	## Roll the fleet toward the commute target (issue #268): surplus
	## rolls in near the player at a measured pace (a rush builds over
	## a few seconds, not one pop); when the target falls, the surplus
	## leaves once it has driven out of the witness range — or after a
	## grace beat, so a quiet street never stalls above target forever.
	_wave_target()
	if _vehicles.size() < _target_n:
		_wave_cd -= delta
		if _wave_cd <= 0.0:
			_vehicles.append(_spawn(true))
			_wave_cd = WAVE_SPAWN_S
		return
	_wave_cd = 0.0
	if _vehicles.size() <= _target_n:
		for v in _vehicles:
			v.leave_s = 0.0
		return
	var eye := _eye()
	var kept: Array[Dictionary] = []
	var cand: Array[Dictionary] = []
	for v in _vehicles:
		v.leave_s = float(v.leave_s) + delta
		if v.pos.distance_to(eye) > WITNESS_M \
				or float(v.leave_s) > RETIRE_GRACE_S:
			cand.append(v)
		else:
			kept.append(v)
	if cand.size() > _vehicles.size() - _target_n:
		# Only the over-target share may leave; keep the nearest.
		cand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.pos.distance_squared_to(eye) \
					> b.pos.distance_squared_to(eye))
		while cand.size() > _vehicles.size() - _target_n:
			kept.append(cand.pop_back())
	for v in cand:
		_release(v)
	_vehicles = kept


func _wave_target() -> void:
	## Fleet target for the current clock hour + preset scale.
	_density_mult = _wave_mult(_hours)
	_target_n = clampi(roundi(float(COUNT) * _density_mult
			* density_scale), MIN_FLEET, PEAK_COUNT)


func _wave_mult(h: float) -> float:
	## Commute curve (issue #268): a rush plateau rides over everything
	## (the lull eases up for the evening peak), night thins the far
	## city, midday sits a little under the baseline.
	var m := 1.0
	m = lerpf(m, NIGHT_MULT, _band(h, 22.0, 5.0))
	m = lerpf(m, LULL_MULT, _band(h, 11.0, 16.0))
	for w in RUSH_WINDOWS:
		m = lerpf(m, RUSH_MULT, _band(h, w.x, w.y))
	return m


func _band(h: float, start: float, end_: float) -> float:
	## 1 inside the clock band [start, end) — wrapping past midnight —
	## 0 outside, with a BAND_EDGE_H-hour soft shoulder on each side.
	var width := fmod(end_ - start + 24.0, 24.0)
	var d := fmod(h - start + 24.0, 24.0)
	return clampf(minf(d, width - d) / BAND_EDGE_H, 0.0, 1.0)


func _eye() -> Vector3:
	## Where the wave is watched from: the player when one is live,
	## else the world centre (headless checks before any registration).
	return _player.global_position if _player != null else Vector3.ZERO


func _idle_exhaust(delta: float) -> void:
	## Idling engines smoke (issue #166): vehicles braked to a stop —
	## usually for the player standing in their lane — puff at their
	## tailpipes. Only near the player; the pool is small and the far
	## side of the city is out of sight anyway.
	_puff_t -= delta
	if _puff_t > 0.0:
		return
	_puff_t = 0.55
	for v in _vehicles:
		if v.speed > 1.2:
			continue
		if _player != null and v.pos.distance_to(_player.global_position) > 70.0:
			continue
		var off: Vector3 = Vehicles.EXHAUST_POS.get(v.kind, Vector3.ZERO)
		_puffs.spawn(v.pos + Basis(Vector3.UP, v.heading) * off,
				Vector3(0.1, 0.5, 0.0),
				0.12 if v.kind == "scooter" else 0.2, 1.5)


func _apply_transform(v: Dictionary) -> void:
	var bob: float = v.get("bob", 0.0)
	var y := 0.09 * sin((1.0 - bob) * PI) if bob > 0.0 else 0.0
	# kerb_n grows while yielding to the ambulance (issue #215): the
	# lane offset eases outward from the road centre, never inward.
	var lane: float = (LANE + float(v.kerb_n)) * v.dir
	if v.along_z:
		v.pos = Vector3(v.road + lane, y, v.t)
		v.heading = PI if v.dir > 0 else 0.0
	else:
		v.pos = Vector3(v.t, y, v.road - lane)
		v.heading = -PI / 2.0 * v.dir
	v.mm.set_instance_transform(v.idx,
			Transform3D(Basis(Vector3.UP, v.heading), v.pos))


func _forward(v: Dictionary) -> Vector3:
	return Vector3(0.0, 0.0, 1.0) * v.dir if v.along_z else Vector3(1.0, 0.0, 0.0) * v.dir


func _player_limit(v: Dictionary) -> float:
	## Brake when the player (on foot or driving) stands in our lane ahead.
	if _player == null:
		return v.cruise
	var rel: Vector3 = _player.global_position - v.pos
	var fwd := _forward(v)
	var along := rel.dot(fwd)
	var lateral := (rel - fwd * along).length()
	if along > 1.0 and along < 9.0 and lateral < 2.6:
		return 0.0
	return v.cruise


func _traffic_limit(v: Dictionary) -> float:
	## Keep distance to the vehicle ahead in the same lane and direction.
	var limit: float = v.cruise
	for w in _vehicles:
		if w.id == v.id or w.along_z != v.along_z or w.dir != v.dir:
			continue
		if absf(w.road - v.road) > 1.0:
			continue
		var gap: float = (w.t - v.t) * v.dir
		if gap > 0.5 and gap < 12.0:
			limit = minf(limit, w.speed * clampf(gap / 12.0, 0.0, 1.0))
	return limit


func _bump_limit(v: Dictionary) -> float:
	## Speed bumps (issue #69): brake for a strip ahead on our road and
	## bob the chassis while the wheels are on it. A z-running lane only
	## meets strips laid across it (along_x == false), and vice versa.
	var limit: float = v.cruise
	if _bumps.is_empty():
		return limit
	for bump: Dictionary in _bumps:
		if v.along_z == bump.along_x:
			continue
		var road_c: float = bump.x if v.along_z else bump.z
		if absf(road_c - v.road) > 1.0:
			continue
		var s: float = (bump.z if v.along_z else bump.x) - v.t
		if s * v.dir > 0.0 and s * v.dir < 10.0:
			limit = minf(limit, 5.5)
			if absf(s) < 1.3:
				v.bob = 1.0
	return limit


func _tick_ambulance(delta: float) -> void:
	## Issue #215 lifecycle: spawn after the gap, let it run, free it
	## past the city edge, re-arm the timer. One ambulance at a time.
	if _amb != null and not is_instance_valid(_amb):
		_amb = null
	if _amb == null:
		_amb_timer -= delta
		if _amb_timer <= 0.0:
			_spawn_ambulance()
	elif absf(_amb.t) > _world / 2.0 + WRAP_MARGIN:
		_amb.queue_free()
		_amb = null
		_amb_timer = _rng.randf_range(AMB_GAP.x, AMB_GAP.y)
	_amb_yield(delta)


func _spawn_ambulance() -> void:
	var along_z := _rng.randf() < 0.5
	var road_i := _rng.randi_range(0, _roads - 1)
	var road := -_world / 2.0 + road_i * _pitch - (_pitch - _road_w) / 2.0
	var dir := 1 if _rng.randf() < 0.5 else -1
	var edge := _world / 2.0 + WRAP_MARGIN
	_amb = Ambulance.new()
	add_child(_amb)
	_amb.setup(along_z, road, dir, -float(dir) * (edge + 2.0))


func _tick_breakdown(delta: float) -> void:
	## Issue #216 lifecycle: after the gap one vehicle pulls to the
	## kerb and dies with hazards on; the node frees itself (towed)
	## after the dark beat, and only then does the timer re-arm.
	## Never more than one breakdown at a time.
	if _bd != null and not is_instance_valid(_bd):
		_bd = null
		_bd_timer = _rng.randf_range(BD_GAP.x, BD_GAP.y)
	if _bd == null:
		_bd_timer -= delta
		if _bd_timer <= 0.0:
			_spawn_breakdown()


func _spawn_breakdown() -> void:
	var along_z := _rng.randf() < 0.5
	var road_i := _rng.randi_range(0, _roads - 1)
	var road := -_world / 2.0 + road_i * _pitch - (_pitch - _road_w) / 2.0
	var dir := 1 if _rng.randf() < 0.5 else -1
	# Roll in from a little inside either end of the road so the
	# pull-in has ~12 m of run to stop in.
	var start_t := (_world / 2.0 - 18.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_bd = Breakdown.new()
	add_child(_bd)
	_bd.setup(along_z, road, dir, start_t, _road_w / 2.0 - BD_KERB_IN)


func _amb_yield(delta: float) -> void:
	## Nearby AI eases toward the kerb until the ambulance passes
	## (issue #215), then merges back. Only vehicles on the same road
	## strip pull in; everyone else holds their lane.
	var amb_pos := Vector3(0.0, -9000.0, 0.0)
	if _amb != null:
		amb_pos = _amb.global_position
	for v in _vehicles:
		var target := 0.0
		if _amb != null:
			var d: float = v.pos.distance_to(amb_pos)
			if d < AMB_YIELD_M:
				var amb_c: float = amb_pos.x if v.along_z else amb_pos.z
				if absf(amb_c - v.road) < _road_w * 0.5 + 0.6:
						target = AMB_KERB
		v.kerb_n = move_toward(float(v.kerb_n), target, AMB_EASE * delta)
		v.amb_yield = target > 0.0 or float(v.kerb_n) > 0.05


func near_horns(pos: Vector3, radius: float, max_n: int = 4) -> Array[Dictionary]:
	## Live traffic within radius of pos, nearest first, as {pos, kind}
	## pairs — the reactive street-horn bed samples this (issue #165) and
	## gives each vehicle its own horn voice (issue #187).
	var out: Array[Dictionary] = []
	var best: Array[float] = []
	for v in _vehicles:
		var d := pos.distance_to(v.pos)
		if d > radius:
			continue
		var idx := out.size()
		while idx > 0 and best[idx - 1] > d:
			idx -= 1
		out.insert(idx, {"pos": v.pos, "kind": v.kind})
		best.insert(idx, d)
		if out.size() > max_n:
			out.pop_back()
			best.pop_back()
	return out

func spray_sources(buf: Array, pos: Vector3, radius: float,
		min_speed: float) -> int:
	## Wheel-spray source points (issue #225): rear positions of fleet
	## vehicles moving fast enough to throw water, filled into the
	## caller's pre-sized buffer so the rain dressing never allocates
	## per frame. Returns how many entries were written.
	var n := 0
	var r2 := radius * radius
	for v in _vehicles:
		if v.speed < min_speed:
			continue
		var p: Vector3 = v.pos - _forward(v) * 1.3
		var dx := p.x - pos.x
		var dz := p.z - pos.z
		if dx * dx + dz * dz > r2:
			continue
		buf[n] = p
		n += 1
		if n >= buf.size():
			break
	return n

func on_road(pos: Vector3, tol := 1.0) -> bool:
	## True when pos sits on a driving-lane strip (within tol) — the
	## foley bed uses it to pick paved vs dirt footsteps (issue #187).
	## Lane coordinates are shared by the x- and z-running roads.
	if _roads <= 0:
		return false
	var base := -_world / 2.0 - (_pitch - _road_w) / 2.0
	var edge := _road_w / 2.0 + tol
	for c in [pos.x, pos.z]:
		var i := clampi(roundi((float(c) - base) / _pitch), 0, _roads - 1)
		if absf(float(c) - (base + i * _pitch)) <= edge:
			return true
	return false


func nearest_enterable(pos: Vector3, max_dist: float) -> Dictionary:
	## Closest ambient traffic vehicle within max_dist, as a takeover spec
	## (id, kind, pos, heading). Empty dict when nothing is in range.
	var best := {}
	var best_d := max_dist * max_dist
	for v in _vehicles:
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < best_d:
			best_d = dx * dx + dz * dz
			best = {"id": v.id, "kind": v.kind,
				"pos": v.pos + Vector3(0.0, 1.0, 0.0),
				"heading": v.heading}
	return best


func take_vehicle(id: int) -> void:
	## Remove a traffic vehicle (the player took it over) and spawn a
	## replacement so street density stays constant. The freed MultiMesh
	## slot is parked below the world until reused.
	for i in range(_vehicles.size()):
		if _vehicles[i].id == id:
			var dead: Dictionary = _vehicles[i]
			_release(dead)
			_vehicles.remove_at(i)
			# Replacement only up to the wave target (issue #268): the
			# street refills to the hour's density, not always full.
			if _vehicles.size() < _target_n:
				_vehicles.append(_spawn())
			return


func worst_hazard_speed(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## on-foot impact damage. Kinematic movers, so no physics events exist.
	var worst := 0.0
	for v in _vehicles:
		if v.speed <= 2.5:
			continue
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < 5.29:
			worst = maxf(worst, v.speed)
	worst = maxf(worst, _amb_hazard_speed(pos, 2.3))
	return worst


func ram_speed_at(pos: Vector3) -> float:
	## Fastest traffic vehicle overlapping `pos`; main.gd turns this into
	## wanted heat when the player's auto rams traffic.
	var worst := 0.0
	for v in _vehicles:
		var dx: float = v.pos.x - pos.x
		var dz: float = v.pos.z - pos.z
		if dx * dx + dz * dz < 8.4:
			worst = maxf(worst, absf(v.speed))
	worst = maxf(worst, _amb_hazard_speed(pos, 2.9))
	return worst


func _amb_hazard_speed(pos: Vector3, radius: float) -> float:
	## The ambulance never brakes for anyone (issue #215): if it is
	## overlapping pos, its full run speed counts as the hazard.
	if _amb == null:
		return 0.0
	var dx: float = _amb.global_position.x - pos.x
	var dz: float = _amb.global_position.z - pos.z
	if dx * dx + dz * dz < radius * radius:
		return Ambulance.SPEED
	return 0.0


# ---------------------------------------------------------------- instancing

func _new_mm(mesh: ArrayMesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = PEAK_COUNT
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mm


func _alloc(mm: MultiMesh) -> int:
	## Reuse a released slot when one is free, else grow the visible range.
	if _mm_free.has(mm) and not _mm_free[mm].is_empty():
		return int(_mm_free[mm].pop_back())
	var used: int = _mm_used.get(mm, 0)
	_mm_used[mm] = used + 1
	mm.visible_instance_count = used + 1
	return used


func _release(v: Dictionary) -> void:
	v.mm.set_instance_transform(v.idx,
			Transform3D(Basis(), Vector3(0.0, -500.0, 0.0)))
	if not _mm_free.has(v.mm):
		_mm_free[v.mm] = []
	_mm_free[v.mm].append(v.idx)


# ---------------------------------------------------------------- visuals

func _auto_mesh() -> ArrayMesh:
	## Whole rickshaw merged into one mesh (wheels included — they never
	## animate separately), one surface per color.
	var b := MeshTools.new()
	Vehicles.build_rickshaw_body(b)
	Vehicles.add_driver(b, "auto")
	for spec in Vehicles.RICKSHAW_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func _car_mesh(paint: Color) -> ArrayMesh:
	var b := MeshTools.new()
	Vehicles.build_hatchback_body(b, paint)
	Vehicles.add_driver(b, "car")
	for spec in Vehicles.HATCH_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func _scooter_mesh(paint: Color) -> ArrayMesh:
	var b := MeshTools.new()
	Vehicles.build_scooter_body(b, paint)
	Vehicles.add_driver(b, "scooter")
	for spec in Vehicles.SCOOTER_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func _tempo_mesh(paint: Color) -> ArrayMesh:
	## Issue #269: shared passenger tempo with its roof-rack luggage.
	var b := MeshTools.new()
	Vehicles.build_tempo_body(b, paint)
	Vehicles.add_driver(b, "tempo")
	for spec in Vehicles.TEMPO_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func _truck_mesh(paint: Color) -> ArrayMesh:
	## Issue #269: flatbed truck — pipes and a tarp roll strapped on.
	var b := MeshTools.new()
	Vehicles.build_truck_body(b, paint)
	Vehicles.add_driver(b, "truck")
	for spec in Vehicles.TRUCK_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func _tanker_mesh() -> ArrayMesh:
	## Issue #269: water tanker — the one-off silver drum on the street.
	var b := MeshTools.new()
	Vehicles.build_tanker_body(b, Vehicles.PAINTS[3])
	Vehicles.add_driver(b, "tanker")
	for spec in Vehicles.TANKER_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()
