extends Node
## Pedestrians: sidewalk NPCs walking the road grid. They turn at corners,
## scatter when the player sounds the horn nearby, then find their way back
## to the nearest sidewalk line. Purely kinematic movers (same approach as
## the traffic manager) recycled around the player, so there is no spawn
## cost and nothing can fall through the world.
## Every walker is an instanced rigged CC0 character (see characters.gd)
## playing its own walk/run clips — the old MultiMesh box bodies are gone.
## Street behaviors (issue #207) layer on top of the stroll: phone
## walkers drift with their heads down (LivelyRig phone pose), plain
## walkers occasionally pause to window-shop a facade or linger at a
## paan counter chewing, and converted zone walkers stand as hawkers
## behind the bazaar stall rows calling their wares (talking accents).
## Crowd life 2 (issue #217) adds chatting pairs and bench idlers: a
## few walkers stroll shoulder-to-shoulder in talking pairs (the
## follower mirrors its leader — same line, same pauses, bolt as one),
## and walkers near a bus-stop shelter drift over to idle at the bench
## facing the road like waiting commuters before rejoining the flow.
## Age + street-character variety (issue #222): kids stroll beside
## adults (shorter, quicker cadence), elders amble stooped with a
## cane, and fixed walkers carry the street trades — a sabzi-wala
## pushing a produce-stacked thela cart, a khaki chowkidar with his
## lathi, a ragpicker under a jute sack.

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")
const Streetfolk := preload("res://scripts/streetfolk.gd")

const COUNT := 26
const EDGE := 1.4
const RECYCLE_DIST := 150.0
const SPAWN_ALONG := 110.0
const SPAWN_MIN_DIST := 42.0
const WALK_MIN := 2.2
const WALK_MAX := 3.6
const TURN_CHANCE := 0.4
const TURN_WINDOW := 0.9
const PANIC_TIME := 2.6
const PANIC_SPEED := 8.0
const SCATTER_RADIUS := 18.0
const REJOIN_SPEED := 5.5
const REJOIN_LIMIT := 4.0
const ZONE_EXTRA := 40
const ZONE_WAKE := 130.0
const ZONE_RECYCLE := 150.0
const ZONE_SPAWN_MIN := 26.0
const ZONE_BIAS := 42.0
const PED_HEIGHT := 1.68
const WALK_CLIP_SPEED := 3.8
# Street behaviors (issue #207).
const PHONE_SHARE := 0.18      ## walkers whose heads stay in a phone
const PHONE_MIN := 1.25        ## phone walkers amble slower
const PHONE_MAX := 1.9
const PAUSE_MIN := 3.5         ## window-shop / paan pause length (s)
const PAUSE_MAX := 7.0
const PAUSE_RETRY_MIN := 3.0   ## gap before another pause roll
const PAUSE_RETRY_MAX := 6.0
const PAUSE_GAP_MIN := 9.0     ## cooldown after a full pause
const PAUSE_GAP_MAX := 22.0
const PAAN_LINGER_R := 10.0    ## near a paan counter, paan pauses win
const HAWKER_STAND := 1.85     ## stand-off in front of a stall counter
# Crowd life 2 (issue #217): chatting pairs + bench idlers.
const PAIR_GAP := 0.85         ## shoulder-to-shoulder pair spacing (m)
const PAIR_STAGGER := 0.55     ## the follower walks half a step back
const BENCH_NEAR := 8.5        ## near a shelter bay, bench idling wins
const BENCH_MIN := 12.0        ## bench linger length (s, after arriving)
const BENCH_MAX := 26.0
const BENCH_APPROACH := 1.5     ## amble speed over to the bench (m/s)
# Age + street-character variety (issue #222): kids stroll beside
# adults, elders walk stooped with a cane, and fixed-index walkers
# carry the readable street silhouettes — sabzi-wala thela cart,
# chowkidar lathi patrol, ragpicker jute sack.
const KID_SHARE := 0.12         ## walkers that spawn as children
const ELDER_SHARE := 0.14       ## walkers that spawn as elders
const KID_SCALE := 0.66         ## kids stand at ~2/3 adult height
const KID_SPEED_MIN := 3.1      ## kids skip along quicker than adults
const KID_SPEED_MAX := 3.9
const KID_CADENCE := 1.28       ## walk-clip rate boost: faster arm swing
const ELDER_SPEED_MIN := 1.35   ## elders amble slow, never rush
const ELDER_SPEED_MAX := 1.85
const ELDER_STOOP_MIN := 0.10   ## LivelyRig stoop pitch range (rad)
const ELDER_STOOP_MAX := 0.17
const ELDER_CANE_SHARE := 0.55  ## elders carrying a cane
const FOLK_SPEED_MIN := 1.5     ## lathi patrol + sack pick amble
const FOLK_SPEED_MAX := 2.0
const CART_SPEED_MIN := 1.55    ## cart vendors lean into a slow push
const CART_SPEED_MAX := 2.05
const ROAD_Y := 0.08  ## asphalt surface height (roads.gd ROAD_Y)
const WALK_H := 0.14  ## sidewalk top height (roads.gd CURB_H)
const WALK_W := 2.2   ## sidewalk band width (roads.gd WALK_TILE)

