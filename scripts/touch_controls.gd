extends CanvasLayer
## On-screen touch controls for phones/tablets (and the web build on a
## phone): a virtual joystick on the left feeds the shared move_* actions
## with analog strength, a button cluster on the right presses the same
## actions a keyboard would. Everything is drawn with engine shapes — no
## textures. The layer is only shown when the device reports a touchscreen.

const STICK_R := 92.0
const KNOB_R := 42.0
const DEADZONE := 0.08
const TINT := Color(1.0, 1.0, 1.0, 0.16)
const TINT_HELD := Color(1.0, 1.0, 1.0, 0.34)

## Photo mode entry toggle, bound by main (issue #100 part 2). Held as a
## Callable because photo mode listens for events in _unhandled_input,
## which synthetic action presses from _make_button do not reach.
var _photo_toggle := Callable()


func _ready() -> void:
	layer = 15
	visible = false
	_build()


## Main enables the layer once gameplay starts; on desktops without a
## touchscreen it stays hidden whatever the game state.
func set_active(on: bool) -> void:
	if not on:
		_on_stick(Vector2.ZERO)
	visible = on and DisplayServer.is_touchscreen_available()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var pad := StickPad.new()
	pad.moved.connect(_on_stick)
	root.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 28.0
	pad.offset_top = -STICK_R * 2.0 - 28.0
	pad.offset_right = STICK_R * 2.0 + 28.0
	pad.offset_bottom = -28.0

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rows.offset_left = -348.0
	rows.offset_top = -212.0
	rows.offset_right = -24.0
	rows.offset_bottom = -24.0
	rows.alignment = BoxContainer.ALIGNMENT_END
	rows.add_theme_constant_override("separation", 12)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rows)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(top)
	top.add_child(_make_button("RADIO", ["radio"], 72.0))
	top.add_child(_make_button("HORN", ["horn"], 72.0))
	top.add_child(_make_button("PAUSE", ["pause"], 72.0))
	var photo_btn := _make_button("PHOTO", [], 72.0)
	photo_btn.pressed.connect(_on_photo_pressed)
	top.add_child(photo_btn)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(bottom)
	bottom.add_child(_make_button("SWAP", ["switch_character"], 72.0))
	# ACT doubles as the dialogue/choice confirm: it presses the shared
	# interact action plus ui_accept, which the dialogue UI listens to.
	bottom.add_child(_make_button("ACT", ["interact", "ui_accept"], 96.0))
	bottom.add_child(_make_button("RUN", ["run"], 96.0))


func _make_button(label: String, actions: Array, diameter: float) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, _style(TINT, diameter))
	b.add_theme_stylebox_override("pressed", _style(TINT_HELD, diameter))
	b.button_down.connect(_press.bind(actions))
	b.button_up.connect(_release.bind(actions))
	return b


func _style(fill: Color, diameter: float) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.set_corner_radius_all(int(diameter / 2.0))
	st.border_color = Color(1.0, 1.0, 1.0, 0.45)
	st.set_border_width_all(2)
	return st


func _press(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)


func _release(actions: Array) -> void:
	for a in actions:
		Input.action_release(a)


func bind_photo(toggle: Callable) -> void:
	_photo_toggle = toggle


func _on_photo_pressed() -> void:
	## One-shot toggle, not a held action: fire the bound callable directly.
	if _photo_toggle.is_valid():
		_photo_toggle.call()


func _on_stick(v: Vector2) -> void:
	_apply_strength("move_forward", maxf(-v.y, 0.0))
	_apply_strength("move_back", maxf(v.y, 0.0))
	_apply_strength("move_left", maxf(-v.x, 0.0))
	_apply_strength("move_right", maxf(v.x, 0.0))


func _apply_strength(action: String, s: float) -> void:
	if s > DEADZONE:
		Input.action_press(action, clampf(s, 0.0, 1.0))
	else:
		Input.action_release(action)


class StickPad:
	extends Control
	## Virtual joystick: track one finger inside the pad, report the knob
	## offset as a -1..1 vector, redraw as it moves.

	signal moved(vec: Vector2)

	var _touch := -1
	var _knob := Vector2.ZERO
	var _radius := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		_radius = minf(size.x, size.y) * 0.5 - 8.0

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _touch == -1:
				_touch = ev.index
				_track(ev.position)
			elif not ev.pressed and ev.index == _touch:
				_touch = -1
				_knob = Vector2.ZERO
				queue_redraw()
				moved.emit(Vector2.ZERO)
		elif ev is InputEventScreenDrag and ev.index == _touch:
			_track(ev.position)

	func _track(p: Vector2) -> void:
		_knob = p - size * 0.5
		if _knob.length() > _radius:
			_knob = _knob.normalized() * _radius
		queue_redraw()
		moved.emit(_knob / _radius if _radius > 0.0 else Vector2.ZERO)

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, _radius, Color(1.0, 1.0, 1.0, 0.05))
		draw_arc(c, _radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0, true)
		var k := _radius * 0.44
		draw_circle(c + _knob, k, Color(0.98, 0.83, 0.4, 0.5))
		draw_arc(c + _knob, k, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55), 2.0, true)
