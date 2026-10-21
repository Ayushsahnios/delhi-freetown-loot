extends Node3D
## Delhi Freetown Loot — from-scratch build. All content procedural, no assets.

const BLOCK := 34.0
const ROAD := 12.0
const PITCH := BLOCK + ROAD
const GRID := 11
const WORLD := GRID * PITCH
const DAY_LEN := 240.0

const PlayerScript := preload("res://scripts/player.gd")
const AutoScript := preload("res://scripts/auto.gd")

const SKY_DAY := Color(0.53, 0.81, 0.92)
const SKY_DUSK := Color(0.88, 0.48, 0.22)
const SKY_NIGHT := Color(0.04, 0.06, 0.19)
const PALETTE := [
	Color(0.85, 0.78, 0.66), Color(0.79, 0.64, 0.48), Color(0.71, 0.72, 0.76),
	Color(0.85, 0.56, 0.42), Color(0.62, 0.71, 0.78), Color(0.88, 0.84, 0.75),
]

var player: CharacterBody3D
var camera: Camera3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment

var day_t := 0.32
var current_auto: CharacterBody3D = null
var _autos: Array[CharacterBody3D] = []
var _rng := RandomNumberGenerator.new()
var _playing := false
var _hud_name: Label
var _hud_clock: Label
var _hud_day: Label
var _select_layer: CanvasLayer
var _cam_anchor := Vector3.ZERO


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_city()
	camera = Camera3D.new()
	add_child(camera)
	_build_hud()
	_build_select_ui()


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_DAY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.7
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_energy = 1.0
	add_child(sun)


# ---------------------------------------------------------------- city

func _build_city() -> void:
	# ground
	var ground_body := StaticBody3D.new()
	ground_body.position = Vector3(0, -0.5, 0)
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(WORLD + 300, 1.0, WORLD + 300)
	ground_shape.shape = ground_box
	ground_body.add_child(ground_shape)
	var ground_mesh := _mesh_box(Vector3(WORLD + 300, 1.0, WORLD + 300), Color(0.44, 0.48, 0.42))
	ground_body.add_child(ground_mesh)
	add_child(ground_body)

	# roads
	for i in range(GRID + 1):
		var pos := -WORLD / 2.0 + i * PITCH - BLOCK / 2.0
		add_child(_flat(Vector3(WORLD, 0.08, ROAD), Vector3(0, 0.04, pos), Color(0.18, 0.19, 0.21)))
		add_child(_flat(Vector3(ROAD, 0.08, WORLD), Vector3(pos, 0.04, 0), Color(0.18, 0.19, 0.21)))
		var s := -WORLD / 2.0 + 7.0
		while s < WORLD / 2.0:
			add_child(_flat(Vector3(5.0, 0.06, 0.45), Vector3(s, 0.09, pos), Color(0.96, 0.88, 0.30)))
			add_child(_flat(Vector3(0.45, 0.06, 5.0), Vector3(pos, 0.09, s), Color(0.96, 0.88, 0.30)))
			s += 14.0

	# blocks
	for ix in range(GRID):
		for iz in range(GRID):
			var c := _block_center(ix, iz)
			if ix == 5 and iz == 5:
				_build_cp(c.x, c.z)
			elif ix == 5 and iz == 3:
				_build_india_gate(c.x, c.z)
			elif ix == 3 and iz == 7:
				_build_purani_dilli(c.x, c.z)
			elif (ix == 8 and iz == 2) or (ix == 2 and iz == 3):
				_build_park(c.x, c.z)
			else:
				var n := _rng.randi_range(2, 4)
				for b in range(n):
					var w := _rng.randf_range(10.0, 24.0)
					var d := _rng.randf_range(10.0, 24.0)
					var h := _rng.randf_range(7.0, 33.0)
					var ox := _rng.randf_range(-1.0, 1.0) * (BLOCK - w) * 0.5
					var oz := _rng.randf_range(-1.0, 1.0) * (BLOCK - d) * 0.5
					_add_building(Vector3(c.x + ox, 0, c.z + oz), Vector3(w, h, d),
							PALETTE[_rng.randi_range(0, PALETTE.size() - 1)])
				_tree(Vector3(c.x - BLOCK / 2.0 + 2.0, 0, c.z - BLOCK / 2.0 + 2.0))

	_build_metro(0.0, -WORLD / 2.0 + 4.0 * PITCH - BLOCK / 2.0)


func _block_center(ix: int, iz: int) -> Vector3:
	var half := (GRID - 1) / 2.0
	return Vector3((ix - half) * PITCH, 0.0, (iz - half) * PITCH)


func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	body.add_child(shape)
	body.add_child(_mesh_box(size, color, Vector3(0, size.y / 2.0, 0)))
	add_child(body)


