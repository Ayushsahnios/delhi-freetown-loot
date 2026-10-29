extends Node
## Scripted loudness check (issue #94) — headless CI gate for the audio mix.
## Instantiates the real synthesis (Audio + Radio), measures every channel's
## peak/RMS in dBFS with its loudest volume_db applied, and asserts:
##   1. Headroom — no channel peaks above -3 dBFS.
##   2. Bed balance — ambient/rain/radio RMS within 8 dB of each other.
##   3. Horn audible but not painful — 6..20 dB over the ambient bed RMS.
##   4. Thunder never dominates the horn — thunder peak ≤ horn peak + 3 dB.
##   5. Master limiter present on the Master bus with ceiling ≤ -0.1 dB.
##
## Usage:
##   godot --headless --path . res://scenes/loudness_check.tscn
## Exits 0 when the mix passes, 2 with a FAILED report otherwise.

const AUDIO_SCRIPT := preload("res://scripts/audio.gd")
const RADIO_SCRIPT := preload("res://scripts/radio.gd")
const CHASE_SCRIPT := preload("res://scripts/chase_music.gd")

const HEADROOM_DB := -3.0
const BED_SPREAD_DB := 8.0
const HORN_FLOOR_OVER_BED_DB := 6.0
const HORN_CEIL_OVER_BED_DB := 20.0
const THUNDER_OVER_HORN_DB := 3.0


func _ready() -> void:
	var audio := AUDIO_SCRIPT.new()
	add_child(audio)
	audio.setup()
	var radio := RADIO_SCRIPT.new()
	add_child(radio)
	radio.setup()
	var chase := CHASE_SCRIPT.new()
	add_child(chase)
	chase.setup()

	var channels: Array = audio.loudness_profile() + radio.loudness_profile() \
			+ chase.loudness_profile()
	if channels.is_empty():
		_fail("loudness profiles came back empty — synthesis not built")
		return
	var by := {}
	for c in channels:
		by[String(c["name"])] = c
		print("%14s peak %7.1f dBFS   rms %7.1f dBFS" % [
			c["name"], c["peak_db"], c["rms_db"]])

	var problems: Array[String] = []

	for c in channels:
		if float(c["peak_db"]) > HEADROOM_DB:
			problems.append("%s peaks at %.1f dBFS — above %.1f headroom floor" % [
				c["name"], c["peak_db"], HEADROOM_DB])

	var beds := [float(by["ambient"]["rms_db"]), float(by["rain"]["rms_db"]),
		float(by["radio"]["rms_db"])]
	if beds.max() - beds.min() > BED_SPREAD_DB:
		problems.append("bed spread %.1f dB exceeds %.1f dB (ambient %.1f / rain %.1f / radio %.1f)" % [
			beds.max() - beds.min(), BED_SPREAD_DB, beds[0], beds[1], beds[2]])

	var horn_over_bed := float(by["horn"]["peak_db"]) - float(by["ambient"]["rms_db"])
	if horn_over_bed < HORN_FLOOR_OVER_BED_DB:
		problems.append("horn only %.1f dB over the ambient bed — needs ≥ %.1f to be audible" % [
			horn_over_bed, HORN_FLOOR_OVER_BED_DB])
	elif horn_over_bed > HORN_CEIL_OVER_BED_DB:
		problems.append("horn is %.1f dB over the ambient bed — painfully loud, cap is %.1f" % [
			horn_over_bed, HORN_CEIL_OVER_BED_DB])

	if float(by["thunder"]["peak_db"]) > float(by["horn"]["peak_db"]) + THUNDER_OVER_HORN_DB:
		problems.append("thunder peak %.1f dBFS dominates horn %.1f dBFS by more than %.1f dB" % [
			by["thunder"]["peak_db"], by["horn"]["peak_db"], THUNDER_OVER_HORN_DB])

	if not _master_has_limiter():
		problems.append("Master bus has no AudioEffectLimiter with ceiling ≤ -0.1 dB")

	if problems.is_empty():
		print("LOUDNESS PASS — %d channels, headroom, bed balance, horn and thunder bounds all OK" % channels.size())
		get_tree().quit(0)
	else:
		_fail("\n".join(problems))


func _master_has_limiter() -> bool:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return false
	for e in AudioServer.get_bus_effect_count(master):
		var fx := AudioServer.get_bus_effect(master, e)
		if fx is AudioEffectLimiter and fx.ceiling_db <= -0.1:
			return true
	return false


func _fail(why: String) -> void:
	push_error("LOUDNESS FAIL — " + why)
	printerr("LOUDNESS FAIL — " + why)
	get_tree().quit(2)
