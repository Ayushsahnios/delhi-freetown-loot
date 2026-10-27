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
const RadioScript := preload("res://scripts/radio.gd")
const MiniMapScript := preload("res://scripts/minimap.gd")
const CharactersScript := preload("res://scripts/characters.gd")
const FoodScript := preload("res://scripts/food.gd")
const WeatherScript := preload("res://scripts/weather.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")
const PauseScript := preload("res://scripts/pause.gd")
const MeshTools := preload("res://scripts/meshtools.gd")
const RoadsScript := preload("res://scripts/roads.gd")
const FurnitureScript := preload("res://scripts/street_furniture.gd")
const DressingScript := preload("res://scripts/delhi_dressing.gd")
const CityDressingScript := preload("res://scripts/city_dressing.gd")
const MetroScript := preload("res://scripts/metro.gd")
const RailwayScript := preload("res://scripts/railway.gd")
const TaxiScript := preload("res://scripts/taxi.gd")
const CourierScript := preload("res://scripts/courier.gd")
const PhotoScript := preload("res://scripts/photo.gd")

## Rideable metro shuttle (issue #98 part 2): boarding state, queued
## boarding while the train is en route, and the interior-cam anchors.
var _metro: MetroScript = null
var _railway: RailwayScript = null
var _metro_riding := false
var _metro_wait := -1
var _metro_board_idx := -1
var _cam_look_pt := Vector3(0.0, 2.0, 0.0)

const SKY_DAY := Color(0.53, 0.81, 0.92)
const SKY_DUSK := Color(0.88, 0.48, 0.22)
const SKY_NIGHT := Color(0.04, 0.06, 0.19)
const STORM_SKY := Color(0.22, 0.25, 0.30)
## Dust-haze atmosphere + warm grade (issue 132): warm-noon sun
## (~5800K per the art reference), warm-gray aerial haze, ground bias.
const SUN_DAY := Color(1.0, 0.93, 0.80)
const SUN_NIGHT := Color(0.55, 0.62, 0.80)
const FOG_DAY := 0.007
const FOG_NIGHT := 0.0012
const FOG_COL_DAY := Color(0.87, 0.80, 0.66)
const FOG_COL_NIGHT := Color(0.10, 0.12, 0.18)
const ROAD_TINT_DRY := Color(1.0, 1.0, 1.0)
const ROAD_TINT_WET := Color(0.45, 0.47, 0.58)
const PALETTE := [
	Color(0.85, 0.78, 0.66), Color(0.79, 0.64, 0.48), Color(0.71, 0.72, 0.76),
	Color(0.85, 0.56, 0.42), Color(0.62, 0.71, 0.78), Color(0.88, 0.84, 0.75),
]

var player: CharacterBody3D
var camera: Camera3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _sun_shadows_wanted := true
var _sky_mat: ProceduralSkyMaterial = null
var _cloud_layer: Node3D = null
var _cloud_mat: StandardMaterial3D = null

var day_t := 0.32
var current_auto: CharacterBody3D = null
var _autos: Array[CharacterBody3D] = []
var _speed_bumps: Array = []
var _rng := RandomNumberGenerator.new()
var _playing := false
var _traffic: Node
var _peds: Node
var _hud_name: Label
var _hud_clock: Label
var _hud_day: Label
var _select_layer: CanvasLayer
var _chars := CharactersScript.new()
var _portrait_models: Array[Node3D] = []
var _portrait_views: Array[SubViewport] = []
var _cam_anchor := Vector3.ZERO
var _health: Node
var _landmarks: Array[Dictionary] = []
var _dead := false
var _impact_cd := 0.0
var _audio: Node
var _radio: Node
var _minimap: Control
var _food: Node
var _taxi: Node
var _courier: Node
var _photo: Node
var _hud_hp_bg: ColorRect
var _hud_hp_fill: ColorRect
var _hud_hp_text: Label
var _hud_stars: Label
var _hud_radio: Label
var _police: Node
var _missions: Node
var _chaos_cd := 0.0
var _flash: ColorRect
var _fade: ColorRect
var _hud_msg: Label
var _hud_msg_sub: Label
var _controls_card: CanvasLayer = null
var _card_alive := 0.0
var _flash_tween: Tween
var _toast: Label
var _toast_tween: Tween
var _char_states := {}
var _switch_lock := 0.0
var _switch_pending_release := false
var _chandni_seen := false
var _weather: WeatherScript
var _road_mat: StandardMaterial3D
var _applied_wet := -1.0
var _touch: CanvasLayer
var _pause: CanvasLayer
var _districts := {}
var _cur_district: MeshTools = null
var _tree_trunk_xfs: Array[Transform3D] = []
var _tree_crown_xfs: Array[Transform3D] = []
var _bunt_pole_xfs: Array[Vector3] = []
var _tank_xfs: Array[Transform3D] = []
var _ac_xfs: Array[Transform3D] = []
var _dish_xfs: Array[Transform3D] = []
var _pillar_xfs: Array[Transform3D] = []
var _metro_seg_xfs: Array[Transform3D] = []
var _win_xfs: Array[Transform3D] = []
var _win_lit_xfs: Array[Transform3D] = []
var _win_lit_mat: StandardMaterial3D = null
var _street_lights: Array[OmniLight3D] = []
var _lamp_pole_xfs: Array[Transform3D] = []
var _lamp_head_xfs: Array[Transform3D] = []


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	var boot := PauseScript.load_settings()
	PauseScript.apply_audio(boot)
	_sun_shadows_wanted = bool(boot.get("shadows", true))
	sun.shadow_enabled = _sun_shadows_wanted
	_weather = WeatherScript.new()
	add_child(_weather)
	_weather.setup()
	_weather.thunder_flash.connect(_on_thunder)
	_build_city()
	_build_landmarks()
	_build_street_lights()
	_food = FoodScript.new()
	add_child(_food)
	_food.setup(_landmarks)
	_taxi = TaxiScript.new()
	add_child(_taxi)
	_taxi.setup(_landmarks)
	_courier = CourierScript.new()
	add_child(_courier)
	_courier.setup(_landmarks)
	_traffic = TrafficScript.new()
	add_child(_traffic)
	_traffic.setup(WORLD, PITCH, ROAD, GRID + 1)
	_traffic.set_speed_bumps(_speed_bumps)
	_peds = PedestrianScript.new()
	add_child(_peds)
	_peds.setup(WORLD, PITCH, ROAD, GRID + 1)
	_peds.set_crowd_zone(_block_center(4, 7) + Vector3(6.0, 0.0, 0.0), 46.0)
	_peds.set_crowd_zone(_block_center(2, 8) + Vector3(0.0, 0.0, -8.0), 40.0)
	_peds.set_crowd_zone(_block_center(9, 8) + Vector3(-11.0, 0.0, 0.0), 40.0)
	_audio = AudioScript.new()
	add_child(_audio)
	_audio.setup()
	_radio = RadioScript.new()
	add_child(_radio)
	_radio.setup()
	camera = Camera3D.new()
	add_child(camera)
	_build_hud()
	_build_select_ui()
	_touch = TouchControlsScript.new()
	add_child(_touch)
	_pause = PauseScript.new()
	_pause.setup(self)
	add_child(_pause)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_tree().root.close_requested.connect(_save_game)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		_show_toast("GAMEPAD CONNECTED")


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = SKY_DAY
	_sky_mat.sky_horizon_color = SKY_DAY
	_sky_mat.ground_bottom_color = Color(0.22, 0.24, 0.22)
	_sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.62)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.6
	# Filmic tonemap + soft bloom: sunlit facades and the emissive night
	# windows get gentle halos instead of clipping to white. The web build
	# runs the compatibility renderer, where glow composites in LDR (no HDR
	# buffer), so intensity/bloom stay conservative and the threshold high
	# or the whole frame washes out (issue #76).
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.29
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Dust-haze atmosphere (issue 132): exponential aerial fog with a
	# warm-gray tint and a subtle ground-height bias — distance reads
	# hazy Delhi noon, not crisp generic. Density and color are
	# day-driven in _update_day so night keeps its lamp pools.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = FOG_DAY
	env.fog_light_color = FOG_COL_DAY
	env.fog_sky_affect = 0.25
	env.fog_height = 2.0
	env.fog_height_density = 0.08
	# Warm North-India grade: gentle contrast, slightly desaturated
	# palette, lifted warm shadows via a procedural 1-D grade (no LUT
	# asset needed). Renderers without color-correction support fall
	# back to the plain grade gracefully.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.9
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	grade.colors = PackedColorArray([
		Color(0.055, 0.048, 0.042), Color(0.32, 0.28, 0.24),
		Color(0.78, 0.75, 0.68), Color(1.0, 0.985, 0.945),
	])
	var grade_tex := GradientTexture1D.new()
	grade_tex.gradient = grade
	env.adjustment_color_correction = grade_tex
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_build_clouds()

