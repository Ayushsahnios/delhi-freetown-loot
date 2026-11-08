extends Node3D
## Issue #291 closing proof — one scene that shows and gates the
## finished model swap. Left group: four walkers spawned exactly like
## the street fleet dresses them (Worker pair + per-seed identity
## rolls + retargeted gait clips). Right group: the three legends
## exactly as the title screen dresses them (Casual pair + build
## poses + tailoring). Headless it is a gate:
##   (A) legend_model() maps riya -> Casual women, sardarji/monty ->
##       Casual men (the Option A auto-pick, owner-approved)
##   (B) every model-sourced mesh in every figure comes from the
##       vendored CC0 candidates (workers on the Worker pair, legends
##       on their expected Casual GLB — no legacy rig left in the
##       swapped paths); procedural add-ons (empty scene_file_path)
##       are counted, not treated as model meshes
##   (C) every figure is rigged and its rendered height sits in the
##       human band; legend def heights stay distinct
##   (D) per-figure + total triangle counts print for the perf record
## Under xvfb it renders the closing capture for docs/captures/humans/.
##
## Usage (gate, no rendering):
##   godot --headless --path . res://tools/closing_proof.tscn
## Usage (capture):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 res://tools/closing_proof.tscn -- \
##     --out docs/captures/humans/closing-proof.png --frames 14

const Game := preload("res://scripts/game.gd")
const Chars := preload("res://scripts/characters.gd")
const Peds := preload("res://scripts/pedestrians.gd")

## Fleet contract (pedestrians.gd): women first, male = last model.
const MODELS := [Chars.WORKER_F, Chars.WORKER_M]
const WALKER_SEEDS := [7401, 7402, 7403, 7404]
const PED_HEIGHT := 1.68
const LEGEND_MODEL := {
	"riya": Chars.CASUAL_F,
	"sardarji": Chars.CASUAL_M,
	"monty": Chars.CASUAL_M,
}

const SETTLE := 0.6
const WALK_X0 := -6.8
const WALK_DX := 1.9
const LEG_X0 := 1.0
const LEG_DX := 1.8
const CENTER_X := -1.1

var _chars := Chars.new()
var _problems: Array[String] = []
var _walkers: Array[Node3D] = []
var _legends: Array[Node3D] = []
var _out := ""
var _frames := 14


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--out" and i + 1 < args.size():
			_out = String(args[i + 1])
		elif String(args[i]) == "--frames" and i + 1 < args.size():
			_frames = int(args[i + 1])
	_stage()
	_spawn_walkers()
	_spawn_legends()
	_check_legend_map()
	_check_walkers()
	_check_legend_meshes()
	_check_heights()
	var total := 0
	for holder in _walkers + _legends:
		var facts := _model_facts(holder)
		total += int(facts["tris"])
	print("CLOSING_CHECK scene tris total=", total,
		" figures=", _walkers.size() + _legends.size())
	await get_tree().create_timer(SETTLE).timeout
	if _problems.is_empty():
		print("CLOSING_CHECK PASS fleet=Worker-pair legends=Casual-pair all-model-meshes-CC0")
	else:
		for p in _problems:
			print("CLOSING_CHECK FAILED: " + p)
	if _out != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("CLOSING_CHECK capture saved: " + _out)
		await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _problems.is_empty() else 2)


func _spawn_walkers() -> void:
	for i in WALKER_SEEDS.size():
		# Mirror pedestrians._dress(): alternating pick, identity roll,
		# fleet height math, then the street wardrobe dress.
		var pick := i % 2
		var path: String = MODELS[pick]
		var female := pick < MODELS.size() - 1
		var id: Dictionary = Chars.identity(WALKER_SEEDS[i], female)
		var node := _chars.spawn(path, PED_HEIGHT * float(id["height"]))
		_chars.dress(node, id)
		node.position = Vector3(WALK_X0 + i * WALK_DX, 0.0, 0.0)
		add_child(node)
		_chars.play(_chars.anim_names(node), _chars.get_player(node),
			"walk", 1.0)
		_walkers.append(node)
		print("CLOSING_CHECK walker-%d model=%s female=%s seed=%d"
			% [i, path.get_file(), female, WALKER_SEEDS[i]])
	if _walkers.size() < 4:
		_problems.append("walker group incomplete")


func _spawn_legends() -> void:
	for i in Game.CHARACTERS.size():
		var def: Dictionary = Game.CHARACTERS[i]
		var path: String = _chars.legend_model(String(def["id"]))
		var holder := _chars.spawn(path, float(def.get("height", 1.72)))
		holder.position = Vector3(LEG_X0 + i * LEG_DX, 0.0, 0.0)
		add_child(holder)
		_chars.dress_legend(holder, def)
		_chars.play(_chars.anim_names(holder), _chars.get_player(holder),
			"idle", float(def.get("anim_rate", 1.0)))
		_legends.append(holder)
		print("CLOSING_CHECK legend %s model=%s"
			% [String(def["id"]), path.get_file()])


func _check_legend_map() -> void:
	for id in LEGEND_MODEL.keys():
		var got: String = _chars.legend_model(String(id))
		if got != String(LEGEND_MODEL[id]):
			_problems.append("legend %s maps to %s (want %s)"
				% [id, got, LEGEND_MODEL[id]])


