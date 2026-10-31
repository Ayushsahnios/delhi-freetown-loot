extends Node
## Graphics quality gate (issue 270) — asserts the preset switch end to
## end on the real game, headless:
##   1. Boot default is AUTO with an armed FPS watcher once play starts.
##   2. A LOW switch re-tiers every LOD-tiered node to ~55 % of its base
##      draw distance, trims the crowd cap and tightens the sun shadow
##      map; a HIGH switch restores the exact base tiers (no drift).
##   3. The AUTO watcher drops a struggling session to LOW on synthetic
##      windows without touching the stored setting.
##   4. settings.json round-trips the new quality key and sanitizes a
##      tampered value back to AUTO.
## Usage:
##   godot --headless --path . res://scenes/quality_check.tscn
## Exits 0 with verdict=PASS when every leg holds, 2 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const QualityScript := preload("res://scripts/quality.gd")
const LodScript := preload("res://scripts/lod.gd")
const PedestrianScript := preload("res://scripts/pedestrians.gd")
const PauseScript := preload("res://scripts/pause.gd")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var problems: Array[String] = []

	# Leg 1 — boot default + watcher armed.
	if String(main.get("_quality_mode")) != "auto":
		problems.append("boot mode is %s, want auto" % main.get("_quality_mode"))
	if main.get("_quality_watch") == null:
		problems.append("AUTO boot did not arm the FPS watcher")

	# Leg 2 — LOW switch: tiers, crowd cap, shadow map, then restore.
	# One fixed probe node is tracked by reference, so the assert reads
	# the SAME geometry before, during and after (a fresh tree walk could
	# hit a vehicle spawned between the legs).
	var probe := _first_tiered(main)
	var base := -1.0
	var low_end := -1.0
	if probe == null:
		problems.append("no LOD-tiered geometry found under main")
	else:
		base = float(probe.get_meta("lod_end_base"))
	main.apply_quality_now("low")
	await get_tree().process_frame
	if is_instance_valid(probe) and base > 0.0:
		low_end = probe.visibility_range_end
	else:
		low_end = -1.0
	if absf(low_end - base * QualityScript.LOW_LOD_SCALE) > 0.75:
		problems.append("LOW tier %.1f != base %.1f x 0.55" % [low_end, base])
	if absf(float(PedestrianScript.crowd_scale) - QualityScript.LOW_CROWD_SCALE) > 0.001:
		problems.append("LOW crowd scale %s, want 0.6" % PedestrianScript.crowd_scale)
	var sun: DirectionalLight3D = main.get("sun")
	if sun.directional_shadow_mode != DirectionalLight3D.SHADOW_ORTHOGONAL:
		problems.append("LOW sun shadow mode is not the tight ortho map")
	if absf(sun.directional_shadow_max_distance - QualityScript.LOW_SHADOW_MAX) > 0.001:
		problems.append("LOW shadow distance %s, want 55" % sun.directional_shadow_max_distance)
	main.apply_quality_now("high")
	await get_tree().process_frame
	var back := -1.0
	if is_instance_valid(probe):
		back = probe.visibility_range_end
	if absf(back - base) > 0.75:
		problems.append("HIGH restore %.1f drifted from base %.1f" % [back, base])

	# Leg 3 — watcher synthetic drop: two bad windows drop the session,
	# the stored setting stays untouched (main holds the truth here).
	main.apply_quality_now("auto")
	await get_tree().process_frame
	var watch: Node = main.get("_quality_watch")
	if watch == null:
		problems.append("re-arming AUTO did not respawn the watcher")
	else:
		watch._consider(20.0)
		if bool(watch.get("_dropped")):
			problems.append("one bad window dropped the session, want two")
		watch._consider(20.0)
		if not bool(watch.get("_dropped")):
			problems.append("two bad windows did not drop the session")
		if not bool(main.get("_quality_low")):
			problems.append("auto-drop did not apply LOW knobs")
		if String(main.get("_quality_mode")) != "auto":
			problems.append("auto-drop changed the stored mode")

	# Leg 4 — settings round trip + sanitize, original settings restored.
	var original := PauseScript.load_settings()
	PauseScript.write_settings({"quality": "low"})
	if String(PauseScript.load_settings().get("quality", "")) != "low":
		problems.append("settings.json did not round-trip quality=low")
	PauseScript.write_settings({"quality": "turbo"})
	if String(QualityScript.sanitize(String(
			PauseScript.load_settings().get("quality", "")))) != "auto":
		problems.append("tampered quality value did not sanitize to auto")
	if original.is_empty():
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("settings.json")
	else:
		PauseScript.write_settings(original)

	for p in problems:
		print("FAILED: %s" % p)
	print("QUALITY_CHECK legs=4 verdict=%s" % ("PASS" if problems.is_empty() else "FAIL"))
	get_tree().quit(0 if problems.is_empty() else 2)


func _first_tiered(root: Node) -> GeometryInstance3D:
	## First LOD-tiered geometry under `root` (lod.gd stamps every tiered
	## node with its unscaled base distance meta).
	var stack: Array[Node] = root.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var gi := n as GeometryInstance3D
		if gi != null and gi.has_meta("lod_end_base") \
				and gi.visibility_range_end > 0.0:
			return gi
		for c in n.get_children():
			stack.push_back(c)
	return null
