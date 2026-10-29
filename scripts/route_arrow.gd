extends Control
## Routing chevron (issue #189): while a mission objective or a custom
## map waypoint is active, a small arrow rides the screen edge pointing
## the way, with the remaining metres under it. The mission objective
## wins over a waypoint; the arrow hides once the target is close. The
## bearing is relative to the player heading — the same convention the
## minimap uses — so it stays truthful on foot, driving and on the metro.

const EDGE := 56.0
const HIDE_DIST := 14.0
const MISSION_COLOR := Color(0.35, 1.0, 0.5)
const WAYPOINT_COLOR := Color(1.0, 0.78, 0.2)
const OUTLINE := Color(0.05, 0.05, 0.08, 0.85)

var _dir := Vector2.UP
var _dist := 0.0
var _mission := false
var _active := false
var _t := 0.0


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	queue_redraw()


func aim(pos: Vector3, heading: float, target: Vector3, mission: bool) -> void:
	## Called by Main every frame with the live focus (player, auto or
	## metro). A non-finite target simply hides the chevron.
	if not target.is_finite():
		_active = false
		visible = false
		return
	var v := Vector2(target.x - pos.x, target.z - pos.z)
	_dist = v.length()
	if _dist < HIDE_DIST:
		_active = false
		visible = false
		return
	_dir = (v / _dist).rotated(heading)
	if not _active:
		_t = 0.0
	_active = true
	_mission = mission
	visible = true
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	# March the chevron out from the centre until it kisses the edge
	# margin — the tip hugs the border whatever the direction.
	var tx := 1.0e9
	var ty := 1.0e9
	if absf(_dir.x) > 0.0001:
		tx = (size.x / 2.0 - EDGE) / absf(_dir.x)
	if absf(_dir.y) > 0.0001:
		ty = (size.y / 2.0 - EDGE) / absf(_dir.y)
	var p := center + _dir * minf(tx, ty)
	var col := MISSION_COLOR if _mission else WAYPOINT_COLOR
	var a := 0.75 + 0.25 * sin(_t * 4.0)
	var perp := Vector2(-_dir.y, _dir.x)
	var tip := p + _dir * 13.0
	var b1 := p - _dir * 5.0 + perp * 9.0
	var b2 := p - _dir * 5.0 - perp * 9.0
	var tri := PackedVector2Array([tip, b1, b2])
	draw_colored_polygon(tri, Color(col.r, col.g, col.b, a))
	draw_polyline(PackedVector2Array([tip, b1, b2, tip]), OUTLINE, 1.5, true)
	var label := "%d m" % int(round(_dist))
	var lp := p - _dir * 24.0
	draw_string(ThemeDB.fallback_font, lp + Vector2(1.0, 1.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, 13, OUTLINE)
	draw_string(ThemeDB.fallback_font, lp, label,
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, 13,
			Color(col.r, col.g, col.b, minf(a + 0.15, 1.0)))
