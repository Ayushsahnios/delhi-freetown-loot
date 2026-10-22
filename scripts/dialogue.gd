extends CanvasLayer
## Reusable dialogue runner: data-driven conversation scripts with
## speaker names, typewriter text reveal, an advance key, and optional
## choices on the final line. All UI procedural — zero assets.
##
## Usage:
##   var dlg = DialogueScript.new(); add_child(dlg)
##   dlg.finished.connect(_on_dlg_done)
##   dlg.start([
##       {"speaker": "Chai uncle", "text": "Arre beta, flask's full!"},
##       {"speaker": "Chai uncle", "text": "Rs 500. Deal?",
##               "choices": ["Take the job", "Not now"]},
##   ])
## finished(picked) fires when the box closes: picked >= 0 is the
## confirmed choice index, -1 means it ended with no choice made.
## One conversation at a time; a new start() while running is ignored.

signal finished(picked: int)

const CHARS_PER_SEC := 45.0
const SPEAKER_DEFAULT := Color(1.0, 0.86, 0.3)
const TEXT_GREY := Color(0.93, 0.93, 0.9)
const HINT_GREY := Color(0.7, 0.72, 0.78)
const CHOICE_ON := Color(1.0, 0.95, 0.7)
const CHOICE_OFF := Color(0.62, 0.64, 0.7)

var _script: Array = []
var _idx := 0
var _shown := 0.0
var _revealed_all := false
var _running := false
var _picked := 0
var _choice_labels: Array[Label] = []

var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _hint: Label
var _choice_box: VBoxContainer


func _ready() -> void:
	layer = 12
	_build_ui()


# ---------------------------------------------------------------- public

func is_running() -> bool:
	return _running


func start(lines: Array) -> void:
	## Begin a conversation. Each line Dictionary: speaker, text,
	## optional color, optional choices (honoured on the last line).
	if lines.is_empty() or _running:
		return
	_script = lines
	_idx = 0
	_running = true
	_panel.visible = true
	_show_line()


func cancel() -> void:
	## Stop immediately; listeners get finished(-1). No-op when idle.
	if _running:
		_close(-1)


# ---------------------------------------------------------------- loop

func _process(_delta: float) -> void:
	if not _running:
		return
	if not _revealed_all:
		if Input.is_action_just_pressed("ui_accept"):
			_body.visible_characters = -1
			_revealed_all = true
			_line_complete()
			return
		_shown += _delta * CHARS_PER_SEC
		if int(_shown) >= _body.text.length():
			_body.visible_characters = -1
			_revealed_all = true
			_line_complete()
		else:
			_body.visible_characters = int(_shown)
	elif not _choice_labels.is_empty():
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_forward"):
			_pick((_picked - 1 + _choice_labels.size()) % _choice_labels.size())
		elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_back"):
			_pick((_picked + 1) % _choice_labels.size())
		elif Input.is_action_just_pressed("ui_accept"):
			_close(_picked)
	else:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			if _idx + 1 >= _script.size():
				_close(-1)
			else:
				_idx += 1
				_show_line()


# ---------------------------------------------------------------- flow

func _show_line() -> void:
	var line: Dictionary = _script[_idx]
	_speaker.text = String(line.get("speaker", ""))
	_speaker.add_theme_color_override("font_color", line.get("color", SPEAKER_DEFAULT))
	_body.text = String(line.get("text", ""))
	_body.visible_characters = 0
	_shown = 0.0
	_revealed_all = false
	_hint.visible = false
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()


func _line_complete() -> void:
	var line: Dictionary = _script[_idx]
	var choices: Array = line.get("choices", [])
	if _idx + 1 >= _script.size() and not choices.is_empty():
		_open_choices(choices)
		return
	_hint.text = "Space — continue ▸" if _idx + 1 < _script.size() else "Space — close ▸"
	_hint.visible = true


func _open_choices(choices: Array) -> void:
	for c in choices:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 16)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_choice_box.add_child(l)
		l.text = String(c)
		_choice_labels.append(l)
	_pick(0)


func _pick(i: int) -> void:
	_picked = i
	for j in _choice_labels.size():
		var on := j == i
		_choice_labels[j].text = ("▸ " if on else "  ") + String(_script[_idx].get("choices", [])[j])
		_choice_labels[j].add_theme_color_override("font_color", CHOICE_ON if on else CHOICE_OFF)


func _close(picked: int) -> void:
	_running = false
	_panel.visible = false
	finished.emit(picked)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(320.0, 500.0)
	_panel.custom_minimum_size = Vector2(640.0, 0.0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	sb.border_color = Color(1.0, 0.84, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 20)
	box.add_child(_speaker)

	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", TEXT_GREY)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(600.0, 0.0)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", HINT_GREY)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_choice_box)