func _build_clouds() -> void:
	## Drifting puff layer: one MultiMesh of soft radial-gradient quads high
	## above the city; the whole layer rotates slowly so cover always moves.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.albedo_texture = tex
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var puff := QuadMesh.new()
	puff.size = Vector2(46.0, 27.0)
	puff.material = _cloud_mat
	var flat := Basis(Vector3(1.0, 0.0, 0.0), PI / 2.0)
	var xfs: Array[Transform3D] = []
	for i in 48:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(40.0, WORLD * 0.75)
		xfs.append(Transform3D(flat.scaled(Vector3(
				_rng.randf_range(0.7, 1.8), _rng.randf_range(0.7, 1.4), 1.0)),
				Vector3(cos(a) * r, 88.0 + _rng.randf_range(-6.0, 10.0), sin(a) * r)))
	_cloud_layer = Node3D.new()
	add_child(_cloud_layer)
	var mmi := MeshTools.make_multimesh(puff, xfs)
	if mmi != null:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cloud_layer.add_child(mmi)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_energy = 1.0
	sun.light_color = SUN_DAY
	# Real-time sun shadows: two split bands (near actors + far buildings)
	# tuned so the web/mobile renderers stay smooth and skin never acnes.
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
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

	# roads — textured asphalt with lane wear, tiled sidewalks with curbs
	# and zebra crossings (one merged mesh); one shared asphalt material so
	# the whole network still darkens as rain soaks in
	_road_mat = RoadsScript.make_asphalt_material()
	add_child(RoadsScript.build(WORLD, PITCH, ROAD, GRID + 1, _road_mat))

	# street furniture (issue #69): bus-stop shelters on the sidewalks of
	# the major roads, speed bumps around Chandni Chowk and Connaught Place
	var furn := FurnitureScript.build(WORLD, PITCH, ROAD, GRID + 1)
	if furn.node != null:
		add_child(furn.node)
	_speed_bumps = furn.bumps
	# Physics pass (issue #77): bus-stop shelters are solid — one box per
	# stop footprint (bench, posts and roof) so vehicles cannot drive
	# through the waiting bays on the sidewalk.
	if not furn.stops.is_empty():
		var stops := StaticBody3D.new()
		stops.name = "ShelterColliders"
		for stop in furn.stops:
			var xf: Transform3D = stop
			stops.add_child(_coll_box(Vector3(3.0, 2.7, 1.5),
					xf * Transform3D(Basis(),
					Vector3(0.4, RoadsScript.CURB_H + 1.35, -0.05))))
		add_child(stops)

	# Delhi street dressing (issue #129): tangled overhead wiring on
	# concrete poles, yellow-black painted kerbs, thela produce carts
	# and a chai stall — the reference-driven Old Delhi street look.
	add_child(DressingScript.build(WORLD, PITCH, ROAD))
	# Delhi street-life dressing (issue #129 slice 2): two incidental
	# kerbside cows and a roadside shrine near the landmarks.
	add_child(CityDressingScript.build(WORLD, PITCH, ROAD))

	# blocks — static visuals accumulate into per-district merged meshes
	for ix in range(GRID):
		for iz in range(GRID):
			_cur_district = _builder_for(ix, iz)
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
			elif ix == 2 and iz == 8:
				_build_hauz_khas(c.x, c.z)
			elif ix == 9 and iz == 8:
				_build_yamuna_ghats(c.x, c.z)
			elif ix == 5 and iz == 0:
				pass  # railway station district — built by RailwayScript below
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
					var bpos := Vector3(c.x + ox, 0, c.z + oz)
					_add_building(bpos, Vector3(w, h, d),
							PALETTE[_rng.randi_range(0, PALETTE.size() - 1)])
					_add_windows(bpos, Vector3(w, h, d))
					# Delhi skyline dressing (issue #129 slice 2): rooftop
					# water tanks, wall AC units and satellite dishes.
					var decor := CityDressingScript.building_decor(c, bpos,
							Vector3(w, h, d))
					_tank_xfs.append_array(decor["tanks"])
					_ac_xfs.append_array(decor["acs"])
					_dish_xfs.append_array(decor["dishes"])
				_tree(Vector3(c.x - BLOCK / 2.0 + 2.0, 0, c.z - BLOCK / 2.0 + 2.0))

	_cur_district = null
	_build_metro(0.0, -WORLD / 2.0 + 4.0 * PITCH - BLOCK / 2.0)
	# Issue #98 part 2: the shuttle itself — train, twin station gates,
	# interior-cam ride. Signal-driven toasts keep the HUD informed.
	_metro = MetroScript.new()
	_metro.setup()
	add_child(_metro)
	_metro.arrived.connect(_on_metro_arrived)
	_metro.departed.connect(_on_metro_departed)

	# Railway station district (issue #133): terminal platforms, truss
	# canopy, porters, trolleys and a scene train that cycles in from
	# beyond the north edge. Toasts announce arrivals/departures.
	_railway = RailwayScript.new()
	_railway.setup(_block_center(5, 0))
	add_child(_railway)
	_railway.arrived.connect(
			func(): _show_toast("Passenger train arriving — New Delhi platform"))
	_railway.departed.connect(
			func(): _show_toast("Passenger train departing — stand clear"))

	# Commit: one merged mesh per district, one MultiMesh per repeated prop.
	for key in _districts:
		var node: MeshInstance3D = _districts[key].build_node()
		if node != null:
			add_child(node)
	_commit_props()


func _block_center(ix: int, iz: int) -> Vector3:
	## Roads, traffic, pedestrians, police, minimap and the metro all place
	## their lines at -W/2 + i*PITCH - BLOCK/2 (roads.gd build(), traffic/
	## pedestrian/police setup math). Blocks fill the gaps BETWEEN road
	## lines: block i sits midway between road i and road i+1, so its
	## 34 m footprint spans exactly [road_i + 6, road_{i+1} - 6] and never
	## touches asphalt (issue #67).
	return Vector3(-WORLD / 2.0 + ix * PITCH + ROAD / 2.0, 0.0,
			-WORLD / 2.0 + iz * PITCH + ROAD / 2.0)


func _builder_for(ix: int, iz: int) -> MeshTools:
	## Districts are 3x3 block tiles: 16 merged meshes cover the whole city.
	var key := Vector2i(int(ix / 3.0), int(iz / 3.0))
	if not _districts.has(key):
		_districts[key] = MeshTools.new()
	return _districts[key]


func _builder_at(p: Vector3) -> MeshTools:
	## Nearest-block index under the road-aligned block grid (see
	## _block_center): i = roundi((v + W/2 - ROAD/2) / PITCH).
	return _builder_for(
			clampi(roundi((p.x + WORLD / 2.0 - ROAD / 2.0) / PITCH), 0, GRID - 1),
			clampi(roundi((p.z + WORLD / 2.0 - ROAD / 2.0) / PITCH), 0, GRID - 1))


func _dist_box(size: Vector3, center: Vector3, color: Color) -> void:
	## Static colored box folded into the current district's merged mesh.
	if _cur_district == null:
		_cur_district = _builder_at(center)
	_cur_district.add_box(size, center, color)


