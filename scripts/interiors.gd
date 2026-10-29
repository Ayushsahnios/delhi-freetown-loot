extends Node
## Walk-in interiors, slice 1 (issue #183): the halwai sweet shop in
## Chandni Chowk and the roadside dhaba in Purani Dilli become places
## you enter. The hollow walls and counters live in delhi_dressing3.gd;
## this node owns the life inside — the halwai at his mithai counter,
## the dhaba cook at the tawa, a customer or two — and two beats:
## crossing the sweet-shop doorway rings the shop chime (issue #187),
## and both counters take orders through the street-food system, so
## mithai, chai and paratha cost paisa and heal like cart food.

const Chars := preload("res://scripts/characters.gd")
const ShadowBlob := preload("res://scripts/shadowblob.gd")

const DOOR_HALF_X := 1.6
const DOOR_HALF_Z := 1.5

var _player: Node3D = null
var _audio: Node = null
var _chars := Chars.new()
var _idles: Array[Dictionary] = []
var _shop := Vector3.ZERO
var _dhaba := Vector3.ZERO
var _inside := false


func setup(world: float, pitch: float, road_w: float, food: Node) -> void:
	## World dressing from the main menu on (like the food carts): the
	## block math mirrors delhi_dressing3.gd so the two never drift.
	var cc := Vector2(-world / 2.0 + 4.0 * pitch + road_w / 2.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	var pd := Vector2(-world / 2.0 + 3.0 * pitch + road_w / 2.0,
			-world / 2.0 + 7.0 * pitch + road_w / 2.0)
	_shop = Vector3(cc.x - 5.0, 0.16, cc.y + 4.0)
	_dhaba = Vector3(pd.x + 9.5, 0.14, pd.y - 9.5)
	# The halwai behind his counter (turban on), a shopper deciding.
	_npc(Chars.MALE, 18301, false, 1.72,
			_shop + Vector3(-1.4, 0.0, -1.05), Vector3(1.0, 0.0, 0.4),
			Color(0.52, 0.16, 0.14))
	_npc(Chars.FEMALE_B, 18302, true, 1.62,
			_shop + Vector3(-0.5, 0.0, 0.5), Vector3(-1.0, 0.0, -0.1))
	# The dhaba cook at the tawa end of his counter, a customer waiting
	# by the charpai.
	_npc(Chars.MALE, 18303, false, 1.75,
			_dhaba + Vector3(2.1, 0.0, -0.5), Vector3(-1.0, 0.0, 0.0))
	_npc(Chars.MALE, 18304, false, 1.68,
			_dhaba + Vector3(-0.9, 0.0, 0.9), Vector3(1.0, 0.0, -0.2))
	# Counter service through the food system (same Q/R economy).
	if food != null and food.has_method("add_counter"):
		food.add_counter(_shop + Vector3(-1.0, 0.0, 0.15),
				[food.CHAI, food.MITHAI])
		food.add_counter(_dhaba + Vector3(0.5, 0.0, -0.1),
				[food.CHAI, food.PARATHA])


func register(p: Node3D, audio: Node) -> void:
	## Live-game nodes: the doorway check needs the walker, the chime
	## needs the audio bus.
	_player = p
	_audio = audio


func _process(_delta: float) -> void:
	## Idle clips loop forever on the interior cast (rigs import the
	## clip without loop flags, so nudge the player when one lands).
	for n in _idles:
		if not n["ap"].is_playing():
			_chars.play(n["anims"], n["ap"], "idle", 0.9)
	if _player == null or _audio == null:
		return
	var p := _player.global_position
	var inside := absf(p.x - _shop.x) < DOOR_HALF_X \
			and absf(p.z - _shop.z) < DOOR_HALF_Z
	if inside != _inside:
		_inside = inside
		_audio.door_chime()


func _npc(model_path: String, seed: int, female: bool, height: float,
		at: Vector3, face: Vector3, turban := Color(-1.0, -1.0, -1.0)) -> void:
	## One rigged idle local — same spawn path as the cart vendors
	## (characters.gd identity + dress), parked facing a spot.
	var id := Chars.identity(seed, female)
	var node := _chars.spawn(model_path, height)
	ShadowBlob.attach(node, 0.48)
	_chars.dress(node, id)
	if turban.r >= 0.0:
		_chars.attach_sardar(node, turban)
	add_child(node)
	node.position = at
	# In-tree before look_at — Godot rejects it on detached nodes.
	node.look_at(at + face, Vector3.UP)
	var ap := _chars.get_player(node)
	var anims := _chars.anim_names(node)
	_chars.play(anims, ap, "idle", 0.9)
	_idles.append({"ap": ap, "anims": anims})
