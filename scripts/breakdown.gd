extends Node3D
## Kerbside breakdown (issue #216): a rare stationary street event.
## An AI vehicle drifts out of the lane flow to the kerb line, hazards
## flashing (four amber corners + a soft relay-click tick on every
## blink), sits dead ~40 s, then despawns as if towed. traffic.gd times
## the event and passes the pull-in target; this node just plays it.
## Kinematic like the rest of the fleet — lane-following conventions,
## never falls through or tunnels — and parked half on the kerb, clear
## of every lane so the flow never jams behind it.

const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")
const AudioSynth := preload("res://scripts/audio.gd")

const LANE := 2.8          # traffic.gd lane offset (shared road grid)
const CRUISE := 9.0        # arrival speed off the flow
const DECEL := 3.5         # pulls up in ~2.6 s over ~12 m
const DWELL := 40.0        # dead-at-the-kerb time, hazards on
const DARK := 1.5          # hazards out, gone a beat later — towed
const FLASH_HZ := 1.15     # hazard rate, all four corners together
const AMBER := Color(1.0, 0.55, 0.08)
const TICK_DB := -14.0     # a soft tick, under horns and the siren

enum { PHASE_PULL, PHASE_DWELL, PHASE_DARK }

var along_z := true
var road := 0.0
var dir := 1
var t := 0.0
var kerb := 5.55          # lateral magnitude parked at the kerb line

var _phase := PHASE_PULL
var _speed := CRUISE
var _lat := LANE
var _time := 0.0
var _dwell := DWELL
var _dark := 0.0
var _on := false
var _quads: Array[MeshInstance3D] = []
var _tick: AudioStreamPlayer3D = null


static func build_body_mesh(van: bool, paint: Color) -> ArrayMesh:
	## A fleet-style body from the de-box vocabulary (issue #237) with
	## the wheels merged in — same recipe as the traffic meshes and the
	## ambulance, so the whole breakdown renders as one draw call plus
	## the four hazard quads.
	var b := MeshTools.new()
	if van:
		Vehicles.build_van_body(b, paint, false)
	else:
		Vehicles.build_hatchback_body(b, paint, false)
	var wheels: Array = Vehicles.VAN_WHEELS if van else Vehicles.HATCH_WHEELS
	for spec in wheels:
		Vehicles.add_merged_wheel(b, spec)
	return b.build_mesh()


func setup(p_along_z: bool, p_road: float, p_dir: int, start_t: float,
		p_kerb: float) -> void:
	along_z = p_along_z
	road = p_road
	dir = p_dir
	t = start_t
	kerb = p_kerb
	var van := randf() < 0.4
	var paint: Color = Vehicles.PAINTS[randi() % Vehicles.PAINTS.size()]
	var body := MeshInstance3D.new()
	body.mesh = build_body_mesh(van, paint)
	add_child(body)
	_hazards(van)
	_tick = AudioStreamPlayer3D.new()
	_tick.stream = AudioSynth.make_relay_click()
	_tick.volume_db = TICK_DB
	_tick.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_tick.unit_size = 8.0
	_tick.max_distance = 45.0
	_tick.position = Vector3(0.0, 1.0, 0.0)
	add_child(_tick)
	_apply()


func _hazards(van: bool) -> void:
	## Four amber lamp positions — at the headlamp and tail-lamp
	## corners of whichever body was built — all four flash in unison,
	## the hazard convention rather than an indicator pair.
	var half_w := 1.22 if van else 1.02
	var fz := -2.36 if van else -2.0
	var rz := 2.12 if van else 2.0
	var fy := 0.85 if van else 0.84
	var ry := 1.0 if van else 0.92
	for corner in [
		[Vector3(half_w, fy, fz), PI / 2.0],
		[Vector3(-half_w, fy, fz), -PI / 2.0],
		[Vector3(half_w, ry, rz), PI / 2.0],
		[Vector3(-half_w, ry, rz), -PI / 2.0],
	]:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.26, 0.15)
		q.mesh = quad
		q.position = corner[0]
		q.rotation.y = corner[1]
		var m := StandardMaterial3D.new()
		m.albedo_color = AMBER.darkened(0.4)
		m.emission_enabled = true
		m.emission = AMBER
		m.emission_energy_multiplier = 0.05
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material_override = m
		add_child(q)
		_quads.append(q)


func _physics_process(delta: float) -> void:
	_time += delta
	match _phase:
		PHASE_PULL:
			_speed = move_toward(_speed, 0.0, DECEL * delta)
			t += dir * _speed * delta
			_lat = lerpf(LANE, kerb, 1.0 - _speed / CRUISE)
			if _speed <= 0.05:
				_speed = 0.0
				_lat = kerb
				_phase = PHASE_DWELL
		PHASE_DWELL:
			_dwell -= delta
			if _dwell <= 0.0:
				_phase = PHASE_DARK
				_flash(false)
		PHASE_DARK:
			_dark += delta
			if _dark >= DARK:
				queue_free()
				return
	var on := _phase != PHASE_DARK and fmod(_time * FLASH_HZ, 1.0) < 0.5
	if on != _on:
		_on = on
		_flash(on)
		if on and _tick != null:
			_tick.play()
	_apply()


func _flash(on: bool) -> void:
	for q in _quads:
		var m: StandardMaterial3D = q.material_override
		m.emission_energy_multiplier = 4.0 if on else 0.05


func _apply() -> void:
	## Same lane convention as the fleet (_apply_transform in
	## traffic.gd): the lateral offset rides the dir sign on z-roads
	## and against it on x-roads, so the pull-in always bends toward
	## the same side the travel lane lives on — keep-left.
	var lat: float = _lat * dir
	if along_z:
		global_transform = Transform3D(Basis(Vector3.UP, PI if dir > 0 else 0.0),
				Vector3(road + lat, 0.0, t))
	else:
		global_transform = Transform3D(Basis(Vector3.UP, -PI / 2.0 * dir),
				Vector3(t, 0.0, road - lat))
