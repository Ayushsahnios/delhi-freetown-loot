extends Node
## tools/qa/soak273.gd — 30-minute headless long-run soak on the real game
## (QA driver, issue #273 lineage; vendored for issue #296 / sweep 5).
## v1.1 — units fix: Performance.MEMORY_STATIC is BYTES; all prints and
## the drift verdict now convert bytes -> KB at the point of use.
##
## Boots main.tscn, starts the first legend, dismisses the first-boot
## card, then lets the full simulation run while hopping between
## landmarks every 2 minutes (exercises LOD wake/sleep, crowd zones,
## traffic, day cycle). Samples drift monitors every 60 s: orphan nodes,
## static memory, walker count, player sanity. Verdict lines print
## SOAK273 PASS/FAIL. Published record: docs/qa/soak273.md (+ sweep-4).

const MAIN_SCENE := preload("res://scenes/main.tscn")

const SOAK_MINUTES := 30
const TICK_SEC := 60.0
const HOP_SEC := 120.0

var main: Node = null
var fails: Array[String] = []
var passes := 0
var _orphans: Array[int] = []
var _mem: Array[int] = []  # raw BYTES from Performance.MEMORY_STATIC

func _note(ok: bool, msg: String) -> void:
	if ok:
		passes += 1
		print("SOAK273 PASS — " + msg)
	else:
		fails.append(msg)
		print("SOAK273 FAIL — " + msg)

func _w(sec: float) -> void:
	var target := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < target:
		await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = MAIN_SCENE.instantiate()
	add_child(main)
	await _w(1.0)
	main._start_game(Game.CHARACTERS[0])
	main._dismiss_controls_card()
	await _w(2.0)

	var landmarks: Array[Vector3] = []
	for lm in main._landmarks:
		landmarks.append(Vector3(lm["center"].x, 1.0, lm["center"].z))
	if landmarks.is_empty():
		landmarks.append(main.player.global_position)

	var deadline := Time.get_ticks_msec() + SOAK_MINUTES * 60_000
	var hop_i := 0
	while Time.get_ticks_msec() < deadline:
		var next_hop := Time.get_ticks_msec() + int(HOP_SEC * 1000.0)
		var next_tick := Time.get_ticks_msec() + int(TICK_SEC * 1000.0)
		main._cam_anchor = landmarks[hop_i % landmarks.size()]
		main.player.global_position = landmarks[hop_i % landmarks.size()] + Vector3(0.0, 0.4, 0.0)
		main.player.velocity = Vector3.ZERO
		hop_i += 1
		while Time.get_ticks_msec() < minf(next_hop, deadline):
			await get_tree().process_frame
			if Time.get_ticks_msec() >= next_tick:
				var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
				var mem_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
				var mem_kb := mem_bytes / 1024
				_orphans.append(orphans)
				_mem.append(mem_bytes)
				var walkers := 0
				if main._peds != null and main._peds.get("_peds") != null:
					walkers = main._peds._peds.size()
				var p: Vector3 = main.player.global_position
				var sane: bool = is_instance_valid(main.player) and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
				print("SOAK273 tick t=%ds orphans=%d mem_kb=%d walkers=%d day_t=%.2f player_sane=%s"
						% [(SOAK_MINUTES * 60_000 - maxi(0, int(deadline - Time.get_ticks_msec()))) / 1000,
							orphans, mem_kb, walkers, float(main.day_t), str(sane)])
				if not sane:
					_note(false, "player went NaN/invalid during soak")
					_finish()
					return
				next_tick = Time.get_ticks_msec() + int(TICK_SEC * 1000.0)

	# ---- Verdicts -------------------------------------------------
	_note(is_instance_valid(main.player) and main._playing, "player alive and playing after 30 min")
	var drift: int = _orphans.back() - _orphans.front() if _orphans.size() >= 2 else 0
	_note(drift < 2000, "orphan-node drift over soak: %+d (start %d → end %d)"
			% [drift, _orphans.front() if not _orphans.is_empty() else -1, _orphans.back() if not _orphans.is_empty() else -1])
	# MEMORY_STATIC is bytes: convert drift to KB before the threshold
	# check, else a ~2 MB drift reads as ~1.8 million "KB" and false-fails.
	var memdrift_kb: int = (_mem.back() - _mem.front()) / 1024 if _mem.size() >= 2 else 0
	_note(memdrift_kb < 200_000, "static-memory drift over soak: %+d KB (start %d KB → end %d KB)"
			% [memdrift_kb,
				_mem.front() / 1024 if not _mem.is_empty() else -1,
				_mem.back() / 1024 if not _mem.is_empty() else -1])
	_finish()

func _finish() -> void:
	print("SOAK273 SUMMARY passes=%d fails=%d ticks=%d" % [passes, fails.size(), _orphans.size()])
	for f in fails:
		print("SOAK273 FAILED: " + f)
	get_tree().quit(0 if fails.is_empty() else 7)