func _commit_props() -> void:
	## Repeated props draw as one MultiMesh each: tree parts,
	## metro pillars and deck segments.
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.5
	trunk.height = 2.6
	trunk.material = MeshTools.shared_material(Color(0.42, 0.29, 0.17))
	_add_mm(trunk, _tree_trunk_xfs)
	var crown := SphereMesh.new()
	crown.radius = 2.1
	crown.height = 3.4
	crown.material = MeshTools.shared_material(Color(0.18, 0.49, 0.20))
	_add_mm(crown, _tree_crown_xfs)
	# Skyline dressing (issue #129 slice 2): merged prop meshes draw
	# once per transform like the tree parts above.
	_add_prop_mm(CityDressingScript.tank_mesh(), _tank_xfs)
	_add_prop_mm(CityDressingScript.ac_mesh(), _ac_xfs)
	_add_prop_mm(CityDressingScript.dish_mesh(), _dish_xfs)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.8
	pillar.bottom_radius = 1.0
	pillar.height = 12.0
	pillar.material = MeshTools.shared_material(Color(0.55, 0.58, 0.62))
	_add_mm(pillar, _pillar_xfs)
	# Pier capitals (issue #78): the pillar tops used to vanish into the
	# deck's shadow side, so from street level a lone column read as a
	# pole terminating mid-air against the buildings behind it. A wider
	# capital under each deck makes the joint read as carrying it.
	var cap := BoxMesh.new()
	cap.size = Vector3(2.2, 0.8, 2.2)
	cap.material = MeshTools.shared_material(Color(0.48, 0.51, 0.55))
	var cap_xfs: Array[Transform3D] = []
	for xf: Transform3D in _pillar_xfs:
		var o: Vector3 = xf.origin
		cap_xfs.append(Transform3D(Basis(), Vector3(o.x, 11.9, o.z)))
	_add_mm(cap, cap_xfs)
	var seg := BoxMesh.new()
	seg.size = Vector3(ROAD - 2.0, 1.2, 22.0)
	seg.material = MeshTools.shared_material(Color(0.32, 0.35, 0.42))
	_add_mm(seg, _metro_seg_xfs)
	# Physics pass (issue #77): repeated props get real collision too —
	# one StaticBody3D holding a box per tree trunk, metro pillar and
	# bazaar bunting pole, matched to the visual footprints, so neither
	# characters nor vehicles can phase through them anymore.
	var solid := StaticBody3D.new()
	solid.name = "PropColliders"
	for xf in _tree_trunk_xfs:
		solid.add_child(_coll_box(Vector3(0.9, 2.6, 0.9), xf))
	for xf in _pillar_xfs:
		solid.add_child(_coll_box(Vector3(1.8, 12.0, 1.8), xf))
	for pole in _bunt_pole_xfs:
		solid.add_child(_coll_box(Vector3(0.44, 6.2, 0.44), Transform3D(Basis(), pole)))
	if solid.get_child_count() > 0:
		add_child(solid)
	# Facade glazing: every tower window is one quad instance; a fixed
	# random subset carries the warm emissive material that glows at night.
	var glass := QuadMesh.new()
	glass.size = Vector2(1.5, 1.9)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.08, 0.11, 0.16)
	glass_mat.metallic = 0.5
	glass_mat.roughness = 0.25
	glass.material = glass_mat
	var glass_mm := _add_mm(glass, _win_xfs)
	var lit := QuadMesh.new()
	lit.size = Vector2(1.5, 1.9)
	_win_lit_mat = StandardMaterial3D.new()
	_win_lit_mat.albedo_color = Color(1.0, 0.87, 0.6)
	_win_lit_mat.emission_enabled = true
	_win_lit_mat.emission = Color(1.0, 0.82, 0.5)
	_win_lit_mat.emission_energy_multiplier = 0.0
	lit.material = _win_lit_mat
	var lit_mm := _add_mm(lit, _win_lit_xfs)
	# Panes are flat stickers on the wall: keep them out of the shadow map.
	for pane in [glass_mm, lit_mm]:
		if pane != null:
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_mm(mesh: PrimitiveMesh, xfs: Array[Transform3D]) -> MultiMeshInstance3D:
	var node := MeshTools.make_multimesh(mesh, xfs)
	if node != null:
		add_child(node)
	return node


func _add_prop_mm(mesh: ArrayMesh, xfs: Array[Transform3D]) -> void:
	## Multi-part prop meshes from the dressing modules: one MultiMesh,
	## no colliders (tanks sit on roofs, ACs/dishes mount well above
	## head height).
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _coll_box(size: Vector3, xf: Transform3D) -> CollisionShape3D:
	## One box collision shape at `xf` — the solid half of a repeated
	## prop (issue #77). Shapes share one parent StaticBody3D so the
	## broadphase sees a single body per prop family.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = xf
	return col


func _add_windows(pos: Vector3, size: Vector3) -> void:
	## Facade pass for district towers: a grid of dark panes on each
	## street-facing wall; a fixed random subset glows after dark. Short
	## huts (h < 9) stay plain plaster — they read as shops, not offices.
	if size.y < 9.0:
		return
	for side in 4:
		var theta := float(side) * PI / 2.0
		var nrm := Vector3(sin(theta), 0.0, cos(theta))
		var across := Vector3(nrm.z, 0.0, -nrm.x)
		var wall_len: float = nrm.z * size.x + nrm.x * size.z
		var cols := int((wall_len - 4.0) / 3.0)
		var rows := int((size.y - 5.0) / 3.6)
		if cols < 1 or rows < 1:
			continue
		var half_out: float = (absf(nrm.x) * size.x + absf(nrm.z) * size.z) * 0.5
		for r in rows:
			for c in cols:
				var u: float = (float(c) + 0.5 - cols * 0.5) * 3.0
				var at := pos + Vector3(0.0, 2.6 + float(r) * 3.6, 0.0) \
						+ across * u + nrm * (half_out + 0.06)
				var xf := Transform3D(Basis(Vector3.UP, theta), at)
				_win_xfs.append(xf)
				if _rng.randf() < 0.42:
					_win_lit_xfs.append(xf.translated(nrm * 0.06))

func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	body.add_child(shape)
	add_child(body)
	_dist_box(size, pos + Vector3(0, size.y / 2.0, 0), color)


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



func _tree(pos: Vector3) -> void:
	## Trees are repeated props: collected here, drawn later as two
	## MultiMeshes (trunks + crowns) in _commit_props().
	_tree_trunk_xfs.append(Transform3D(Basis(), pos + Vector3(0, 1.3, 0)))
	_tree_crown_xfs.append(Transform3D(Basis(), pos + Vector3(0, 4.1, 0)))


func _grass(pos: Vector3) -> void:
	_dist_box(Vector3(BLOCK - 2.0, 0.06, BLOCK - 2.0), pos + Vector3(0, 0.1, 0), Color(0.24, 0.48, 0.25))


