extends Node
## Prop placement check (issue #103) — headless gate for the sweep-fix
## geometry. Boots the real game and asserts:
##   1. Every landmark wake-up spot stands ≥ 2.5 m clear of every
##      bus-stop shelter footprint — the police-station and India Gate
##      spawns used to wake up INSIDE their south shelter (canopy
##      clipping the torso, collider swallowing the player).
##   2. Chandni Chowk bunting poles sit at ±6.0 from the market lane
##      axis — inboard of the stall awnings (street ∓6.7 … ∓10.1) so no
##      pole passes through a stall frame; flags span pole to pole.
## Usage:
##   godot --headless --path . res://scenes/prop_check.tscn
## Exits 0 when placement passes, 2 with a FAILED report otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const SPAWN_CLEAR := 2.5  ## min horizontal spawn-to-shelter distance (m)
const LANE_HALF := 6.0    ## bunting pole offset from the market lane axis
const POLE_TOL := 0.5     ## tolerance on the pole offset

func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []

	# --- 1. landmark spawns vs shelter footprints (ShelterColliders,
	# issue #77: one box per stop footprint).
	var shelters: Array[CollisionShape3D] = []
	var sc := main.get_node_or_null("ShelterColliders")
	if sc == null:
		problems.append("no ShelterColliders node — shelter physics missing")
	else:
		for c: CollisionShape3D in sc.get_children():
			shelters.append(c)
	var landmarks: Array = main.get("_landmarks")
	var worst := INF
	for lm: Dictionary in landmarks:
		var spawn: Vector3 = lm["spawn"]
		for pole_xf: CollisionShape3D in shelters:
			var d := Vector2(spawn.x - pole_xf.global_position.x,
					spawn.z - pole_xf.global_position.z).length()
			if d < worst:
				worst = d
			if d < SPAWN_CLEAR:
				problems.append("%s spawn is %.2f m from a shelter — expected ≥ %.1f m"
						% [lm["name"], d, SPAWN_CLEAR])
	print("spawns: %d landmarks vs %d shelters — closest approach %.2f m (min %.1f)"
			% [landmarks.size(), shelters.size(), worst, SPAWN_CLEAR])

	# --- 2. bunting poles clear of the stall awnings. Poles are the
	# 6.2 m-tall PropColliders boxes (trees are 2.6, metro pillars 12.0).
	var street_x: float = main._block_center(4, 7).x + 6.0
	var poles := 0
	var worst_off := INF
	var pc := main.get_node_or_null("PropColliders")
	if pc == null:
		problems.append("no PropColliders node — prop physics missing")
	else:
		for c: CollisionShape3D in pc.get_children():
			var box: BoxShape3D = c.shape as BoxShape3D
			if box == null or not is_equal_approx(box.size.y, 6.2):
				continue
			poles += 1
			var off := absf(c.global_position.x - street_x)
			worst_off = minf(worst_off, absf(off - LANE_HALF))
			if absf(off - LANE_HALF) > POLE_TOL:
				problems.append("bunting pole at lane offset %.2f m — expected %.1f ± %.1f (clear of stall awnings)"
						% [off, LANE_HALF, POLE_TOL])
	print("bunting: %d poles on the market lane — worst offset drift %.2f m"
			% [poles, worst_off if poles > 0 else -1.0])
	if poles == 0:
		problems.append("no bunting poles found in PropColliders")

	if problems.is_empty():
		print("PROP CHECK PASS — spawns clear of shelters, bunting off the stall frames")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		get_tree().quit(2)
