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
const TrafficScript := preload("res://scripts/traffic.gd")
const PedestrianScript := preload("res://scripts/pedestrians.gd")
const HealthScript := preload("res://scripts/health.gd")
const PoliceScript := preload("res://scripts/police.gd")
const MissionScript := preload("res://scripts/missions.gd")
const AudioScript := preload("res://scripts/audio.gd")
const MiniMapScript := preload("res://scripts/minimap.gd")
const FoodScript := preload("res://scripts/food.gd")

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
var _traffic: Node
var _peds: Node
var _hud_name: Label
var _hud_clock: Label
var _hud_day: Label
var _select_layer: CanvasLayer
var _cam_anchor := Vector3.ZERO
var _health: Node
var _landmarks: Array[Dictionary] = []
var _dead := false
var _impact_cd := 0.0
var _audio: Node
var _minimap: Control
var _food: Node
var _hud_hp_bg: ColorRect
var _hud_hp_fill: ColorRect
var _hud_hp_text: Label
var _hud_stars: Label
var _police: Node
var _missions: Node
var _chaos_cd := 0.0
var _flash: ColorRect
var _fade: ColorRect
var _hud_msg: Label
var _flash_tween: Tween
var _toast: Label
var _toast_tween: Tween
var _char_states := {}
var _switch_lock := 0.0
var _switch_pending_release := false
var _chandni_seen := false


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_city()
	_build_landmarks()
	_food = FoodScript.new()
	add_child(_food)
	_food.setup(_landmarks)
	_traffic = TrafficScript.new()
	add_child(_traffic)
	_traffic.setup(WORLD, PITCH, ROAD, GRID + 1)
	_peds = PedestrianScript.new()
	add_child(_peds)
	_peds.setup(WORLD, PITCH, ROAD, GRID + 1)
	_peds.set_crowd_zone(_block_center(4, 7) + Vector3(6.0, 0.0, 0.0), 46.0)
	_audio = AudioScript.new()
	add_child(_audio)
	_audio.setup()
	camera = Camera3D.new()
	add_child(camera)
	_build_hud()
	_build_select_ui()
	get_tree().root.close_requested.connect(_save_game)


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
			elif ix == 4 and iz == 7:
				_build_chandni_chowk(c.x, c.z)
			elif ix == 7 and iz == 5:
				_build_police_station(c.x, c.z)
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


const AWNINGS := [
	[Color(0.95, 0.45, 0.12), Color(0.94, 0.92, 0.88)],
	[Color(0.12, 0.55, 0.55), Color(0.95, 0.90, 0.80)],
	[Color(0.85, 0.20, 0.45), Color(0.95, 0.85, 0.25)],
	[Color(0.20, 0.55, 0.20), Color(0.90, 0.88, 0.84)],
	[Color(0.95, 0.70, 0.15), Color(0.30, 0.50, 0.80)],
	[Color(0.60, 0.25, 0.60), Color(0.94, 0.92, 0.88)],
]

func _build_chandni_chowk(x: float, z: float) -> void:
	## Bazaar district: the block's inner street becomes a market lane —
	## a signature red gate at the south entry, stalls with striped
	## awnings and bunting on both sides, shop rows behind them, and a
	## pedestrian crowd zone (pedestrians.gd) filling it with shoppers.
	add_child(_flat(Vector3(BLOCK - 2.0, 0.06, BLOCK - 2.0), Vector3(x, 0.07, z),
			Color(0.71, 0.62, 0.48)))
	var street := x + 6.0
	var gate_z := z - 15.0
	var red := Color(0.60, 0.25, 0.15)
	var cream := Color(0.93, 0.88, 0.76)
	_add_building(Vector3(street - 7.5, 0, gate_z), Vector3(2.6, 10.0, 2.6), red)
	_add_building(Vector3(street + 7.5, 0, gate_z), Vector3(2.6, 10.0, 2.6), red)
	add_child(_mesh_box(Vector3(16.6, 2.6, 2.8), red, Vector3(street, 10.8, gate_z)))
	add_child(_mesh_box(Vector3(16.6, 0.5, 2.9), cream, Vector3(street, 9.5, gate_z)))
	for fx in [-6.0, 0.0, 6.0]:
		add_child(_mesh_box(Vector3(0.7, 1.1, 0.7), cream, Vector3(street + fx, 12.6, gate_z)))
	var zeds := [z - 12.0, z - 6.5, z + 14.5]
	for i in zeds.size():
		_stall(Vector3(street - 9.0, 0, zeds[i]), 1.0, i)
		_stall(Vector3(street + 9.0, 0, zeds[i]), -1.0, i + 3)
	_add_building(Vector3(x - 11.5, 0, z - 8.0), Vector3(11.0, 7.0, 16.0), Color(0.82, 0.66, 0.45))
	add_child(_mesh_box(Vector3(11.4, 0.7, 16.4), cream, Vector3(x - 11.5, 5.6, z - 8.0)))
	_add_building(Vector3(x - 9.0, 0, z + 14.5), Vector3(16.0, 5.5, 5.0), Color(0.75, 0.55, 0.35))
	add_child(_mesh_box(Vector3(16.4, 0.6, 5.4), cream, Vector3(x - 9.0, 4.4, z + 14.5)))
	for bz in [z - 11.5, z - 4.0]:
		_bunting(street, bz)