func _mesh_box(size: Vector3, color: Color, offset := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	m.mesh = bm
	m.position = offset
	return m


func _flat(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	return _mesh_box(size, color, pos)


func _tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var tmc := CylinderMesh.new()
	tmc.top_radius = 0.35
	tmc.bottom_radius = 0.5
	tmc.height = 2.6
	tmc.material = _mat(Color(0.42, 0.29, 0.17))
	trunk.mesh = tmc
	trunk.position = pos + Vector3(0, 1.3, 0)
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var cmc := SphereMesh.new()
	cmc.radius = 2.1
	cmc.height = 3.4
	cmc.material = _mat(Color(0.18, 0.49, 0.20))
	crown.mesh = cmc
	crown.position = pos + Vector3(0, 4.1, 0)
	add_child(crown)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _grass(pos: Vector3) -> void:
	add_child(_flat(Vector3(BLOCK - 2.0, 0.06, BLOCK - 2.0), pos + Vector3(0, 0.1, 0), Color(0.24, 0.48, 0.25)))


func _build_cp(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var park := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 11.0
	pm.bottom_radius = 11.0
	pm.height = 0.7
	pm.material = _mat(Color(0.18, 0.56, 0.27))
	park.mesh = pm
	park.position = Vector3(x, 0.35, z)
	add_child(park)
	_add_building(Vector3(x, 0, z), Vector3(18.0, 1.0, 18.0), Color(0.18, 0.56, 0.27))
	for a in range(8):
		var ang := TAU * a / 8.0
		var bp := Vector3(x + cos(ang) * 21.0, 0, z + sin(ang) * 21.0)
		var h := 14.0 + (a % 3) * 4.0
		_add_building(bp, Vector3(7.0, h, 7.0), Color(0.94, 0.92, 0.85))


func _build_india_gate(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var stone := Color(0.54, 0.45, 0.33)
	_add_building(Vector3(x - 6.0, 0, z), Vector3(3.0, 16.0, 5.0), stone)
	_add_building(Vector3(x + 6.0, 0, z), Vector3(3.0, 16.0, 5.0), stone)
	add_child(_mesh_box(Vector3(16.0, 4.0, 5.0), stone, Vector3(x, 16.5, z)))
	_tree(Vector3(x - 12, 0, z - 12))
	_tree(Vector3(x + 12, 0, z + 12))


func _build_purani_dilli(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var red := Color(0.61, 0.24, 0.18)
	_add_building(Vector3(x, 0, z - BLOCK / 2.0 + 2.0), Vector3(BLOCK - 4.0, 9.0, 3.0), red)
	_add_building(Vector3(x, 0, z), Vector3(12.0, 12.0, 12.0), red)
	var dome_base := MeshInstance3D.new()
	var dbm := CylinderMesh.new()
	dbm.top_radius = 3.4
	dbm.bottom_radius = 4.2
	dbm.height = 2.2
	dbm.material = _mat(Color(0.85, 0.78, 0.66))
	dome_base.mesh = dbm
	dome_base.position = Vector3(x, 13.1, z)
	add_child(dome_base)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 3.4
	dm.height = 8.5
	dm.material = _mat(Color(0.95, 0.92, 0.82))
	dome.mesh = dm
	dome.scale = Vector3(1, 1.25, 1)
	dome.position = Vector3(x, 15.2, z)
	add_child(dome)


func _build_park(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	for t in range(7):
		_tree(Vector3(x + _rng.randf_range(-13, 13), 0, z + _rng.randf_range(-13, 13)))


func _build_metro(x: float, z_line: float) -> void:
	var s := -WORLD / 2.0 + 10.0
	while s < WORLD / 2.0 - 10.0:
		var p := MeshInstance3D.new()
		var pcm := CylinderMesh.new()
		pcm.top_radius = 0.8
		pcm.bottom_radius = 1.0
		pcm.height = 12.0
		pcm.material = _mat(Color(0.55, 0.58, 0.62))
		p.mesh = pcm
		p.position = Vector3(x, 6.0, s)
		add_child(p)
		add_child(_mesh_box(Vector3(ROAD - 2.0, 1.2, 22.0), Color(0.32, 0.35, 0.42), Vector3(x, 12.4, s)))
		s += 22.0
	add_child(_mesh_box(Vector3(3.4, 3.2, 30.0), Color(0.85, 0.87, 0.90), Vector3(x, 14.6, -40.0)))
	add_child(_mesh_box(Vector3(3.5, 0.7, 30.0), Color(0.18, 0.44, 0.70), Vector3(x, 14.0, -40.0)))


# ---------------------------------------------------------------- UI

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud_name = Label.new()
	_hud_name.position = Vector2(16, 12)
	_hud_name.add_theme_font_size_override("font_size", 22)
	layer.add_child(_hud_name)
	_hud_clock = Label.new()
	_hud_clock.position = Vector2(16, 44)
	_hud_clock.add_theme_font_size_override("font_size", 16)
	layer.add_child(_hud_clock)
	_hud_day = Label.new()
	_hud_day.position = Vector2(16, 70)
	_hud_day.add_theme_font_size_override("font_size", 13)
	layer.add_child(_hud_day)


func _build_select_ui() -> void:
	_select_layer = CanvasLayer.new()
	_select_layer.layer = 20
	add_child(_select_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.16, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "DELHI FREETOWN LOOT"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "An indie free-roam loot game. Pick your legend."
	sub.add_theme_font_size_override("font_size", 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	for def in Game.CHARACTERS:
		var btn := Button.new()
		btn.text = "%s\n%s" % [def["name"], def["role"]]
		btn.custom_minimum_size = Vector2(460, 0)
		btn.pressed.connect(_start_game.bind(def))
		box.add_child(btn)

	var hint := Label.new()
	hint.text = "WASD move · Shift run · E vehicle · free roam"
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _start_game(def: Dictionary) -> void:
	Game.selected_character = def
	_select_layer.visible = false
	_hud_name.text = String(def["name"])

	player = PlayerScript.new()
	player.setup(def)
	player.position = Vector3(ROAD / 2.0 + 2.0, 1.0, 2.0 * PITCH - BLOCK)
	add_child(player)
	_cam_anchor = player.position

	var spots := [
		[Vector3(ROAD / 2.0 + 1.5, 1.0, 2.0 * PITCH - BLOCK - 12.0), 0.0],
		[Vector3(-ROAD / 2.0 - 1.5, 1.0, -PITCH + 6.0), PI],
		[Vector3(3.0 * PITCH - BLOCK, 1.0, ROAD / 2.0 + 1.5), PI / 2.0],
		[Vector3(-2.0 * PITCH + 8.0, 1.0, ROAD / 2.0 + 1.5), PI / 2.0],
		[Vector3(4.0 * PITCH - BLOCK + 20.0, 1.0, -ROAD / 2.0 - 1.5), -PI / 2.0],
	]
	for spot in spots:
		var a := AutoScript.new()
		a.setup(spot[0], spot[1])
		add_child(a)
		_autos.append(a)

	_playing = true


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_update_day(delta)
	if not _playing:
		return
	if Input.is_action_just_pressed("interact"):
		_toggle_vehicle()
	if current_auto != null:
		current_auto.drive(delta)
		player.global_position = current_auto.global_position
	_update_camera(delta)


func _toggle_vehicle() -> void:
	if current_auto != null:
		var exit_pos: Vector3 = current_auto.global_position + current_auto.global_transform.basis.x * 3.2
		player.global_position = exit_pos
		player.visible = true
		current_auto.driver_inside = false
		current_auto = null
		return
	var best: CharacterBody3D = null
	var best_d := 6.0
	for a in _autos:
		var d: float = a.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best != null:
		current_auto = best
		current_auto.driver_inside = true
		player.visible = false


func _update_camera(delta: float) -> void:
	var target := player
	var back := 10.0
	var up := 6.0
	if current_auto != null:
		target = current_auto
		back = 14.0
		up = 7.0
	var want: Vector3 = target.global_position + target.global_transform.basis.z * back + Vector3(0, up, 0)
	_cam_anchor = _cam_anchor.lerp(want, minf(delta * 4.5, 1.0))
	camera.position = _cam_anchor
	camera.look_at(target.global_position + Vector3(0, 2.5, 0))


func _update_day(delta: float) -> void:
	day_t = fmod(day_t + delta / DAY_LEN, 1.0)
	var sun_angle: float = sin(day_t * TAU - PI / 2.0)
	var daylight: float = clampf((sun_angle + 0.25) * 1.6, 0.0, 1.0)
	sun.light_energy = 0.15 + daylight * 0.85
	sun.rotation_degrees = Vector3(-30.0 - daylight * 45.0, 40.0, 0.0)
	var sky := SKY_NIGHT.lerp(SKY_DAY, daylight)
	var dusk: float = clampf(1.0 - absf(daylight - 0.5) * 2.0, 0.0, 1.0)
	sky = sky.lerp(SKY_DUSK, dusk * 0.5)
	world_env.environment.background_color = sky
	if _playing:
		var hours: float = fmod(day_t * 24.0 + 6.0, 24.0)
		var hh := int(hours)
		var mm := int((hours - hh) * 60.0)
		_hud_clock.text = "%02d:%02d" % [hh, mm]
		_hud_day.text = "Delhi \u00b7 " + ("Day" if daylight > 0.55 else ("Golden hour" if daylight > 0.2 else "Night"))