func _build_cp(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var pm := CylinderMesh.new()
	pm.top_radius = 9.5
	pm.bottom_radius = 9.5
	pm.height = 0.7
	_cur_district.add_mesh(pm, Transform3D(Basis(), Vector3(x, 0.35, z)), Color(0.18, 0.56, 0.27))
	_add_building(Vector3(x, 0, z), Vector3(18.0, 1.0, 18.0), Color(0.18, 0.56, 0.27))
	# Ring colonnade hugs the central green inside the block: radius 13.4
	# keeps every footprint within +-17 m of the block center, clear of the
	# road/sidewalk band that starts at the block edge (issue #67).
	for a in range(8):
		var ang := TAU * a / 8.0
		var bp := Vector3(x + cos(ang) * 13.4, 0, z + sin(ang) * 13.4)
		var h := 14.0 + (a % 3) * 4.0
		_add_building(bp, Vector3(7.0, h, 7.0), Color(0.94, 0.92, 0.85))


func _build_india_gate(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var stone := Color(0.54, 0.45, 0.33)
	_add_building(Vector3(x - 6.0, 0, z), Vector3(3.0, 16.0, 5.0), stone)
	_add_building(Vector3(x + 6.0, 0, z), Vector3(3.0, 16.0, 5.0), stone)
	_dist_box(Vector3(16.0, 4.0, 5.0), Vector3(x, 16.5, z), stone)
	_tree(Vector3(x - 12, 0, z - 12))
	_tree(Vector3(x + 12, 0, z + 12))


func _build_purani_dilli(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	var red := Color(0.61, 0.24, 0.18)
	_add_building(Vector3(x, 0, z - BLOCK / 2.0 + 2.0), Vector3(BLOCK - 4.0, 9.0, 3.0), red)
	_add_building(Vector3(x, 0, z), Vector3(12.0, 12.0, 12.0), red)
	var dbm := CylinderMesh.new()
	dbm.top_radius = 3.4
	dbm.bottom_radius = 4.2
	dbm.height = 2.2
	_cur_district.add_mesh(dbm, Transform3D(Basis(), Vector3(x, 13.1, z)), Color(0.85, 0.78, 0.66))
	var dm := SphereMesh.new()
	dm.radius = 3.4
	dm.height = 8.5
	_cur_district.add_mesh(dm,
			Transform3D(Basis().scaled(Vector3(1, 1.25, 1)), Vector3(x, 15.2, z)),
			Color(0.95, 0.92, 0.82))


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
	_dist_box(Vector3(BLOCK - 2.0, 0.06, BLOCK - 2.0), Vector3(x, 0.07, z),
			Color(0.71, 0.62, 0.48))
	var street := x + 6.0
	var gate_z := z - 15.0
	var red := Color(0.60, 0.25, 0.15)
	var cream := Color(0.93, 0.88, 0.76)
	_add_building(Vector3(street - 7.5, 0, gate_z), Vector3(2.6, 10.0, 2.6), red)
	_add_building(Vector3(street + 7.5, 0, gate_z), Vector3(2.6, 10.0, 2.6), red)
	_dist_box(Vector3(16.6, 2.6, 2.8), Vector3(street, 10.8, gate_z), red)
	_dist_box(Vector3(16.6, 0.5, 2.9), Vector3(street, 9.5, gate_z), cream)
	for fx in [-6.0, 0.0, 6.0]:
		_dist_box(Vector3(0.7, 1.1, 0.7), Vector3(street + fx, 12.6, gate_z), cream)
	var zeds := [z - 12.0, z - 6.5, z + 14.5]
	for i in zeds.size():
		_stall(Vector3(street - 9.0, 0, zeds[i]), 1.0, i)
		_stall(Vector3(street + 9.0, 0, zeds[i]), -1.0, i + 3)
	_add_building(Vector3(x - 11.5, 0, z - 8.0), Vector3(11.0, 7.0, 16.0), Color(0.82, 0.66, 0.45))
	_dist_box(Vector3(11.4, 0.7, 16.4), Vector3(x - 11.5, 5.6, z - 8.0), cream)
	_add_building(Vector3(x - 9.0, 0, z + 14.5), Vector3(16.0, 5.5, 5.0), Color(0.75, 0.55, 0.35))
	_dist_box(Vector3(16.4, 0.6, 5.4), Vector3(x - 9.0, 4.4, z + 14.5), cream)
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
	_dist_box(Vector3(3.4, 0.28, 2.5), Vector3(ax, 5.6, pos.z - 1.25), pair[0])
	_dist_box(Vector3(3.4, 0.28, 2.5), Vector3(ax, 5.6, pos.z + 1.25), pair[1])
	for side in [-2.2, 2.2]:
		_dist_box(Vector3(0.22, 5.6, 0.22), Vector3(ax, 2.8, pos.z + side),
				Color(0.35, 0.25, 0.16))
	var fruit := [Color(0.95, 0.55, 0.10), Color(0.25, 0.65, 0.25), Color(0.90, 0.20, 0.20), Color(0.95, 0.85, 0.30)]
	for g in range(2):
		_dist_box(Vector3(1.1, 1.0, 1.3), Vector3(pos.x, 2.75, pos.z + (1.0 if g == 0 else -1.0)),
				fruit[(idx + g) % 4])


func _bunting(street: float, bz: float) -> void:
	## Festival flags strung across the market lane, hung between two
	## poles with a gentle sag. Poles stand at ±6.0 from the lane axis —
	## inboard of the stall awnings (which reach street∓6.7) so no pole
	## or flag card intersects a stall frame (issue #103).
	for side in [-6.0, 6.0]:
		var pole := Vector3(street + side, 3.1, bz)
		_dist_box(Vector3(0.2, 6.2, 0.2), pole, Color(0.30, 0.22, 0.15))
		_bunt_pole_xfs.append(pole)
	var cols := [Color(0.95, 0.45, 0.12), Color(0.85, 0.20, 0.45), Color(0.20, 0.60, 0.25),
		Color(0.95, 0.85, 0.25), Color(0.25, 0.55, 0.90)]
	for f in range(9):
		var t := (f + 1) / 10.0
		var fy := 6.1 - sin(PI * t) * 0.7
		_dist_box(Vector3(0.55, 0.7, 0.14), Vector3(street - 6.0 + 12.0 * t, fy, bz),
				cols[f % 5])


func _build_park(x: float, z: float) -> void:
	_grass(Vector3(x, 0, z))
	## Keep the respawn clearing free of trunks (see _build_landmarks:
	## parks respawn at block center + z+12) — nobody spawns inside a
	## tree once trunks are solid (issue #77).
	var keep_out := Vector2(x, z + 12.0)
	for t in range(7):
		var p := Vector2(x + _rng.randf_range(-13, 13), z + _rng.randf_range(-13, 13))
		if p.distance_to(keep_out) < 3.5:
			continue
		_tree(Vector3(p.x, 0, p.y))


func _build_police_station(x: float, z: float) -> void:
	## Thana on a full block: white hall with a navy band, entrance canopy,
	## a watch tower with red/blue beacons. Busted players respawn here.
	_dist_box(Vector3(BLOCK - 6.0, 0.06, BLOCK - 6.0), Vector3(x, 0.09, z), Color(0.60, 0.61, 0.64))
	var white := Color(0.92, 0.93, 0.95)
	var navy := Color(0.10, 0.16, 0.35)
	_add_building(Vector3(x, 0, z - 7.0), Vector3(20.0, 8.0, 9.0), white)
	_dist_box(Vector3(20.4, 1.1, 9.4), Vector3(x, 6.2, z - 7.0), navy)
	_dist_box(Vector3(9.0, 0.5, 5.0), Vector3(x, 4.6, z - 1.2), navy)
	for s in [-4.4, 0.0, 4.4]:
		_dist_box(Vector3(0.45, 4.6, 0.45), Vector3(x + s, 2.3, z + 1.2), white)
	_add_building(Vector3(x + 9.0, 0, z - 9.0), Vector3(3.2, 12.0, 3.2), navy)
	_dist_box(Vector3(0.9, 0.9, 0.9), Vector3(x + 8.4, 12.45, z - 9.0), Color(0.95, 0.08, 0.12))
	_dist_box(Vector3(0.9, 0.9, 0.9), Vector3(x + 9.6, 12.45, z - 9.0), Color(0.10, 0.30, 0.98))


func _build_hauz_khas(x: float, z: float) -> void:
	## Lake district (issue #97): a royal tank ringed by domed tomb
	## pavilions and broken pillars, with a cafe strip on the north edge.
	## Landmark respawn is on the east rim, clear of the water.
	_grass(Vector3(x, 0, z))
	var lake := Vector3(x, 0, z + 3.0)
	var bank := CylinderMesh.new()
	bank.top_radius = 12.6
	bank.bottom_radius = 12.6
	bank.height = 0.12
	_cur_district.add_mesh(bank, Transform3D(Basis(),
			lake + Vector3(0, 0.10, 0)), Color(0.62, 0.55, 0.40))
	var water := CylinderMesh.new()
	water.top_radius = 11.8
	water.bottom_radius = 11.8
	water.height = 0.1
	_cur_district.add_mesh(water, Transform3D(Basis(),
			lake + Vector3(0, 0.16, 0)), Color(0.13, 0.35, 0.38))
	var stone := Color(0.72, 0.66, 0.55)
	var cream := Color(0.93, 0.88, 0.74)
	for deg in [150.0, 180.0, 210.0]:
		var a := deg_to_rad(deg)
		var pav := lake + Vector3(cos(a) * 13.8, 0, sin(a) * 13.8)
		_add_building(pav, Vector3(4.2, 3.4, 4.2), stone)
		var drum := CylinderMesh.new()
		drum.top_radius = 1.9
		drum.bottom_radius = 1.9
		drum.height = 0.8
		_cur_district.add_mesh(drum, Transform3D(Basis(),
				pav + Vector3(0, 3.8, 0)), stone)
		var dome := SphereMesh.new()
		dome.radius = 1.9
		dome.height = 5.2
		_cur_district.add_mesh(dome,
				Transform3D(Basis().scaled(Vector3(1, 1.1, 1)),
				pav + Vector3(0, 4.4, 0)), cream)
	for stub in [
		[Vector3(x - 7.0, 0, z + 7.0), 1.1],
		[Vector3(x - 16.0, 0, z - 5.0), 1.6],
		[Vector3(x + 14.5, 0, z + 9.0), 0.9],
		[Vector3(x - 9.0, 0, z - 8.0), 2.1],
	]:
		_add_building(stub[0], Vector3(0.8, stub[1], 0.8), stone)
	var cafe_cols := [Color(0.86, 0.62, 0.44), Color(0.62, 0.71, 0.78),
			Color(0.85, 0.56, 0.42)]
	for i in 3:
		var cx := x + (i - 1) * 10.0
		_add_building(Vector3(cx, 0, z - 12.5), Vector3(6.0, 3.4, 4.4), cafe_cols[i])
		var pair: Array = AWNINGS[i]
		_dist_box(Vector3(6.4, 0.3, 1.6), Vector3(cx, 3.6, z - 11.2), pair[0])
		_dist_box(Vector3(6.4, 0.3, 1.6), Vector3(cx, 3.6, z - 9.6), pair[1])
		_dist_box(Vector3(1.8, 0.8, 0.2), Vector3(cx, 4.0, z - 14.6), pair[1])
	_tree(Vector3(x - 15.0, 0, z + 14.0))
	_tree(Vector3(x + 15.0, 0, z - 14.0))
	_tree(Vector3(x - 16.0, 0, z - 9.0))


func _build_yamuna_ghats(x: float, z: float) -> void:
	## Riverfront district (issue #97): broad ghat steps descending east
	## into the water, moored wooden boats, parasols, a shrine at the head
	## of the steps and a footbridge over the south end.
	_dist_box(Vector3(BLOCK - 2.0, 0.06, BLOCK - 2.0), Vector3(x, 0.09, z),
			Color(0.66, 0.60, 0.50))
	_dist_box(Vector3(24.0, 0.1, 30.0), Vector3(x + 5.0, 0.1, z),
			Color(0.28, 0.40, 0.50))
	var step_cols := [Color(0.78, 0.72, 0.60), Color(0.78, 0.72, 0.60),
			Color(0.70, 0.66, 0.56), Color(0.70, 0.66, 0.56)]
	var step_h := [1.2, 0.9, 0.6, 0.3]
	for i in 4:
		_add_building(Vector3(x - 11.0 + i * 3.4, 0, z),
				Vector3(3.4, step_h[i], 26.0), step_cols[i])
	_add_building(Vector3(x - 14.3, 0, z - 10.0), Vector3(3.0, 2.8, 3.0),
			Color(0.85, 0.55, 0.25))
	var sd := SphereMesh.new()
	sd.radius = 1.3
	sd.height = 3.4
	_cur_district.add_mesh(sd, Transform3D(Basis().scaled(Vector3(1, 0.9, 1)),
			Vector3(x - 14.3, 3.1, z - 10.0)), Color(0.93, 0.88, 0.74))
	_dist_box(Vector3(0.1, 3.2, 0.1), Vector3(x - 14.3, 1.6, z - 8.2),
			Color(0.35, 0.25, 0.15))
	_dist_box(Vector3(0.9, 0.5, 0.06), Vector3(x - 13.8, 2.95, z - 8.2),
			Color(0.95, 0.55, 0.15))
	for pd in [
		[Vector3(x - 14.0, 0, z + 5.0), Color(0.85, 0.25, 0.45)],
		[Vector3(x - 14.0, 0, z + 9.0), Color(0.15, 0.55, 0.55)],
		[Vector3(x - 12.0, 0, z + 1.0), Color(0.95, 0.55, 0.15)],
	]:
		_dist_box(Vector3(0.12, 2.3, 0.12),
				pd[0] + Vector3(0, 1.15, 0), Color(0.35, 0.25, 0.15))
		var disc := CylinderMesh.new()
		disc.top_radius = 1.4
		disc.bottom_radius = 1.4
		disc.height = 0.16
		_cur_district.add_mesh(disc, Transform3D(Basis(),
				pd[0] + Vector3(0, 2.32, 0)), pd[1])
	var boat_cols := [Color(0.50, 0.36, 0.22), Color(0.55, 0.30, 0.18),
			Color(0.45, 0.32, 0.20)]
	var boat_at := [[Vector3(x + 4.0, 0.4, z - 6.0), 0.3],
			[Vector3(x + 9.0, 0.4, z + 4.0), -0.2],
			[Vector3(x + 13.5, 0.4, z - 1.0), 0.7]]
	for i in boat_at.size():
		var at: Vector3 = boat_at[i][0]
		var ang: float = boat_at[i][1]
		var bas := Basis(Vector3.UP, ang)
		var hull := BoxMesh.new()
		hull.size = Vector3(1.6, 0.5, 5.2)
		_cur_district.add_mesh(hull, Transform3D(bas, at), boat_cols[i])
		var bow := BoxMesh.new()
		bow.size = Vector3(1.2, 0.42, 1.2)
		_cur_district.add_mesh(bow,
				Transform3D(Basis(Vector3.UP, ang + PI / 4.0),
				at + bas * Vector3(0, 0.04, 2.9)), boat_cols[i])
		var bench := BoxMesh.new()
		bench.size = Vector3(1.5, 0.15, 0.5)
		_cur_district.add_mesh(bench,
				Transform3D(bas, at + bas * Vector3(0, 0.32, 0.6)),
				Color(0.60, 0.45, 0.28))
	_add_building(Vector3(x + 1.0, 0, z + 12.0), Vector3(0.8, 3.3, 0.8),
			Color(0.72, 0.66, 0.55))
	_add_building(Vector3(x + 13.0, 0, z + 12.0), Vector3(0.8, 3.3, 0.8),
			Color(0.72, 0.66, 0.55))
	_dist_box(Vector3(16.0, 0.4, 2.6), Vector3(x + 7.0, 3.3, z + 12.0),
			Color(0.55, 0.40, 0.26))
	_dist_box(Vector3(16.0, 0.5, 0.12), Vector3(x + 7.0, 4.05, z + 10.75),
			Color(0.35, 0.25, 0.15))
	_dist_box(Vector3(16.0, 0.5, 0.12), Vector3(x + 7.0, 4.05, z + 13.25),
			Color(0.35, 0.25, 0.15))
	_tree(Vector3(x - 15.5, 0, z + 14.0))
	_tree(Vector3(x - 15.5, 0, z - 14.0))


func _build_metro(x: float, z_line: float) -> void:
	## Viaduct: repeated pillars and deck segments become MultiMeshes; the
	## station hall merges into the district mesh at its position.
	var s := -WORLD / 2.0 + 10.0
	while s < WORLD / 2.0 - 10.0:
		_pillar_xfs.append(Transform3D(Basis(), Vector3(x, 6.0, s)))
		_metro_seg_xfs.append(Transform3D(Basis(), Vector3(x, 12.4, s)))
		s += 22.0
	_dist_box(Vector3(3.4, 3.2, 30.0), Vector3(x, 14.6, -40.0), Color(0.85, 0.87, 0.90))
	_dist_box(Vector3(3.5, 0.7, 30.0), Vector3(x, 14.0, -40.0), Color(0.18, 0.44, 0.70))


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
	_hud_radio = Label.new()
	_hud_radio.position = Vector2(824, 46)
	_hud_radio.add_theme_font_size_override("font_size", 15)
	_hud_radio.add_theme_color_override("font_color", Color(1.0, 0.83, 0.25))
	_hud_radio.visible = false
	layer.add_child(_hud_radio)
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
	_hud_msg_sub = Label.new()
	_hud_msg_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_msg_sub.offset_top = 64.0
	_hud_msg_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_msg_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_msg_sub.add_theme_font_size_override("font_size", 15)
	_hud_msg_sub.add_theme_color_override("font_color", Color(0.93, 0.93, 0.86))
	_hud_msg_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_msg_sub.visible = false
	layer.add_child(_hud_msg_sub)
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
	var portraits := HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 16)
	box.add_child(portraits)
	for def in Game.CHARACTERS:
		portraits.add_child(_portrait_card(def))

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
	hint.text = "WASD move · Shift run · E vehicle/metro · F mission · H horn · N radio · Q/R street food · Tab switch character · F9 save · X debug hurt · C debug drop · Esc pause\nGamepad · stick move · A interact · B horn · X radio · Y switch · RB sprint · D-pad food · Select pause · Start save · touch pad UI on touchscreens"
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _portrait_card(def: Dictionary) -> Control:
	## Title-screen close-up of one legend: the rigged model idles and
	## slowly turns in its own viewport — the Sardar's turban + beard and
	## each legend's outfit colors show at a glance before picking.
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(128, 168)
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 168)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.09, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-38.0, 55.0, 0.0)
	lamp.light_energy = 1.2
	vp.add_child(lamp)
	var path: String = CharactersScript.FEMALE_A if String(def.get("id")) == "riya" else CharactersScript.MALE
	var model := _chars.spawn(path, 1.72)
	_chars.dress_legend(model, def)
	vp.add_child(model)
	_chars.play(_chars.anim_names(model), _chars.get_player(model), "idle",
			float(def.get("anim_rate", 1.0)))
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.transform = Transform3D(
			Basis.looking_at(Vector3(0.0, -0.25, -2.3).normalized(), Vector3.UP),
			Vector3(0.0, 1.5, 2.3))
	vp.add_child(cam)
	_portrait_models.append(model)
	_portrait_views.append(vp)
	return svc