## Graphics preset (issue 270): LOW trims the crowd cap — both targets
## scale together, so a LOW street carries ~60 % of the bodies at every
## hour of the day cycle without touching spawn logic.
static var crowd_scale := 1.0
const MODELS := [
	Chars.FEMALE_A, Chars.FEMALE_B, Chars.FEMALE_C, Chars.FEMALE_D, Chars.MALE,
]

var _peds: Array[Dictionary] = []
var _player: Node3D = null
var _rng := RandomNumberGenerator.new()
var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _placed := false
var _zones: Array[Dictionary] = []
var _chars := Chars.new()
var _night := 0.0
var _rush := 0.0
var _base_target := 0
var _zone_target := 0
var _last_model := -1
var _paan: Array[Vector3] = []
var _hawker_next := 0
var _benches: Array = []


func setup(world_size: float, pitch: float, road_width: float, road_count: int) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_rng.randomize()
	_base_target = COUNT
	_zone_target = ZONE_EXTRA
	var total := COUNT + ZONE_EXTRA
	for i in range(total):
		var v := _new_ped(i >= COUNT)
		v.rank = i - COUNT if i >= COUNT else i
		_dress(v, i)
		_peds.append(v)
	_pair_up()


func _pair_up() -> void:
	## Crowd life 2 (issue #217): a few walkers stroll as chatting
	## pairs — mates with talking accents, one leader and one mirroring
	## follower. The follower shares the leader's rank so the night
	## thinning never splits a pair, and pair members never convert to
	## hawkers (a stall is a solo post).
	for leader_i in [3, 13, COUNT + 8, COUNT + 19, COUNT + 30]:
		if leader_i + 1 >= _peds.size():
			continue
		var a: Dictionary = _peds[leader_i]
		var b: Dictionary = _peds[leader_i + 1]
		a["pair"] = leader_i + 1
		b["pair"] = leader_i
		b["lead"] = false
		b["side"] = 1.0 if _rng.randf() < 0.5 else -1.0
		b["rank"] = a["rank"]
		a["phone"] = false
		b["phone"] = false
		for m in [a, b]:
			var rig: Node = _chars.lively(m["node"])
			if rig != null:
				rig.phone_override = false
				rig.talking = true


func set_crowd_zone(center: Vector3, radius: float) -> void:
	## Crowd density boost: ZONE_EXTRA extra shoppers walk the sidewalk
	## lines around each registered zone while the player is nearby; they
	## sleep (and cost nothing) when every zone is far away. Districts
	## each register their own zone (issue #97). Issue #181 wave 1 raised
	## the squad 18 -> 40: with the 26 ambient walkers a busy strip now
	## carries ~66 bodies (~+50%) instead of 44, using the same recycler
	## and identity seeds — no new models.
	_zones.append({"c": center, "r": radius})


func set_life_pattern(night: float, rush: float, keep: float) -> void:
	## Daily rhythm (issue #185), driven by daily_life.gd: night thins the
	# street crowd to the keep floor; the morning chai rush fills the
	# bazaar zones back up regardless of the hour's darkness.
	_night = night
	_rush = rush
	_base_target = roundi(float(COUNT) * crowd_scale
			* clampf(keep, 0.0, 1.0))
	_zone_target = roundi(float(ZONE_EXTRA) * crowd_scale
			* clampf(maxf(keep, rush), 0.0, 1.0))


func life_debug() -> Dictionary:
	## Read-back for the headless gate (daily_life_check.gd).
	var base_vis := 0
	var zone_vis := 0
	for v in _peds:
		if v.visible:
			if bool(v.get("zone", false)):
				zone_vis += 1
			else:
				base_vis += 1
	return {"night": _night, "rush": _rush,
			"crowd_scale": crowd_scale,
			"base_target": _base_target, "zone_target": _zone_target,
			"base_visible": base_vis, "zone_visible": zone_vis,
			"base_total": COUNT, "zone_total": ZONE_EXTRA}


func register_player(p: Node3D) -> void:
	_player = p


