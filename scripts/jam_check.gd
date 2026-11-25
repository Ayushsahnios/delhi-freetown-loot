extends Node
## Jam event gate (issue #348) — headless check that one arterial
## gridlocks on cue. Boots the real game, forces the first jam with
## --jam-now and asserts the full cycle:
##   1. The jam fires within 8 s of start (--jam-now).
##   2. The name comes from the parody list (locality + -style).
##   3. The wave target pins at the rush ceiling (32) even at the
##      midday lull, and the fleet rolls up to it on ONE road.
##   4. At least one wrong-side gap-runner rides the jam road.
##   5. Average frame time stays under the 22 ms budget while the
##      jam is pinned (perf_check timing idiom).
##   6. end_jam() clears the flags and the target falls back to the
##      clock curve (19 at noon).
## Usage:
##   godot --headless --path . res://scenes/jam_check.tscn -- --jam-now
## Exits 0 with verdict=PASS when the whole cycle holds, 2 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const JAM_NAMES_EXPECTED := ["ITO Mor-style gridlock",
		"Anand Vihar-style snarl", "DND-style toll crawl"]
const FRAME_BUDGET_MS := 22.0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []
	var traffic: Node = main.get("_traffic")
	if traffic == null or not traffic.has_method("jam_debug"):
		print("FAILED: traffic wiring missing (jam_debug)")
		get_tree().quit(2)
		return

	# Noon lull: the clock curve alone says 19. The hour is pinned on
	# traffic directly — main's daily-life fan-out can lag a beat at
	# boot, and the pre-jam baseline must not race it.
	main.day_t = 0.5
	traffic.set_hours(12.0)
	await _settle(12)
	var lull: Dictionary = traffic.wave_debug()
	print("lull    fleet %d target %d — midday before the jam"
			% [lull["fleet"], lull["target"]])
	if int(lull["target"]) != 19:
		problems.append("lull target %d — expected 19 pre-jam"
				% lull["target"])

	# --jam-now: the first gridlock lands within 8 s.
	var fired: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var d: Dictionary = traffic.jam_debug()
		if bool(d["active"]):
			fired = d
			break
	if fired.is_empty():
		problems.append("jam never fired within 8 s of --jam-now")
	else:
		print("jam     fired '%s' on road %.1f (along_z=%s)"
				% [fired["name"], fired["road"], fired["along_z"]])
		if not (String(fired["name"]) in JAM_NAMES_EXPECTED):
			problems.append("jam name '%s' not from the parody list"
					% fired["name"])
		if int(fired["target"]) != 32:
			problems.append("jam target %d — expected pinned 32"
					% fired["target"])
		# The fleet rolls up to the pinned ceiling on the jam road.
		await _settle_wave(traffic, 30.0)
		var peak: Dictionary = traffic.jam_debug()
		print("peak    fleet %d on_jam_road %d gaprun %d target %d"
				% [peak["fleet"], peak["on_jam_road"],
				peak["gaprun"], peak["target"]])
		if int(peak["fleet"]) != 32:
			problems.append("jam fleet %d — expected 32" % peak["fleet"])
		if int(peak["on_jam_road"]) < 10:
			problems.append("on_jam_road %d — readable one-arterial needs >= 10"
					% peak["on_jam_road"])
		if int(peak["gaprun"]) < 1:
			problems.append("gaprun %d — expected >= 1 wrong-side runner"
					% peak["gaprun"])
		# Frame budget while the jam is pinned (perf_check idiom).
		var stamps: Array[float] = []
		var last := Time.get_ticks_msec()
		for i in range(120):
			await get_tree().process_frame
			var now := Time.get_ticks_msec()
			stamps.append(float(now - last))
			last = now
		var total := 0.0
		for s in stamps:
			total += s
		var avg := total / maxf(1.0, float(stamps.size()))
		print("perf    avg_ms=%.2f budget_ms=%.1f over %d jam frames"
				% [avg, FRAME_BUDGET_MS, stamps.size()])
		if avg > FRAME_BUDGET_MS:
			problems.append("avg frame %.2f ms over budget %.1f"
					% [avg, FRAME_BUDGET_MS])
		# Release: flags clear, the clock curve takes the target back.
		traffic.end_jam()
		await _settle(12)
		var after: Dictionary = traffic.jam_debug()
		print("after   active=%s fleet %d target %d gaprun %d"
				% [after["active"], after["fleet"], after["target"],
				after["gaprun"]])
		if bool(after["active"]):
			problems.append("end_jam() left the jam active")
		if int(after["gaprun"]) != 0:
			problems.append("end_jam() left gaprun flags set")
		if int(after["target"]) != 19:
			problems.append("post-jam target %d — expected lull 19"
					% after["target"])

	if problems.is_empty():
		print("JAM CHECK PASS — gridlock pins density, gap-runs the wrong side, clears clean")
		print("verdict=PASS")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		print("verdict=FAIL")
		get_tree().quit(2)


func _settle(frames: int) -> void:
	## Let the day clock and the physics loop push state through.
	for i in range(frames):
		await get_tree().process_frame


func _settle_wave(traffic: Node, secs: float) -> void:
	## The traffic wave rolls in at one vehicle per 0.2 s and retires
	## on a 6 s grace beat — real seconds, not frames.
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var w: Dictionary = traffic.wave_debug()
		if int(w["fleet"]) == int(w["target"]):
			return