func _stall(pos: Vector3, face: float, idx: int) -> void:
	## One bazaar stall: solid counter, striped awning on poles, crates of
	## goods. `face` is +1/-1 — the direction the stall faces (toward the
	## market street).
	var woods := [Color(0.55, 0.40, 0.26), Color(0.48, 0.34, 0.22), Color(0.60, 0.44, 0.28)]
	_add_building(pos, Vector3(2.6, 2.2, 4.2), woods[idx % 3])
	var ax := pos.x + 0.6 * face
	var pair: Array = AWNINGS[idx % AWNINGS.size()]
	add_child(_mesh_box(Vector3(3.4, 0.28, 2.5), pair[0], Vector3(ax, 5.6, pos.z - 1.25)))
	add_child(_mesh_box(Vector3(3.4, 0.28, 2.5), pair[1], Vector3(ax, 5.6, pos.z + 1.25)))
	for side in [-2.2, 2.2]:
		add_child(_mesh_box(Vector3(0.22, 5.6, 0.22), Color(0.35, 0.25, 0.16),
				Vector3(ax, 2.8, pos.z + side)))
	var fruit := [Color(0.95, 0.55, 0.10), Color(0.25, 0.65, 0.25), Color(0.90, 0.20, 0.20), Color(0.95, 0.85, 0.30)]
	for g in range(2):
		add_child(_mesh_box(Vector3(1.1, 1.0, 1.3), fruit[(idx + g) % 4],
				Vector3(pos.x, 2.75, pos.z + (1.0 if g == 0 else -1.0))))


func _bunting(street: float, bz: float) -> void:
	## Festival flags strung across the market lane, hung between two
	## poles with a gentle sag.
	for side in [-7.2, 7.2]:
		add_child(_mesh_box(Vector3(0.2, 6.2, 0.2), Color(0.30, 0.22, 0.15),
				Vector3(street + side, 3.1, bz)))
	var cols := [Color(0.95, 0.45, 0.12), Color(0.85, 0.20, 0.45), Color(0.20, 0.60, 0.25),
		Color(0.95, 0.85, 0.25), Color(0.25, 0.55, 0.90)]
	for f in range(9):
		var t := (f + 1) / 10.0
		var fy := 6.1 - sin(PI * t) * 0.7
		add_child(_mesh_box(Vector3(0.55, 0.7, 0.14), cols[f % 5],
				Vector3(street - 7.2 + 14.4 * t, fy, bz)))


