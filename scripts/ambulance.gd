extends Node3D
## Ambulance street event (issue #215): a white lofted-hull van with a
## flashing beacon that sweeps down a traffic lane faster than the
## ambient flow, weaving across the road with a looping two-tone siren
## while nearby AI traffic eases aside (traffic.gd drives the yield).
## Kinematic like the rest of the fleet — lane-following, never falls
## through or tunnels — and despawns past the city edge.

const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const AudioSynth := preload("res://scripts/audio.gd")

const SPEED := 19.0          # quicker than every ambient cruise (8-16)
const WEAVE_AMP := 1.15      # lateral sweep while threading traffic
const WEAVE_HZ := 0.5
const SIREN_DB := -8.0       # pinned under the car horn (-6)
const FLASH_HZ := 2.6        # alternating beacon quads

const HULL := Color(0.93, 0.94, 0.96)   # ambulance white
const BEACON := Color(1.0, 0.10, 0.06)

var along_z := true
var road := 0.0
var dir := 1
var t := 0.0

var _time := 0.0
var _quads: Array[MeshInstance3D] = []


static func build_body_mesh() -> ArrayMesh:
	## White van hull from the de-box vocabulary (issue #237) with the
	## wheels merged in — same recipe as the traffic fleet meshes, so
	## the whole ambulance renders as one draw call plus the beacon.
	var b := MeshTools.new()
	Vehicles.build_van_body(b, HULL, false)
	for spec in Vehicles.VAN_WHEELS:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func setup(p_along_z: bool, p_road: float, p_dir: int, start_t: float) -> void:
	along_z = p_along_z
	road = p_road
	dir = p_dir
	t = start_t
	var body := MeshInstance3D.new()
	body.mesh = build_body_mesh()
	add_child(body)
	_beacon()
	var siren := AudioStreamPlayer3D.new()
	siren.stream = AudioSynth.make_siren()
	siren.volume_db = SIREN_DB
	siren.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	siren.unit_size = 10.0
	siren.max_distance = 85.0
	siren.position = Vector3(0.0, 2.7, 0.35)
	add_child(siren)
	siren.play()
	_apply()


func _beacon() -> void:
	## Roof beacon: a dark plinth cylinder and two emissive quads that
	## alternate — the classic red flash, fully procedural.
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.17
	cyl.height = 0.10
	plinth.mesh = cyl
	plinth.position = Vector3(0.0, 2.72, 0.35)
	plinth.material_override = _dark()
	add_child(plinth)
	for side in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.30, 0.17)
		q.mesh = quad
		q.position = Vector3(side * 0.19, 2.83, 0.35)
		q.rotation.y = PI / 2.0 * side
		var m := StandardMaterial3D.new()
		m.albedo_color = BEACON.darkened(0.35)
		m.emission_enabled = true
		m.emission = BEACON
		m.emission_energy_multiplier = 0.05
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = m
		add_child(q)
		_quads.append(q)


func _dark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	return m


func _physics_process(delta: float) -> void:
	_time += delta
	t += dir * SPEED * delta
	_apply()
	var on_i := 0 if fmod(_time * FLASH_HZ, 1.0) < 0.5 else 1
	for i in _quads.size():
		var m: StandardMaterial3D = _quads[i].material_override
		m.emission_energy_multiplier = 4.0 if i == on_i else 0.05


func _apply() -> void:
	## Same lane convention as the fleet (_apply_transform in
	## traffic.gd); the weave sweeps across the road centre instead of
	## holding one lane.
	var weave := sin(TAU * WEAVE_HZ * _time) * WEAVE_AMP
	var pos := Vector3.ZERO
	var heading := 0.0
	if along_z:
		pos = Vector3(road + weave, 0.0, t)
		heading = PI if dir > 0 else 0.0
	else:
		pos = Vector3(t, 0.0, road - weave)
		heading = -PI / 2.0 * dir
	global_transform = Transform3D(Basis(Vector3.UP, heading), pos)
