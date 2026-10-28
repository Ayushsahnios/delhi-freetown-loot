extends Node
## Screenshot capture tool — renders the actual game server-side (Xvfb + software GL)
## and saves a PNG. Skips the select screen, starts as the first character, captures
## gameplay after a settle period.
##
## Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://scenes/screenshot.tscn -- --out /tmp/shot.png --frames 90
##
## Options (after `--`):
##   --out PATH    output PNG path           (default /tmp/shot.png)
##   --title       capture the select screen (title) instead of gameplay;
##                 also saves each legend's portrait card and FAILS with a
##                 nonzero exit when any pair of cards is pixel-near-
##                 identical (issue 152 all-pink-portraits regression)
##   --frames N    frames to simulate first  (default 90)
##   --tp X,Z      teleport player to X,Z before settling
##   --day T       force time of day (0..1 of the day cycle) before settling
##   --no-card     dismiss the first-boot controls card before settling
##   --nclouds     hide the drifting cloud layer (issue #104: the alpha-
##                 blended cloud MultiMesh washes out the whole frame under
##                 software GL; this knob captures the city cloud-free)
##   --noglow       disable environment glow (issue #104 discriminator: on
##                 the compatibility renderer glow composites in LDR, which
##                 can wash bright noon skies out to white under software GL)

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _ready() -> void:
	var out := "/tmp/shot.png"
	var frames := 90
	var tp := Vector2(INF, INF)
	var day := -1.0
	var card := true
	var nclouds := false
	var noglow := false
	var finale := false
	var ending := false
	var metro := false
	var title := false
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--out" and i + 1 < args.size():
			out = args[i + 1]
		elif a == "--frames" and i + 1 < args.size():
			frames = int(args[i + 1])
		elif a == "--no-card":
			card = false
		elif a == "--nclouds":
			nclouds = true
		elif a == "--noglow":
			noglow = true
		elif a == "--metro":
			metro = true
		elif a == "--finale":
			finale = true
		elif a == "--ending":
			ending = true
		elif a == "--title":
			title = true
		elif a == "--tp" and i + 1 < args.size():
			var bits := String(args[i + 1]).split(",")
			if bits.size() == 2:
				tp = Vector2(float(bits[0]), float(bits[1]))
		elif a == "--day" and i + 1 < args.size():
			day = clampf(float(args[i + 1]), 0.0, 1.0)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if title:
		await _title_shot(main, out, frames)
		return
	if main.has_method("_start_game"):
		main._start_game(Game.CHARACTERS[0])
		if not card and main.has_method("_dismiss_controls_card"):
			main._dismiss_controls_card()

	if day >= 0.0 and "day_t" in main:
		main.day_t = day

	if nclouds:
		var clouds: Node3D = main.get("_cloud_layer")
		if clouds != null:
			clouds.visible = false

	if noglow:
		var we: WorldEnvironment = main.get("world_env")
		if we != null:
			we.environment.glow_enabled = false

	if tp.x != INF and main.get("player") != null:
		var p: Node3D = main.get("player")
		p.position = Vector3(tp.x, p.position.y, tp.y)

	if metro and main.has_method("_capture_board_metro"):
		main._capture_board_metro()

	if finale or ending:
		var m: Node = main.get("_missions")
		if m != null:
			if finale:
				# Staged progress capture: chapters one cleared, Finale I unlocked.
				m.restore(0, {"kahani_sardarji": 1, "kahani_riya": 1, "kahani_monty": 1})
			if ending and m.has_method("show_ending_preview"):
				m.show_ending_preview()

	for i in range(frames):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("screenshot saved: ", out)
	if main.get("player") != null:
		print("player at: ", main.get("player").position)
	get_tree().quit()


## Issue 152 reproduction + CI gate: capture the select screen itself —
## the full board plus each legend's portrait card from its own
## SubViewport — then quit nonzero when any pair of cards is
## pixel-near-identical (the all-pink-portraits regression).
func _title_shot(main: Node, out: String, frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("screenshot saved: ", out)
	var names := ["sardarji", "riya", "monty"]
	var cards: Array[Image] = []
	var views: Array = main.get("_portrait_views")
	for idx in range(views.size()):
		var card: Image = views[idx].get_texture().get_image()
		var label := String(names[idx]) if idx < names.size() else str(idx)
		var p := out.get_base_dir().path_join(
				out.get_file().get_basename() + "-" + label + ".png")
		card.save_png(p)
		print("title card saved: ", p)
		cards.append(card)
	var worst := 1.0e9
	for a in range(cards.size()):
		for b in range(a + 1, cards.size()):
			var d := _mean_abs_diff(cards[a], cards[b])
			var pair := "%s/%s" % [String(names[a]), String(names[b])] \
				if a < names.size() and b < names.size() \
				else "%d/%d" % [a, b]
			print("title card diff %s: %.2f" % [pair, d])
			worst = minf(worst, d)
	if worst < 2.0:
		printerr("TITLE CARDS NOT DISTINCT (worst pair mean diff %.2f < 2.0)" % worst)
		get_tree().quit(1)
	else:
		print("title cards distinct: worst pair mean diff %.2f" % worst)
		get_tree().quit(0)


## Mean absolute per-channel difference (0..255 scale) of two images;
## a size mismatch counts as fully different.
func _mean_abs_diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 255.0
	var total := 0.0
	var samples := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r8 - cb.r8) + absf(ca.g8 - cb.g8) \
				+ absf(ca.b8 - cb.b8)
			samples += 3
	return total / float(maxi(samples, 1))