## The figure's model must come from an allowed vendored GLB — the
## model root carries the source scene path Chars.spawn instantiated
## (mesh-level scene_file_path is empty on GLB descendants, so the
## root is the honest provenance). Catches any legacy rig sneaking
## back into a swapped path.
func _check_figure(holder: Node3D, tag: String, allowed: Array) -> void:
	if holder.get_child_count() == 0:
		_problems.append("%s has no model child" % tag)
		return
	var model: Node3D = holder.get_child(0)
	var src := String(model.scene_file_path)
	print("CLOSING_CHECK %s model source %s" % [tag, src])
	if not src.contains("/candidates/"):
		_problems.append("%s model from non-candidate source: %s"
			% [tag, src])
		return
	var ok := false
	for a in allowed:
		if src.ends_with(String(a).get_file()):
			ok = true
			break
	if not ok:
		_problems.append("%s model from wrong candidate: %s" % [tag, src])
	var meshed := false
	for mi_node in model.find_children("*", "MeshInstance3D", true, false):
		if (mi_node as MeshInstance3D).mesh != null:
			meshed = true
			break
	if not meshed:
		_problems.append("%s model carries no meshes" % tag)
	var rigged := false
	for skel in model.find_children("*", "Skeleton3D", true, false):
		rigged = true
		break
	if not rigged:
		_problems.append("%s has no skeleton" % tag)


func _check_walkers() -> void:
	# The fleet's own MODELS constant is the contract — gate against it,
	# not against this tool's spawn copy.
	var fleet_models: Array = Peds.MODELS
	if fleet_models != [Chars.WORKER_F, Chars.WORKER_M]:
		_problems.append("fleet MODELS drifted off the Worker pair: %s"
			% str(fleet_models))
	for i in _walkers.size():
		_check_figure(_walkers[i], "walker-%d" % i, fleet_models)


func _check_legend_meshes() -> void:
	for i in Game.CHARACTERS.size():
		var id := String(Game.CHARACTERS[i]["id"])
		_check_figure(_legends[i], "legend-" + id, [LEGEND_MODEL[id]])


func _check_heights() -> void:
	# Legend def heights: in band + pairwise distinct (same contract as
	# legend_check). Walker rendered heights: inside the human band.
	var expect := {}
	for def in Game.CHARACTERS:
		expect[String(def["id"])] = float(def.get("height", 1.72))
	for id in expect.keys():
		if expect[id] < Chars.HEIGHT_MIN or expect[id] > Chars.HEIGHT_MAX:
			_problems.append("%s def height %.2f outside human band"
				% [id, expect[id]])
	if absf(expect["sardarji"] - expect["monty"]) < 0.045 \
			or absf(expect["riya"] - expect["monty"]) < 0.045 \
			or absf(expect["riya"] - expect["sardarji"]) < 0.045:
		_problems.append("legend defs do not carry distinct heights")
	for i in _walkers.size():
		var model: Node3D = _walkers[i].get_child(0)
		var rendered := _chars._visual_height(model) * model.scale.y
		print("CLOSING_CHECK walker-%d rendered height %.2f" % [i, rendered])
		if rendered < 1.40 or rendered > 1.95:
			_problems.append("walker-%d rendered height %.2f outside band"
				% [i, rendered])
	print("CLOSING_CHECK def heights: sardarji %.2f  riya %.2f  monty %.2f"
		% [expect["sardarji"], expect["riya"], expect["monty"]])


func _model_facts(holder: Node3D) -> Dictionary:
	var tris := 0
	var meshes := 0
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh == null:
			continue
		meshes += 1
		var am: ArrayMesh = mi.mesh as ArrayMesh
		if am != null:
			for s in am.get_surface_count():
				var arrays: Array = am.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
					tris += arrays[Mesh.ARRAY_INDEX].size() / 3
				elif arrays.size() > Mesh.ARRAY_VERTEX:
					tris += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return {"tris": tris, "meshes": meshes}


## Camera + light + ground so the capture reads at gameplay scale
## (same stage as legend_check — Chars.spawn flips models to face -Z).
func _stage() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(CENTER_X, 1.6, -10.5)
	cam.look_at_from_position(cam.position,
		Vector3(CENTER_X, 0.95, 0.0), Vector3.UP)
	cam.fov = 40.0
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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_energy = 1.0
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(40.0, 0.1, 12.0)
	ground.mesh = gm
	ground.position = Vector3(0.0, -0.05, 0.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.52, 0.50, 0.46)
	ground.material_override = gmat
	add_child(ground)
	# 1.70 m reference post between the two groups.
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 1.70
	post.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.15, 0.16)
	post.material_override = pmat
	post.position = Vector3(-0.05, 0.85, 0.0)
	add_child(post)
	add_child(_label("WORKER FLEET (walkers)", Vector3(-4.2, 2.25, 0.0)))
	add_child(_label("CASUAL LEGENDS", Vector3(2.8, 2.25, 0.0)))
	add_child(_label("1.70 m", Vector3(-0.05, 1.92, 0.0)))


func _label(text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.085 / 64.0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.08, 0.08, 0.09)
	l.outline_size = 24
	l.position = pos
	return l
