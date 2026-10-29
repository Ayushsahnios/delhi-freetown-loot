extends CanvasLayer
## Session stats page (issue #211): distance driven, fares completed,
## missions completed and money earned since this legend took the
## street. Opens from the pause menu; the world stays frozen behind
## it exactly like the pause menu. ESC or the CLOSE button dismisses
## it back to the pause menu.

const PAPER := Color(0.15, 0.13, 0.10, 0.97)
const BORDER := Color(0.88, 0.82, 0.62, 0.9)
const INK := Color(0.93, 0.89, 0.76)
const DIM_INK := Color(0.62, 0.56, 0.44)
const GOLD := Color(1.0, 0.78, 0.2)

var _game: Node
var _rows: Label
var _from_pause := false


func setup(game: Node) -> void:
	_game = game


func _ready() -> void:
	layer = 33
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("overlay_screen")
	visible = false
	_build()


func open(from_pause: bool) -> void:
	_from_pause = from_pause
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	visible = false
	if not _from_pause:
		get_tree().paused = false
	elif _game != null and _game._pause != null:
		_game._pause.visible = true


func _process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("pause"):
		close()


func _refresh() -> void:
	var km := 0.0
	var fares := 0
	var missions := 0
	var earned := 0
	if _game != null:
		km = maxf(float(_game._stat_m), 0.0) / 1000.0
		fares = int(_game._missions.session_fares)
		missions = int(_game._missions.session_missions)
		earned = int(_game._missions.session_earned)
	var lines: Array[String] = [
		"Distance driven   %s" % ("%.1f km" % km),
		"Fares completed   %d" % fares,
		"Missions completed   %d" % missions,
		"Money earned   Rs %d" % earned,
	]
	_rows.text = "\n".join(lines)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.10, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 26.0
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var title := Label.new()
	title.text = "SESSION STATS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "since this legend took the street"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", DIM_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var rule := ColorRect.new()
	rule.color = BORDER
	rule.custom_minimum_size = Vector2(360, 2)
	box.add_child(rule)

	_rows = Label.new()
	_rows.add_theme_font_size_override("font_size", 18)
	_rows.add_theme_color_override("font_color", INK)
	box.add_child(_rows)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(180, 0)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)
