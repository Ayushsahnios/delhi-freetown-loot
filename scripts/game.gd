extends Node
## Game autoload: input map, character roster, shared state.

const CHARACTERS := [
	{
		"id": "sardarji",
		"name": "Jaspreet 'Sardar Ji' Singh",
		"role": "Auto-rickshaw legend of Connaught Place",
		"skin": Color(0.78, 0.55, 0.37),
		"shirt": Color(0.93, 0.90, 0.83),
		"pants": Color(0.15, 0.19, 0.25),
		"turban": Color(1.0, 0.56, 0.12),
		"beard": Color(0.44, 0.42, 0.40),
		"jacket": Color(0.36, 0.17, 0.11),
		"sardar": true,
		"anim_rate": 0.85,
		"height": 1.61,
	},
	{
		"id": "riya",
		"name": "Riya Sharma",
		"role": "Delivery rider, fastest lanes in the city",
		"skin": Color(0.72, 0.48, 0.31),
		"shirt": Color(0.55, 0.30, 0.36),
		"pants": Color(0.13, 0.13, 0.16),
		"turban": Color(0.1, 0.1, 0.1),
		"hair": Color(0.14, 0.09, 0.06),
		"helmet": Color(0.93, 0.91, 0.87),
		"sardar": false,
		"anim_rate": 1.18,
		"height": 1.67,
	},
	{
		"id": "monty",
		"name": "Monty 'Dilli ka Don' Malhotra",
		"role": "Connaught Place hustler",
		"skin": Color(0.79, 0.56, 0.39),
		"shirt": Color(0.35, 0.28, 0.45),
		"pants": Color(0.07, 0.07, 0.10),
		"turban": Color(0.1, 0.1, 0.1),
		"hair": Color(0.05, 0.04, 0.04),
		"sardar": false,
		"anim_rate": 1.0,
		"height": 1.78,
	},
]

var selected_character: Dictionary = CHARACTERS[0]


func _ready() -> void:
	_setup_inputs()
	_setup_audio_buses()


func _setup_inputs() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("run", [KEY_SHIFT])
	_add_keys("interact", [KEY_E])
	_add_keys("horn", [KEY_H])
	_add_keys("radio", [KEY_N])
	_add_keys("buy_chai", [KEY_Q])
	_add_keys("buy_samosa", [KEY_R])
	_add_keys("switch_character", [KEY_TAB])
	_add_keys("debug_hurt", [KEY_X])
	_add_keys("debug_fall", [KEY_C])
	_add_keys("save", [KEY_F9])
	_add_keys("pause", [KEY_ESCAPE])
	# Photo mode (issue #100): P toggles the free camera, F cycles the
	# filters, ENTER shoots, G opens the gallery.
	_add_keys("photo", [KEY_P])
	_add_keys("photo_filter", [KEY_F])
	_add_keys("photo_shutter", [KEY_ENTER, KEY_KP_ENTER])
	_add_keys("photo_gallery", [KEY_G])
	# Gamepad — the same actions, so every gameplay reader works unchanged:
	# left stick drives move_* with analog strength, face buttons take the
	# one-shot actions, D-pad buys street food.
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_buttons("interact", [JOY_BUTTON_A])
	_add_joy_buttons("horn", [JOY_BUTTON_B])
	_add_joy_buttons("radio", [JOY_BUTTON_X])
	_add_joy_buttons("switch_character", [JOY_BUTTON_Y])
	_add_joy_buttons("run", [JOY_BUTTON_RIGHT_SHOULDER])
	_add_joy_buttons("buy_chai", [JOY_BUTTON_DPAD_UP])
	_add_joy_buttons("buy_samosa", [JOY_BUTTON_DPAD_DOWN])
	_add_joy_buttons("save", [JOY_BUTTON_START])
	_add_joy_buttons("pause", [JOY_BUTTON_BACK])
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		InputMap.action_set_deadzone(action, 0.2)


func _setup_audio_buses() -> void:
	## Runtime mixer buses for the settings sliders: gameplay scripts keep
	## their own volume_db untouched; sliders scale the bus instead.
	_ensure_bus("Ambient")
	_ensure_bus("Radio")
	# Master limiter (issue #94): every channel sums here, so stacked beds
	# plus a horn plus thunder can never slam past full scale.
	var master := AudioServer.get_bus_index("Master")
	for e in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, e) is AudioEffectLimiter:
			return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -0.2
	limiter.threshold_db = -1.5
	AudioServer.add_bus_effect(master, limiter)


func _ensure_bus(bus_name: String) -> void:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus_name:
			return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _add_keys(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for code in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)


func _add_joy_buttons(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for btn in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = btn
		InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: int, dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)