func _start_game(def: Dictionary, save: Dictionary = {}) -> void:
	Game.selected_character = def
	_select_layer.visible = false
	for v in _portrait_views:
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hud_name.text = String(def["name"])

	player = PlayerScript.new()
	player.setup(def)
	player.position = Vector3(ROAD / 2.0 + 2.0, 1.0, 2.0 * PITCH - BLOCK)
	# Spawn safety: slide along the road until solid ground sits right below,
	# so a fresh game never opens inside or atop stray geometry.
	var space := get_world_3d().direct_space_state
	if space != null:
		for i in 12:
			var probe := player.position + Vector3(i * 1.5, 0.0, 0.0)
			var pq := PhysicsRayQueryParameters3D.create(
					probe + Vector3(0, 3.0, 0), probe + Vector3(0, -1.0, 0))
			var phit := space.intersect_ray(pq)
			if phit and absf(float(phit.position.y) - probe.y) < 2.2:
				player.position = probe
				break
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
	_taxi.register(player, _missions)
	_courier.register(player, _missions)
	_photo = PhotoScript.new()
	add_child(_photo)
	_photo.setup(camera, player, world_env)
	# Issue #100 part 2: the touch-layer PHOTO button toggles photo mode
	# through this callable (event-based input never sees synthetic
	# action presses).
	_touch.bind_photo(Callable(_photo, "toggle"))
	# First-boot spawn framing (issue #95): park the camera high on the
	# mall road behind spawn so the opening shot holds the player, the
	# gold START HERE beacon and the road toward India Gate — then the
	# normal follow lerp eases in. Returning saves spawn tight.
	_cam_anchor = player.position
	if save.is_empty():
		_cam_anchor = player.position + Vector3(0.0, 10.0, 17.0)
	_audio.start_ambient()
	_minimap.visible = true

	var spots := [
		[Vector3(ROAD / 2.0 + 1.5, 1.0, 2.0 * PITCH - BLOCK - 12.0), 0.0, "auto"],
		[Vector3(ROAD / 2.0 + 1.2, 1.0, 2.0 * PITCH - BLOCK + 6.0), 0.0, "scooter"],
		[Vector3(-ROAD / 2.0 - 1.2, 1.0, 2.0 * PITCH - BLOCK - 10.0), PI, "scooter"],
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
		a.set_speed_bumps(_speed_bumps)
		a.bump_hit.connect(_on_bump_hit)
		_autos.append(a)

	_playing = true
	_touch.set_active(true)
	if not save.is_empty():
		_apply_save(save)
	else:
		_show_controls_card()


# ---------------------------------------------------------------- first boot

func _show_controls_card() -> void:
	## Issue #95: first boot only — a dismissable card with the controls
	## and where the first job waits, so a fresh player is never lost.
	_controls_card = CanvasLayer.new()
	_controls_card.layer = 15
	add_child(_controls_card)
	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.35)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_card.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_card.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "FIRST DAY ON THE STREET"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := Label.new()
	body.text = "WASD move · Shift sprint · E enter or exit vehicles · metro gates board the shuttle\nH horn · N radio · Q chai · R samosa · Tab switch legend · Esc pause\nYour first job waits at the gold START HERE beacon up the road"
	body.add_theme_font_size_override("font_size", 14)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var ok := Button.new()
	ok.text = "GOT IT — HIT THE STREET"
	ok.pressed.connect(_dismiss_controls_card)
	box.add_child(ok)
	_card_alive = 0.6


