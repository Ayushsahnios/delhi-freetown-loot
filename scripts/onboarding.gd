extends CanvasLayer
## First-5-minutes goal checklist (issue #271): a dismissible card that
## exists ONLY for fresh saves — reach the START HERE beacon, finish a
## first job, buy street food, ride the metro, save the run. Each tick
## rings a small chime; all five clears (or HIDE) retire the card for
## good. Saves written before this feature carry no "onboarding" key,
## so existing runs never see it. Reuses the HUD/toast vocabulary.

signal all_clear

const GOLD := Color(1.0, 0.92, 0.45)
const GREEN := Color(0.55, 1.0, 0.6)
const BEACON_R := 7.0

const GOALS := [
	{"id": "beacon", "label": "Reach the gold START HERE beacon"},
	{"id": "job", "label": "Complete your first job"},
	{"id": "food", "label": "Buy street food — chai at a cart  [Q]"},
	{"id": "metro", "label": "Ride the metro  [E]"},
	{"id": "save", "label": "Save your run  [F9]"},
]

var _done := {}
var _retired := false
var _active := false
var _beacon := Vector3.INF
var _audio: Node = null
var _panel: PanelContainer = null
var _rows := {}


func setup(save: Dictionary, beacon_pos: Vector3, audio) -> void:
	## Empty save = brand-new game: the card's one and only audience. A
	## save carrying the "onboarding" key resumes its checklist; a save
	## with no key predates the feature and stays dark either way.
	_done = {}
	_retired = false
	_active = false
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_rows = {}
	if not save.is_empty() and not save.has("onboarding"):
		return
	var st = save.get("onboarding", {})
	if typeof(st) == TYPE_DICTIONARY:
		var done_list = st.get("done", [])
		if typeof(done_list) == TYPE_ARRAY:
			for id in done_list:
				_done[String(id)] = true
		_retired = bool(st.get("retired", false))
	_beacon = beacon_pos
	_audio = audio
	if _beacon == Vector3.INF and not _done.has("beacon"):
		# Intro job already run on a resumed save: the marker is long
		# gone, so the goal ticks itself rather than stranding.
		_done["beacon"] = true
	_active = not _retired and _done.size() < GOALS.size()
	if _active:
		_build_card()
		_refresh()


func tick_beacon(pos: Vector3) -> void:
	## Beacon proximity is the only per-frame goal; the rest arrive as
	## one-shot events through the note_* hooks.
	if not _active or _done.has("beacon") or _beacon == Vector3.INF:
		return
	if Vector2(pos.x - _beacon.x, pos.z - _beacon.z).length() < BEACON_R:
		_complete("beacon")


func note_job() -> void:
	_complete("job")


func note_food() -> void:
	_complete("food")


func note_metro() -> void:
	_complete("metro")


func note_save() -> void:
	_complete("save")


func snapshot() -> Dictionary:
	## {} = the feature never activated for this save, so pre-#271
	## saves keep that shape forever and the card stays away.
	if not _active and _done.is_empty() and not _retired:
		return {}
	return {"done": _done.keys(), "retired": _retired}


func _complete(id: String) -> void:
	if not _active or _done.has(id):
		return
	_done[id] = true
	if _audio != null and _audio.has_method("door_chime"):
		_audio.door_chime()
	_refresh()
	if _done.size() >= GOALS.size():
		# All five clear: retire with a fade — gone after completion.
		_retired = true
		_active = false
		if _panel != null and is_instance_valid(_panel):
			var card := _panel
			_panel = null
			var tw := create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.8)
			tw.tween_callback(card.queue_free)
		all_clear.emit()


func _dismiss() -> void:
	## HIDE retires the card too — the choice rides the next save.
	_retired = true
	_active = false
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _build_card() -> void:
	layer = 12
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "FIRST 5 MINUTES"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var sub := Label.new()
	sub.text = "clear all five — then this card is gone for good"
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1.0, 1.0, 1.0, 0.6)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)
	for g in GOALS:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		_rows[String(g["id"])] = row
	var hide := Button.new()
	hide.text = "HIDE — I know the streets"
	hide.add_theme_font_size_override("font_size", 12)
	hide.pressed.connect(_dismiss)
	box.add_child(hide)
	add_child(_panel)


func _refresh() -> void:
	if _panel == null:
		return
	for g in GOALS:
		var id := String(g["id"])
		if not _rows.has(id):
			continue
		var row: Label = _rows[id]
		if _done.has(id):
			row.text = "[x]  " + String(g["label"])
			row.add_theme_color_override("font_color", GREEN)
		else:
			row.text = "[  ]  " + String(g["label"])
			row.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
