extends Node
## Screenshot capture tool — renders the actual game server-side (Xvfb + software GL)
## and saves a PNG. Skips the select screen, starts as the first character, captures
## gameplay after a settle period.
##
## Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://scenes/screenshot.tscn -- --out /tmp/shot.png --frames 90
##
## NEVER add --headless: captures need the real GL context Xvfb provides;
## headless never renders a frame, the capture hangs, and the run only dies
## at SIGTERM (two 15-30 min lost attempts, Nov 9). The script now refuses
## to run headless and exits 1 immediately instead of hanging.
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
##   --no-hud      hide every HUD overlay layer (refs #293 eyeball
##                 captures: nameplate/clock/HP+stamina rails, minimap,
##                 touch controls, tutorial card) so captures read as
##                 the world alone
##   --no-beacon   hide mission-giver beacons (refs #293 attempt-12:
##                 the START HERE ring/beam/Label3D stands on the thana
##                 plaza in every eastward shopfront sightline and
##                 dominates street-side frames; --no-hud hides HUD
##                 layers only, not world-space markers)
##   --cam-elev M  lift the capture camera M meters above its chase
##                 spot, re-aiming at the same subject (refs #293
##                 attempt-8 doorway shot: a ~3 m vantage clears the
##                 stall-side trunk/canopy and crops the spawn-beacon
##                 text; the main controllers freeze for the capture
##                 frame so the chase ease cannot pull it back down)
##   --weather S   pin the weather state machine (refs #296): "clear"
##                 freezes it bone-dry, "rain" locks a full squall —
##                 makes captures deterministic instead of rolling the
##                 65%-per-day monsoon dice; the live weather state is
##                 printed with the capture for audit trails
##   --no-festival (refs #296 sweep-5) strips the Diwali dressing even
##                 inside the Nov 1-14 window — see scripts/festival.gd
##                 is_festival(); pair a pinned-weather shot with a
##                 --no-festival shot for clean before/after baselines
##   --closeup     with --title: after the standard card trio, re-frame
##                 each portrait SubViewport camera tight on the face
##                 and save an extra face crop per legend (refs #292:
##                 the swap's acceptance is *close-up* portraits that
##                 read as people, not puppets — title-card framing is
##                 a mid-shot; files land as <out-base>-closeup-*.png)
##   --card M      slam the #349 busted/gaya card in after settling
##                 ("busted" = PAKDE GAYE with a 4-star sub-line,
##                 "gaya" = GAYA with the desat wash); ~75 frames of
##                 title tween + bar breathing play out before the
##                 capture, saving the full-screen README/IG card shot

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _ready() -> void:
	# Capture-trap guard (refs #296 sweep-5 prep): fail fast and loud when
	# launched --headless — the render texture never yields a frame there,
	# so the settle loop below would hang until SIGTERM. Guard before any
	# scene is instantiated so the refusal costs seconds, not minutes.
	if DisplayServer.get_name() == "headless":
		printerr("screenshot.gd: refusing --headless run — captures need "
				+ "the Xvfb GL context (see usage header); "
				+ "no frame would ever render")
		get_tree().quit(1)
		return
	var out := "/tmp/shot.png"
	var frames := 90
	var tp := Vector2(INF, INF)
	var look := Vector2(INF, INF)
	var day := -1.0
	var card := true
	var nclouds := false
	var noglow := false
	var nohud := false
	var nobeacon := false
	var camelev := 0.0
	var weather := ""
	var finale := false
	var ending := false
	var metro := false
	var title := false
	var cardmode := ""
	var closeup := false
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
		elif a == "--no-hud":
			nohud = true
		elif a == "--no-beacon":
			nobeacon = true
		elif a == "--cam-elev" and i + 1 < args.size():
			camelev = clampf(float(args[i + 1]), 0.5, 30.0)
		elif a == "--weather" and i + 1 < args.size():
			weather = String(args[i + 1])
		elif a == "--metro":
			metro = true
		elif a == "--finale":
			finale = true
		elif a == "--ending":
			ending = true
		elif a == "--title":
			title = true
		elif a == "--card" and i + 1 < args.size():
			cardmode = String(args[i + 1])
		elif a == "--closeup":
			closeup = true
		elif a == "--tp" and i + 1 < args.size():
			var bits := String(args[i + 1]).split(",")
			if bits.size() == 2:
				tp = Vector2(float(bits[0]), float(bits[1]))
		elif a == "--look" and i + 1 < args.size():
			var lb := String(args[i + 1]).split(",")
			if lb.size() == 2:
				look = Vector2(float(lb[0]), float(lb[1]))
		elif a == "--day" and i + 1 < args.size():
			day = clampf(float(args[i + 1]), 0.0, 1.0)

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if title:
		await _title_shot(main, out, frames, closeup)
		return
	if main.has_method("_start_game"):
		main._start_game(Game.CHARACTERS[0])
		if not card and main.has_method("_dismiss_controls_card"):
			main._dismiss_controls_card()

	if day >= 0.0 and "day_t" in main:
		main.day_t = day

	if weather != "":
		var wpin: Node = main.get("_weather")
		if wpin != null and wpin.has_method("debug_pin"):
			wpin.debug_pin(weather)

	if nclouds:
		var clouds: Node3D = main.get("_cloud_layer")
		if clouds != null:
			clouds.visible = false

	if noglow:
		var we: WorldEnvironment = main.get("world_env")
		if we != null:
			we.environment.glow_enabled = false

	if nohud:
		# Refs #293 acceptance pass: eyeball captures should read as
		# the world, not the UI. Hiding the CanvasLayers (HUD rails,
		# minimap, touch controls, tutorial card) is enough — the
		# viewport texture then holds only the 3D scene.
		for cl: CanvasLayer in main.find_children("*", "CanvasLayer",
				true, false):
			cl.visible = false

	if nobeacon:
		# Refs #293 attempt-12: the START HERE intro beacon (ring, beam
		# and world-space Label3D, missions.gd _spawn_giver) stands on
		# the thana plaza in every eastward shopfront sightline, and
		# --no-hud hides CanvasLayers only — not 3D mission markers.
		# Hide every giver's visuals the same way _show_giver(id, false)
		# does; the per-frame giver tick skips hidden rings, so the
		# state holds for the whole settle window.
		var missions: Node = main.get("_missions")
		if missions != null:
			var givers: Dictionary = missions.get("_givers")
			for id in givers:
				var g: Dictionary = givers[id]
				for part in ["ring", "beam", "label"]:
					if g.has(part) and g[part] != null:
						(g[part] as Node3D).visible = false

	if tp.x != INF and main.get("player") != null:
		var p: Node3D = main.get("player")
		p.position = Vector3(tp.x, p.position.y, tp.y)
		# Aimed captures (sweep-5 capture matrix, refs #296): point the
		# player at a world spot so the follow cam frames it — the chase
		# anchor sits behind the player's -Z and looks over the shoulder.
		if look.x != INF:
			p.look_at(Vector3(look.x, p.global_position.y, look.y),
					Vector3.UP)

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

	if cardmode != "":
		# Issue #349 acceptance: slam the busted/gaya card in post-settle
		# and let the title tween + bar breathing play out (~75 frames)
		# before the capture. This runs after --no-hud, so a paired flag
		# gives a clean world under the card.
		var bc: Node = main.get("_busted_card")
		if bc != null and bc.has_method("show_busted"):
			if cardmode == "busted":
				bc.show_busted(4, 400)
			else:
				bc.show_wasted()
			for i in range(75):
				await get_tree().process_frame

	if camelev > 0.0:
		# Refs #293 attempt 8 (doorway shot): lift the settled chase cam
		# M meters, re-aim at the player's head (the chase look point),
		# and freeze main's per-frame controllers — the chase ease would
		# otherwise pull the camera back down before the capture frame.
		var cam = main.get("camera")
		var pl: Node3D = main.get("player")
		if cam is Camera3D and pl != null:
			cam.global_position += Vector3.UP * camelev
			cam.look_at(pl.global_position + Vector3(0.0, 1.45, 0.0))
			main.set_process(false)
			main.set_physics_process(false)
			await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("screenshot saved: ", out)
	if main.get("player") != null:
		print("player at: ", main.get("player").position)
	var wstate: Node = main.get("_weather")
	if wstate != null:
		print("weather: ", wstate.get("label"),
				" intensity=%.3f" % wstate.get("intensity"),
				" cloud=%.3f" % wstate.get("cloud"),
				" wetness=%.3f" % wstate.get("wetness"))
	var jsrc: Node = main.get("_traffic")
	if jsrc != null and jsrc.has_method("jam_debug"):
		var jd: Dictionary = jsrc.jam_debug()
		print("jam: active=%s name=%s gaprun=%d on_jam_road=%d target=%d fleet=%d"
				% [str(jd.get("active", false)), jd.get("name", ""),
				int(jd.get("gaprun", 0)), int(jd.get("on_jam_road", 0)),
				int(jd.get("target", 0)), int(jd.get("fleet", 0))])
	get_tree().quit()


