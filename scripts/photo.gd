extends Node
## Photo mode (issue #100). P toggles a free camera: the world
## freezes, the HUD hides, and the camera orbits the player — drag to
## swing, wheel to zoom. F cycles warm/mono/vivid filters, ENTER shoots a
## PNG into user://photos, G opens the gallery of saved shots. The mode
## runs in PROCESS_MODE_ALWAYS so it keeps working while the tree is
## paused; the pause menu skips its own ESC toggle while this is active.
## All UI built in code; no assets. Part 2: a touch button strip makes the
## mode usable on touchscreens, and web builds download shots through the
## browser (data-URL click) right after saving or from gallery taps.

const FILTERS := ["OFF", "WARM", "MONO", "VIVID"]
const PIVOT_H := 1.7
const R_MIN := 3.0
const R_MAX := 42.0
const PITCH_MIN := -0.15
const PITCH_MAX := 1.35
const PHOTOS_DIR := "user://photos"

var _camera: Camera3D
var _player: CharacterBody3D
var _env: Environment
var _active := false
var _filter := 0
var _yaw := 0.6
var _pitch := 0.42
var _radius := 9.0
var _hidden: Array = []

var _layer: CanvasLayer
var _warm: ColorRect
var _hint: Label
var _toast: Label
var _toast_tween: Tween
var _gallery: Control
var _grid: GridContainer
var _strip: VBoxContainer


func setup(camera: Camera3D, player: CharacterBody3D, world_env: WorldEnvironment) -> void:
	_camera = camera
	_player = player
	if world_env != null:
		_env = world_env.environment
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func active() -> bool:
	return _active


func toggle() -> void:
	if _active:
		_deactivate()
	else:
		_activate()


# ---------------------------------------------------------------- on/off

func _activate() -> void:
	_active = true
	add_to_group("photo_mode")
	get_tree().paused = true
	_layer.visible = true
	_hide_hud()
	_snap_to_player()
	_apply_filter()
	_show_toast("PHOTO MODE · drag swing · wheel zoom · F filter · ENTER shoot · G gallery · P exit")
	_strip.visible = _strip_wanted()


func _deactivate() -> void:
	_active = false
	remove_from_group("photo_mode")
	if _gallery != null:
		_gallery.visible = false
	_strip.visible = false
	_layer.visible = false
	_restore_hud()
	_restore_env()
	get_tree().paused = false


func _hide_hud() -> void:
	_hidden = []
	_collect_layers(get_tree().root)
	for cv in _hidden:
		cv.visible = false


