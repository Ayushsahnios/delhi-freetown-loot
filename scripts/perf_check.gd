extends Node
## Headless frame-time budget gate — issue 167.
##
## Boots the REAL game (world build, traffic, peds, police, missions,
## HUD — all of it), plays a fixed number of frames and measures
## wall-clock frame time. Exits nonzero when the average frame exceeds
## the budget, so a density or systems PR that silently tanks the
## simulation cannot land green.
##
## Usage:
##   godot --headless --path . res://scenes/perf_check.tscn \
##       -- --frames 240 --warmup 90 --budget 22 --no-lod --tp -57,75
##
## --tp X,Z optionally parks the player at a world position before the
## warmup (same knob as screenshot.tscn), so density changes to the
## crowd-zone strips (issue #181) can be measured AT a strip, not only
## at the default spawn.
##
## What this measures: SIMULATION cost — the headless renderer is a
## dummy, there is no GPU in CI. Renderer-side effects (draw calls,
## fill) are invisible here; docs/perf_budget.md documents what the
## gate catches and what it deliberately does not.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LodScript := preload("res://scripts/lod.gd")
const DEFAULT_BUDGET_MS := 22.0


func _ready() -> void:
	var frames := 240
	var warmup := 90
	var budget := DEFAULT_BUDGET_MS
	var draws := false
	var tp := Vector2(INF, INF)
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--frames" and i + 1 < args.size():
			frames = int(args[i + 1])
		elif a == "--warmup" and i + 1 < args.size():
			warmup = int(args[i + 1])
		elif a == "--budget" and i + 1 < args.size():
			budget = float(args[i + 1])
		elif a == "--no-lod":
			LodScript.disabled = true
		elif a == "--tp" and i + 1 < args.size():
			var bits: PackedStringArray = args[i + 1].split(",")
			if bits.size() == 2:
				tp = Vector2(float(bits[0]), float(bits[1]))
		elif a == "--draws":
			draws = true

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main.has_method("_start_game"):
		main._start_game(Game.CHARACTERS[0])
	if main.has_method("_dismiss_controls_card"):
		main._dismiss_controls_card()
	if tp.x != INF and main.get("player") != null:
		var p: Node3D = main.get("player")
		p.position = Vector3(tp.x, p.position.y, tp.y)

	for i in range(warmup):
		await get_tree().process_frame

	if draws:
		# Renderer-side sample: needs a real renderer (xvfb + opengl3),
		# headless reads zero. Median over the window is stable enough
		# to compare draw-distance tiers before/after.
		var dc := PackedInt64Array()
		for i in range(frames):
			await get_tree().process_frame
			dc.append(int(Performance.get_monitor(
					Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		dc.sort()
		print("PERF_DRAW_CALLS median=%d max=%d" % [
				dc[int(dc.size() / 2.0)], dc[dc.size() - 1]])
		get_tree().quit(0)
		return

	var stamps := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in range(frames):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		stamps.append((now - last) / 1000.0)
		last = now

	stamps.sort()
	var total := 0.0
	for ms in stamps:
		total += ms
	var avg := total / float(stamps.size())
	var p95: float = stamps[int(clampf(stamps.size() * 0.95, 0.0,
			stamps.size() - 1.0))]
	var passed := avg <= budget
	print("PERF_CHECK frames=%d avg_ms=%.2f p95_ms=%.2f budget_ms=%.1f verdict=%s" \
			% [frames, avg, p95, budget, "PASS" if passed else "FAIL"])
	get_tree().quit(0 if passed else 1)
