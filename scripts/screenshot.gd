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
##   --frames N    frames to simulate first  (default 90)
##   --tp X,Z      teleport player to X,Z before settling
##   --day T       force time of day (0..1 of the day cycle) before settling

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _ready() -> void:
	var out := "/tmp/shot.png"
	var frames := 90
	var tp := Vector2(INF, INF)
	var day := -1.0
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--out" and i + 1 < args.size():
			out = args[i + 1]
		elif a == "--frames" and i + 1 < args.size():
			frames = int(args[i + 1])
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
	if main.has_method("_start_game"):
		main._start_game(Game.CHARACTERS[0])

	if day >= 0.0 and "day_t" in main:
		main.day_t = day

	if tp.x != INF and main.get("player") != null:
		var p: Node3D = main.get("player")
		p.position = Vector3(tp.x, p.position.y, tp.y)

	for i in range(frames):
		await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("screenshot saved: ", out)
	if main.get("player") != null:
		print("player at: ", main.get("player").position)
	get_tree().quit()
