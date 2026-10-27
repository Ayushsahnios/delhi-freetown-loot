extends Node
## Human-scale gate (issue 128) — headless check that every humanoid in
## the game stands inside the human height band (1.55-1.90 m). Two parts:
##   A. Factory clamp — spawn() every character model at wild requested
##      heights (micro 0.6 up to dinosaur 12.0, including the old wrong
##      values 2.7 / 4.7 / 5.9) and assert the clamped render lands in
##      band; identity-seeded heights too.
##   B. Live world — boot the real game, let the crowd out, then measure
##      every instanced character model in the tree (sidewalk walkers,
##      zone shoppers, food vendors, the player legend) the same way.
## Usage:
##   godot --headless --path . res://scenes/scale_check.tscn
## Exits 0 when every humanoid is in band, 2 with a FAILED report.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Chars := preload("res://scripts/characters.gd")

const SETTLE := 1.4   ## seconds of live world before measuring
const MIN_LIVE := 20  ## a vacuous pass is a failed pass
const EPS := 0.005    ## 5 mm float round-trip slack on the band edges
const MODELS := [
	Chars.FEMALE_A, Chars.FEMALE_B, Chars.FEMALE_C, Chars.FEMALE_D, Chars.MALE,
]
const WILD := [0.6, 2.7, 4.7, 5.9, 12.0]

var _chars := Chars.new()
var _problems: Array[String] = []


func _ready() -> void:
	_part_a()
	await _part_b()
	if _problems.is_empty():
		print("SCALE_CHECK PASS")
		get_tree().quit(0)
	else:
		for p in _problems:
			print("SCALE_CHECK FAILED: " + p)
		get_tree().quit(2)


func _part_a() -> void:
	for path in MODELS:
		for want in WILD:
			var holder := _chars.spawn(String(path), float(want))
			var h := _chars.height_of(holder)
			if h < Chars.HUMAN_MIN - EPS or h > Chars.HUMAN_MAX + EPS:
				_problems.append("clamp: %s asked %.2f m rendered %.2f m"
						% [String(path).get_file(), want, h])
			holder.free()
		for seed_i in [1, 7, 42, 31337]:
			var id: Dictionary = Chars.identity(int(seed_i))
			var holder := _chars.spawn(String(path), 1.72 * float(id["height"]))
			var h := _chars.height_of(holder)
			if h < Chars.HUMAN_MIN - EPS or h > Chars.HUMAN_MAX + EPS:
				_problems.append("identity: %s seed %d rendered %.2f m"
						% [String(path).get_file(), seed_i, h])
			holder.free()


func _part_b() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().create_timer(SETTLE).timeout
	var live := 0
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		var holder := n as Node3D
		var h := _chars.height_of(holder)
		if h <= 0.0:
			continue
		live += 1
		if h < Chars.HUMAN_MIN - EPS or h > Chars.HUMAN_MAX + EPS:
			_problems.append("live: %s rendered %.2f m" % [holder.name, h])
	if live < MIN_LIVE:
		_problems.append("only %d live humanoids measured — expected ≥ %d"
				% [live, MIN_LIVE])
	else:
		print("measured %d live humanoids" % live)
