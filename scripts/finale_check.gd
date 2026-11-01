extends Node
## Legend finale gate (issue #264) — headless acceptance for the three
## closing chains and their persistent payoffs. Boots the real game as
## Sardar Ji and verifies:
##   (A) all nine finale arcs are registered with the mission system
##   (B) chain openers stay gated until finale_monty is done AND eight
##       total completions sit on the résumé (need_done)
##   (C) each chain's closing step fires payoff_unlocked exactly once
##       and lands its effect: dhaba sign node, doubled courier streak
##       cap (6 -> 12), one-star police heat discount, wardrobe looks
##   (D) the payoff looks land owned on the rack and the payoff set
##       round-trips through the save dict
##   (E) re-applying payoffs never duplicates the sign (idempotent)
## ...plus a PNG capture of the dhaba sign under xvfb for human eyes.
## Usage:
##   godot --headless --path . res://scenes/finale_check.tscn
## Usage (capture):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 res://scenes/finale_check.tscn -- \
##     --out docs/screenshots/dhaba-empire-264.png

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Game := preload("res://scripts/game.gd")
const CourierScript := preload("res://scripts/courier.gd")

const ARC_IDS := [
	"empire_1_licence", "empire_2_tandoor", "empire_3_name",
	"franchise_1_pitch", "franchise_2_fleet", "franchise_3_signing",
	"don_1_round", "don_2_fold", "don_3_word",
]

var _problems: Array[String] = []
var _payoff_kinds: Array[String] = []


func _ready() -> void:
	var out := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--out" and i + 1 < args.size():
			out = String(args[i + 1])
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start_game(Game.CHARACTERS[0])
	await get_tree().process_frame
	var missions: Node = main.get("_missions")
	var courier: Node = main.get("_courier")
	var police: Node = main.get("_police")
	var wardrobe: Node = main.get("_wardrobe")
	if missions == null or courier == null or police == null \
			or wardrobe == null:
		_fail("game wiring missing (missions/courier/police/wardrobe)")
		_finish(main, out)
		return
	missions.payoff_unlocked.connect(_on_payoff)

	# (A) registration — all nine arcs on the mission table.
	var ids := {}
	for def in missions._defs:
		ids[String(def["id"])] = def
	for id in ARC_IDS:
		if not ids.has(id):
			_fail("(A) arc missing from mission defs: " + id)

	# (B) need_done gate: the opener stays locked until the résumé hits
	# eight completions AND the shared finale (#96) is closed.
	if String(missions._states.get("empire_1_licence", "locked")) == "available":
		_fail("(B) empire opener available before résumé threshold")
	missions.completed = {"finale_monty": 1, "m1": 1, "m2": 1, "m3": 1,
			"m4": 1, "m5": 1, "m6": 1, "m7": 1}
	missions._refresh_finale_gates()
	if String(missions._states.get("empire_1_licence", "")) != "available":
		_fail("(B) empire opener still gated at 8 completions + finale done")

	# (C) payoffs fire once, ever, and land their effects.
	_complete(missions, ids.get("empire_3_name", {}))
	if not bool(missions.payoffs.get("dhaba_empire", false)):
		_fail("(C) dhaba_empire payoff not armed")
	if main.get_node_or_null(NodePath("DhabaEmpireSign")) == null:
		_fail("(C) dhaba sign node missing after payoff")
	_complete(missions, ids.get("franchise_3_signing", {}))
	if courier.streak_cap() != CourierScript.STREAK_CAP * 2:
		_fail("(C) franchise streak cap not doubled: %d" % courier.streak_cap())
	_complete(missions, ids.get("don_3_word", {}))
	if not police.respect:
		_fail("(C) police respect flag not set")
	police.heat = 0.0
	police._raise(1.5)
	if absf(police.heat - 0.5) > 0.01:
		_fail("(C) heat discount wrong: %.2f" % police.heat)
	var kinds_before := _payoff_kinds.size()
	_complete(missions, ids.get("don_3_word", {}))
	if _payoff_kinds.size() != kinds_before:
		_fail("(C) payoff fired twice on re-complete")

	# (D) rack ownership + save round-trip.
	if not wardrobe.owns("riya", "franchise"):
		_fail("(D) franchise jacket not owned")
	if not wardrobe.owns("monty", "goldchain"):
		_fail("(D) gold chain not owned")
	var data: Dictionary = main._collect_save()
	if not data.has("legend_payoffs") \
			or data["legend_payoffs"].size() != 3:
		_fail("(D) save dict missing legend payoffs")

	# (E) idempotent re-apply — one sign, flags unchanged.
	missions.restore_payoffs(data.get("legend_payoffs", {}))
	main._apply_legend_payoffs()
	var count := 0
	for c in main.get_children():
		if String(c.name) == "DhabaEmpireSign":
			count += 1
	if count != 1:
		_fail("(E) sign duplicated: %d nodes" % count)

	# Perf note for the PR: sign mesh surface + triangle count.
	var sign: MeshInstance3D = main.get_node_or_null(NodePath("DhabaEmpireSign"))
	if sign != null and sign.mesh is ArrayMesh:
		var mesh: ArrayMesh = sign.mesh
		var tris := 0
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idxa = arrays[Mesh.ARRAY_INDEX]
			if idxa != null and idxa.size() > 0:
				tris += idxa.size() / 3
			else:
				tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("dhaba sign mesh: %d surfaces, %d tris"
				% [mesh.get_surface_count(), tris])

	if _payoff_kinds.size() != 3:
		_fail("(C) payoff signal fired %d times, expected 3" % _payoff_kinds.size())
	_finish(main, out)


func _complete(missions: Node, def: Dictionary) -> void:
	## Drive the real completion path with a stub active mission —
	## reward, ledger, gates, outro and the payoff guard all run.
	if def.is_empty():
		_fail("(C) payoff mission def missing")
		return
	missions._active = {"def": def, "time": 0.0, "left": 0.0,
			"stage": 0, "objs": []}
	missions._complete_mission()


func _on_payoff(kind: String, _label: String) -> void:
	_payoff_kinds.append(kind)


func _fail(msg: String) -> void:
	_problems.append(msg)


func _finish(main: Node, out: String) -> void:
	if out != "":
		main.player.global_position = Vector3(6.0, 1.2, 61.0)
		main.player.rotation.y = PI
		await get_tree().create_timer(0.8).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("finale_check capture saved: " + out)
		await get_tree().create_timer(0.2).timeout
	if _problems.is_empty():
		print("FINALE_CHECK PASS — 9 arcs, gates, 3 payoffs, effects, save round-trip")
		print("verdict=PASS")
		get_tree().quit(0)
	else:
		for p in _problems:
			print("FINALE_CHECK FAILED: " + p)
		print("verdict=FAIL")
		get_tree().quit(2)
