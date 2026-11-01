extends Node
## Daily life gate (issue #185) — headless check that the city breathes on
## one clock. Boots the real game and asserts three rhythms at noon, deep
## night and the 08:00 chai rush:
##   1. Animated shop shutters stand open as lintel slats at noon and
##      close to full panels at night (scale + offset read back live).
##   2. The street crowd is full at noon, thins to ~40% at night and
##      refills through the morning rush.
##   3. Chai-stall market bulbs stay dark by day and glow after dusk.
##   4. Traffic breathes on the same clock (issue #268): the fleet sits
##      at 19 in the midday lull, thins to 13 in the late-night quiet
##      band, holds the 22 baseline at 16:30 and peaks at 32 through
##      the 08:30 rush — night < lull < baseline < rush.
## Usage:
##   godot --headless --path . res://scenes/daily_life_check.tscn
## Exits 0 with verdict=PASS when every rhythm holds, 2 otherwise.
## Usage (captures, issue #268 rush vs lull for human eyes):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 res://scenes/daily_life_check.tscn -- \
##     --out-lull docs/screenshots/traffic-lull-268.png \
##     --out-rush docs/screenshots/traffic-rush-268.png

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var out_lull := ""
	var out_rush := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--out-lull" and i + 1 < args.size():
			out_lull = String(args[i + 1])
		elif String(args[i]) == "--out-rush" and i + 1 < args.size():
			out_rush = String(args[i + 1])
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []

	var life: Node = main.get("_daily_life")
	var peds: Node = main.get("_peds")
	var food: Node = main.get("_food")
	var traffic: Node = main.get("_traffic")
	if life == null or peds == null or food == null or traffic == null:
		print("FAILED: daily life wiring missing (life/peds/food/traffic)")
		get_tree().quit(2)
		return

	# Noon: shutters open to lintel slats, full crowd, bulbs dark.
	main.day_t = 0.5
	await _settle(main)
	var noon_probe: Dictionary = life.shutter_probe(0)
	var noon_dbg: Dictionary = peds.life_debug()
	var noon_bulb: float = food.get("_bulb_mat").emission_energy_multiplier
	print("noon    shutters sy=%.2f dy=%+.2f  crowd %d/%d base  bulb %.2f"
			% [noon_probe.get("sy", -1.0), noon_probe.get("dy", 99.0),
			noon_dbg["base_visible"], noon_dbg["base_total"], noon_bulb])
	if not noon_probe["wired"] or noon_probe["instances"] < 1 \
			or noon_probe["sy"] > 0.3 or noon_probe["dy"] < 0.8:
		problems.append("noon shutter open-state wrong: %s" % [noon_probe])
	if noon_dbg["base_visible"] < noon_dbg["base_total"]:
		problems.append("noon crowd %d/%d — expected full street"
				% [noon_dbg["base_visible"], noon_dbg["base_total"]])
	if noon_bulb > 0.05:
		problems.append("market bulb glowing at noon: %.2f" % noon_bulb)
	# Traffic rhythm (issue #268): noon sits inside the midday lull band
	# (0.85x of the 22 baseline = 19 on the street).
	await _settle_wave(traffic, 10.0)
	var noon_wave: Dictionary = traffic.wave_debug()
	print("noon    fleet %d target (mult %.2f) — midday lull  t_h=%.2f life_h=%.2f"
			% [noon_wave["fleet"], noon_wave["mult"], noon_wave["hours"], life.hours])
	if int(noon_wave["target"]) != 19 or int(noon_wave["fleet"]) != 19:
		problems.append("noon traffic fleet %d target %d — expected lull 19"
				% [noon_wave["fleet"], noon_wave["target"]])
	if out_lull != "":
		await _capture(out_lull, "lull")

	# Deep night: shutters closed, crowd thinned to the keep floor, bulbs on.
	main.day_t = 0.02
	await _settle(main)
	var night_probe: Dictionary = life.shutter_probe(0)
	var night_dbg: Dictionary = peds.life_debug()
	var night_bulb: float = food.get("_bulb_mat").emission_energy_multiplier
	print("night   shutters sy=%.2f dy=%+.2f  crowd %d/%d base  bulb %.2f"
			% [night_probe.get("sy", -1.0), night_probe.get("dy", 99.0),
			night_dbg["base_visible"], night_dbg["base_total"], night_bulb])
	if not night_probe["wired"] or night_probe["sy"] < 0.95 \
			or absf(float(night_probe["dy"])) > 0.05:
		problems.append("night shutter closed-state wrong: %s" % [night_probe])
	var keep_ratio := float(night_dbg["base_visible"]) \
			/ maxf(1.0, float(night_dbg["base_total"]))
	if keep_ratio > 0.55 or keep_ratio < 0.25:
		problems.append("night crowd ratio %.2f — expected ~0.40 keep floor"
				% keep_ratio)
	if night_bulb < 2.0:
		problems.append("night market bulb %.2f — expected ≥ 2.0" % night_bulb)
	# Traffic quiet band (issue #268): 0.6x of baseline = 13.
	await _settle_wave(traffic, 12.0)
	var night_wave: Dictionary = traffic.wave_debug()
	print("night   fleet %d target (mult %.2f) — quiet band  t_h=%.2f life_h=%.2f"
			% [night_wave["fleet"], night_wave["mult"], night_wave["hours"], life.hours])
	if int(night_wave["target"]) != 13 or int(night_wave["fleet"]) != 13:
		problems.append("night traffic fleet %d target %d — expected quiet 13"
				% [night_wave["fleet"], night_wave["target"]])

	# Chai rush 08:00: the bazaar zone squads refill even on a dim hour —
	# step into the first crowd zone so the squads are awake to show it.
	var zones: Array = peds.get("_zones")
	main.player.global_position = zones[0]["c"] + Vector3(0.0, 2.0, 0.0)
	main.day_t = 8.0 / 24.0
	await _settle(main)
	var rush_dbg: Dictionary = peds.life_debug()
	var rush_food := float(food.rush_f)
	print("rush    crowd %d/%d zone  rush=%.0f  hours=%.1f"
			% [rush_dbg["zone_visible"], rush_dbg["zone_total"],
			rush_food, life.hours])
	if rush_dbg["zone_target"] < rush_dbg["zone_total"] \
			or rush_dbg["zone_visible"] < rush_dbg["zone_total"] * 0.9:
		problems.append("chai rush zone crowd %d/%d (target %d) — expected refill"
				% [rush_dbg["zone_visible"], rush_dbg["zone_total"],
				rush_dbg["zone_target"]])
	if rush_food < 1.0:
		problems.append("food stalls report no rush (rush_f=%.2f)" % rush_food)
	# Traffic wave (issue #268): baseline at 16:30, then the morning
	# rush plateau at 08:30 — the fleet must climb 13 < 19 < 22 < 32
	# across the four probe hours.
	main.day_t = 16.5 / 24.0
	await _settle(main)
	await _settle_wave(traffic, 12.0)
	var base_wave: Dictionary = traffic.wave_debug()
	print("16:30   fleet %d target (mult %.2f) — baseline  t_h=%.2f life_h=%.2f"
			% [base_wave["fleet"], base_wave["mult"], base_wave["hours"], life.hours])
	if int(base_wave["target"]) != 22 or int(base_wave["fleet"]) != 22:
		problems.append("baseline traffic fleet %d target %d — expected 22"
				% [base_wave["fleet"], base_wave["target"]])
	main.day_t = 8.5 / 24.0
	await _settle(main)
	await _settle_wave(traffic, 12.0)
	var rush_wave: Dictionary = traffic.wave_debug()
	print("rush    fleet %d target (mult %.2f) — 08:30 peak  t_h=%.2f life_h=%.2f"
			% [rush_wave["fleet"], rush_wave["mult"], rush_wave["hours"], life.hours])
	if int(rush_wave["target"]) != 32 or int(rush_wave["fleet"]) != 32:
		problems.append("rush traffic fleet %d target %d — expected peak 32"
				% [rush_wave["fleet"], rush_wave["target"]])
	if out_rush != "":
		await _capture(out_rush, "rush")

	if problems.is_empty():
		print("DAILY LIFE CHECK PASS — shutters, crowds, chai rush and traffic wave on one clock")
		print("verdict=PASS")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		print("verdict=FAIL")
		get_tree().quit(2)


func _settle(main: Node) -> void:
	## A dozen frames lets _update_day push day_t through daily_life.tick
	## and the pedestrian physics loop apply the new visibility targets.
	for i in range(12):
		await get_tree().process_frame


func _settle_wave(traffic: Node, secs: float) -> void:
	## The traffic wave (issue #268) rolls in at one vehicle per 0.2 s
	## and retires on a 6 s grace beat, so unlike the per-frame crowd
	## state it needs real seconds to reach its target.
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var w: Dictionary = traffic.wave_debug()
		if int(w["fleet"]) == int(w["target"]):
			return


func _capture(path: String, label: String) -> void:
	## Rush vs lull captures (issue #268 acceptance): save what the
	## street looks like at this probe hour for human eyeballs. Skipped
	## in the pure headless gate (no --out args, no GPU to read back).
	for i in range(30):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("daily_life_check %s capture saved: %s" % [label, path])