func _dismiss_controls_card() -> void:
	if _controls_card != null and is_instance_valid(_controls_card):
		_controls_card.queue_free()
	_controls_card = null


func _unhandled_input(event: InputEvent) -> void:
	## Any key, pad button or click clears the first-boot card (once the
	## instant-open guard has passed); the event is consumed so the same
	## press does not also trigger gameplay.
	if _controls_card == null or not is_instance_valid(_controls_card):
		return
	if _card_alive > 0.0:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		_dismiss_controls_card()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_card_alive = maxf(_card_alive - delta, 0.0)
	_update_day(delta)
	_weather.tick(delta, day_t, camera)
	var grip := 1.0 - _weather.wetness * 0.55
	if player != null and is_instance_valid(player):
		player.grip = grip
	if current_auto != null:
		current_auto.grip = 1.0 - _weather.wetness * 0.5
	_apply_wetness()
	_audio.set_rain(_weather.intensity)
	if not _playing:
		for m in _portrait_models:
			m.rotate_y(delta * 0.7)
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
		if current_auto != null and Input.is_action_just_pressed("radio"):
			_hud_radio.text = _radio.cycle_station()
			_show_toast(_hud_radio.text)
		if Input.is_action_just_pressed("debug_hurt"):
			_health.damage(25.0)
		if current_auto == null and not _metro_riding and Input.is_action_just_pressed("debug_fall"):
			player.global_position += Vector3(0.0, 22.0, 0.0)
		if Input.is_action_just_pressed("save"):
			_save_game()
		if current_auto == null and not _metro_riding and _impact_cd <= 0.0:
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
	elif _metro_riding:
		player.global_position = _metro.carriage_floor_pos()
	_update_camera(delta)
	if _minimap.visible:
		var focus: Node3D = current_auto if current_auto != null else player
		if _metro_riding:
			focus = _metro
		_minimap.track(focus.global_position, focus.rotation.y)
		_minimap.set_mission_target(_missions.active_target())
		_minimap.set_police(_police.jeep_positions())
	_taxi.tick(delta, current_auto, player)
	_courier.tick(delta, player)


