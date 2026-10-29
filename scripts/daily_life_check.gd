extends Node
## Daily life gate (issue #185) — headless check that the city breathes on
## one clock. Boots the real game and asserts three rhythms at noon, deep
## night and the 08:00 chai rush:
##   1. Animated shop shutters stand open as lintel slats at noon and
##      close to full panels at night (scale + offset read back live).
##   2. The street crowd is full at noon, thins to ~40% at night and
##      refills through the morning rush.
##   3. Chai-stall market bulbs stay dark by day and glow after dusk.
## Usage:
##   godot --headless --path . res://scenes/daily_life_check.tscn
## Exits 0 with verdict=PASS when every rhythm holds, 2 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
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
	if life == null or peds == null or food == null:
		print("FAILED: daily life wiring missing (life/peds/food)")
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

	if problems.is_empty():
		print("DAILY LIFE CHECK PASS — shutters, crowds and chai rush on one clock")
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
