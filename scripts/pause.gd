extends CanvasLayer
## Pause menu (Esc / gamepad Select / touch PAUSE button): freezes the
## world behind a dim and offers resume, save, settings and quit-to-title.
## Audio settings ride runtime buses (Master/Ambient/Radio) so gameplay
## volume logic is never touched; settings persist to user://settings.json.

const SETTINGS_PATH := "user://settings.json"
const SETTINGS_TMP := "user://settings.json.tmp"
const QualityScript := preload("res://scripts/quality.gd")
const DEFAULTS := {"master": 100.0, "ambient": 100.0, "radio": 100.0,
	"shadows": true, "muted": false, "quality": "auto"}

var _game: Node
var _visible_last_frame := false
var _settings := {}
var _resume_btn: Button
var _settings_box: VBoxContainer
var _quality_btn: Button


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
	var was_visible := _visible_last_frame
	_visible_last_frame = visible
	if not Input.is_action_just_pressed("pause"):
		return
	if _game == null or not _game._playing:
		return
	# Photo mode owns ESC while it is active (issue #100).
	if get_tree().get_first_node_in_group("photo_mode") != null:
		return
	# The city map owns ESC while it is open (issue #189); it closes
	# itself on the same press.
	var city_map := get_tree().get_first_node_in_group("map_screen")
	if city_map != null and city_map.visible:
		return
	# Credits and stats overlays (issue #211) own ESC the same way.
	if get_tree().get_first_node_in_group("overlay_screen") != null:
		return
	# An overlay closing on this same press may have re-shown this menu
	# within the frame (issue #211); that press must not also resume.
	if visible and not was_visible:
		return
	if visible:
		_resume()
	else:
		_open()


func _open() -> void:
	visible = true
	get_tree().paused = true
	_resume_btn.grab_focus()
	# Pausing is a natural checkpoint: save silently so a browser
	# refresh right here never loses the run (issue 169).
	if _game != null and _game.has_method("_autosave_silent"):
		_game._autosave_silent()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _quit_to_title() -> void:
	## Back to character select via a clean scene reload — every gameplay
	## child is rebuilt from scratch, so no teardown bookkeeping is needed.
	## Save first: quitting should never drop progress (issue 169).
	if _game != null and _game.has_method("_autosave_silent"):
		_game._autosave_silent()
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
	var saved_reset := Timer.new()
	saved_reset.wait_time = 1.4
	saved_reset.one_shot = true
	box.add_child(saved_reset)
	save_btn.pressed.connect(func() -> void:
		_game._save_game()
		# Flash the button so the menu itself confirms the save even if
		# the toast was missed (issue 169).
		save_btn.text = "SAVED ✓"
		saved_reset.start())
	saved_reset.timeout.connect(func() -> void: save_btn.text = "SAVE GAME")
	var stats_btn := _menu_button(box, "SESSION STATS")
	stats_btn.pressed.connect(func() -> void:
		visible = false
		_game._open_stats(true))
	var credits_btn := _menu_button(box, "CREDITS")
	credits_btn.pressed.connect(func() -> void:
		visible = false
		_game._open_credits(true))
	var settings_btn := _menu_button(box, "SETTINGS")
	settings_btn.pressed.connect(_toggle_settings)
	var quit_btn := _menu_button(box, "QUIT TO TITLE")
	quit_btn.pressed.connect(_quit_to_title)
	var stamp := Label.new()
	stamp.text = "Delhi Freetown Loot · v%s" % Game.VERSION
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.modulate = Color(1.0, 1.0, 1.0, 0.5)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stamp)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	box.add_child(_settings_box)
	_make_slider("MASTER", "master")
	_make_slider("RADIO", "radio")
	_make_slider("CITY SOUNDS", "ambient")
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(mute_row)
	var mute := CheckBox.new()
	mute.text = "MUTE ALL"
	mute.button_pressed = bool(_settings.get("muted", false))
	mute.toggled.connect(func(on: bool) -> void: _apply_setting("muted", on))
	mute_row.add_child(mute)
	var shadow_row := HBoxContainer.new()
	shadow_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(shadow_row)
	var cb := CheckBox.new()
	cb.text = "SUN SHADOWS (quality)"
	cb.button_pressed = bool(_settings.get("shadows", false))
	cb.toggled.connect(func(on: bool) -> void: _apply_setting("shadows", on))
	shadow_row.add_child(cb)
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(quality_row)
	var qbtn := Button.new()
	qbtn.custom_minimum_size = Vector2(320, 0)
	_quality_btn = qbtn
	_refresh_quality_label()
	qbtn.pressed.connect(func() -> void:
		# AUTO -> HIGH -> LOW -> AUTO; sanitize keeps a tampered
		# settings.json from breaking the cycle (issue 270).
		var modes: Array = QualityScript.MODES
		var cur := modes.find(QualityScript.sanitize(
				String(_settings.get("quality", "auto"))))
		_apply_setting("quality", modes[(cur + 1) % modes.size()]))
	quality_row.add_child(qbtn)


func _apply_setting(key: String, value) -> void:
	_settings[key] = value
	write_settings(_settings)
	apply_audio(_settings)
	if key == "quality" and _game != null and _game.has_method("apply_quality_now"):
		# Live-apply without reload (issue 270); the button label rides
		# along so the menu always shows the effective stored mode.
		_game.apply_quality_now(String(value))
		_refresh_quality_label()
	if key == "shadows" and _game != null and _game.sun != null:
		# The day cycle re-evaluates this every tick (sun below the
		# horizon suspends the shadow map), so only the want-flag is set.
		_game._sun_shadows_wanted = bool(value)
		_game.sun.shadow_enabled = bool(value)


func _refresh_quality_label() -> void:
	if _quality_btn == null:
		return
	var mode := QualityScript.sanitize(String(_settings.get("quality", "auto")))
	_quality_btn.text = "QUALITY: %s" % mode.to_upper()


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
	# Atomic like the save game: temp file first, then rename, so a
	# crash mid-write can't wipe the volume/mute settings (issue 169).
	var payload := JSON.stringify(s, "\t")
	var f := FileAccess.open(SETTINGS_TMP, FileAccess.WRITE)
	if f != null:
		f.store_string(payload)
		f.close()
		var dir := DirAccess.open("user://")
		if dir != null and dir.rename(SETTINGS_TMP.get_file(), SETTINGS_PATH.get_file()) == OK:
			return
	var g := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if g == null:
		return
	g.store_string(payload)
	g.close()


static func apply_audio(s: Dictionary) -> void:
	_set_bus_volume("Ambient", float(s.get("ambient", 100.0)))
	_set_bus_volume("Radio", float(s.get("radio", 100.0)))
	# MUTE ALL wins over the master slider while on, and toggling it
	# back off restores exactly the slider volume (issue 169).
	if bool(s.get("muted", false)):
		var idx := AudioServer.get_bus_index("Master")
		if idx >= 0:
			AudioServer.set_bus_mute(idx, true)
			AudioServer.set_bus_volume_db(idx, 0.0)
	else:
		_set_bus_volume("Master", float(s.get("master", 100.0)))


static func _set_bus_volume(bus_name: String, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var linear := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, -60.0 if linear <= 0.001 else linear_to_db(linear))