func _on_bump_hit(strength: float) -> void:
	## The driven vehicle took a speed bump (issue #69): chassis thunk.
	_audio.thunk(strength)


func _toggle_vehicle() -> void:
	if _metro_riding:
		if _metro.dwelling_idx() < 0:
			_show_toast("HOLD ON · STEP OUT AT A STATION")
		else:
			_metro_alight()
		return
	if current_auto != null:
		var exit_pos: Vector3 = current_auto.global_position + current_auto.global_transform.basis.x * 3.2
		player.global_position = exit_pos
		player.visible = true
		current_auto.driver_inside = false
		current_auto = null
		_radio_off()
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
		_radio_on()
		return
	# Metro gate (issue #98 part 2): board the elevated shuttle before
	# falling back to jacking traffic.
	if _metro != null:
		var gate: Dictionary = _metro.gate_near(player.global_position, 4.2)
		if not gate.is_empty():
			_metro_board(int(gate["idx"]))
			return
	# No parked vehicle nearby: take over the closest ambient traffic vehicle.
	# Traffic brakes for the player standing in its lane, so the nearest one
	# is usually stopped when you step in front of it.
	var hit: Dictionary = _traffic.nearest_enterable(player.global_position, 7.0)
	if not hit.is_empty():
		var v := AutoScript.new()
		v.setup(hit["pos"], hit["heading"], hit["kind"])
		add_child(v)
		v.set_speed_bumps(_speed_bumps)
		v.bump_hit.connect(_on_bump_hit)
		_autos.append(v)
		_traffic.take_vehicle(int(hit["id"]))
		current_auto = v
		current_auto.driver_inside = true
		player.visible = false
		_radio_on()


func _metro_board(idx: int) -> void:
	## Issue #98 part 2: E at a station gate. If the shuttle is dwelling
	## here, hop straight on; otherwise queue and board its arrival.
	if _metro_riding:
		return
	if not _metro.is_dwelling_at(idx):
		_metro_wait = idx
		_show_toast("METRO · TRAIN EN ROUTE · WAIT AT THE GATE")
		return
	_metro_wait = -1
	_metro_riding = true
	_metro_board_idx = idx
	player.visible = false
	player.controls_enabled = false
	player.suspend_for_ride()
	_cam_anchor = camera.global_position
	_cam_look_pt = _metro.cam_look()
	_show_toast("BOARDED · NEXT STOP " + _metro.station_name(_metro.other_idx(idx)))


func _metro_alight() -> void:
	var idx := _metro.dwelling_idx()
	_metro_riding = false
	_metro_board_idx = -1
	player.visible = true
	player.controls_enabled = true
	player.global_position = _metro.alight_pos(idx)
	player.resume_after_ride()
	_show_toast("STEP OUT · " + _metro.station_name(idx))


func _metro_clear_ride() -> void:
	## Death/busted path: nobody rides the shuttle through a respawn.
	_metro_riding = false
	_metro_wait = -1
	_metro_board_idx = -1
	player.visible = true
	player.resume_after_ride()


func _on_metro_arrived(idx: int, stop_name: String) -> void:
	if _metro_wait == idx:
		_metro_board(idx)
	elif _metro_riding:
		_show_toast("ARRIVED · " + stop_name + " · E TO STEP OUT")


func _on_metro_departed(_idx: int, next_name: String) -> void:
	if _metro_riding:
		_show_toast("DEPARTING · NEXT STOP " + next_name)


func _capture_board_metro() -> void:
	## Screenshot hook (issue #98): straight onto the shuttle from boot.
	_metro_riding = true
	_metro_board_idx = maxi(_metro.dwelling_idx(), 0)
	player.visible = false
	player.controls_enabled = false
	player.suspend_for_ride()
	_cam_anchor = camera.global_position
	_cam_look_pt = _metro.cam_look()


func _radio_on() -> void:
	## Ignition: head unit resumes the last station, HUD strip lights up.
	_radio.set_active(true)
	_hud_radio.text = _radio.label()
	_hud_radio.visible = true


func _radio_off() -> void:
	_radio.set_active(false)
	_hud_radio.visible = false


# ---------------------------------------------------------------- switch

func _switch_character() -> void:
	if not _playing or _dead or _switch_lock > 0.0 \
			or player == null or not is_instance_valid(player):
		return
	if not player.controls_enabled:
		return
	if current_auto != null or _metro_riding:
		_show_toast("STEP OUT OF THE RIDE TO SWITCH")
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
	if _metro_riding:
		# Interior cam (issue #98 part 2): aisle eye in the middle car,
		# eased in from the street view — benches and poles in frame, the
		# city sliding past the glass.
		_cam_anchor = _cam_anchor.lerp(_metro.cam_eye(), minf(delta * 3.0, 1.0))
		_cam_look_pt = _cam_look_pt.lerp(_metro.cam_look(), minf(delta * 3.0, 1.0))
		camera.position = _cam_anchor
		camera.look_at(_cam_look_pt)
		return
	var target := player
	# On-foot framing follows the 1.78 m player model (issue 128);
	# the auto branch keeps its wider vehicle framing.
	var back := 5.5
	var up := 2.7
	var look_y := 1.45
	if current_auto != null:
		target = current_auto
		back = 14.0
		up = 7.0
		look_y = 2.5
	var want: Vector3 = target.global_position + target.global_transform.basis.z * back + Vector3(0, up, 0)
	_cam_anchor = _cam_anchor.lerp(want, minf(delta * 4.5, 1.0))
	var look_from := target.global_position + Vector3(0, look_y, 0)
	# Obstruction handling: ray from the target toward the anchor — if static
	# world geometry blocks it, snap the camera in front of the occluder.
	# Pull-in is instant (never see through a wall); the eased anchor swings
	# the camera back out once the line of sight is clear again.
	var pos := _cam_anchor
	if camera.get_world_3d() != null:
		var q := PhysicsRayQueryParameters3D.create(look_from, _cam_anchor)
		q.exclude = [player.get_rid()]
		if current_auto != null:
			q.exclude.append(current_auto.get_rid())
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and (hit.collider is StaticBody3D or hit.collider is AnimatableBody3D):
			var clear_len := maxf(look_from.distance_to(hit.position) - 0.4, 0.6)
			pos = look_from + (_cam_anchor - look_from).limit_length(clear_len)
	camera.position = pos
	camera.look_at(look_from)