## Issue 152 reproduction + CI gate: capture the select screen itself —
## the full board plus each legend's portrait card from its own
## SubViewport — then quit nonzero when any pair of cards is
## pixel-near-identical (the all-pink-portraits regression).
func _title_shot(main: Node, out: String, frames: int,
		closeup := false) -> void:
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
	if closeup:
		# Refs #292: the acceptance is close-up portraits — capture the
		# face crops while the views are still live, before the gate.
		await _closeup_cards(views, names,
				main.get("_portrait_models"), out)
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


## Issue 292 close-up pass: re-frame each legend's portrait
## SubViewport camera tight on the face. The card cameras sit at a
## mid-shot distance (fov 30, 2.3 m); parking one at portrait distance
## on the legend's face line — eye height tracks each legend's own
## body height — yields a face-filling crop for the owner's eyeball
## pass vs art-ref-1. The SubViewports keep rendering (LivelyRig bone
## poses stay live), so two frames after the re-aim the texture holds
## the tight framing; the distinctness gate above still runs on the
## standard mid-shot cards.
func _closeup_cards(views: Array, names: Array, models: Array,
		out: String) -> void:
	for idx in range(views.size()):
		var vp: SubViewport = views[idx]
		var cams := vp.find_children("*", "Camera3D", true, false)
		if cams.is_empty():
			continue
		var cam: Camera3D = cams[0]
		var h: float = 1.72
		if idx < Game.CHARACTERS.size():
			h = float(Game.CHARACTERS[idx].get("height", 1.72))
		# Handoff audit 14:27 Nov-13: aiming at h - 0.12 lands on the
		# hairline (hair-only crops for monty/riya). The rig head sits
		# lower in the height field; aim at h - 0.25 so the face plane
		# fills the frame.
		var face_y := h - 0.25
		cam.fov = 22.0
		# Handoff audit 22:15 Nov-13: a FIXED +Z station crops whatever
		# the title idle happens to show — the select screen rotates
		# every legend holder at 0.7 rad/s (main.gd _process), so two of
		# three crops landed back-of-head. Orbit instead: read each
		# holder's live global basis, flatten to the floor, and park the
		# camera on the FACE bearing at portrait distance (spawn() authors
		# holders facing -Z, so forward = -basis.z).
		var focus := Vector3(0.0, face_y - 0.01, 0.0)
		var station := Vector3(0.0, face_y + 0.06, 0.85)
		var rig: Node3D = models[idx] if idx < models.size() else null
		if rig != null:
			var fwd := -rig.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() \
					if fwd.length_squared() > 0.0001 \
					else Vector3(0.0, 0.0, -1.0)
			focus = Vector3(rig.global_position.x, face_y - 0.01,
					rig.global_position.z)
			station = focus + fwd * 0.85 + Vector3.UP * 0.07
		cam.global_position = station
		cam.look_at(focus)
		await get_tree().process_frame
		await get_tree().process_frame
		var label := String(names[idx]) if idx < names.size() else str(idx)
		var p := out.get_base_dir().path_join(
				out.get_file().get_basename() + "-closeup-" + label + ".png")
		vp.get_texture().get_image().save_png(p)
		print("close-up card saved: ", p)


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
