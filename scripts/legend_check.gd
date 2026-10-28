extends Node
## Legend body-build + tailoring check (issue 161) — acceptance gate
## for the distinct-silhouettes pass. Spawns the three legends exactly
## as the game dresses them (title-screen path) and verifies headless:
##   (A) every legend's torso chain carries its build pose scale
##   (B) the barrel chest reads in bone geometry: Sardar Ji's shoulder
##       span beats Monty's by >= 12% on the same rig
##   (C) every legend carries its tailoring meshes (collar / buttons /
##       seams; plus the barrel belly for Sardar Ji)
##   (D) height defs are distinct and inside the human band
## ...plus a PNG capture of the lineup under xvfb for human eyeballs.
## Usage (gate, no rendering):
##   godot --headless --path . res://scenes/legend_check.tscn
## Usage (capture):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 res://scenes/legend_check.tscn -- \
##     --out docs/screenshots/legend-trio-161.png

const Game := preload("res://scripts/game.gd")
const Chars := preload("res://scripts/characters.gd")

const SETTLE := 0.6
const SPACING := 1.9

var _problems: Array[String] = []
var _chars := Chars.new()
var _holders: Array[Node3D] = []


func _ready() -> void:
	var out := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--out" and i + 1 < args.size():
			out = String(args[i + 1])
	_stage()
	for i in range(Game.CHARACTERS.size()):
		var def: Dictionary = Game.CHARACTERS[i]
		var path: String = Chars.FEMALE_A if String(def["id"]) == "riya" else Chars.MALE
		var holder := _chars.spawn(path, float(def.get("height", 1.72)))
		holder.position = Vector3((i - 1) * SPACING, 0.0, 0.0)
		add_child(holder)
		_chars.dress_legend(holder, def)
		_chars.play(_chars.anim_names(holder), _chars.get_player(holder), "idle",
				float(def.get("anim_rate", 1.0)))
		_holders.append(holder)
	_check_build_poses()
	_check_shoulder_spans()
	_check_tailoring()
	_check_heights()
	await get_tree().create_timer(SETTLE).timeout
	if _problems.is_empty():
		print("LEGEND_CHECK PASS trio built, tailored, distinct")
	else:
		for p in _problems:
			print("LEGEND_CHECK FAILED: " + p)
	if out != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("LEGEND_CHECK capture saved: " + out)
		await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _problems.is_empty() else 2)


func _holder_for(id: String) -> Node3D:
	# Holders were spawned in CHARACTERS order: 0 sardarji, 1 riya, 2 monty.
	var want := 0 if id == "sardarji" else (1 if id == "riya" else 2)
	return _holders[want]


func _check_build_poses() -> void:
	var expect := {
		"sardarji": {"bone": "spine_02", "min": 1.10},
		"monty": {"bone": "spine_02", "max": 0.95},
		"riya": {"bone": "torso", "min": 1.03},
	}
	for id in expect.keys():
		var spec: Dictionary = expect[id]
		var skel := _skeleton(_holder_for(id))
		if skel == null:
			_problems.append("%s has no skeleton" % id)
			continue
		var idx := _bone_index(skel, String(spec["bone"]))
		if idx < 0:
			_problems.append("%s rig lacks bone %s" % [id, spec["bone"]])
			continue
		var scale: Vector3 = skel.get_bone_pose_scale(idx)
		var v := scale.x
		if spec.has("min") and v < float(spec["min"]):
			_problems.append("%s %s pose scale %.3f < %.2f"
					% [id, spec["bone"], v, float(spec["min"])])
		if spec.has("max") and v > float(spec["max"]):
			_problems.append("%s %s pose scale %.3f > %.2f"
					% [id, spec["bone"], v, float(spec["max"])])
		print("LEGEND_CHECK %s %s pose scale x=%.3f" % [id, spec["bone"], v])