func _build_park(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	for t in range(7):
		_tree(Vector3(x + _rng.randf_range(-13, 13), 0, z + _rng.randf_range(-13, 13)))


func _build_police_station(x: float, z: float) -> void:
	## Thana on a full block: white hall with a navy band, entrance canopy,
	## a watch tower with red/blue beacons. Busted players respawn here.
	add_child(_flat(Vector3(BLOCK - 6.0, 0.06, BLOCK - 6.0), Vector3(x, 0.09, z), Color(0.60, 0.61, 0.64)))
	var white := Color(0.92, 0.93, 0.95)
	var navy := Color(0.10, 0.16, 0.35)
	_add_building(Vector3(x, 0, z - 7.0), Vector3(20.0, 8.0, 9.0), white)
	add_child(_mesh_box(Vector3(20.4, 1.1, 9.4), navy, Vector3(x, 6.2, z - 7.0)))
	add_child(_mesh_box(Vector3(9.0, 0.5, 5.0), navy, Vector3(x, 4.6, z - 1.2)))
	for s in [-4.4, 0.0, 4.4]:
		add_child(_mesh_box(Vector3(0.45, 4.6, 0.45), white, Vector3(x + s, 2.3, z + 1.2)))
	_add_building(Vector3(x + 9.0, 0, z - 9.0), Vector3(3.2, 12.0, 3.2), navy)
	add_child(_mesh_box(Vector3(0.9, 0.9, 0.9), Color(0.95, 0.08, 0.12), Vector3(x + 8.4, 12.6, z - 9.0)))
	add_child(_mesh_box(Vector3(0.9, 0.9, 0.9), Color(0.10, 0.30, 0.98), Vector3(x + 9.6, 12.6, z - 9.0)))


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

	_hud_hp_bg = ColorRect.new()
	_hud_hp_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	_hud_hp_bg.position = Vector2(16, 96)
	_hud_hp_bg.size = Vector2(220, 14)
	_hud_hp_bg.visible = false
	layer.add_child(_hud_hp_bg)
	_hud_hp_fill = ColorRect.new()
	_hud_hp_fill.color = Color(0.25, 0.85, 0.3)
	_hud_hp_fill.position = Vector2(19, 99)
	_hud_hp_fill.size = Vector2(214, 8)
	_hud_hp_fill.visible = false
	layer.add_child(_hud_hp_fill)
	_hud_hp_text = Label.new()
	_hud_hp_text.position = Vector2(242, 93)
	_hud_hp_text.add_theme_font_size_override("font_size", 13)
	_hud_hp_text.visible = false
	layer.add_child(_hud_hp_text)
	_hud_stars = Label.new()
	_hud_stars.position = Vector2(1004, 14)
	_hud_stars.add_theme_font_size_override("font_size", 24)
	_hud_stars.add_theme_color_override("font_color", Color(1.0, 0.83, 0.25))
	_hud_stars.visible = false
	layer.add_child(_hud_stars)
	_flash = ColorRect.new()
	_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_hud_msg = Label.new()
	_hud_msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_msg.add_theme_font_size_override("font_size", 40)
	_hud_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_msg.visible = false
	layer.add_child(_hud_msg)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -46.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	layer.add_child(_toast)
	_minimap = MiniMapScript.new()
	_minimap.setup(WORLD, PITCH, ROAD, GRID + 1, _landmarks)
	layer.add_child(_minimap)


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

	var saved := SaveGame.read()
	if not saved.is_empty():
		var cont_def := _character_by_id(String(saved.get("character", "")))
		if not cont_def.is_empty():
			var runs := 0
			for id in saved.get("missions_completed", {}):
				runs += int(saved["missions_completed"][id])
			var cont := Button.new()
			cont.text = "CONTINUE  ·  %s\nRs %d  ·  %d missions run" % [
					String(cont_def["name"]), int(saved.get("cash", 0)), runs]
			cont.custom_minimum_size = Vector2(460, 0)
			cont.pressed.connect(_start_game.bind(cont_def, saved))
			box.add_child(cont)
			var fresh := Label.new()
			fresh.text = "— or start fresh below —"
			fresh.add_theme_font_size_override("font_size", 12)
			fresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(fresh)

	for def in Game.CHARACTERS:
		var btn := Button.new()
		btn.text = "%s\n%s" % [def["name"], def["role"]]
		btn.custom_minimum_size = Vector2(460, 0)
		btn.pressed.connect(_start_game.bind(def))
		box.add_child(btn)

	var hint := Label.new()
	hint.text = "WASD move · Shift run · E vehicle · F mission · H horn · Q/R street food · Tab switch character · F9 save · X debug hurt · C debug drop"
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _start_game(def: Dictionary, save: Dictionary = {}) -> void:
	Game.selected_character = def
	_select_layer.visible = false
	_hud_name.text = String(def["name"])

	player = PlayerScript.new()
	player.setup(def)
	player.position = Vector3(ROAD / 2.0 + 2.0, 1.0, 2.0 * PITCH - BLOCK)
	add_child(player)
	_traffic.register_player(player)
	_peds.register_player(player)
	_police = PoliceScript.new()
	add_child(_police)
	_police.setup(WORLD, PITCH, ROAD, GRID + 1)
	_police.register_player(player)
	_police.stars_changed.connect(_on_stars_changed)
	_police.arrested.connect(_on_arrested)
	player.landed_hard.connect(_on_landed_hard)
	_health = HealthScript.new()
	add_child(_health)
	_health.changed.connect(_on_health_changed)
	_health.damaged.connect(_on_health_damaged)
	_health.died.connect(_on_died)
	_hud_hp_bg.visible = true
	_hud_hp_fill.visible = true
	_hud_hp_text.visible = true
	_on_health_changed(_health.hp, _health.MAX_HP)
	_missions = MissionScript.new()
	add_child(_missions)
	_missions.register_player(player)
	_food.register(player, _health, _missions)
	_cam_anchor = player.position
	_audio.start_ambient()
	_minimap.visible = true

	var spots := [
		[Vector3(ROAD / 2.0 + 1.5, 1.0, 2.0 * PITCH - BLOCK - 12.0), 0.0, "auto"],
		[Vector3(-ROAD / 2.0 - 1.5, 1.0, -PITCH + 6.0), PI, "car"],
		[Vector3(3.0 * PITCH - BLOCK, 1.0, ROAD / 2.0 + 1.5), PI / 2.0, "car"],
		[Vector3(-2.0 * PITCH + 8.0, 1.0, ROAD / 2.0 + 1.5), PI / 2.0, "van"],
		[Vector3(4.0 * PITCH - BLOCK + 20.0, 1.0, -ROAD / 2.0 - 1.5), -PI / 2.0, "auto"],
		[Vector3(ROAD / 2.0 + 1.5, 1.0, -3.0 * PITCH + 8.0), 0.0, "car"],
		[Vector3(-3.0 * PITCH + 4.0, 1.0, -ROAD / 2.0 - 1.5), -PI / 2.0, "van"],
	]
	for spot in spots:
		var a := AutoScript.new()
		a.setup(spot[0], spot[1], spot[2])
		add_child(a)
		_autos.append(a)

	_playing = true
	if not save.is_empty():
		_apply_save(save)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_update_day(delta)
	if not _playing:
		return
	_impact_cd = maxf(_impact_cd - delta, 0.0)
	_chaos_cd = maxf(_chaos_cd - delta, 0.0)
	var cc := _block_center(4, 7)
	var ccd := Vector2(player.global_position.x - cc.x, player.global_position.z - cc.z).length()
	if not _chandni_seen and ccd < 34.0:
		_chandni_seen = true
		_show_toast("CHANDNI CHOWK · moonlight bazaar")
	elif _chandni_seen and ccd > 60.0:
		_chandni_seen = false
	if _switch_lock > 0.0:
		_switch_lock = maxf(_switch_lock - delta, 0.0)
		if _switch_lock <= 0.0 and _switch_pending_release:
			_switch_pending_release = false
			if not _dead:
				player.controls_enabled = true
	if not _dead:
		if Input.is_action_just_pressed("interact"):
			_toggle_vehicle()
		if Input.is_action_just_pressed("switch_character"):
			_switch_character()
		if Input.is_action_just_pressed("horn"):
			_audio.horn()
		if Input.is_action_just_pressed("debug_hurt"):
			_health.damage(25.0)
		if current_auto == null and Input.is_action_just_pressed("debug_fall"):
			player.global_position += Vector3(0.0, 22.0, 0.0)
		if Input.is_action_just_pressed("save"):
			_save_game()
		if current_auto == null and _impact_cd <= 0.0:
			var hazard: float = _traffic.worst_hazard_speed(player.global_position)
			if hazard > 2.5:
				_health.damage(clampf(4.0 + hazard * 1.4, 8.0, 35.0))
				_impact_cd = 0.8
	if current_auto != null:
		current_auto.drive(delta)
		player.global_position = current_auto.global_position
		if _chaos_cd <= 0.0 and current_auto.current_speed() > 3.0:
			var struck: int = _peds.vehicle_strike(current_auto.global_position, 2.4)
			if struck > 0:
				_police.chaos_peds(struck)
				_chaos_cd = 0.5
			elif _traffic.ram_speed_at(current_auto.global_position) > 3.0:
				_police.chaos_ram()
				_chaos_cd = 0.5
	_update_camera(delta)
	if _minimap.visible:
		var focus: Node3D = current_auto if current_auto != null else player
		_minimap.track(focus.global_position, focus.rotation.y)
		_minimap.set_mission_target(_missions.active_target())
		_minimap.set_police(_police.jeep_positions())


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
		return
	# No parked vehicle nearby: take over the closest ambient traffic vehicle.
	# Traffic brakes for the player standing in its lane, so the nearest one
	# is usually stopped when you step in front of it.
	var hit: Dictionary = _traffic.nearest_enterable(player.global_position, 7.0)
	if not hit.is_empty():
		var v := AutoScript.new()
		v.setup(hit["pos"], hit["heading"], hit["kind"])
		add_child(v)
		_autos.append(v)
		_traffic.take_vehicle(int(hit["id"]))
		current_auto = v
		current_auto.driver_inside = true
		player.visible = false


# ---------------------------------------------------------------- switch

func _switch_character() -> void:
	if not _playing or _dead or _switch_lock > 0.0 \
			or player == null or not is_instance_valid(player):
		return
	if not player.controls_enabled:
		return
	if current_auto != null:
		_show_toast("STEP OUT OF THE VEHICLE TO SWITCH")
		return
	var cur_id := String(Game.selected_character.get("id", ""))
	_stash_character(cur_id)
	var nxt: Dictionary = Game.CHARACTERS[(_char_index(cur_id) + 1) % Game.CHARACTERS.size()]
	Game.selected_character = nxt
	_hud_name.text = String(nxt["name"])
	player.swap_character(nxt)
	var st: Dictionary = _char_states.get(String(nxt["id"]), {})
	if st.is_empty():
		# First outing: debut beside the previous character's spot.
		player.global_position += Vector3(1.4, 0.0, 0.9)
		player.global_position.y = maxf(player.global_position.y, 1.0)
		player.velocity = Vector3.ZERO
		_health.restore(100.0)
		_missions.set_cash(0)
	else:
		player.global_position = st["pos"]
		player.rotation.y = float(st["heading"])
		player.velocity = Vector3.ZERO
		_health.restore(float(st["hp"]))
		_missions.set_cash(int(st["cash"]))
	# Brief control lock while the camera glides over to the new lead.
	_switch_lock = 0.6
	_switch_pending_release = true
	player.controls_enabled = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color.a = 0.16
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)
	_show_toast("NOW PLAYING · " + String(nxt["name"]).to_upper())