func walker_list() -> Array[Dictionary]:
	## Live walker records for the monsoon crowd gear (issue #221) —
	## raingear.gd reads node/identity/visibility per walker and adds
	## umbrellas, jackets and soak without touching the walk logic.
	return _peds


func register_paan_counters(spots: Array[Vector3]) -> void:
	## Paan counter anchors (issue #188 carts, main.gd): walkers passing
	## within PAAN_LINGER_R of one roll paan-eater pauses — stand, face
	## the counter and chew (talking accents) — before moving on.
	_paan = spots


func station_hawkers(spots: Array) -> void:
	## Convert zone walkers into stationary hawkers behind the bazaar
	## stall rows (issue #207): one per stall spot, standing between the
	## counter and the market lane, facing the street, idle clip plus
	## hawking call accents (LivelyRig talking). They keep their zone
	## rank, so the bazaar night thinning still applies to them.
	for spot in spots:
		if _hawker_next >= _peds.size():
			return
		var v: Dictionary = _peds[_hawker_next]
		_hawker_next += 1
		if not bool(v.get("zone", false)):
			continue
		if v["pair"] >= 0:
			continue  # chatting pairs stay strollers; a stall is a solo post
		if String(v.get("age", "adult")) != "adult" \
					or String(v.get("street", "")) != "":
			continue  # kids/elders/street characters keep their silhouettes
		v["hawker"] = {"pos": spot["pos"], "face": spot["face"]}
		v["phone"] = false
		v["pause"] = 0.0
		v["pkind"] = ""
		var rig: Node = _chars.lively(v["node"])
		if rig != null:
			rig.phone_override = false
			rig.talking = true


func register_benches(slots: Array) -> void:
	## Bus-stop bench anchors (street_furniture.gd, main.gd): walkers
	## passing near a shelter bay may drift over and idle at the bench
	## facing the road (issue #217), then rejoin the sidewalk flow. One
	## stand point per bench seat; a slot is busy while an idler holds it.
	for s in slots:
		_benches.append({"pos": s["pos"], "face": s["face"], "busy": false})


func street_debug() -> Dictionary:
	## Read-back for the headless gate + PR evidence: how many visible
	## walkers are in each street-behavior state right now (issues #207
	## and #217).
	var out := {"phone": 0, "hawker": 0, "window": 0, "paan": 0, "strolling": 0,
			"pair": 0, "bench": 0}
	for v in _peds:
		if not v.visible:
			continue
		if not v["hawker"].is_empty():
			out["hawker"] += 1
		elif v["pause"] > 0.0:
			if v["pkind"] == "bench":
				out["bench"] += 1
			else:
				out[v["pkind"]] += 1
		elif v["phone"]:
			out["phone"] += 1
		else:
			out["strolling"] += 1
		if v["lead"] and v["pair"] >= 0:
			out["pair"] += 1
	return out


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if not _placed:
		_placed = true
		for v in _peds:
			if not bool(v.get("zone", false)):
				_place(v)
	if Input.is_action_just_pressed("horn"):
		_scatter(_player.global_position)
	for v in _peds:
		if not v.lead and v.pair >= 0:
			# follower half of a chatting pair (issue #217): mirrors its
			# leader every frame — no independent walk line of its own
			_pair_follow(v, delta)
			continue
		var is_zone := bool(v.get("zone", false))
		if is_zone and not _zone_awake():
			if v.visible:
				v.visible = false
				_hide_ped(v)
				v.panic = 0.0
				v.rejoin = 0.0
			continue
		# Night thinning (issue #185): walkers past the day's target sleep
		# out of sight — the tail of each squad stops ticking until dawn
		# (or the chai rush refills the bazaar zones).
		var target := _zone_target if is_zone else _base_target
		if v.rank >= target:
			if v.visible:
				v.visible = false
				_hide_ped(v)
				v.panic = 0.0
				v.rejoin = 0.0
			continue
		if is_zone:
			if not v.visible:
				_place_zone(v)
		elif not v.visible:
			_place(v)
		if v.cd > 0.0:
			v.cd -= delta
		if v.panic > 0.0 or v.rejoin > 0.0:
			_flee_tick(v, delta)
		else:
			_walk_tick(v, delta)
			if v.hawker.is_empty():
				var recycle := RECYCLE_DIST
				if is_zone:
					recycle = ZONE_RECYCLE
				if _flat_dist(v) > recycle:
					if is_zone:
						_place_zone(v)
					else:
						_place(v)
		_animate(v)


# ---------------------------------------------------------------- walking