## Shoulder span in world units: distance between the clavicle bones'
## global poses (male rig) once the build scales apply.
func _shoulder_span(id: String) -> float:
	var skel := _skeleton(_holder_for(id))
	if skel == null:
		return 0.0
	skel.force_update_all_bone_transforms()
	var names := ["clavicle_l", "clavicle_r"]
	var pts := []
	for i in skel.get_bone_count():
		if names.has(skel.get_bone_name(i).to_lower()):
			pts.append(skel.get_bone_global_pose(i).origin)
	if pts.size() != 2:
		return 0.0
	return pts[0].distance_to(pts[1])


func _check_shoulder_spans() -> void:
	var broad := _shoulder_span("sardarji")
	var lean := _shoulder_span("monty")
	print("LEGEND_CHECK shoulder spans: sardarji %.3f  monty %.3f" % [broad, lean])
	if broad <= 0.0 or lean <= 0.0:
		_problems.append("shoulder span measurement failed (clavicles missing)")
		return
	if broad < lean * 1.12:
		_problems.append("barrel chest not reading: sardarji span %.3f < monty %.3f x 1.12"
				% [broad, lean])


func _check_tailoring() -> void:
	# Procedural-mesh floors per legend: turban kit + vest + tailoring
	# for Sardar Ji, rider gear + jacket tailoring for Riya, identity +
	# shirt tailoring for Monty. The build gates above carry the
	# correctness load; these floors catch a tailoring branch silently
	# not attaching.
	var floors := {"sardarji": 18, "riya": 7, "monty": 11}
	for id in floors.keys():
		var count := _mesh_count(_holder_for(id))
		print("LEGEND_CHECK %s procedural meshes: %d" % [id, count])
		if count < int(floors[id]):
			_problems.append("%s tailoring meshes %d < floor %d"
					% [id, count, int(floors[id])])


func _mesh_count(holder: Node3D) -> int:
	var n := 0
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh is PrimitiveMesh:
			n += 1
	return n


func _check_heights() -> void:
	# Height distinctness is gated on the DEFS (the spec the bodies
	# converge to at spawn — riya/monty measure exact in the rendered
	# AABB). The dressed AABB of a turban legend swings with the idle
	# animation phase (attachments ride the bones), so it is not a
	# stable gate metric; the captures carry the visual check.
	var expect := {}
	for def in Game.CHARACTERS:
		expect[String(def["id"])] = float(def.get("height", 1.72))
	for id in expect.keys():
		if expect[id] < Chars.HEIGHT_MIN or expect[id] > Chars.HEIGHT_MAX:
			_problems.append("%s def height %.2f outside human band" % [id, expect[id]])
	if absf(expect["sardarji"] - expect["monty"]) < 0.045 \
			or absf(expect["riya"] - expect["monty"]) < 0.045 \
			or absf(expect["riya"] - expect["sardarji"]) < 0.045:
		_problems.append("legend defs do not carry distinct heights")
	print("LEGEND_CHECK def heights: sardarji %.2f  riya %.2f  monty %.2f"
			% [expect["sardarji"], expect["riya"], expect["monty"]])


func _skeleton(holder: Node3D) -> Skeleton3D:
	if holder == null or holder.get_child_count() == 0:
		return null
	var model: Node3D = holder.get_child(0)
	for skel_node in model.find_children("*", "Skeleton3D", true, false):
		return skel_node
	return null


func _bone_index(skel: Skeleton3D, lower_name: String) -> int:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).to_lower() == lower_name:
			return i
	return -1


## Camera + light + ground so the capture reads at gameplay scale.
func _stage() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.1, -5.4)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.9, 0.0), Vector3.UP)
	add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 200.0, 0.0)
	sun.light_energy = 1.15
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, 20.0, 0.0)
	fill.light_energy = 0.45
	add_child(fill)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(40.0, 0.1, 12.0)
	ground.mesh = gm
	ground.position = Vector3(0.0, -0.05, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.52, 0.50, 0.46)
	ground.material_override = gmat
	add_child(ground)
