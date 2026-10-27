extends Node
## Humanoid height-band check (issue 128) — headless gate for the NPC
## scale fix. Two parts: (A) a variant matrix that spawns every rigged
## character model at a spread of requested heights — including the
## legacy out-of-band 2.7/4.7/5.9 requests that produced micro and
## dinosaur vendors/walkers/player — plays the walk clip, and measures
## each model's rendered upright extent in world space; (B) the real
## game booted with its live crowd, sampling every visible walker plus
## the player model. Every measured humanoid must stand inside the
## human height band 1.55–1.90 m.
## Usage:
##   godot --headless --path . res://scenes/scale_check.tscn
## Exits 0 when every humanoid is in band, 2 with a FAILED report.

const Chars := preload("res://scripts/characters.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const HEIGHT_MIN := 1.55
const HEIGHT_MAX := 1.90
const TOL := 0.04     ## pose/float slop on top of the hard band edges
const SETTLE := 0.35  ## seconds of walk animation before measuring
const CROWD_SETTLE := 1.4  ## seconds of walking before crowd sampling
const MIN_CROWD := 8  ## a vacuous pass is a failed pass

var _problems: Array[String] = []
var _chars := Chars.new()


func _ready() -> void:
	await _matrix()
	await _crowd()
	if _problems.is_empty():
		print("SCALE_CHECK PASS")
		get_tree().quit(0)
	else:
		for p in _problems:
			print("SCALE_CHECK FAILED: " + p)
		get_tree().quit(2)


## Part A — every model variant × requested heights spanning the band
## and the legacy out-of-band requests (2.7 vendor, 4.7 walker, 5.9
## player): all must render inside the band after the factory clamp.
func _matrix() -> void:
	var models := [Chars.FEMALE_A, Chars.FEMALE_B, Chars.FEMALE_C,
		Chars.FEMALE_D, Chars.MALE]
	var requests := [1.56, 1.68, 1.80, 2.7, 4.7, 5.9]
	for path in models:
		for h in requests:
			var holder := _chars.spawn(String(path), float(h))
			add_child(holder)
			_chars.play(_chars.anim_names(holder), _chars.get_player(holder), "walk", 1.0)
			await get_tree().create_timer(SETTLE).timeout
			var measured := _rendered_height(holder)
			if measured < HEIGHT_MIN - TOL or measured > HEIGHT_MAX + TOL:
				_problems.append("variant %s requested %.2f m renders %.2f m (band %.2f-%.2f)"
					% [String(path).get_file(), h, measured, HEIGHT_MIN, HEIGHT_MAX])
			holder.queue_free()


## Part B — the real crowd: boot the game, let walkers spread, measure
## every visible pedestrian and the player.
func _crowd() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().create_timer(CROWD_SETTLE).timeout
	var checked := 0
	var peds: Node = main.get("_peds")
	if peds == null:
		_problems.append("no pedestrians node — crowd missing")
	else:
		var walkers: Array = peds.get("_peds")
		for i in range(walkers.size()):
			var w: Dictionary = walkers[i]
			var n: Node3D = w.node
			if n == null or not n.visible:
				continue
			var measured := _rendered_height(n)
			checked += 1
			if measured < HEIGHT_MIN - TOL or measured > HEIGHT_MAX + TOL:
				_problems.append("walker %d renders %.2f m (band %.2f-%.2f)"
					% [i, measured, HEIGHT_MIN, HEIGHT_MAX])
		if checked < MIN_CROWD:
			_problems.append("only %d walkers sampled — expected ≥ %d"
				% [checked, MIN_CROWD])
	var player: Node3D = main.get("player")
	if player != null:
		var measured := _rendered_height(player)
		checked += 1
		if measured < HEIGHT_MIN - TOL or measured > HEIGHT_MAX + TOL:
			_problems.append("player renders %.2f m (band %.2f-%.2f)"
				% [measured, HEIGHT_MIN, HEIGHT_MAX])
	print("SCALE_CHECK sampled %d humanoids" % checked)


## Upright world-space extent of every rendered mesh under `node` —
## the same box the renderer draws, so headwear and hair count too.
func _rendered_height(node: Node3D) -> float:
	var box := AABB()
	var has := false
	for mi_node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh == null:
			continue
		var part: AABB = mi.global_transform * mi.mesh.get_aabb()
		if has:
			box = box.merge(part)
		else:
			box = part
			has = true
	if not has:
		return 0.0
	return box.size.y