func _walk_tick(v: Dictionary, delta: float) -> void:
	if not v.hawker.is_empty():
		return
	if v.pause > 0.0:
		if v.pkind == "bench" and not v.barrived:
			# bench idler (issue #217): amble over to the shelter bay
			# first; the linger clock only starts once they arrive.
			var step: Vector3 = v.bgo - v.pos
			step.y = 0.0
			var d := step.length()
			if d > 0.22:
				step = step / d * BENCH_APPROACH
				v.pos += step * delta
				_face(v, step)
				v.phase += delta * 3.4
			else:
				v.barrived = true
				_face(v, v.bseat["face"])
			return
		v.pause -= delta
		if v.pause <= 0.0:
			_end_pause(v)
		return
	if not v.phone:
		v.pcd -= delta
		if v.pcd <= 0.0:
			_begin_pause(v)
			return
	v.t += v.dir * v.speed * delta
	if absf(v.t) > _world / 2.0 + 20.0:
		v.dir = -v.dir
	_maybe_turn(v)
	_apply(v)
	var d := Vector3(0.0, 0.0, 1.0) if v.along_z else Vector3(1.0, 0.0, 0.0)
	_face(v, d * v.dir)
	v.phase += delta * v.speed * 2.6


func _maybe_turn(v: Dictionary) -> void:
	## At an intersection, the crossing road's sidewalk lines cross ours at
	## cross +/- offset. Chance to turn onto one of those corners.
	if v.cd > 0.0:
		return
	var cross := _nearest_line(v.t)
	for side in [1.0, -1.0]:
		var corner: float = cross + side * _offset()
		if absf(v.t - corner) < TURN_WINDOW and _rng.randf() < TURN_CHANCE:
			v.t = v.road
			v.road = corner
			v.along_z = not v.along_z
			v.dir = 1 if _rng.randf() < 0.5 else -1
			v.cd = 2.0
			return


func _apply(v: Dictionary) -> void:
	if v.along_z:
		v.pos = Vector3(v.road, 0.0, v.t)
	else:
		v.pos = Vector3(v.t, 0.0, v.road)

# ------------------------------------------------- street behaviors

func _begin_pause(v: Dictionary) -> void:
	## Roll a pause (issue #207): near a paan counter the paan-eater
	## lingers facing the cart with chewing accents; anywhere else a
	## window-shopper stops and studies the block facade across the
	## walk band. Either way they stand on the idle clip for a few
	## seconds, then resume the stroll with a fresh cooldown.
	var slot: Dictionary = _bench_free_near(v.pos)
	if not slot.is_empty() and _rng.randf() < 0.55:
		# bench idler (issue #217): drift to the shelter bay and idle at
		# the bench facing the road like a waiting commuter.
		v.pkind = "bench"
		slot["busy"] = true
		v.bseat = slot
		v.bgo = slot["pos"]
		v.barrived = false
		v.pause = _rng.randf_range(BENCH_MIN, BENCH_MAX)
		return
	if v.pair >= 0:
		# chatting pair (issue #217): sometimes they stop and stand
		# face-to-face mid-stroll, gesturing through a point.
		v.pkind = "chat"
		var mate: Vector3 = _peds[v.pair].pos
		_face(v, Vector3(mate.x - v.pos.x, 0.0, mate.z - v.pos.z))
		v.pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX) * 0.8
		return
	var counter: Variant = _paan_counter_near(v.pos)
	if counter != null and _rng.randf() < 0.6:
		v.pkind = "paan"
		var rig: Node = _chars.lively(v.node)
		if rig != null:
			rig.talking = true
		_face(v, Vector3(counter.x - v.pos.x, 0.0, counter.z - v.pos.z))
	else:
		v.pkind = "window"
		var side: float = signf(v.road - _nearest_line(v.road))
		_face(v, Vector3(side, 0.0, 0.0) if v.along_z else Vector3(0.0, 0.0, side))
	v.pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)


func _end_pause(v: Dictionary) -> void:
	if v.pkind == "bench":
		_release_bench(v)
		_snap_to_sidewalk(v)
		v.pcd = _rng.randf_range(PAUSE_GAP_MIN, PAUSE_GAP_MAX)
		return
	_clear_pause(v)
	v.pcd = _rng.randf_range(PAUSE_GAP_MIN, PAUSE_GAP_MAX)


func _release_bench(v: Dictionary) -> void:
	if v.bseat != null:
		v.bseat["busy"] = false
		v.bseat = null
		v.barrived = false


func _bench_free_near(pos: Vector3) -> Dictionary:
	## Nearest free bench-bay slot within BENCH_NEAR, or {}.
	var best := {}
	var best_d := BENCH_NEAR
	for s in _benches:
		var d := Vector2(s["pos"].x - pos.x, s["pos"].z - pos.z).length()
		if d < best_d and not s["busy"]:
			best = s
			best_d = d
	return best


