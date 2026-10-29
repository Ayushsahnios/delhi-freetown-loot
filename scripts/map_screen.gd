extends Control
## Full-screen city map (issue #189): M on keyboard, LB on gamepad or the
## MAP touch button swings out a stylized north-up view of the whole
## grid — roads, landmark icons with names, the player, the active
## mission objective and a custom waypoint pin. Click or tap anywhere on
## the map to drop a waypoint; tap the pin itself to clear it. The world
## freezes behind the map exactly like the pause menu, so the city can
## be studied mid-chase without anything moving underneath.

signal waypoint_chosen(world_pos: Vector3)
signal waypoint_cleared

const MARGIN := 24.0
const TITLE_BAND := 44.0
const LEGEND_BAND := 34.0
const PAPER := Color(0.15, 0.13, 0.10, 0.97)
const BLOCK_FILL := Color(0.23, 0.20, 0.15)
const ROAD_COLOR := Color(0.63, 0.58, 0.46)
const BORDER := Color(0.88, 0.82, 0.62, 0.9)
const INK := Color(0.93, 0.89, 0.76)
const DIM := Color(0.05, 0.04, 0.11, 0.72)
const PLAYER_FILL := Color(1.0, 1.0, 1.0)
const PLAYER_EDGE := Color(0.05, 0.05, 0.08)
const MISSION_COLOR := Color(0.35, 1.0, 0.5)
const WAYPOINT_COLOR := Color(1.0, 0.78, 0.2)
const LM_COLORS: Array[Color] = [
	Color(0.2, 0.85, 0.45), Color(1.0, 0.62, 0.2),
	Color(0.95, 0.35, 0.3), Color(0.55, 0.85, 1.0),
]

var _world := 0.0
var _pitch := 0.0
var _road_w := 0.0
var _roads := 0
var _landmarks: Array = []
var _pos := Vector3.ZERO
var _heading := 0.0
var _target := Vector3.INF
var _waypoint := Vector3.INF
var _t := 0.0
var _origin := Vector2.ZERO
var _side := 0.0
var _scale := 1.0


func setup(world_size: float, pitch: float, road_width: float,
		road_count: int, landmarks: Array) -> void:
	_world = world_size
	_pitch = pitch
	_road_w = road_width
	_roads = road_count
	_landmarks = landmarks
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("map_screen")
	visible = false


func open(pos: Vector3, heading: float, target: Vector3,
		waypoint: Vector3) -> void:
	## Snapshot of the frozen moment: the tree pauses, so nothing moves
	## under the map until it closes.
	_pos = pos
	_heading = heading
	_target = target
	_waypoint = waypoint
	_t = 0.0
	visible = true
	get_tree().paused = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Closing polls the action (not _input) so the touch pad's synthetic
	# presses work too; pause.gd yields Esc to the map while it is open.
	if Input.is_action_just_pressed("map") \
			or Input.is_action_just_pressed("pause"):
		close()
		return
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_handle_tap(event.position)


func _handle_tap(local: Vector2) -> void:
	## Map click -> world position. A tap on the existing pin clears the
	## waypoint; any other tap inside the city moves it there.
	if local.x < _origin.x or local.y < _origin.y \
			or local.x > _origin.x + _side or local.y > _origin.y + _side:
		return
	if _waypoint.is_finite() and local.distance_to(_to_map(_waypoint)) <= 22.0:
		_waypoint = Vector3.INF
		waypoint_cleared.emit()
		queue_redraw()
		return
	var wx := (local.x - _origin.x) / _scale - _world / 2.0
	var wz := (local.y - _origin.y) / _scale - _world / 2.0
	_waypoint = Vector3(wx, 0.0, wz)
	waypoint_chosen.emit(_waypoint)
	queue_redraw()