func _update_day(delta: float) -> void:
	day_t = fmod(day_t + delta / DAY_LEN, 1.0)
	var sun_angle: float = sin(day_t * TAU - PI / 2.0)
	var daylight: float = clampf((sun_angle + 0.25) * 1.6, 0.0, 1.0)
	sun.light_energy = (0.15 + daylight * 0.85) * (1.0 - _weather.cloud * 0.5)
	sun.rotation_degrees = Vector3(-30.0 - daylight * 45.0, 40.0, 0.0)
	# Night falls: ambient dims and cools toward moonlight, and the shadow
	# map sleeps once the sun stops casting anything worth drawing.
	var env := world_env.environment
	env.ambient_light_energy = lerpf(0.16, 0.6, daylight)
	env.ambient_light_color = Color(0.42, 0.48, 0.66).lerp(Color(0.7, 0.75, 0.85), daylight)
	# Dust haze breathes with the day (issue 132): thick warm haze at
	# noon, near-clear cool haze at night so the lamp pools keep
	# reading, and the sun swings warm-noon to moon-cool.
	env.fog_density = lerpf(FOG_NIGHT, FOG_DAY, daylight)
	env.fog_light_color = FOG_COL_NIGHT.lerp(FOG_COL_DAY, daylight)
	sun.light_color = SUN_NIGHT.lerp(SUN_DAY, daylight)
	sun.shadow_enabled = _sun_shadows_wanted and daylight > 0.12
	# Dusk falls, the city lights up: window panes start glowing as the sun
	# drops and reach full warm brightness through the night.
	if _win_lit_mat != null:
		_win_lit_mat.emission_energy_multiplier = lerpf(1.9, 0.0,
				clampf(daylight * 1.4, 0.0, 1.0))
	# Street lamps join the windows at dusk: real OmniLights under every
	# lamp head, so their warm pools render in every pipeline — the
	# software-GL capture path included (issue #102).
	var lamp_glow := lerpf(1.7, 0.0, clampf(daylight * 1.4, 0.0, 1.0))
	for l in _street_lights:
		l.light_energy = lamp_glow
	var sky := SKY_NIGHT.lerp(SKY_DAY, daylight)
	var dusk: float = clampf(1.0 - absf(daylight - 0.5) * 2.0, 0.0, 1.0)
	sky = sky.lerp(SKY_DUSK, dusk * 0.5)
	sky = sky.lerp(STORM_SKY, _weather.cloud * 0.6)
	if _sky_mat != null:
		_sky_mat.sky_top_color = sky * 0.85
		_sky_mat.sky_horizon_color = sky.lerp(SKY_DUSK, dusk * 0.3)
	if _cloud_layer != null:
		_cloud_layer.rotate_y(delta * 0.004)
		var cover := clampf(_weather.cloud * 0.7 + 0.12, 0.0, 1.0)
		var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.32, 0.33, 0.38), 1.0 - daylight * 0.8)
		tint.a = 0.28 + cover * 0.62
		_cloud_mat.albedo_color = tint
	if _playing:
		var hours: float = fmod(day_t * 24.0 + 6.0, 24.0)
		var hh := int(hours)
		var mm := int((hours - hh) * 60.0)
		_hud_clock.text = "%02d:%02d" % [hh, mm]
		var phase := "Day" if daylight > 0.55 else ("Golden hour" if daylight > 0.2 else "Night")
		_hud_day.text = "Delhi \u00b7 " + phase + " \u00b7 " + _weather.label


func _apply_wetness() -> void:
	## Storm-darkened, glossy asphalt as the streets soak — and the puddle
	## spots from the road-decal pass gloss up into mirrors (issue #68);
	## skipped when wetness has not moved enough to matter.
	var w := _weather.wetness
	if absf(w - _applied_wet) < 0.02:
		return
	_applied_wet = w
	if _road_mat == null:
		return
	_road_mat.albedo_color = ROAD_TINT_DRY.lerp(ROAD_TINT_WET, w)
	_road_mat.roughness = 1.0 - 0.62 * w
	_road_mat.metallic = 0.28 * w
	RoadsScript.set_wetness(w)


func _on_thunder(strength: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(0.93, 0.96, 1.0, clampf(strength, 0.2, 0.7))
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.5)
	get_tree().create_timer(0.6).timeout.connect(_audio.thunder)


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
		{"name": "India Gate", "center": _block_center(5, 3), "spawn": _block_center(5, 3) + Vector3(8.0, 1.0, 15.0)},
		{"name": "Purani Dilli Fort", "center": _block_center(3, 7), "spawn": _block_center(3, 7) + Vector3(0.0, 1.0, 13.5)},
		{"name": "Chandni Chowk", "center": _block_center(4, 7), "spawn": _block_center(4, 7) + Vector3(6.0, 1.0, -14.0)},
		{"name": "Neighbourhood Park", "center": _block_center(8, 2), "spawn": _block_center(8, 2) + Vector3(0.0, 1.0, 12.0)},
		{"name": "Police Station", "center": _block_center(7, 5), "spawn": _block_center(7, 5) + Vector3(0.0, 1.0, 14.0), "police": true},
		{"name": "Hauz Khas", "center": _block_center(2, 8), "spawn": _block_center(2, 8) + Vector3(14.0, 1.0, 0.0)},
		{"name": "Yamuna Ghats", "center": _block_center(9, 8), "spawn": _block_center(9, 8) + Vector3(-15.0, 1.0, 12.0)},
		{"name": "Railway Station", "center": _block_center(5, 0), "spawn": _block_center(5, 0) + Vector3(-10.5, 1.0, 14.0)},
	]

func _build_street_lights() -> void:
	## Night lighting (issue #102): one lamp by every landmark wake-up
	## spot plus three down the Chandni Chowk market lane. Posts and heads
	## each draw as a single shared MultiMesh; every lamp carries a real
	## OmniLight3D so its warm pool renders in every pipeline — the
	## software-GL capture path included, where emissive windows alone can
	## read as flat dark.
	for lm in _landmarks:
		var sp: Vector3 = lm["spawn"]
		var d := sp - Vector3(lm["center"])
		d.y = 0.0
		if d.length() < 0.5:
			d = Vector3(1.0, 0.0, 0.0)
		d = d.normalized() * 3.0
		_add_lamp(Vector3(sp.x + d.x, 0.0, sp.z + d.z))
	var cc := _block_center(4, 7)
	var street := cc.x + 6.0
	var lane: Array[Vector3] = [
		Vector3(street - 4.5, 0.0, cc.z - 6.5),
		Vector3(street + 4.5, 0.0, cc.z + 1.0),
		Vector3(street - 4.5, 0.0, cc.z + 14.5),
	]
	for p in lane:
		_add_lamp(p)
	var pole := BoxMesh.new()
	pole.size = Vector3(0.18, 5.4, 0.18)
	pole.material = MeshTools.shared_material(Color(0.22, 0.26, 0.24))
	_add_mm(pole, _lamp_pole_xfs)
	var head := BoxMesh.new()
	head.size = Vector3(0.6, 0.3, 0.6)
	head.material = MeshTools.shared_material(Color(0.98, 0.9, 0.7))
	_add_mm(head, _lamp_head_xfs)

func _add_lamp(pos: Vector3) -> void:
	## One straight post lamp: dark pole, warm head, OmniLight tucked
	## just under the head. Light energy follows _update_day's dusk curve.
	_lamp_pole_xfs.append(Transform3D(Basis(), pos + Vector3(0.0, 2.7, 0.0)))
	_lamp_head_xfs.append(Transform3D(Basis(), pos + Vector3(0.0, 5.35, 0.0)))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.0, 5.1, 0.0)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.omni_range = 22.0
	light.light_energy = 0.0
	add_child(light)
	_street_lights.append(light)


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
	_taxi.drop_fare("knocked out")
	_courier.drop_parcel("knocked out")
	if _police != null:
		_police.reset()
	if _missions != null:
		_missions.abort_active("You went down")
	if current_auto != null:
		current_auto.driver_inside = false
		current_auto = null
		player.visible = true
		_radio_off()
	if _metro_riding or _metro_wait >= 0:
		_metro_clear_ride()
	player.controls_enabled = false
	var lm := _nearest_landmark(player.global_position)
	_hud_msg.text = "DOWN & OUT"
	_hud_msg.visible = true
	_hud_msg_sub.text = "Health hit zero — the street knocked you out.\nRunning job dropped · cash safe · waking at the nearest landmark"
	_hud_msg_sub.visible = true
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
	_hud_msg_sub.visible = false
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
		_radio_off()
	if _metro_riding or _metro_wait >= 0:
		_metro_clear_ride()
	player.controls_enabled = false
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(0.20, 0.35, 0.95, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.6)
	_hud_msg.text = "BUSTED"
	_hud_msg.visible = true
	_hud_msg_sub.text = "Caught at %d-star heat — Rs %d seized from your job wallet.\nHeat cleared · released outside the police station" % [stars, fine]
	_hud_msg_sub.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(_do_busted_respawn.bind(fine))
	tw.tween_interval(1.0)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)
	tw.tween_callback(_respawn_done)
	tw.tween_interval(1.5)
	tw.tween_callback(_clear_invuln)


func _do_busted_respawn(fine: int) -> void:
	_taxi.drop_fare("busted")
	_courier.drop_parcel("busted")
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
	if _metro_riding or _metro_wait >= 0:
		# Never persist a ride: savers step out at the gate they used.
		var gi := _metro_board_idx if _metro_riding else _metro_wait
		pos = _metro.alight_pos(gi)
		heading = PI / 2.0
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
