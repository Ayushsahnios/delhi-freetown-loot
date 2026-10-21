extends Control
## Live top-down minimap (bottom-right): rotating heading-up view of the road
## grid, landmark dots, active-mission blip and police blips while wanted.
## Drawn in 2D from the same grid constants the city uses — no second 3D
## camera pass, so web and mobile builds keep their frame budget.

const SIZE := 168.0
const MARGIN := 16.0
const VIEW_RADIUS := 80.0  # world metres from the player to the map edge
const BG := Color(0.08, 0.10, 0.09, 0.9)
const ROAD_COLOR := Color(0.32, 0.34, 0.37)
const RING := Color(0.95, 0.95, 0.9)
const RING_WANTED := Color(0.95, 0.25, 0.2)
const PLAYER_FILL := Color(1.0, 1.0, 1.0)
const PLAYER_EDGE := Color(0.05, 0.05, 0.08)
const MISSION_COLOR := Color(0.35, 1.0, 0.5)
const LM_COLORS: Array[Color] = [
	Color(0.2, 0.85, 0.45), Color(1.0, 0.62, 0.2),
	Color(0.95, 0.35, 0.3), Color(0.55, 0.85, 1.0),
]

var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _landmarks: Array = []
var _center := Vector2.ZERO
var _scale := 1.0
var _pos := Vector3.ZERO
var _heading := 0.0
var _target := Vector3.INF
var _police_pts: Array[Vector3] = []
var _wanted := 0
var _t := 0.0


func setup(world_size: float, pitch: float, road_width: float, road_count: int,
		landmarks: Array) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_landmarks = landmarks
	_scale = (SIZE / 2.0 - 4.0) / VIEW_RADIUS
	_center = Vector2(SIZE / 2.0, SIZE / 2.0)
	size = Vector2(SIZE, SIZE)
	position = Vector2(1280.0 - MARGIN - SIZE, 720.0 - MARGIN - SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func track(p: Vector3, heading: float) -> void:
	## Called by Main every frame with the on-foot player or the driven auto.
	_pos = p
	_heading = heading


func set_mission_target(p: Vector3) -> void:
	_target = p


func set_police(pts: Array[Vector3]) -> void:
	_police_pts = pts


func set_wanted(stars: int) -> void:
	_wanted = stars


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, SIZE / 2.0, BG)
	for i in range(_roads):
		var line := -_world / 2.0 + i * _pitch - (_pitch - _road_w) / 2.0
		var z_off := line - _pos.z
		if absf(z_off) <= VIEW_RADIUS + _road_w:
			_seg(Vector2(-_world / 2.0 - _pos.x, z_off),
					Vector2(_world / 2.0 - _pos.x, z_off))
		var x_off := line - _pos.x
		if absf(x_off) <= VIEW_RADIUS + _road_w:
			_seg(Vector2(x_off, -_world / 2.0 - _pos.z),
					Vector2(x_off, _world / 2.0 - _pos.z))
	for i in range(_landmarks.size()):
		var lm: Dictionary = _landmarks[i]
		_blip(lm["center"], LM_COLORS[i % LM_COLORS.size()], 4.0, true,
				_initials(String(lm["name"])))
	if _target.is_finite():
		_blip(_target, MISSION_COLOR, 4.0 + sin(_t * 5.0) * 1.5, true)
	if _wanted > 0:
		var flash := Color(1.0, 0.25, 0.2) if int(_t * 5.0) % 2 == 0 \
				else Color(0.25, 0.45, 1.0)
		for pt in _police_pts:
			_blip(pt, flash, 3.0, true)
	var north := _center + Vector2(0.0, -1.0).rotated(_heading) \
			* (SIZE / 2.0 - 12.0)
	draw_string(ThemeDB.fallback_font, north + Vector2(-3.0, 4.0), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 1.0, 1.0, 0.8))
	var tip := _center + Vector2(0.0, -8.0)
	var right := _center + Vector2(6.0, 6.0)
	var left := _center + Vector2(-6.0, 6.0)
	draw_colored_polygon(PackedVector2Array([tip, right, left]), PLAYER_FILL)
	draw_polyline(PackedVector2Array([tip, right, left, tip]), PLAYER_EDGE, 1.5,
			true)
	var ring := RING if _wanted <= 0 \
			else RING_WANTED.lerp(RING, 0.5 + 0.5 * sin(_t * 6.0))
	draw_arc(_center, SIZE / 2.0 - 2.0, 0.0, TAU, 64, ring, 2.0, true)


func _seg(a_world: Vector2, b_world: Vector2) -> void:
	## Road segment in world-offset metres, clipped to the circular map.
	var a: Vector2 = _center + a_world.rotated(_heading) * _scale
	var b: Vector2 = _center + b_world.rotated(_heading) * _scale
	var r := SIZE / 2.0 - 3.0
	var d := b - a
	var f := a - _center
	var dd := d.dot(d)
	if dd < 0.001:
		return
	var disc := f.dot(d) * f.dot(d) - dd * (f.dot(f) - r * r)
	if disc < 0.0:
		return
	var sq := sqrt(disc)
	var t1 := (-f.dot(d) - sq) / dd
	var t2 := (-f.dot(d) + sq) / dd
	if t1 > 1.0 or t2 < 0.0:
		return
	draw_line(a + d * maxf(t1, 0.0), a + d * minf(t2, 1.0), ROAD_COLOR,
			maxf(_road_w * _scale, 3.0), true)


func _blip(world_pos: Vector3, color: Color, radius: float, clamp_edge: bool,
		letter := "") -> void:
	var m: Vector2 = Vector2(world_pos.x - _pos.x, world_pos.z - _pos.z) \
			.rotated(_heading) * _scale
	var lim := SIZE / 2.0 - 10.0
	var pinned := false
	if m.length() > lim:
		if not clamp_edge:
			return
		m = m.normalized() * lim
		pinned = true
	var pt := _center + m
	var col := Color(color.r, color.g, color.b, 0.75) if pinned else color
	draw_circle(pt, radius, col)
	draw_arc(pt, radius + 1.5, 0.0, TAU, 12, Color(0.0, 0.0, 0.0, 0.55), 1.5,
			true)
	if letter != "" and not pinned:
		draw_string(ThemeDB.fallback_font, pt + Vector2(radius + 3.0, 4.0),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9,
				Color(1.0, 1.0, 1.0, 0.9))


func _initials(name: String) -> String:
	var out := ""
	for word in name.split(" "):
		if word.length() > 0:
			out += word[0]
	return out