func _clear_pause(v: Dictionary) -> void:
	## Drop any active pause state (also used when a walker bolts, sleeps
	## or respawns — a hidden walker must never keep talking accents on).
	_release_bench(v)
	v.pause = 0.0
	if v.pkind == "paan":
		var rig: Node = _chars.lively(v.node)
		if rig != null:
			rig.talking = false
	v.pkind = ""
	v.pcd = _rng.randf_range(PAUSE_RETRY_MIN, PAUSE_RETRY_MAX)


func _paan_counter_near(pos: Vector3) -> Variant:
	var best: Variant = null
	var best_d := PAAN_LINGER_R
	for c in _paan:
		var d := Vector2(c.x - pos.x, c.z - pos.z).length()
		if d < best_d:
			best = c
		best_d = d
	return best


# ------------------------------------------------------------ pairs

func _pair_follow(v: Dictionary, delta: float) -> void:
	## The follower half of a chatting pair (issue #217). While the pair
	## bolts, the follower flees its own copy of the leader's panic (same
	## direction, same timers — parallel paths); once both are calm the
	## follower's pose is derived straight from the leader again, so a
	## pair can never drift apart for long.
	if v.panic > 0.0 or v.rejoin > 0.0:
		_flee_tick(v, delta)
		var calm_l: Dictionary = _peds[v.pair]
		if v.panic <= 0.0 and v.rejoin <= 0.0 \
				and calm_l.panic <= 0.0 and calm_l.rejoin <= 0.0:
			_pair_snap(v, calm_l)
		_animate(v)
		return
	var leader: Dictionary = _peds[v.pair]
	if not leader.visible:
		if v.visible:
			v.visible = false
			_hide_ped(v)
		return
	if not v.visible:
		v.visible = true
		if v.node != null:
			v.node.visible = true
	var fwd := Vector3(-sin(leader.heading), 0.0, -cos(leader.heading))
	v.pos = leader.pos + Vector3(fwd.z, 0.0, -fwd.x) * (v.side * PAIR_GAP) \
			- fwd * PAIR_STAGGER
	v.pause = leader.pause
	v.pkind = leader.pkind
	if leader.pause > 0.0 and leader.pkind == "chat":
		v.heading = leader.heading + PI  # stand face-to-face
	else:
		v.heading = leader.heading
	_animate(v)


func _pair_snap(v: Dictionary, leader: Dictionary) -> void:
	## Re-align a follower to its leader after the panic dust settles
	## (also used when the leader is re-placed or snapped back to a
	## sidewalk line) so the pair reforms shoulder-to-shoulder.
	v.along_z = leader.along_z
	v.road = leader.road
	v.t = leader.t
	v.dir = leader.dir
	v.speed = leader.speed
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = leader.cd
	_apply(v)


# ---------------------------------------------------------------- panic

func _scatter(origin: Vector3) -> void:
	## Horn blast: NPCs within SCATTER_RADIUS bolt away from the sound.
	## Hawkers hold their stalls — a vendor does not abandon the wares.
	for v in _peds:
		if not v.hawker.is_empty():
			continue
		if not v.lead and v.pair >= 0:
			# pairs bolt together: the follower copies its leader's panic
			var pl: Dictionary = _peds[v.pair]
			if pl.panic > 0.0:
				_clear_pause(v)
				v.panic = pl.panic
				v.rejoin = 0.0
				v.cd = 1.0
				v.panic_dir = pl.panic_dir
			continue
		_clear_pause(v)
		var p: Vector3 = v.pos
		var away := Vector3(p.x - origin.x, 0.0, p.z - origin.z)
		if away.length() > SCATTER_RADIUS:
			continue
		if away.length() < 0.05:
			away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		v.panic = PANIC_TIME
		v.rejoin = 0.0
		v.cd = 1.0
		v.panic_dir = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))


func vehicle_strike(pos: Vector3, radius: float) -> int:
	## Player auto plowed into the crowd: stricken NPCs bolt away and the
	## count feeds the wanted system (main.gd).
	var n := 0
	for v in _peds:
		if not v.hawker.is_empty():
			continue
		if not v.lead and v.pair >= 0:
			# a pair reacts as one body — the leader's strike decides
			continue
		_clear_pause(v)
		var p: Vector3 = v.pos
		var away := Vector2(p.x - pos.x, p.z - pos.z)
		if away.length() > radius:
			continue
		n += 1
		var dir := Vector3(away.x, 0.0, away.y)
		if away.length() < 0.05:
			dir = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		v.panic = PANIC_TIME
		v.rejoin = 0.0
		v.cd = 1.0
		v.panic_dir = dir.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	return n