func _collect_layers(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			if child != _layer and child.visible:
				_hidden.append(child)
		_collect_layers(child)


func _restore_hud() -> void:
	for cv in _hidden:
		cv.visible = true
	_hidden = []


func _restore_env() -> void:
	if _env == null:
		return
	_env.adjustment_enabled = false
	_env.adjustment_brightness = 1.0
	_env.adjustment_contrast = 1.0
	_env.adjustment_saturation = 1.0


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if not _active:
		return
	var pivot: Vector3 = _player.global_position + Vector3(0, PIVOT_H, 0)
	var offset := Vector3(
		sin(_yaw) * cos(_pitch) * _radius,
		sin(_pitch) * _radius,
		cos(_yaw) * cos(_pitch) * _radius)
	_camera.global_position = _camera.global_position.lerp(pivot + offset, 10.0 * delta)
	_camera.look_at(pivot)


func _input(event: InputEvent) -> void:
	if not _active or _gallery.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_radius = maxf(_radius - 1.6, R_MIN)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_radius = minf(_radius + 1.6, R_MAX)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			_yaw -= mm.relative.x * 0.005
			_pitch = clampf(_pitch + mm.relative.y * 0.004, PITCH_MIN, PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		if event.is_action_pressed("photo"):
			toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("photo") or event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo_filter"):
		next_filter()
	elif event.is_action_pressed("photo_shutter"):
		shoot()
	elif event.is_action_pressed("photo_gallery"):
		toggle_gallery()


func _snap_to_player() -> void:
	var pivot: Vector3 = _player.global_position + Vector3(0, PIVOT_H, 0)
	_camera.global_position = pivot + Vector3(
		sin(_yaw) * cos(_pitch) * _radius,
		sin(_pitch) * _radius,
		cos(_yaw) * cos(_pitch) * _radius)
	_camera.look_at(pivot)


# ---------------------------------------------------------------- actions

func next_filter() -> void:
	_filter = (_filter + 1) % FILTERS.size()
	_apply_filter()
	_show_toast("FILTER · %s" % FILTERS[_filter])


func toggle_gallery() -> void:
	if _gallery.visible:
		_gallery.visible = false
	else:
		_fill_gallery()
		_gallery.visible = true
	_strip.visible = _strip_wanted()


func shoot() -> void:
	_hide_for_capture()
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_image()
	DirAccess.make_dir_recursive_absolute(PHOTOS_DIR)
	var path := "%s/photo_%04d.png" % [PHOTOS_DIR, _next_index()]
	var err: int = img.save_png(path)
	_show_capture_ui()
	if err != OK:
		_show_toast("SAVE FAILED (%d)" % err)
	else:
		_show_toast("SAVED · %s" % path.get_file())
		if OS.has_feature("web"):
			_download_web(path.get_file(), img.save_png_to_buffer())


func _hide_for_capture() -> void:
	_hint.visible = false
	_toast.visible = false
	_strip.visible = false


func _show_capture_ui() -> void:
	_hint.visible = true
	_strip.visible = _strip_wanted()


func _apply_filter() -> void:
	_warm.visible = _active and FILTERS[_filter] == "WARM"
	if _env == null:
		return
	_env.adjustment_enabled = _filter != 0
	match FILTERS[_filter]:
		"WARM":
			_env.adjustment_brightness = 1.05
			_env.adjustment_contrast = 1.02
			_env.adjustment_saturation = 1.08
		"MONO":
			_env.adjustment_brightness = 1.02
			_env.adjustment_contrast = 1.08
			_env.adjustment_saturation = 0.0
		"VIVID":
			_env.adjustment_brightness = 1.0
			_env.adjustment_contrast = 1.12
			_env.adjustment_saturation = 1.45
		_:
			_restore_env()


func _next_index() -> int:
	var best := 1
	for f in DirAccess.get_files_at(PHOTOS_DIR):
		var name := String(f)
		if name.begins_with("photo_") and name.ends_with(".png"):
			best = maxi(best, name.get_slice("_", 1).to_int() + 1)
	return best


# ---------------------------------------------------------------- gallery

func _fill_gallery() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var files := Array(DirAccess.get_files_at(PHOTOS_DIR))
	files.sort_custom(func(a, b): return String(a) > String(b))
	var shown := 0
	for f in files:
		var name := String(f)
		if not name.ends_with(".png"):
			continue
		var img: Image = Image.load_from_file("%s/%s" % [PHOTOS_DIR, name])
		if img == null:
			continue
		if OS.has_feature("web"):
			# Web build (issue #100 part 2): tapping a photo hands it to the
			# browser as a download.
			var pick := TextureButton.new()
			pick.texture_normal = ImageTexture.create_from_image(img)
			pick.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
			pick.custom_minimum_size = Vector2(240, 135)
			pick.pressed.connect(_download_web.bind(
				name, FileAccess.get_file_as_bytes("%s/%s" % [PHOTOS_DIR, name])))
			_grid.add_child(pick)
		else:
			var frame := TextureRect.new()
			frame.texture = ImageTexture.create_from_image(img)
			frame.custom_minimum_size = Vector2(240, 135)
			frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_grid.add_child(frame)
		shown += 1
		if shown >= 30:
			break
	if shown == 0:
		var empty := Label.new()
		empty.text = "No photos yet — ENTER shoots one"
		empty.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		empty.custom_minimum_size = Vector2(240, 135)
		_grid.add_child(empty)


# ---------------------------------------------------------------- ui

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_warm = ColorRect.new()
	_warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warm.color = Color(1.0, 0.86, 0.68, 0.22)
	_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warm.visible = false
	_layer.add_child(_warm)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.offset_top = 24.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "P exit · drag swing · wheel zoom · F filter · ENTER shoot · G gallery"
	_layer.add_child(_hint)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -64.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 19)
	_toast.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_layer.add_child(_toast)
	_strip = _build_touch_strip()
	_layer.add_child(_strip)
	_build_gallery()
	_layer.visible = false


func _build_gallery() -> void:
	_gallery = Control.new()
	_gallery.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gallery.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.05, 0.08, 0.92)
	_gallery.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	_gallery.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "GALLERY · newest first · G to close" + (" · tap a photo to save" if OS.has_feature("web") else "")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle_gallery)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)
	_gallery.visible = false
	_layer.add_child(_gallery)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- touch

func _strip_wanted() -> bool:
	return _active and not _gallery.visible and DisplayServer.is_touchscreen_available()


func _build_touch_strip() -> VBoxContainer:
	## Touch controls (issue #100 part 2): the regular touch HUD hides
	## while photo mode is active, so this strip carries the four actions
	## as tappable buttons. Rectangles instead of circles to read as a
	## separate overlay.
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 24.0
	box.offset_top = -262.0
	box.offset_right = 172.0
	box.offset_bottom = -24.0
	box.add_theme_constant_override("separation", 10)
	box.visible = false
	box.add_child(_strip_button("EXIT", Color(0.92, 0.32, 0.32, 0.42), toggle))
	box.add_child(_strip_button("FILTER", Color(0.30, 0.52, 0.95, 0.42), next_filter))
	box.add_child(_strip_button("SHOOT", Color(0.32, 0.82, 0.42, 0.42), shoot))
	box.add_child(_strip_button("GALLERY", Color(0.90, 0.72, 0.34, 0.42), toggle_gallery))
	return box


func _strip_button(label: String, fill: Color, handler: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(148, 46)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.set_corner_radius_all(10)
	st.border_color = Color(1.0, 1.0, 1.0, 0.4)
	st.set_border_width_all(2)
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, st)
	var held: StyleBoxFlat = st.duplicate()
	held.bg_color = Color(fill.r, fill.g, fill.b, 0.72)
	b.add_theme_stylebox_override("pressed", held)
	b.pressed.connect(handler)
	return b


# ---------------------------------------------------------------- web save

func _download_web(fname: String, png: PackedByteArray) -> void:
	## Browser download of a shot, web build only (issue #100 part 2):
	## hand the PNG bytes to the page as a data-URL anchor click. Desktop
	## and mobile builds save straight to user:// and never reach this.
	if not OS.has_feature("web") or png.is_empty():
		return
	var js := "(function(){var a=document.createElement('a');"
	js += "a.href='data:image/png;base64," + Marshalls.raw_to_base64(png) + "';"
	js += "a.download='" + fname + "';a.click();})"
	JavaScriptBridge.eval(js + "()", true)
