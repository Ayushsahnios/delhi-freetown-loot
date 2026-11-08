extends Node3D
## Retarget proof: candidate bodies playing the grafted idle/walk/run
## clips. Six walkers (3 per Worker body) + clip labels.

const Chars := preload("res://scripts/characters.gd")

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -30.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28.0, 150.0, 0.0)
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 0.5
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.72, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.68)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.31, 0.28)
	ground.material_override = mat
	add_child(ground)

	var clips := ["idle", "walk", "run"]
	var seeds := [101, 202, 303]
	var i := 0
	for clip in clips:
		for path in [Chars.WORKER_F, Chars.WORKER_M]:
			var chars := Chars.new()
			var holder: Node3D = chars.spawn(path, 1.68)
			var id: Dictionary = chars.identity(seeds[i % seeds.size()], path == Chars.WORKER_F)
			chars.dress(holder, id)
			holder.position = Vector3((i % 6 - 2.5) * 1.5, 0.0, 0.0)
			add_child(holder)
			var ap: AnimationPlayer = chars.get_player(holder)
			var anims: Dictionary = chars.anim_names(holder)
			print("walker ", i, " clip=", clip, " anims=", anims.keys(),
				" ap=", ap != null)
			if ap != null and anims.has(clip):
				ap.get_animation(anims[clip]).loop_mode = Animation.LOOP_LINEAR
				ap.play(anims[clip])
			var tag := Label3D.new()
			tag.text = clip + (" F" if path == Chars.WORKER_F else " M")
			tag.font_size = 64
			tag.pixel_size = 0.08 / 64.0
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.modulate = Color(0.1, 0.1, 0.1)
			tag.position = holder.position + Vector3(0, 2.0, 0)
			add_child(tag)
			i += 1
	await get_tree().process_frame
	for f in 90:
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0.0, 1.5, 8.2)
	cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://docs/captures/humans/retarget-proof.png")
	print("saved docs/captures/humans/retarget-proof.png")
	get_tree().quit()
