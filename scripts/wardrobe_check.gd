extends Node
## Indian street wardrobe check (issue 134) — acceptance gate for the
## wardrobe meshes over the modular character system. Two parts:
## (A) a deterministic lineup — one walker for every outfit/role the
## wardrobe roll can produce (kurta, lungi, porter-with-head-load,
## khaki guard, western; saree, kameez, western on the women's rigs) —
## each checked for its expected holder-fixed wardrobe mesh; plus
## issue 182 print slots: checked/plaid/striped tops, a contrast-
## collar kurta, and a zari-bordered saree, each gated on its print
## material actually landing; (B) a PNG capture of that lineup under
## xvfb so a human can eyeball pattern variety at gameplay distance.
## Exits 0 when every lineup slot passes, 2 with a FAILED report.
## Usage (gate, no rendering):
##   godot --headless --path . res://scenes/wardrobe_check.tscn
## Usage (capture):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 res://scenes/wardrobe_check.tscn -- \
##     --out docs/screenshots/wardrobe-prints-182.png

const Chars := preload("res://scripts/characters.gd")

const SPACING := 1.6
const SETTLE := 0.6

var _problems: Array[String] = []
var _chars := Chars.new()

## Lineup definition: model + identity overrides. Seeds are fixed so
## the lineup is the same every run (heights/faces vary, outfits are
## pinned by the overrides).
const LINEUP := [
	{"model": Chars.MALE, "seed": 11, "female": false,
		"over": {"outfit": Chars.W_KURTA, "role": 0},
		"want": "kurta skirt"},
	{"model": Chars.MALE, "seed": 23, "female": false,
		"over": {"outfit": Chars.W_KURTA, "role": 0,
			"shirt": Color(0.91, 0.74, 0.32)},
		"want": "kurta skirt"},
	{"model": Chars.MALE, "seed": 37, "female": false,
		"over": {"outfit": Chars.W_LUNGI, "role": 0},
		"want": "lungi wrap"},
	{"model": Chars.MALE, "seed": 41, "female": false,
		"over": {"outfit": Chars.W_KURTA, "role": 1,
			"shirt": Color(0.62, 0.16, 0.12)},
		"want": "porter bundle", "want_top": 1.35},
	{"model": Chars.MALE, "seed": 53, "female": false,
		"over": {"outfit": Chars.W_WESTERN, "role": 2,
			"shirt": Color(0.56, 0.51, 0.38), "pants": Color(0.44, 0.40, 0.30),
			"hat": Color(0.44, 0.40, 0.30), "headwear": 1},
		"want": "guard cap"},
	{"model": Chars.MALE, "seed": 67, "female": false,
		"over": {"outfit": Chars.W_WESTERN, "role": 0},
		"want": ""},
	{"model": Chars.FEMALE_A, "seed": 71, "female": true,
		"over": {"outfit": Chars.W_SAREE, "role": 0,
			"pants": Color(0.95, 0.30, 0.45), "shirt": Color(0.26, 0.07, 0.12),
			"border": 0},
		"want": "saree skirt", "bordered": true},
	{"model": Chars.FEMALE_B, "seed": 83, "female": true,
		"over": {"outfit": Chars.W_KURTA, "role": 0},
		"want": "kameez skirt"},
	{"model": Chars.FEMALE_C, "seed": 97, "female": true,
		"over": {"outfit": Chars.W_WESTERN, "role": 0},
		"want": ""},
	# Issue 182 print slots: gingham checks, plaid, striped tee,
	# contrast-collar kurta — pinned via overrides, gated on the print
	# material landing (white albedo + baked texture).
	{"model": Chars.MALE, "seed": 101, "female": false,
		"over": {"outfit": Chars.W_WESTERN, "role": 0, "print": 1,
			"print_var": 0, "shirt": Color(0.24, 0.45, 0.45)},
		"want": "", "print": true},
	{"model": Chars.MALE, "seed": 103, "female": false,
		"over": {"outfit": Chars.W_WESTERN, "role": 0, "print": 2,
			"print_var": 1, "shirt": Color(0.22, 0.30, 0.44)},
		"want": "", "print": true},
	{"model": Chars.FEMALE_D, "seed": 107, "female": true,
		"over": {"outfit": Chars.W_WESTERN, "role": 0, "print": 3,
			"print_var": 0, "shirt": Color(0.60, 0.28, 0.36)},
		"want": "", "print": true},
	{"model": Chars.MALE, "seed": 109, "female": false,
		"over": {"outfit": Chars.W_KURTA, "role": 0, "collar": true,
			"hat": Color(0.85, 0.72, 0.20)},
		"want": "kurta skirt", "collar": true},
]