func _stash_character(id: String) -> void:
	if player == null or not is_instance_valid(player) \
			or _health == null or _missions == null:
		return
	_char_states[id] = {
		"pos": player.global_position,
		"heading": player.rotation.y,
		"hp": _health.hp,
		"cash": _missions.cash,
	}


func _char_index(id: String) -> int:
	for i in Game.CHARACTERS.size():
		if String(Game.CHARACTERS[i]["id"]) == id:
			return i
	return 0


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


# ---------------------------------------------------------------- health

func _on_health_changed(hp: float, max_hp: float) -> void:
	var ratio: float = hp / max_hp
	_hud_hp_fill.size.x = 214.0 * ratio
	_hud_hp_fill.color = Color(1.0, 0.25, 0.2).lerp(Color(0.25, 0.85, 0.3), ratio)
	_hud_hp_text.text = "HP %d" % int(ceilf(hp))


func _on_stars_changed(s: int) -> void:
	_minimap.set_wanted(s)
	if s <= 0:
		_hud_stars.visible = false
		return
	_hud_stars.visible = true
	_hud_stars.text = "WANTED  " + "*".repeat(s)


func _on_health_damaged(_amount: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color.a = 0.45
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.4)


func _on_landed_hard(impact: float) -> void:
	if _health != null and not _dead:
		_health.damage(clampf((impact - 14.0) * 3.0, 5.0, 50.0))


