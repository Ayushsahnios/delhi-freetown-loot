extends Node
## Monsoon squall gate (issue #205) — headless capture of one full
## dry -> rain -> dry cycle on the real game clock. Boots the game,
## forces a deterministic rain window, then asserts every squall system
## moved with it:
##   1. Weather: dry streets, then intensity/wetness/cloud climb under
##      the window, then clear again while wetness lingers (drying out).
##   2. Audio: rain bed silent -> downpour level -> silent again; the
##      footstep surface flips to the wet squelch while roads soak and
##      stays wet through the drying phase; thunder flashes fire.
##   3. Food: the chai cart carries the rain-demand premium only while
##      it pours (surge pricing on, then off).
## Usage:
##   godot --headless --path . res://scenes/squall_check.tscn
## Exits 0 with verdict=PASS when the whole cycle holds, 2 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _flashes := 0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []

	var weather: Node = main.get("_weather")
	var audio: Node = main.get("_audio")
	var food: Node = main.get("_food")
	if weather == null or audio == null or food == null:
		print("FAILED: squall wiring missing (weather/audio/food)")
		get_tree().quit(2)
		return
	weather.thunder_flash.connect(func(_s: float) -> void: _flashes += 1)
	weather.debug_force_window(0.40, 0.52)

	# DRY — clock parked just before the window: bed silent, no premium.
	main.day_t = 0.36
	await _settle(2.0)
	var dry_int: float = weather.intensity
	var dry_bed: float = audio.get("_rain_player").volume_db
	var dry_price: int = food._price(food.CHAI)
	print("dry     intensity %.2f  bed %.0f dB  chai Rs %d"
			% [dry_int, dry_bed, dry_price])
	if dry_int > 0.05:
		problems.append("not dry before the window: intensity %.2f" % dry_int)
	if dry_bed > -55.0:
		problems.append("rain bed audible while dry: %.0f dB" % dry_bed)
	if dry_price != int(food.CHAI["price"]):
		problems.append("rain premium on a dry day: Rs %d" % dry_price)

	# RAIN — mid-window: downpour, soaked roads, squelch, thunder,
	# premium chai.
	main.day_t = 0.44
	await _settle(10.0)
	var rain_int: float = weather.intensity
	var rain_cloud: float = weather.cloud
	var rain_wet: float = weather.wetness
	var rain_bed: float = audio.get("_rain_player").volume_db
	var rain_foot: float = audio.get("_wetness")
	var rain_price: int = food._price(food.CHAI)
	print("rain    intensity %.2f  cloud %.2f  wet %.2f  bed %.0f dB  footing %.2f  chai Rs %d  flashes %d"
			% [rain_int, rain_cloud, rain_wet, rain_bed, rain_foot,
					rain_price, _flashes])
	if rain_int < 0.3:
		problems.append("no downpour mid-window: intensity %.2f" % rain_int)
	if rain_cloud < 0.4:
		problems.append("sky did not cloud over: %.2f" % rain_cloud)
	if rain_wet < 0.1:
		problems.append("roads never soaked: wetness %.2f" % rain_wet)
	if rain_bed < -35.0:
		problems.append("rain bed too quiet mid-squall: %.0f dB" % rain_bed)
	if rain_foot < 0.2:
		problems.append("footing never went wet: %.2f" % rain_foot)
	if rain_price <= int(food.CHAI["price"]):
		problems.append("no rain-demand premium mid-squall: Rs %d" % rain_price)
	if _flashes < 1:
		problems.append("no thunder flash during the squall")

	# DRYING — past the window: bed off, streets still damp, squelch
	# lingers, premium gone.
	main.day_t = 0.62
	await _settle(8.0)
	var end_int: float = weather.intensity
	var end_wet: float = weather.wetness
	var end_bed: float = audio.get("_rain_player").volume_db
	var end_foot: float = audio.get("_wetness")
	var end_price: int = food._price(food.CHAI)
	print("drying  intensity %.2f  wet %.2f  bed %.0f dB  footing %.2f  chai Rs %d"
			% [end_int, end_wet, end_bed, end_foot, end_price])
	if end_int > 0.05:
		problems.append("rain never stopped: intensity %.2f" % end_int)
	if end_wet < 0.1:
		problems.append("streets dried instantly: wetness %.2f" % end_wet)
	if end_bed > -55.0:
		problems.append("rain bed stuck on after the squall: %.0f dB" % end_bed)
	if end_foot < 0.15:
		problems.append("squelch died the instant rain stopped: %.2f" % end_foot)
	if end_price != int(food.CHAI["price"]):
		problems.append("rain premium stuck after the squall: Rs %d" % end_price)

	if problems.is_empty():
		print("verdict=PASS")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		print("verdict=FAIL")
		get_tree().quit(2)


func _settle(seconds: float) -> void:
	## Let the game loop run real time so the per-second ramps (rain
	## intensity, wetness soak/dry) actually play out.
	var timer := get_tree().create_timer(seconds)
	while timer.time_left > 0.0:
		await get_tree().process_frame
