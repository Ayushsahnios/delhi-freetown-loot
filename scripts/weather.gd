extends Node
## Monsoon weather cycle — one rain window rolled per in-game day.
## Drives a camera-following rain particle field, wetness (road darkening
## and traction), cloud cover for the sky, occasional thunder flashes and
## the rain audio bed level. Fully procedural; no assets.

signal thunder_flash(strength: float)

const RAIN_CHANCE := 0.65     # monsoon season: most days get a shower
const MIN_WINDOW := 0.10      # rain window length as a day fraction
const MAX_WINDOW := 0.22
const CLOUD_LEAD := 0.02      # clouding-up time before the window
const CLEAR_LAG := 0.03       # clearing time after the window
const WET_SOAK_RATE := 0.22   # wetness gained per second in rain
const WET_DRY_RATE := 0.045   # wetness lost per second after rain
const EDGE_RAMP := 0.18       # window fraction spent ramping in/out
const MAX_DROPS := 900
const THUNDER_MIN_GAP := 5.0
const THUNDER_MAX_GAP := 13.0

var wetness := 0.0    # 0 dry .. 1 soaked — roads and grip follow this
var intensity := 0.0  # 0..1 rain strength right now
var cloud := 0.0      # 0..1 cloud cover for sky dimming
var label := "Clear"

var _rng := RandomNumberGenerator.new()
var _plan_day := -1
var _plan_rain := false
var _plan_start := 0.0
var _plan_end := 0.0
var _prev_day_t := 0.0
var _rain: GPUParticles3D
var _thunder_cd := 6.0


func setup() -> void:
	_rng.randomize()
	_build_rain_field()


func tick(delta: float, day_t: float, cam: Camera3D) -> void:
	## Advance the state machine from the shared day cycle position.
	_roll_plan(day_t)
	var target := 0.0
	var cloud_target := 0.0
	if _plan_rain:
		if day_t >= _plan_start - CLOUD_LEAD and day_t < _plan_start:
			cloud_target = 0.7
		elif day_t >= _plan_start and day_t <= _plan_end:
			cloud_target = 1.0
			var into: float = (day_t - _plan_start) / maxf(_plan_end - _plan_start, 0.0001)
			target = clampf(minf(into, 1.0 - into) / EDGE_RAMP, 0.0, 1.0)
		elif day_t > _plan_end and day_t <= _plan_end + CLEAR_LAG:
			cloud_target = 0.7 * (1.0 - (day_t - _plan_end) / CLEAR_LAG)
	intensity = move_toward(intensity, target, delta * 0.25)
	cloud = lerpf(cloud, cloud_target, clampf(delta * 0.35, 0.0, 1.0))
	# Roads soak fast in rain, dry out slowly once the shower passes.
	var rate := WET_SOAK_RATE if intensity > wetness else WET_DRY_RATE
	wetness = move_toward(wetness, intensity, rate * delta)
	_update_label()
	_update_particles(cam)
	_update_thunder(delta)


func _roll_plan(day_t: float) -> void:
	## A fresh monsoon plan at every wrap of the day cycle.
	var wrapped := _plan_day >= 0 and day_t < _prev_day_t - 0.5
	if _plan_day < 0 or wrapped:
		_plan_day += 1
		_plan_rain = _rng.randf() < RAIN_CHANCE
		_plan_start = _rng.randf_range(0.06, 0.72)
		_plan_end = minf(_plan_start + _rng.randf_range(MIN_WINDOW, MAX_WINDOW), 0.97)
	_prev_day_t = day_t


func _update_label() -> void:
	if intensity > 0.15:
		label = "Monsoon"
	elif cloud > 0.45:
		label = "Dark clouds"
	elif wetness > 0.25:
		label = "Drying out"
	else:
		label = "Clear"


func _update_particles(cam: Camera3D) -> void:
	if cam != null:
		_rain.global_position = cam.global_position + Vector3(0.0, 20.0, 0.0)
	_rain.amount_ratio = clampf(intensity, 0.0, 1.0)
	_rain.emitting = intensity > 0.02


func _update_thunder(delta: float) -> void:
	if intensity < 0.5:
		_thunder_cd = maxf(_thunder_cd, 3.0)
		return
	_thunder_cd -= delta
	if _thunder_cd <= 0.0:
		_thunder_cd = _rng.randf_range(THUNDER_MIN_GAP, THUNDER_MAX_GAP)
		thunder_flash.emit(_rng.randf_range(0.35, 0.7))


func _build_rain_field() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.06, -1.0, 0.04)
	mat.spread = 6.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 36.0
	mat.gravity = Vector3(0.0, -22.0, 0.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(55.0, 6.0, 55.0)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.05, 1.1, 0.05)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.62, 0.72, 0.88, 0.42)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material = drop_mat
	_rain = GPUParticles3D.new()
	_rain.process_material = mat
	_rain.draw_pass_1 = streak
	_rain.amount = MAX_DROPS
	_rain.amount_ratio = 0.0
	_rain.lifetime = 1.7
	_rain.visibility_aabb = AABB(Vector3(-60.0, -8.0, -60.0), Vector3(120.0, 40.0, 120.0))
	add_child(_rain)