func _build_landmarks() -> void:
	_landmarks = [
		{"name": "Connaught Place", "center": _block_center(5, 5), "spawn": _block_center(5, 5) + Vector3(14.0, 1.0, 14.0)},
		{"name": "India Gate", "center": _block_center(5, 3), "spawn": _block_center(5, 3) + Vector3(0.0, 1.0, 10.0)},
		{"name": "Purani Dilli Fort", "center": _block_center(3, 7), "spawn": _block_center(3, 7) + Vector3(0.0, 1.0, 12.0)},
		{"name": "Chandni Chowk", "center": _block_center(4, 7), "spawn": _block_center(4, 7) + Vector3(6.0, 1.0, -14.0)},
		{"name": "Neighbourhood Park", "center": _block_center(8, 2), "spawn": _block_center(8, 2) + Vector3(0.0, 1.0, 12.0)},
		{"name": "Police Station", "center": _block_center(7, 5), "spawn": _block_center(7, 5) + Vector3(0.0, 1.0, 10.0), "police": true},
	]


func _nearest_landmark(pos: Vector3) -> Dictionary:
	var best: Dictionary = _landmarks[0]
	var best_d := INF
	for lm in _landmarks:
		var flat := Vector2(pos.x - lm.center.x, pos.z - lm.center.z)
		if flat.length() < best_d:
			best_d = flat.length()
			best = lm
	return best


