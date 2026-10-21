extends Node
## Game autoload: input map, character roster, shared state.

const CHARACTERS := [
	{
		"id": "sardarji",
		"name": "Jaspreet 'Sardar Ji' Singh",
		"role": "Auto-rickshaw legend of Connaught Place",
		"skin": Color(0.78, 0.55, 0.37),
		"shirt": Color(0.18, 0.42, 0.20),
		"pants": Color(0.15, 0.19, 0.25),
		"turban": Color(1.0, 0.56, 0.12),
		"sardar": true,
	},
	{
		"id": "riya",
		"name": "Riya Sharma",
		"role": "Delivery rider, fastest lanes in the city",
		"skin": Color(0.72, 0.48, 0.31),
		"shirt": Color(0.84, 0.20, 0.42),
		"pants": Color(0.12, 0.16, 0.27),
		"turban": Color(0.1, 0.1, 0.1),
		"sardar": false,
	},
	{
		"id": "monty",
		"name": "Monty 'Dilli ka Don' Malhotra",
		"role": "Connaught Place hustler",
		"skin": Color(0.79, 0.56, 0.39),
		"shirt": Color(0.54, 0.17, 0.89),
		"pants": Color(0.07, 0.07, 0.10),
		"turban": Color(0.1, 0.1, 0.1),
		"sardar": false,
	},
]

var selected_character: Dictionary = CHARACTERS[0]


func _ready() -> void:
	_setup_inputs()


func _setup_inputs() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("run", [KEY_SHIFT])
	_add_keys("interact", [KEY_E])
	_add_keys("mission", [KEY_F])
	_add_keys("horn", [KEY_H])
	_add_keys("debug_hurt", [KEY_X])
	_add_keys("debug_fall", [KEY_C])


func _add_keys(action: String, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for code in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action, ev)
