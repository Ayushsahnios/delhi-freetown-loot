extends Node
## Legend wardrobe unlocks (issue #223): every legend can buy two
## alternate outfits from the enterable shops — a tailor rack beside
## the halwai counter and one at the dhaba. An outfit is a palette
## recolor plus an accessory swap expressed purely as def-key
## overrides, so the existing wardrobe code (dress_legend, the
## tailoring pass, tint) renders every look with zero new rigging.
## Purchase deducts rupees from the shared wallet; owned looks and
## the worn choice persist through the save.

const Chars := preload("res://scripts/characters.gd")

## Rack reach — a touch tighter than the food counters so the tailor
## prompt only reads when you step up to the rack itself.
const BUY_R := 3.0

## Catalog per legend. Overrides are legend def keys; "turban",
## "helmet" and "jacket" ride the existing accessory paths, so a
## wardrobe change is a recolor + accessory swap end to end.
const CATALOG := {
	"sardarji": [
		{
			"key": "ivory",
			"name": "WEDDING IVORY",
			"price": 220,
			"overrides": {
				"shirt": Color(0.97, 0.95, 0.90),
				"pants": Color(0.82, 0.78, 0.68),
				"turban": Color(0.72, 0.10, 0.14),
				"jacket": Color(0.45, 0.12, 0.10),
			},
		},
		{
			"key": "sessional",
			"name": "BLUE SESSIONAL",
			"price": 160,
			"overrides": {
				"shirt": Color(0.62, 0.70, 0.82),
				"pants": Color(0.16, 0.20, 0.30),
				"turban": Color(0.14, 0.22, 0.42),
				"jacket": Color(0.24, 0.24, 0.26),
			},
		},
	],
	"riya": [
		{
			"key": "courier",
			"name": "NIGHT COURIER",
			"price": 180,
			"overrides": {
				"shirt": Color(0.16, 0.16, 0.20),
				"pants": Color(0.05, 0.05, 0.07),
				"helmet": Color(0.12, 0.12, 0.14),
			},
		},
		{
			"key": "marigold",
			"name": "MARIGOLD RUN",
			"price": 150,
			"overrides": {
				"shirt": Color(0.95, 0.62, 0.12),
				"pants": Color(0.18, 0.24, 0.38),
				"helmet": Color(0.96, 0.80, 0.30),
			},
		},
	],
	"monty": [
		{
			"key": "pinstripe",
			"name": "PINSTRIPE DON",
			"price": 200,
			"overrides": {
				"shirt": Color(0.13, 0.14, 0.18),
				"pants": Color(0.30, 0.31, 0.34),
			},
		},
		{
			"key": "mela",
			"name": "MELA GOLD",
			"price": 140,
			"overrides": {
				"shirt": Color(0.90, 0.72, 0.16),
				"pants": Color(0.88, 0.86, 0.80),
			},
		},
	],
}

var _player: CharacterBody3D = null
var _missions: Node = null
var _audio: Node = null
var _autosave := Callable()
var _racks: Array[Vector3] = []
## owned[legend_id][outfit_key] = true; worn[legend_id] = outfit_key.
var _owned := {}
var _worn := {}
## Browse cursor per legend so [Y] walks the rack one look at a time.
var _cursor := {}
var _browse := false

var _prompt: Label
var _toast: Label
var _toast_tween: Tween


func setup(racks: Array[Vector3]) -> void:
	## World dressing from the main menu on (like the carts): the racks
	## stand beside the shop counters; selling starts once register()
	## hands over the live game nodes.
	_racks = racks
	for pos in _racks:
		_build_rack(pos)
	_build_ui()


func register(p: CharacterBody3D, missions: Node, audio: Node = null,
		autosave := Callable()) -> void:
	_player = p
	_missions = missions
	_audio = audio
	_autosave = autosave


# ---------------------------------------------------------------- state

func dress_def(def: Dictionary) -> Dictionary:
	## The def to actually dress: a duplicate with the legend's worn
	## outfit overrides merged over the base palette. Original defs are
	## shared consts, so never mutate the input.
	var out: Dictionary = def.duplicate()
	var id := String(def.get("id", ""))
	var key := String(_worn.get(id, ""))
	if key == "" or not _owned.get(id, {}).get(key, false):
		return out
	for outfit in CATALOG.get(id, []):
		if String(outfit["key"]) == key:
			for k in outfit["overrides"]:
				out[k] = outfit["overrides"][k]
			break
	return out


func snapshot() -> Dictionary:
	## Save block for _collect_save: owned keys per legend plus the
	## worn choice — everything else (prices, palettes) is catalog.
	var owned := {}
	for id in _owned:
		owned[id] = _owned[id].keys()
	return {"owned": owned, "worn": _worn.duplicate()}


