extends Node
## Headless gate for the 3-star escalation (issue #188): jeep count tracks
## stars, a roadblock plants ahead once heat hits 3+, the spike strip fires
## exactly once, ploughing a parked jeep smashes that post, and a paan-shop
## bribe wipes heat for the cooldown window. Prints verdict=PASS/FAIL for
## CI like its sibling check scenes.

const PoliceScript := preload("res://scripts/police.gd")

var _police: Node
var _player: Node3D
var _fails: Array[String] = []
var _spiked := 0
var _crashed := 0


func _ready() -> void:
	_police = PoliceScript.new()
	add_child(_police)
	_police.setup(400.0, 46.0, 12.0, 9)
	_player = Node3D.new()
	add_child(_player)
	_police.register_player(_player)
	_police.spiked.connect(func(): _spiked += 1)
	_police.roadblock_crash.connect(func(): _crashed += 1)
	_run()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok      %s" % what)
	else:
		_fails.append(what)
		print("FAIL    %s" % what)


func _step(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _run() -> void:
	# --- 1. Heat 2 -> two jeeps on the hunt.
	_police.chaos_peds(1)
	await _step(110)
	_check(_police.stars() == 2, "ped chaos at 2 stars")
	_check(_police.jeep_positions().size() == 2, "two jeeps at 2 stars")

	# --- 2. Heat 4 -> four jeeps and a roadblock ahead.
	_police.chaos_ram()
	_police.chaos_ram()
	await _step(110)
	_check(_police.stars() == 4, "ram chaos at 4 stars")
	_check(_police.jeep_positions().size() == 4, "four jeeps at 4 stars")
	var blocks: Array = _police.roadblock_positions()
	_check(blocks.size() >= 1, "roadblock planted at 3+ stars")

	# --- 3. Thread the middle: spike strip fires once, jeeps untouched.
	if blocks.size() >= 1:
		var rb: Vector3 = blocks[0]
		_player.position = Vector3(rb.x, 0.0, rb.z - 12.0)
		await _step(3)
		for i in range(120):
			_player.position += Vector3(0.0, 0.0, 0.4)
			await _step(1)
			if _spiked > 0:
				break
		_check(_spiked == 1, "spike strip fired once")
		_check(_crashed == 0, "threading the gap did not smash jeeps")

	# --- 4. Plough a parked jeep: the post scatters.
	_police.set("_rb_cd", 0.0)
	await _step(2)
	var rbs: Array = _police.get("_roadblocks")
	if rbs.size() >= 1:
		var before: int = _police.roadblock_positions().size()
		var rb2: Dictionary = rbs[0]
		var jeep: Node3D = rb2["jeeps"][0]
		var jp: Vector3 = jeep.global_position
		_player.position = Vector3(jp.x, 0.0, jp.z - 12.0)
		await _step(3)
		for i in range(120):
			_player.position += Vector3(0.0, 0.0, 0.4)
			await _step(1)
			if _crashed > 0:
				break
		_check(_crashed == 1, "ploughing the jeep smashed the post")
		_check(_police.roadblock_positions().size() < before, \
				"smashed post removed from the map")
	else:
		_fails.append("second roadblock never planted")

	# --- 5. The paan-shop bribe: heat gone, network hot.
	_check(_police.can_bribe(), "bribe available while wanted")
	_check(_police.bribe_cost() == 480, "bribe price scales with stars (Rs 480 at 4)")
	_police.bribe()
	_check(_police.stars() == 0, "bribe wiped the heat")
	_check(_police.jeep_positions().is_empty(), "bribe stood the jeeps down")
	_check(_police.roadblock_positions().is_empty(), "bribe packed the roadblocks up")
	_check(not _police.can_bribe(), "network too hot for a second bribe")
	_check(_police.bribe_cooldown_remaining() > 0.0, "bribe cooldown running")

	if _fails.is_empty():
		print("verdict=PASS")
	else:
		print("verdict=FAIL (%d)" % _fails.size())
		get_tree().quit(1)
		return
	get_tree().quit(0)