func _flee_tick(v: Dictionary, delta: float) -> void:
	if v.rejoin > 0.0:
		v.rejoin += delta
		var mv: Vector3 = v.panic_dir * REJOIN_SPEED
		v.pos += mv * delta
		v.phase += delta * REJOIN_SPEED * 2.6
		_face(v, mv)
		var near := _nearest_sidewalk(v.pos)
		if near["dist"] < 1.6 or v.rejoin > REJOIN_LIMIT:
			_snap_to_sidewalk(v)
		return
	v.panic -= delta
	var falloff: float = 0.35 + 0.65 * v.panic / PANIC_TIME
	var mv2: Vector3 = v.panic_dir * PANIC_SPEED * falloff
	v.pos += mv2 * delta
	v.phase += delta * 12.0
	_face(v, mv2)
	if v.panic <= 0.0:
		v.rejoin = 0.0001


func _snap_to_sidewalk(v: Dictionary) -> void:
	var near := _nearest_sidewalk(v.pos)
	var pos: Vector3 = v.pos
	v.along_z = near["along_z"]
	v.road = near["line"]
	v.t = pos.z if v.along_z else pos.x
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _roll_speed(v)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = 1.0
	_apply(v)
	if v.pair >= 0 and v.lead:
		_pair_snap(_peds[v.pair], v)


# ---------------------------------------------------------------- helpers

func _place(v: Dictionary) -> void:
	## (Re)spawn on a random sidewalk line, biased around the player but far
	## enough away that nothing pops into view.
	v.along_z = _rng.randf() < 0.5
	var i := _rng.randi_range(0, _roads - 1)
	v.road = _line_at(i) + (1.0 if _rng.randf() < 0.5 else -1.0) * _offset()
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _roll_speed(v)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = _rng.randf_range(0.5, 2.5)
	_clear_pause(v)
	var p: Vector3 = _player.global_position
	var base: float = p.z if v.along_z else p.x
	for _attempt in range(6):
		v.t = base + _rng.randf_range(-1.0, 1.0) * SPAWN_ALONG
		_apply(v)
		if _flat_dist(v) >= SPAWN_MIN_DIST:
			break
	v.visible = true
	if v.node != null:
		v.node.visible = true


func _roll_speed(v: Dictionary) -> float:
	## Kids skip, elders amble, street characters plod at their trade
	## (issue #222); phone walkers amble (heads down, no urgency);
	## everyone else strolls.
	match String(v.get("street", "")):
		"sabzi":
			return _rng.randf_range(CART_SPEED_MIN, CART_SPEED_MAX)
		"chowkidar", "ragpicker":
			return _rng.randf_range(FOLK_SPEED_MIN, FOLK_SPEED_MAX)
	match String(v.get("age", "adult")):
		"kid":
			return _rng.randf_range(KID_SPEED_MIN, KID_SPEED_MAX)
		"elder":
			return _rng.randf_range(ELDER_SPEED_MIN, ELDER_SPEED_MAX)
	return _rng.randf_range(PHONE_MIN, PHONE_MAX) if v.phone \
			else _rng.randf_range(WALK_MIN, WALK_MAX)


func _place_hawker(v: Dictionary) -> void:
	## Pin a hawker behind their stall counter, facing the market lane
	## (issue #207). Grounded like every other walker; never recycled —
	## they hold the spot until the bazaar thins for the night.
	var spot: Dictionary = v.hawker
	v.pos = Vector3(spot["pos"].x + spot["face"] * HAWKER_STAND, 0.0,
			spot["pos"].z + _rng.randf_range(-1.1, 1.1))
	_face(v, Vector3(spot["face"], 0.0, 0.0))
	v.pause = 0.0
	v.panic = 0.0
	v.rejoin = 0.0
	v.visible = true
	if v.node != null:
		v.node.visible = true


func _zone_awake() -> bool:
	## The crowd squads are only simulated while the player can plausibly
	## see one of the registered districts.
	if _zones.is_empty():
		return false
	var p: Vector3 = _player.global_position
	for zone in _zones:
		var c: Vector3 = zone["c"]
		if Vector2(p.x - c.x, p.z - c.z).length() <= ZONE_WAKE:
			return true
	return false


