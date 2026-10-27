extends Node
## Facing-vs-travel check (issue 127) — headless gate for the walker
## forward-axis fix. Boots the real game, lets the crowd walk, takes two
## snapshots of every visible pedestrian, and asserts each walker's body
## faces its direction of travel: the character's visual forward (holder
## basis composed with the corrective flip on the model child) must agree
## with the walker's measured velocity. The pre-fix bug — spawn() put the
## 180° flip on the holder, which the pedestrian recycler overwrote every
## physics frame — reads here as every walker facing AGAINST travel.
## Usage:
##   godot --headless --path . res://scenes/facing_check.tscn
## Exits 0 when every sampled walker faces travel, 2 with a FAILED
## report otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const SETTLE := 1.4    ## seconds of walking before the first snapshot
const SAMPLE := 0.7    ## seconds between snapshots
const MIN_SPEED := 0.4 ## m/s — slower movers say nothing about facing
const MIN_DOT := -0.2  ## facing·travel; corner turns and wake jumps
                       ## stay above ~0.0, a backwards walker lands at −1
const MIN_CHECKED := 8 ## a vacuous pass is a failed pass

func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().create_timer(SETTLE).timeout
	var problems: Array[String] = []
	var checked := 0
	var peds: Node = main.get("_peds")
	if peds == null:
		problems.append("no pedestrians node — crowd missing")
	else:
		var walkers: Array = peds.get("_peds")
		var before: Array[Vector3] = []
		var nodes: Array[Node3D] = []
		for w in walkers:
			var n: Node3D = w.node
			before.append(w.pos)
			nodes.append(n)
		await get_tree().create_timer(SAMPLE).timeout
		for i in range(walkers.size()):
			var n: Node3D = nodes[i]
			if n == null or not n.visible or n.get_child_count() == 0:
				continue
			var w: Dictionary = walkers[i]
			var vel: Vector3 = (w.pos - before[i]) / SAMPLE
			vel.y = 0.0
			if vel.length() < MIN_SPEED:
				continue
			var model: Node3D = n.get_child(0)
			var fwd: Vector3 = n.global_transform.basis \
				* model.transform.basis * Vector3(0.0, 0.0, 1.0)
			fwd.y = 0.0
			var dot := fwd.normalized().dot(vel.normalized())
			checked += 1
			if dot < MIN_DOT:
				problems.append("walker %d faces travel backwards "
					% i + "(dot=%.2f, heading=%.2f)" % [dot, w.heading])
		if checked < MIN_CHECKED:
			problems.append("only %d walkers sampled — expected ≥ %d"
				% [checked, MIN_CHECKED])
	if problems.is_empty():
		print("FACING_CHECK PASS (walkers facing travel: %d)" % checked)
		get_tree().quit(0)
	else:
		for p in problems:
			print("FACING_CHECK FAILED: " + p)
		get_tree().quit(2)