func _on_died() -> void:
	if _police != null and _police.stars() > 0:
		_start_busted_flow()
		return
	_dead = true
	if _police != null:
		_police.reset()
	if _missions != null:
		_missions.abort_active("You went down")
	if current_auto != null:
		current_auto.driver_inside = false
		current_auto = null
		player.visible = true
	player.controls_enabled = false
	var lm := _nearest_landmark(player.global_position)
	_hud_msg.text = "DOWN & OUT"
	_hud_msg.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(_do_respawn.bind(lm))
	tw.tween_interval(1.0)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)
	tw.tween_callback(_respawn_done)
	tw.tween_interval(1.5)
	tw.tween_callback(_clear_invuln)


func _do_respawn(lm: Dictionary) -> void:
	_health.invulnerable = true
	_health.respawn_reset()
	player.global_position = lm.spawn
	player.velocity = Vector3.ZERO
	_cam_anchor = player.global_position + player.global_transform.basis.z * 10.0 + Vector3(0, 6, 0)
	_hud_msg.text = "Back on your feet \u00b7 " + String(lm.name)


func _respawn_done() -> void:
	_hud_msg.visible = false
	_dead = false
	player.controls_enabled = true
	if _missions != null:
		_missions.resume()


func _clear_invuln() -> void:
	if _health != null:
		_health.invulnerable = false


# ---------------------------------------------------------------- busted

func _on_arrested() -> void:
	_start_busted_flow()


func _start_busted_flow() -> void:
	## BUSTED: surrounded while wanted, or down with heat on you. Fine out
	## of the mission wallet, heat cleared, respawn outside the thana.
	if _dead:
		return
	_dead = true
	var stars := 1
	if _police != null:
		stars = maxi(_police.stars(), 1)
		_police.reset()
	var fine := 0
	if _missions != null:
		fine = _missions.charge_fine(100 * stars)
		_missions.abort_active("you got busted")
	if current_auto != null:
		current_auto.driver_inside = false
		current_auto = null
		player.visible = true
	player.controls_enabled = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(0.20, 0.35, 0.95, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.6)
	_hud_msg.text = "BUSTED"
	_hud_msg.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(_do_busted_respawn.bind(fine))
	tw.tween_interval(1.0)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)
	tw.tween_callback(_respawn_done)
	tw.tween_interval(1.5)
	tw.tween_callback(_clear_invuln)