func _place_zone(v: Dictionary) -> void:
	## (Re)spawn a crowd shopper on a sidewalk line near one of the crowd
	## zones, biased toward whichever side the player is watching from.
	if not v.hawker.is_empty():
		_place_hawker(v)
		return
	var zone: Dictionary = _zones[_rng.randi_range(0, _zones.size() - 1)]
	var zc: Vector3 = zone["c"]
	var zr: float = zone["r"]
	v.along_z = _rng.randf() < 0.5
	var along_center: float = zc.z if v.along_z else zc.x
	v.road = _nearest_line(zc.x if v.along_z else zc.z) \
			+ (1.0 if _rng.randf() < 0.5 else -1.0) * _offset()
	v.dir = 1 if _rng.randf() < 0.5 else -1
	v.speed = _roll_speed(v)
	v.panic = 0.0
	v.rejoin = 0.0
	v.cd = _rng.randf_range(0.5, 2.5)
	var p: Vector3 = _player.global_position
	var p_along: float = p.z if v.along_z else p.x
	for _attempt in range(6):
		v.t = clampf(p_along + _rng.randf_range(-1.0, 1.0) * ZONE_BIAS,
				along_center - zr, along_center + zr)
		_apply(v)
		if _flat_dist(v) >= ZONE_SPAWN_MIN:
			break
	v.visible = true
	if v.node != null:
		v.node.visible = true


func _nearest_sidewalk(pos: Vector3) -> Dictionary:
	## Closest sidewalk line of either axis: {"line", "along_z", "dist"}.
	var best := {"line": 0.0, "along_z": true, "dist": INF}
	for axis in [true, false]:
		var fixed: float = pos.x if axis else pos.z
		var base_line := _nearest_line(fixed)
		for side in [1.0, -1.0]:
			var cand: float = base_line + side * _offset()
			var d := absf(fixed - cand)
			if d < best["dist"]:
				best = {"line": cand, "along_z": axis, "dist": d}
	return best


func _offset() -> float:
	return _road_w / 2.0 + EDGE


func _line_at(i: int) -> float:
	return -_world / 2.0 + i * _pitch - (_pitch - _road_w) / 2.0


func _nearest_line(coord: float) -> float:
	var i := clampi(roundi((coord + _world / 2.0 + (_pitch - _road_w) / 2.0) / _pitch), 0, _roads - 1)
	return _line_at(i)


func _flat_dist(v: Dictionary) -> float:
	var p: Vector3 = _player.global_position
	var np: Vector3 = v.pos
	return Vector2(np.x - p.x, np.z - p.z).length()


func _ground_y(x: float, z: float) -> float:
	## Analytic ground height under a point (mirrors roads.gd build()):
	## asphalt strips at ROAD_Y, sidewalk bands at CURB_H, block interiors
	## at 0. Walkers are kinematic, so they read the street shape instead
	## of raycasting every frame (issue #75: no more floating/sunk peds).
	var dx := absf(x - _nearest_line(x))
	var dz := absf(z - _nearest_line(z))
	var hw := _road_w / 2.0
	if dx <= hw or dz <= hw:
		return ROAD_Y
	if dx <= hw + WALK_W or dz <= hw + WALK_W:
		return WALK_H
	return 0.0

