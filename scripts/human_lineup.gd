extends Node3D
## Issue #291 Phase 1 — standalone lineup of the four vendored CC0
## human candidates (Quaternius Modular Men/Women, Worker + Casual),
## sized exactly like game spawns (same basis math as characters.gd),
## under flat day lighting. Rendered server-side via xvfb (same
## pattern as screenshot.gd) to produce the capture set under
## docs/captures/humans/.
##
## Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     res://scenes/human_lineup.tscn -- --out docs/captures/humans/lineup-wide.png \
##     --mode wide
##   --mode p0..p3 renders a portrait closeup of candidate 0..3.

const MODELS := [
	"res://assets/characters/candidates/quat_men_Worker.glb",
	"res://assets/characters/candidates/quat_women_Worker.glb",
	"res://assets/characters/candidates/quat_men_Casual.glb",
	"res://assets/characters/candidates/quat_women_Casual.glb",
]
const NAMES := ["Men / Worker", "Women / Worker", "Men / Casual", "Women / Casual"]

const Chars := preload("res://scripts/characters.gd")

var _chars := Chars.new()

const SPACING := 1.6
const TARGET_HEIGHT := 1.7

var _mode := "wide"
var _out := "/tmp/lineup.png"
var _frames := 12
var _holders: Array[Node3D] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a: String = args[i]
		if a == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif a == "--mode" and i + 1 < args.size():
			_mode = String(args[i + 1])
		elif a == "--frames" and i + 1 < args.size():
			_frames = int(args[i + 1])

	_build_stage()
	var report := {}
	for i in MODELS.size():
		var holder: Node3D = _spawn_model(i)
		report[NAMES[i]] = _model_facts(holder)
	for i in range(_frames):
		await get_tree().process_frame

	_frame_camera()
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("lineup saved: ", _out)
	for key in report:
		var f: Dictionary = report[key]
		print("MODEL ", key, " tris=", f["tris"], " meshes=", f["meshes"],
			" bones=", f["bones"], " scaled_to=", f["height"])
	get_tree().quit()


func _build_stage() -> void:
	# Flat day lighting: warm sun from the front-left, cool sky bounce.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	# Shadowless fill from the opposite side so faces read evenly in
	# the portrait closeups (single-key lighting banding hid cheeks).
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, 148.0, 0.0)
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
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
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.32, 0.29)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	# Height reference post: exactly the 1.70 m spawn target.
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = TARGET_HEIGHT
	post.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.15, 0.16)
	post.material_override = pmat
	post.position = Vector3(-3.1, TARGET_HEIGHT * 0.5, 0.0)
	add_child(post)
	var ref := _label("1.70 m", 0.09)
	ref.position = Vector3(-3.1, TARGET_HEIGHT + 0.12, 0.0)
	add_child(ref)


func _spawn_model(i: int) -> Node3D:
	var ps: PackedScene = load(MODELS[i])
	var model: Node3D = ps.instantiate()
	# Same sizing contract as characters.gd.spawn(): clamp into the
	# height band, then correct against the model's true rendered height.
	var target := clampf(TARGET_HEIGHT, Chars.HEIGHT_MIN, Chars.HEIGHT_MAX)
	var basis := _chars._size_basis(model)
	if basis > 0.001:
		model.scale = Vector3.ONE * (target / basis)
	var rendered := _chars._visual_height(model) * model.scale.y
	if rendered > 0.001 and absf(rendered - target) > 0.01:
		model.scale = Vector3.ONE * (target / rendered)
	# No facing flip: these models author facing +Z and the lineup camera
	# sits at +Z, so the camera reads their faces (the in-game PI flip is
	# for the game camera, which trails the holder).
	var holder := Node3D.new()
	holder.name = "Cand" + str(i)
	holder.position = Vector3((i - 1.5) * SPACING, 0.0, 0.0)
	holder.add_child(model)
	add_child(holder)
	_holders.append(holder)

	var tag := _label(NAMES[i], 0.085)
	tag.position = Vector3(holder.position.x, TARGET_HEIGHT + 0.28, 0.0)
	add_child(tag)
	return holder


func _label(text: String, size: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.08, 0.08, 0.09)
	l.outline_size = 24
	return l


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
	var bones := 0
	for skel_node in holder.find_children("*", "Skeleton3D", true, false):
		bones = (skel_node as Skeleton3D).get_bone_count()
		break
	return {"tris": tris, "meshes": meshes, "bones": bones,
		"height": TARGET_HEIGHT}


func _frame_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = Camera3D.new()
		add_child(cam)
		cam.current = true
	if _mode == "wide":
		cam.position = Vector3(0.0, 1.35, 6.2)
		cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
		cam.fov = 39.0
	else:
		var idx := int(_mode.substr(1))
		# Portraits isolate their subject: the neighbors' T-pose arms
		# would otherwise cross the frame edges.
		for j in _holders.size():
			_holders[j].visible = j == idx
		var x := (idx - 1.5) * SPACING
		cam.position = Vector3(x + 0.18, 1.5, 0.95)
		cam.look_at(Vector3(x, 1.5, 0.0), Vector3.UP)
		cam.fov = 30.0