func _do_busted_respawn(fine: int) -> void:
	var station := _police_station()
	_health.invulnerable = true
	_health.respawn_reset()
	player.global_position = station
	player.velocity = Vector3.ZERO
	_cam_anchor = player.global_position + player.global_transform.basis.z * 10.0 + Vector3(0, 6, 0)
	_hud_msg.text = "RELEASED \u00b7 Rs %d fine" % fine if fine > 0 else "RELEASED \u00b7 pockets empty"


func _police_station() -> Vector3:
	for lm in _landmarks:
		if bool(lm.get("police", false)):
			return lm["spawn"]
	return _landmarks[0]["spawn"]


# ---------------------------------------------------------------- save/load

func _save_game() -> void:
	var data := _collect_save()
	if data.is_empty():
		return
	_show_toast("GAME SAVED" if SaveGame.write(data) else "SAVE FAILED")


func _collect_save() -> Dictionary:
	if not _playing or player == null or not is_instance_valid(player) \
			or _health == null or _missions == null:
		return {}
	# Local transform == world transform here (main sits at the origin),
	# and .position stays readable during teardown, unlike the global_
	# getters which error out on the quit-time save path.
	var pos := player.position
	var heading := player.rotation.y
	if current_auto != null:
		pos = current_auto.position
		heading = current_auto.rotation.y
	var data := {
		"character": String(Game.selected_character.get("id", "")),
		"cash": _missions.cash,
		"hp": _health.hp,
		"pos": [pos.x, pos.y, pos.z],
		"heading": heading,
		"day_t": day_t,
		"missions_completed": _missions.completed,
	}
	# Per-character snapshots so everyone's wallet, health and last spot
	# survive a save/load cycle, not just the current lead.
	var chars := {}
	var cur := String(Game.selected_character.get("id", ""))
	chars[cur] = {"hp": _health.hp, "cash": _missions.cash, "heading": heading,
		"pos": [pos.x, pos.y, pos.z]}
	for id in _char_states:
		if String(id) == cur:
			continue
		var st: Dictionary = _char_states[id]
		var p: Vector3 = st["pos"]
		chars[String(id)] = {"hp": float(st["hp"]), "cash": int(st["cash"]),
			"heading": float(st["heading"]), "pos": [p.x, p.y, p.z]}
	data["chars"] = chars
	return data


func _apply_save(save: Dictionary) -> void:
	day_t = clampf(float(save.get("day_t", day_t)), 0.0, 1.0)
	_health.restore(float(save.get("hp", 100.0)))
	var missions_done = save.get("missions_completed", {})
	if typeof(missions_done) != TYPE_DICTIONARY:
		missions_done = {}
	_missions.restore(int(save.get("cash", 0)), missions_done)
	var chars = save.get("chars", {})
	if typeof(chars) == TYPE_DICTIONARY:
		for id in chars:
			var c: Dictionary = chars[id]
			var raw_c = c.get("pos", [])
			if typeof(raw_c) != TYPE_ARRAY or raw_c.size() != 3:
				continue
			_char_states[String(id)] = {
				"pos": Vector3(float(raw_c[0]), maxf(float(raw_c[1]), 1.0), float(raw_c[2])),
				"heading": float(c.get("heading", 0.0)),
				"hp": clampf(float(c.get("hp", 100.0)), 1.0, 100.0),
				"cash": maxi(int(c.get("cash", 0)), 0),
			}
	var pos := player.global_position
	var raw = save.get("pos", [])
	if typeof(raw) == TYPE_ARRAY and raw.size() == 3:
		pos = Vector3(float(raw[0]), maxf(float(raw[1]), 1.0), float(raw[2]))
	player.global_position = pos
	player.rotation.y = float(save.get("heading", 0.0))
	player.velocity = Vector3.ZERO
	_cam_anchor = player.global_position + player.global_transform.basis.z * 10.0 + Vector3(0, 6, 0)
	_show_toast("WELCOME BACK  ·  GAME LOADED")


func _exit_tree() -> void:
	## Last-resort save when the process ends without a window-close
	## signal (belt-and-braces alongside close_requested).
	var data := _collect_save()
	if not data.is_empty():
		SaveGame.write(data)


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _character_by_id(id: String) -> Dictionary:
	for def in Game.CHARACTERS:
		if String(def["id"]) == id:
			return def
	return {}