func restore(data: Dictionary) -> void:
	## Load path — tolerant of missing/old saves.
	_owned = {}
	_worn = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	var raw_owned = data.get("owned", {})
	if typeof(raw_owned) == TYPE_DICTIONARY:
		for id in raw_owned:
			var keys: Array = []
			if typeof(raw_owned[id]) == TYPE_ARRAY:
				keys = raw_owned[id]
			var bag := {}
			for k in keys:
				bag[String(k)] = true
			_owned[String(id)] = bag
	var raw_worn = data.get("worn", {})
	if typeof(raw_worn) == TYPE_DICTIONARY:
		for id in raw_worn:
			_worn[String(id)] = String(raw_worn[id])
	_cursor = {}


# ---------------------------------------------------------------- shop

func _process(_delta: float) -> void:
	if _player == null or _missions == null:
		return
	if not _rack_near() or not _player.controls_enabled:
		_browse = false
		_prompt.visible = false
		return
	# A running dialogue owns the bottom of the screen (food pattern).
	for d in get_tree().get_nodes_in_group("dialogue"):
		if d.is_running():
			_browse = false
			_prompt.visible = false
			return
	var id := String(Game.selected_character.get("id", ""))
	var looks: Array = CATALOG.get(id, [])
	if looks.is_empty():
		_prompt.visible = false
		return
	var i := int(_cursor.get(id, 0)) % looks.size()
	if Input.is_action_just_pressed("cycle_outfit"):
		i = (i + 1) % looks.size()
		_cursor[id] = i
		if _audio != null and _audio.has_method("purchase_blip"):
			_audio.purchase_blip()
	var look: Dictionary = looks[i]
	var key := String(look["key"])
	var has: bool = _owned.get(id, {}).get(key, false)
	var worn := String(_worn.get(id, "")) == key
	if Input.is_action_just_pressed("buy_outfit"):
		if not has:
			var price := int(look["price"])
			if not _missions.spend(price):
				_show_toast("Not enough paisa — Rs %d needed" % price)
			else:
				if _owned.get(id) == null:
					_owned[id] = {}
				_owned[id][key] = true
				_wear(id, key)
				_show_toast("%s  ·  bought + worn  ·  Rs %d"
						% [String(look["name"]), price])
		elif not worn:
			_wear(id, key)
			_show_toast("%s  ·  worn" % String(look["name"]))
		else:
			_show_toast("Already wearing it")
	if worn:
		_prompt.text = "TAILOR · %s — worn  ·  [Y] next look" \
				% String(look["name"])
	elif has:
		_prompt.text = "TAILOR · %s — owned  ·  [T] wear  ·  [Y] next look" \
				% String(look["name"])
	else:
		_prompt.text = "TAILOR · %s Rs %d  ·  [T] buy + wear  ·  [Y] next look" \
				% [String(look["name"]), int(look["price"])]
	_prompt.visible = true


func _wear(id: String, key: String) -> void:
	## Swap the worn outfit and rebuild the live model on the spot —
	## the same rebuild path as a Tab legend switch.
	_worn[id] = key
	if _player != null and is_instance_valid(_player):
		_player.swap_character(dress_def(Game.selected_character))
	# Outfit changes are keepers — persist immediately so a crash
	# after the tailor never loses the purchase.
	if _autosave.is_valid():
		_autosave.call()


func _rack_near() -> bool:
	if _racks.is_empty():
		return false
	var p: Vector3 = _player.global_position
	for rack in _racks:
		if Vector2(p.x - rack.x, p.z - rack.z).length() < BUY_R:
			return true
	return false


# ---------------------------------------------------------------- visuals

func _build_rack(pos: Vector3) -> void:
	## Procedural tailor rack: two cylinder posts, a crossbar and three
	## hanging capsule garments in legend accent colors. Mesh-only, no
	## collision — the city trees pattern. ~1.4k tris per rack.
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 1.9
	for px in [-1.1, 1.1]:
		var leg := MeshInstance3D.new()
		var lm := pole.duplicate()
		lm.material = _solid(Color(0.42, 0.30, 0.18))
		leg.mesh = lm
		leg.position = Vector3(px, 0.95, 0.0)
		root.add_child(leg)
	var bar := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.035
	bm.bottom_radius = 0.035
	bm.height = 2.3
	bm.material = _solid(Color(0.55, 0.40, 0.24))
	bar.mesh = bm
	bar.rotation.z = PI / 2.0
	bar.position = Vector3(0.0, 1.86, 0.0)
	root.add_child(bar)
	# Hanging garments: capsule silhouettes in wardrobe accent shades.
	var shades := [Color(0.95, 0.62, 0.12), Color(0.62, 0.70, 0.82),
			Color(0.90, 0.72, 0.16)]
	for i in range(3):
		var garment := MeshInstance3D.new()
		var gm := CapsuleMesh.new()
		gm.radius = 0.16
		gm.height = 0.72
		gm.material = _solid(shades[i])
		garment.mesh = gm
		garment.position = Vector3(-0.7 + i * 0.7, 1.44, 0.0)
		root.add_child(garment)


func _solid(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.offset_bottom = -60.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -108.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)