func _ready() -> void:
	var out := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--out" and i + 1 < args.size():
			out = String(args[i + 1])
	_stage()
	var holders: Array[Node3D] = []
	for i in LINEUP.size():
		var spec: Dictionary = LINEUP[i]
		var id: Dictionary = Chars.identity(int(spec["seed"]), bool(spec["female"]))
		for k in (spec["over"] as Dictionary):
			id[k] = (spec["over"] as Dictionary)[k]
		var holder := _chars.spawn(String(spec["model"]), 1.68 * float(id["height"]))
		holder.position = Vector3((i - (LINEUP.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		add_child(holder)
		_chars.play(_chars.anim_names(holder), _chars.get_player(holder), "idle", 1.0)
		_chars.dress(holder, id)
		holders.append(holder)
		if String(spec["want"]) != "" and not _has_wardrobe_mesh(holder):
			_problems.append("lineup %d (%s) missing wardrobe mesh for: %s"
				% [i, String(spec["model"]).get_file(), String(spec["want"])])
		if spec.get("print", false) and not _has_print_mat(holder):
			_problems.append("lineup %d missing print material (print %s)"
				% [i, str((spec["over"] as Dictionary).get("print", 0))])
		if spec.get("bordered", false) and not _has_print_mat(holder):
			_problems.append("lineup %d missing zari border material" % i)
		if spec.get("collar", false) and not _has_collar_meshes(holder):
			_problems.append("lineup %d missing contrast collar meshes" % i)
		if spec.has("want_top"):
			# Head-load slots: at least one wardrobe primitive must sit in
			# the head zone (a bundle on the ground fails the acceptance).
			var top := _tallest_wardrobe_y(holder)
			print("WARDROBE_CHECK slot %d highest wardrobe mesh at y=%.2f"
				% [i, top])
			if top < float(spec["want_top"]):
				_problems.append("lineup %d head mesh too low: y=%.2f < %.2f"
					% [i, top, float(spec["want_top"])])
	await get_tree().create_timer(SETTLE).timeout
	if _problems.is_empty():
		print("WARDROBE_CHECK PASS %d lineup slots dressed" % LINEUP.size())
	else:
		for p in _problems:
			print("WARDROBE_CHECK FAILED: " + p)
	if out != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("WARDROBE_CHECK capture saved: " + out)
		# Rendering path: keep the window long enough for a clean grab.
		await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if _problems.is_empty() else 2)


## Print/border materials (issue 182) bake the garment tint into the
## albedo texture and reset albedo_color to pure white — weave
## materials keep the tint in albedo_color instead — so white-albedo-
## with-texture is the print fingerprint on any surface or override.
func _has_print_mat(holder: Node3D) -> bool:
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		var ov = mi.material_override
		if ov != null and ov is StandardMaterial3D and _is_print_mat(ov):
			return true
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			if m != null and m is StandardMaterial3D and _is_print_mat(m):
				return true
	return false


func _is_print_mat(m: StandardMaterial3D) -> bool:
	return m.albedo_texture != null and m.albedo_color.r > 0.98 \
			and m.albedo_color.g > 0.98 and m.albedo_color.b > 0.98


## Contrast-collar kurta (issue 182): the collar ring plus placket
## strip attach as a flat torus and a chest box — count both.
func _has_collar_meshes(holder: Node3D) -> bool:
	var ring := false
	var strip := false
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh is TorusMesh:
			ring = true
		elif mi.mesh is BoxMesh and mi.global_position.y > 0.55 \
				and mi.mesh.size.y < 0.2:
			strip = true
	return ring and strip


## Camera + light + ground so the capture reads at gameplay scale.
func _stage() -> void:
	var cam := Camera3D.new()
	# Issue 182: 13 lineup slots — pulled back so the full wardrobe row
	# (and its prints) frames at a gameplay-distance camera.
	cam.position = Vector3(0.0, 1.2, -7.6)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.95, 0.0), Vector3.UP)
	add_child(cam)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	# Light the camera side: the lineup faces -Z, so the sun must shine
	# from -Z toward them or every figure silhouettes black in the grab.
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


## Highest world-space center Y of any procedural wardrobe mesh under
## the holder — the head-load bundle must ride near the skull, not the
## shoes.
func _tallest_wardrobe_y(holder: Node3D) -> float:
	var top := 0.0
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh is CylinderMesh or mi.mesh is SphereMesh or mi.mesh is BoxMesh:
			top = maxf(top, mi.global_position.y)
	return top


## True when the holder carries a procedural wardrobe mesh (a cylinder
## skirt/wrap, a pallu slab, or a bundle sphere) beyond the rig's own
## meshes — i.e. dress() actually layered clothing on this body.
func _has_wardrobe_mesh(holder: Node3D) -> bool:
	for mi_node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node
		if mi.mesh is CylinderMesh or mi.mesh is SphereMesh or mi.mesh is BoxMesh:
			return true
	return false
