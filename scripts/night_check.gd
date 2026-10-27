extends Node
## Night lighting check (issue #102) — headless gate for the dusk light
## path. Boots the real game, forces deep night then full noon, and
## asserts:
##   1. The lamp network exists (≥ 10 OmniLights: landmarks + market lane).
##   2. Window emission ramps on at night (≥ 1.5) and off at noon (0).
##   3. Every street lamp glows at night (≥ 1.0) and sleeps at noon (0).
## Usage:
##   godot --headless --path . res://scenes/night_check.tscn
## Exits 0 when the night path passes, 2 with a FAILED report otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []

	# Deep night: day_t 0.02 keeps the sun well below the horizon.
	main.day_t = 0.02
	for i in range(10):
		await get_tree().process_frame
	var win_mat: StandardMaterial3D = main.get("_win_lit_mat")
	var lights: Array = main.get("_street_lights")
	var win_n := win_mat.emission_energy_multiplier
	var lamp_min_n := INF
	for l: OmniLight3D in lights:
		lamp_min_n = minf(lamp_min_n, l.light_energy)
	print("night  t=%.2f  window emission %.2f  dimmest lamp %.2f  (%d lamps)"
			% [main.day_t, win_n, lamp_min_n, lights.size()])
	if lights.size() < 10:
		problems.append("only %d street lights — expected ≥ 10 (8 landmarks + 3 market lane)"
				% lights.size())
	if win_n < 1.5:
		problems.append("window emission %.2f at night — expected ≥ 1.5" % win_n)
	if lamp_min_n < 1.0:
		problems.append("dimmest lamp %.2f at night — expected ≥ 1.0" % lamp_min_n)

	# Full noon: everything above should switch fully off.
	main.day_t = 0.5
	for i in range(10):
		await get_tree().process_frame
	var win_d := win_mat.emission_energy_multiplier
	var lamp_max_d := 0.0
	for l: OmniLight3D in lights:
		lamp_max_d = maxf(lamp_max_d, l.light_energy)
	print("noon   t=%.2f  window emission %.2f  brightest lamp %.2f"
			% [main.day_t, win_d, lamp_max_d])
	if not is_zero_approx(win_d):
		problems.append("window emission %.2f at noon — expected 0" % win_d)
	if lamp_max_d > 0.01:
		problems.append("brightest lamp %.2f at noon — expected 0" % lamp_max_d)

	if problems.is_empty():
		print("NIGHT CHECK PASS — dusk path live (windows + %d lamps)" % lights.size())
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		get_tree().quit(2)
