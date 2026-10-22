extends CanvasLayer
## Pause menu (Esc / gamepad Select / touch PAUSE button): freezes the
## world behind a dim and offers resume, save, settings and quit-to-title.
## Audio settings ride runtime buses (Master/Ambient/Radio) so gameplay
## volume logic is never touched; settings persist to user://settings.json.

const SETTINGS_PATH := "user://settings.json"
const DEFAULTS := {"master": 100.0, "ambient": 100.0, "radio": 100.0, "shadows": false}

var _game: Node
var _settings := {}
var _resume_btn: Button
var _settings_box: VBoxContainer


func setup(game: Node) -> void:
	_game = game
	_settings = DEFAULTS.duplicate()
	var stored := load_settings()
	for key in stored:
		_settings[key] = stored[key]


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _process(_delta: float) -> void:
	## ALWAYS-mode polling (not _input): the touch pad drives actions via
	## Input.action_press, which never reaches _input handlers.
	if not Input.is_action_just_pressed("pause"):
		return
	if _game == null or not _game._playing:
		return
	if visible:
		_resume()
	else:
		_open()


func _open() -> void:
	visible = true
	get_tree().paused = true
	_resume_btn.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _quit_to_title() -> void:
	## Back to character select via a clean scene reload — every gameplay
	## child is rebuilt from scratch, so no teardown bookkeeping is needed.
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible


func _menu_button(parent: Container, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 0)
	parent.add_child(b)
	return b


func _make_slider(label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(200, 24)
	slider.value = float(_settings.get(key, 100.0))
	row.add_child(slider)
	var value := Label.new()
	value.text = "%d%%" % int(slider.value)
	value.custom_minimum_size = Vector2(48, 0)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % int(v)
		_apply_setting(key, v))


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.10, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_resume_btn = _menu_button(box, "RESUME")
	_resume_btn.pressed.connect(_resume)
	var save_btn := _menu_button(box, "SAVE GAME")
	save_btn.pressed.connect(Callable(_game, "_save_game"))
	var settings_btn := _menu_button(box, "SETTINGS")
	settings_btn.pressed.connect(_toggle_settings)
	var quit_btn := _menu_button(box, "QUIT TO TITLE")
	quit_btn.pressed.connect(_quit_to_title)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	box.add_child(_settings_box)
	_make_slider("MASTER", "master")
	_make_slider("RADIO", "radio")
	_make_slider("CITY SOUNDS", "ambient")
	var shadow_row := HBoxContainer.new()
	shadow_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(shadow_row)
	var cb := CheckBox.new()
	cb.text = "SUN SHADOWS (quality)"
	cb.button_pressed = bool(_settings.get("shadows", false))
	cb.toggled.connect(func(on: bool) -> void: _apply_setting("shadows", on))
	shadow_row.add_child(cb)


func _apply_setting(key: String, value) -> void:
	_settings[key] = value
	write_settings(_settings)
	apply_audio(_settings)
	if key == "shadows" and _game != null and _game.sun != null:
		_game.sun.shadow_enabled = bool(value)


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func write_settings(s: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(s, "\t"))
	f.close()


static func apply_audio(s: Dictionary) -> void:
	_set_bus_volume("Master", float(s.get("master", 100.0)))
	_set_bus_volume("Ambient", float(s.get("ambient", 100.0)))
	_set_bus_volume("Radio", float(s.get("radio", 100.0)))


static func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var linear := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, -60.0 if linear <= 0.001 else linear_to_db(linear))