func _to_map(world_pos: Vector3) -> Vector2:
	return _origin + Vector2(world_pos.x + _world / 2.0,
			world_pos.z + _world / 2.0) * _scale


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	_side = minf(size.x, size.y) - 2.0 * MARGIN - TITLE_BAND - LEGEND_BAND
	_origin = Vector2((size.x - _side) / 2.0, TITLE_BAND + MARGIN * 0.5)
	_scale = _side / _world
	var city := Rect2(_origin, Vector2(_side, _side))
	draw_rect(city, PAPER)
	draw_rect(city.grow(-_road_w * _scale * 0.5), BLOCK_FILL)
	# The same grid constants the city builder uses: one road line every
	# pitch, edge to edge, drawn crisp whatever the window scale.
	var w := maxf(_road_w * _scale, 2.5)
	for i in range(_roads):
		var line := -_world / 2.0 + i * _pitch - (_pitch - _road_w) / 2.0
		var px: float = _origin.x + (line + _world / 2.0) * _scale
		draw_line(Vector2(px, _origin.y), Vector2(px, _origin.y + _side),
				ROAD_COLOR, w, true)
		var py: float = _origin.y + (line + _world / 2.0) * _scale
		draw_line(Vector2(_origin.x, py), Vector2(_origin.x + _side, py),
				ROAD_COLOR, w, true)
	draw_rect(city, BORDER, false, 2.0)
	# Compass and scale bar keep the map honest at a glance.
	draw_string(ThemeDB.fallback_font,
			Vector2(_origin.x + _side - 34.0, _origin.y + 20.0), "N",
			HORIZONTAL_ALIGNMENT_CENTER, -1.0, 15, INK)
	draw_line(Vector2(_origin.x + 10.0, _origin.y + _side - 12.0),
			Vector2(_origin.x + 10.0 + 100.0 * _scale,
					_origin.y + _side - 12.0), INK, 2.0, true)
	draw_string(ThemeDB.fallback_font,
			Vector2(_origin.x + 10.0, _origin.y + _side - 18.0), "100 m",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, INK)
	for i in range(_landmarks.size()):
		var lm: Dictionary = _landmarks[i]
		var pt := _to_map(lm["center"])
		var col: Color = LM_COLORS[i % LM_COLORS.size()]
		draw_circle(pt, 7.0, col)
		draw_arc(pt, 8.5, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.6), 1.5, true)
		draw_string(ThemeDB.fallback_font, pt + Vector2(-2.5, 3.5),
				_initials(String(lm["name"])), HORIZONTAL_ALIGNMENT_CENTER,
				-1.0, 10, Color(0.05, 0.05, 0.08))
		draw_string(ThemeDB.fallback_font, pt + Vector2(-40.0, 20.0),
				String(lm["name"]), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11, INK)
	if _target.is_finite():
		var t := _to_map(_target)
		var pulse := 6.5 + sin(_t * 5.0) * 2.0
		draw_circle(t, pulse, MISSION_COLOR)
		draw_arc(t, pulse + 1.5, 0.0, TAU, 16, Color(0.0, 0.0, 0.0, 0.6),
				1.5, true)
		draw_string(ThemeDB.fallback_font, t + Vector2(-40.0, 24.0),
				"MISSION", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11,
				MISSION_COLOR)
	if _waypoint.is_finite():
		var p := _to_map(_waypoint)
		var d := PackedVector2Array([p + Vector2(0.0, -8.0),
				p + Vector2(6.0, 0.0), p + Vector2(0.0, 8.0),
				p + Vector2(-6.0, 0.0)])
		draw_colored_polygon(d, WAYPOINT_COLOR)
		draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]),
				Color(0.0, 0.0, 0.0, 0.6), 1.5, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-40.0, 24.0),
				"WAYPOINT", HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11,
				WAYPOINT_COLOR)
	# Player triangle: north-up map, so the arrow turns with the heading.
	var pp := _to_map(_pos)
	var rot := -_heading
	var tip := pp + Vector2(0.0, -9.0).rotated(rot)
	var right := pp + Vector2(6.0, 7.0).rotated(rot)
	var left := pp + Vector2(-6.0, 7.0).rotated(rot)
	draw_colored_polygon(PackedVector2Array([tip, right, left]),
			PLAYER_FILL)
	draw_polyline(PackedVector2Array([tip, right, left, tip]), PLAYER_EDGE,
			1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 30.0),
			"DELHI — CITY MAP", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, INK)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y - 12.0),
			"Click — set waypoint · click pin — clear · M / Esc — close",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
			Color(0.9, 0.87, 0.75, 0.85))


func _initials(name: String) -> String:
	var out := ""
	for word in name.split(" "):
		if word.length() > 0:
			out += word[0]
	return out