func _face(v: Dictionary, dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		v.heading = atan2(-dir.x, -dir.z)


func _animate(v: Dictionary) -> void:
	## Place one walker in the world and keep its clip honest: stroll on
	## the sidewalk, run while panicking.
	var node: Node3D = v.node
	if node == null:
		return
	var grounded := Vector3(v.pos.x, _ground_y(v.pos.x, v.pos.z), v.pos.z)
	node.global_transform = Transform3D(Basis(Vector3.UP, v.heading), grounded)
	if v.panic > 0.0 or v.rejoin > 0.0:
		_chars.play(v.anims, v.ap, "run", 1.1)
	elif not v.hawker.is_empty():
		_chars.play(v.anims, v.ap, "idle", 0.85)
	elif v.pause > 0.0:
		_chars.play(v.anims, v.ap, "idle", 0.8)
	else:
		var rate: float = float(v.speed) / WALK_CLIP_SPEED
		if String(v.get("age", "adult")) == "kid":
			rate *= KID_CADENCE  # quicker cadence, faster arm swing
		_chars.play(v.anims, v.ap, "walk", rate)


func _hide_ped(v: Dictionary) -> void:
	## Park the walker out of sight until its zone wakes again.
	_clear_pause(v)
	if v.node != null:
		v.node.visible = false
	if v.ap != null:
		v.ap.stop()


# ---------------------------------------------------------------- visuals


func _new_ped(zone: bool) -> Dictionary:
	return {
		"pos": Vector3.ZERO, "heading": 0.0, "visible": false, "parts": [],
		"along_z": true, "road": 0.0, "t": 0.0, "dir": 1,
		"speed": 3.0, "panic": 0.0, "panic_dir": Vector3.ZERO,
		"rejoin": 0.0, "cd": 0.0, "phase": _rng.randf() * TAU,
		"zone": zone, "node": null, "ap": null, "anims": {}, "id": {},
		"phone": false, "pause": 0.0, "pkind": "", "pcd": 0.0, "hawker": {},
		"age": "adult", "street": "",
		"pair": -1, "lead": true, "side": 1.0, "bseat": null,
		"barrived": false, "bgo": Vector3.ZERO,
	}


func _dress(v: Dictionary, idx := -1) -> void:
	## One rigged walker with its own identity seed (issue #120): body,
	## hair, headwear and outfit all roll from one number, so a walker
	## keeps its look across recycles while no two dress alike. A reroll
	## keeps the same body from spawning twice in a row (acceptance:
	## crowd visibly varied).
	var pick := _rng.randi_range(0, MODELS.size() - 1)
	if pick == _last_model and MODELS.size() > 1:
		pick = (pick + 1 + _rng.randi_range(0, MODELS.size() - 2)) % MODELS.size()
	_last_model = pick
	var path: String = MODELS[pick]
	# The wardrobe branch (issue #134) rolls per body type: the women's
	# rigs take saree / kameez, the universal male takes kurta / lungi /
	# porter duty — so the crowd reads Indian street dress.
	var female := pick < MODELS.size() - 1
	var id: Dictionary = Chars.identity(_rng.randi(), female)
	v["id"] = id
	# Age + street-character roll (issue #222). Fixed indices guarantee
	# the acceptance silhouettes exist every session: pair followers 4
	# and COUNT+20 walk as kids beside adults, 7/COUNT+12 push thela
	# carts, 17 patrols with a lathi, 22 carries the picking sack.
	var age := "adult"
	var street := ""
	if idx == 4 or idx == COUNT + 20:
		age = "kid"
	elif idx == 7 or idx == COUNT + 12:
		street = "sabzi"
	elif idx == 17:
		street = "chowkidar"
	elif idx == 22:
		street = "ragpicker"
	else:
		var ar := _rng.randf()
		if ar < KID_SHARE:
			age = "kid"
		elif ar < KID_SHARE + ELDER_SHARE:
			age = "elder"
	v["age"] = age
	v["street"] = street
	match age:
		"kid":
			id["height"] = float(id["height"]) * KID_SCALE
		"elder":
			id["height"] = float(id["height"]) * 0.955
			id["hair"] = (id["hair"] as Color).lerp(Chars.HAIR_GREY, 0.75)
	match street:
		"chowkidar":
			# Khaki watchman uniform (the guard wardrobe branch).
			id["role"] = 2
			id["shirt"] = Chars.GUARD_KHAKI
			id["pants"] = Chars.GUARD_KHAKI_DARK
			id["hat"] = Chars.GUARD_KHAKI_DARK
			id["headwear"] = 1
			id["outfit"] = 0
			id["print"] = 0
			id["border"] = 0
		"ragpicker":
			id["shirt"] = Color(0.45, 0.42, 0.36)
			id["pants"] = Color(0.30, 0.28, 0.25)
			id["print"] = 0
		"sabzi":
			# Plain kurta vendor — the cart carries the silhouette.
			id["outfit"] = 1
			id["print"] = 0
	var node := _chars.spawn(path, PED_HEIGHT * float(id["height"]))
	ShadowBlob.attach(node, 0.34 if age == "kid" else 0.48)
	_chars.dress(node, id)
	add_child(node)
	node.visible = false
	v.node = node
	v.ap = _chars.get_player(node)
	v.anims = _chars.anim_names(node)
	var body_h := PED_HEIGHT * float(id["height"])
	match street:
		"sabzi":
			Streetfolk.cart(node, body_h)
		"chowkidar":
			Streetfolk.lathi(node, body_h)
		"ragpicker":
			Streetfolk.sack(node, body_h)
	if age == "elder" and street == "":
		var rig_e: Node = _chars.lively(node)
		if rig_e != null:
			rig_e.stoop = _rng.randf_range(ELDER_STOOP_MIN, ELDER_STOOP_MAX)
		if _rng.randf() < ELDER_CANE_SHARE:
			Streetfolk.cane(node, body_h)
	# Street behavior roll (issue #207): this walker's head stays in a
	# phone — slower amble and the head-down LivelyRig phone pose. Kids
	# and street characters keep their heads up; the silhouette carries.
	v["phone"] = age == "adult" and street == "" and _rng.randf() < PHONE_SHARE
	if v["phone"]:
		var rig: Node = _chars.lively(node)
		if rig != null:
			rig.phone_override = true
