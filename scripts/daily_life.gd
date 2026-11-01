extends Node
## Daily life patterns (issue #185) — the city breathes on the same dusk
## curve that already drives windows, lamps and headlights. One tick per
## frame from main._update_day fans out three rhythms:
##   - Shop shutters roll down after dusk and back up at dawn (a thin
##     corrugated slat parked under the lintel by day, the full panel at
##     night), so street fronts visibly close for the night.
##   - The street crowd thins toward night and refills through the morning
##     chai rush (pedestrians.gd owns the actual hide/show).
##   - Chai stalls glow as night markets and steam harder through the rush
##     (food.gd owns the bulbs and the kettle).
## All state is public so the headless gate (daily_life_check.gd) can read
## the same numbers the visuals follow.

const SHUTTER_HALF_H := 1.125  ## half of the 2.25 m shutter panel
const ROLL_SY := 0.12          ## squashed roll height at full dawn-open
const NIGHT_CROWD_KEEP := 0.40 ## share of the day crowd still out at night
const RUSH_START_H := 7.0      ## chai rush window, clock hours (sun-aligned)
const RUSH_END_H := 10.0

## 0 = shops open (slat up), 1 = shutters down for the night.
var roll := 0.0
var night := 0.0
var rush := 0.0
var hours := 0.0

var _mm: MultiMesh = null
var _xfs: Array[Transform3D] = []
var _applied := -1.0
var _live_sy := -1.0   ## last sy written to the buffer (-1 = never)
var _live_dy := 0.0    ## last dy written to the buffer
var _peds: Node = null
var _food: Node = null
var _traffic: Node = null


func setup_shutters(mmi: MultiMeshInstance3D, xfs: Array[Transform3D]) -> void:
	## Owns the animated shutter MultiMesh: closed-panel transforms come in
	## pre-baked, the day state is squashed up under each lintel. A roomy
	## custom AABB keeps the moving instances from being frustum-culled
	## against a stale tight bound.
	if mmi == null or xfs.is_empty():
		return
	_mm = mmi.multimesh
	_xfs = xfs
	var aabb := AABB(_xfs[0].origin, Vector3.ONE * 4.0)
	for xf in _xfs:
		aabb = aabb.expand(xf.origin - Vector3.ONE * 2.0)
		aabb = aabb.expand(xf.origin + Vector3(2.0, SHUTTER_HALF_H * 2.0 + 2.0, 2.0))
	mmi.custom_aabb = aabb


func register_life(peds: Node, food: Node) -> void:
	_peds = peds
	_food = food


func register_traffic(t: Node) -> void:
	## Traffic rhythm (issue #268): the fleet breathes on this clock —
	## rush roll-ins, the midday lull and the late-night quiet band.
	_traffic = t


func tick(day_t: float, daylight: float) -> void:
	## Called once per frame from main._update_day — the clock is sun-aligned
	## (day_t 0.5 reads 12:00), so the rush window sits right after dawn.
	hours = fmod(day_t * 24.0, 24.0)
	night = 1.0 - clampf(daylight * 1.4, 0.0, 1.0)
	rush = 1.0 if hours >= RUSH_START_H and hours < RUSH_END_H else 0.0
	roll = night
	_apply_roll()
	var keep := NIGHT_CROWD_KEEP \
			+ (1.0 - NIGHT_CROWD_KEEP) * (1.0 - night)
	if _peds != null:
		_peds.set_life_pattern(night, rush, keep)
	if _food != null:
		_food.set_night_rush(night, rush)
	if _traffic != null:
		_traffic.set_hours(hours)


func _apply_roll() -> void:
	## Squash-and-lift every animated shutter between its rolled-up day
	## slat and the closed night panel. Only touches the MultiMesh while
	## the roll actually moves, so noon and midnight cost nothing.
	if _mm == null:
		return
	if _applied >= 0.0 and absf(roll - _applied) < 0.01:
		return
	var t := roll
	if t < 0.004:
		t = 0.0
	elif t > 0.996:
		t = 1.0
	var sy := lerpf(ROLL_SY, 1.0, t)
	## Top edge stays pinned at the lintel: as the panel grows downward
	## its centre drops by exactly the half-height it gained.
	var dy := SHUTTER_HALF_H * (1.0 - sy)
	for i in _xfs.size():
		var xf := _xfs[i]
		var b := xf.basis.scaled(Vector3(1.0, sy, 1.0))
		_mm.set_instance_transform(i, Transform3D(b,
				xf.origin + Vector3(0.0, dy, 0.0)))
	_applied = roll
	_live_sy = sy
	_live_dy = dy


func shutter_probe(_i: int = 0) -> Dictionary:
	## Read-back for the headless gate. Godot 4.7 headless cannot read a
	## MultiMesh instance buffer back (get_instance_transform returns
	## identity), so this reports the last state _apply_roll actually
	## pushed into the buffer plus whether the write pass ever ran.
	return {"sy": _live_sy, "dy": _live_dy,
			"wired": _mm != null and not _xfs.is_empty(),
			"instances": _xfs.size() if _mm != null else 0}
