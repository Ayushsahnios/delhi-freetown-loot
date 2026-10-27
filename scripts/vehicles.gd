extends RefCounted
## Shared procedural vehicle builders: auto-rickshaw, hatchback, delivery
## van. One geometry source for the drivable vehicle node (separate wheel
## nodes that spin and steer) and the ambient traffic fleet (whole vehicle
## merged into one mesh per paint color). Purely procedural, no assets.
## Vehicle front is -Z; origin sits at ground level between the wheels.

const MeshTools := preload("res://scripts/meshtools.gd")

## Palette — original colors, no real-world brands or liveries.
const PAINTS := [
	Color(0.75, 0.12, 0.12), Color(0.10, 0.22, 0.55), Color(0.85, 0.82, 0.78),
	Color(0.12, 0.14, 0.16), Color(0.55, 0.52, 0.20), Color(0.20, 0.45, 0.28),
]
const RICK_GREEN := Color(0.18, 0.55, 0.20)
const RICK_YELLOW := Color(0.97, 0.77, 0.19)
const CARGO := Color(0.88, 0.86, 0.80)
const GLASS := Color(0.16, 0.22, 0.28)
const TIRE := Color(0.1, 0.11, 0.13)
const HUB := Color(0.68, 0.70, 0.74)
const TRIM := Color(0.16, 0.17, 0.19)
const FRAME := Color(0.12, 0.13, 0.14)
const LAMP := Color(0.98, 0.93, 0.70)
const TAIL := Color(0.85, 0.10, 0.10)
const SEAT := Color(0.30, 0.20, 0.14)

## Wheel layout per vehicle: position, radius, width, steers (front).
const RICKSHAW_WHEELS := [
	{"pos": Vector3(0, 0.55, -1.62), "r": 0.55, "w": 0.32, "steer": true},
	{"pos": Vector3(-1.0, 0.55, 1.42), "r": 0.55, "w": 0.36, "steer": false},
	{"pos": Vector3(1.0, 0.55, 1.42), "r": 0.55, "w": 0.36, "steer": false},
]
const HATCH_WHEELS := [
	{"pos": Vector3(-0.95, 0.48, -1.32), "r": 0.46, "w": 0.34, "steer": true},
	{"pos": Vector3(0.95, 0.48, -1.32), "r": 0.46, "w": 0.34, "steer": true},
	{"pos": Vector3(-0.95, 0.48, 1.32), "r": 0.46, "w": 0.34, "steer": false},
	{"pos": Vector3(0.95, 0.48, 1.32), "r": 0.46, "w": 0.34, "steer": false},
]
const VAN_WHEELS := [
	{"pos": Vector3(-1.05, 0.55, -1.55), "r": 0.55, "w": 0.36, "steer": true},
	{"pos": Vector3(1.05, 0.55, -1.55), "r": 0.55, "w": 0.36, "steer": true},
	{"pos": Vector3(-1.0, 0.55, 1.75), "r": 0.55, "w": 0.36, "steer": false},
	{"pos": Vector3(1.0, 0.55, 1.75), "r": 0.55, "w": 0.36, "steer": false},
]
const SCOOTER_WHEELS := [
	{"pos": Vector3(0, 0.30, -0.95), "r": 0.30, "w": 0.14, "steer": true},
	{"pos": Vector3(0, 0.30, 0.95), "r": 0.30, "w": 0.16, "steer": false},
]


## ---------------------------------------------------------------- bodies

static func build_rickshaw_body(b: MeshTools) -> void:
	## Green-and-yellow three-wheeler: open sides, passenger bench, canvas
	## canopy, front cowl with handlebar steering and one front wheel.
	_panel(b, Vector3(1.8, 0.16, 3.0), Vector3(0, 0.62, 0.1), FRAME)  # floor
	_panel(b, Vector3(0.07, 0.85, 2.7), Vector3(-0.9, 1.05, 0.3), RICK_GREEN)  # side panels
	_panel(b, Vector3(0.07, 0.85, 2.7), Vector3(0.9, 1.05, 0.3), RICK_GREEN)
	_panel(b, Vector3(1.75, 0.8, 0.07), Vector3(0, 1.03, 1.72), RICK_GREEN)  # rear panel
	_panel(b, Vector3(1.7, 0.72, 0.1), Vector3(0, 1.08, -0.5), RICK_GREEN)  # bulkhead
	_panel(b, Vector3(1.5, 0.3, 0.7), Vector3(0, 0.93, 1.0), SEAT)  # bench
	_panel(b, Vector3(1.5, 0.55, 0.14), Vector3(0, 1.28, 1.38), SEAT)  # backrest
	_panel(b, Vector3(2.0, 0.13, 3.05), Vector3(0, 2.02, 0.35), RICK_YELLOW)  # canopy roof
	_panel(b, Vector3(0.07, 0.3, 3.05), Vector3(-0.97, 1.82, 0.35), RICK_YELLOW)  # roof rails
	_panel(b, Vector3(0.07, 0.3, 3.05), Vector3(0.97, 1.82, 0.35), RICK_YELLOW)
	_panel(b, Vector3(1.66, 0.7, 0.05), Vector3(0, 1.68, -1.13), GLASS, 0.18)  # windshield
	_panel(b, Vector3(0.06, 0.7, 0.06), Vector3(-0.8, 1.68, -1.11), RICK_YELLOW, 0.18)  # posts
	_panel(b, Vector3(0.06, 0.7, 0.06), Vector3(0.8, 1.68, -1.11), RICK_YELLOW, 0.18)
	_panel(b, Vector3(1.0, 0.88, 0.95), Vector3(0, 0.94, -1.28), RICK_YELLOW)  # front cowl
	_panel(b, Vector3(0.95, 0.5, 0.62), Vector3(0, 0.76, -1.9), RICK_YELLOW, 0.45)  # sloped nose
	_panel(b, Vector3(0.46, 0.06, 1.15), Vector3(0, 1.14, -1.62), RICK_YELLOW)  # front fender
	b.add_mesh(_cyl_mesh(0.045, 0.7, 8), Transform3D(Basis(Vector3(1, 0, 0), -0.89), Vector3(0, 1.55, -1.4)), TRIM)  # steering column
	_cyl_x(b, 0.04, 1.1, Vector3(0, 1.76, -1.66), TRIM)  # handlebar
	_cyl_x(b, 0.055, 0.2, Vector3(-0.55, 1.76, -1.66), FRAME)  # grips
	_cyl_x(b, 0.055, 0.2, Vector3(0.55, 1.76, -1.66), FRAME)
	_cyl_z(b, 0.13, 0.09, Vector3(0, 1.08, -2.1), LAMP)  # headlamp


static func build_hatchback_body(b: MeshTools, paint: Color) -> void:
	## Small city hatchback: one-box silhouette, raked windshield, hatch
	## rear glass, bumpers, grille, headlights and taillights.
	_panel(b, Vector3(1.9, 0.66, 3.9), Vector3(0, 0.73, 0), paint)  # body
	_panel(b, Vector3(1.72, 0.6, 2.05), Vector3(0, 1.4, 0.3), paint)  # cabin
	_panel(b, Vector3(1.56, 0.58, 0.06), Vector3(0, 1.33, -0.74), GLASS, 0.4)  # windshield
	_panel(b, Vector3(1.5, 0.5, 0.06), Vector3(0, 1.36, 1.34), GLASS, -0.45)  # hatch glass
	_panel(b, Vector3(0.05, 0.42, 1.7), Vector3(-0.865, 1.42, 0.3), GLASS)  # side glass
	_panel(b, Vector3(0.05, 0.42, 1.7), Vector3(0.865, 1.42, 0.3), GLASS)
	_panel(b, Vector3(1.94, 0.28, 0.28), Vector3(0, 0.44, -1.97), TRIM)  # bumpers
	_panel(b, Vector3(1.94, 0.28, 0.28), Vector3(0, 0.44, 1.97), TRIM)
	_panel(b, Vector3(0.85, 0.13, 0.06), Vector3(0, 0.62, -1.96), FRAME)  # grille
	_panel(b, Vector3(0.36, 0.16, 0.07), Vector3(-0.6, 0.84, -1.955), LAMP)  # headlights
	_panel(b, Vector3(0.36, 0.16, 0.07), Vector3(0.6, 0.84, -1.955), LAMP)
	_panel(b, Vector3(0.3, 0.14, 0.07), Vector3(-0.58, 0.92, 1.955), TAIL)  # taillights
	_panel(b, Vector3(0.3, 0.14, 0.07), Vector3(0.58, 0.92, 1.955), TAIL)


static func build_van_body(b: MeshTools, paint: Color) -> void:
	## Delivery van: painted cab up front, tall cargo box behind.
	_panel(b, Vector3(2.15, 1.35, 1.35), Vector3(0, 1.3, -1.62), paint)  # cab
	_panel(b, Vector3(1.9, 0.6, 0.06), Vector3(0, 1.68, -2.3), GLASS, 0.22)  # windshield
	_panel(b, Vector3(2.3, 2.05, 3.0), Vector3(0, 1.53, 0.55), CARGO)  # cargo box
	_panel(b, Vector3(2.2, 0.3, 0.28), Vector3(0, 0.45, -2.0), TRIM)  # bumpers
	_panel(b, Vector3(2.32, 0.3, 0.28), Vector3(0, 0.45, 2.1), TRIM)
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(-0.72, 0.85, -2.33), LAMP)
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(0.72, 0.85, -2.33), LAMP)
	_panel(b, Vector3(0.28, 0.16, 0.07), Vector3(-0.88, 1.0, 2.06), TAIL)
	_panel(b, Vector3(0.28, 0.16, 0.07), Vector3(0.88, 1.0, 2.06), TAIL)


static func build_scooter_body(b: MeshTools, paint: Color) -> void:
	## Issue #98: step-through two-wheeler — floorboard, front apron,
	## under-seat body, bench seat, rear rack, raked steering column with
	## handlebar and a small windscreen. Original design, no badges.
	_panel(b, Vector3(0.5, 0.08, 0.65), Vector3(0, 0.36, 0.18), FRAME)  # floorboard
	_panel(b, Vector3(0.58, 0.5, 0.42), Vector3(0, 0.62, -0.52), paint)  # front apron
	_panel(b, Vector3(0.5, 0.4, 0.06), Vector3(0, 0.55, -0.72), paint, 0.35)  # leg shield
	_panel(b, Vector3(0.52, 0.34, 0.95), Vector3(0, 0.56, 0.42), paint)  # under-seat body
	_panel(b, Vector3(0.42, 0.12, 0.7), Vector3(0, 0.8, 0.32), SEAT)  # bench seat
	_panel(b, Vector3(0.46, 0.05, 0.4), Vector3(0, 0.74, 0.92), TRIM)  # rear rack
	_panel(b, Vector3(0.34, 0.08, 0.7), Vector3(0, 0.63, -0.95), paint)  # front fender
	b.add_mesh(_cyl_mesh(0.045, 0.62, 8), Transform3D(Basis(Vector3(1, 0, 0), -0.28), Vector3(0, 0.85, -0.6)), TRIM)  # steering column
	_cyl_x(b, 0.035, 0.95, Vector3(0, 1.1, -0.68), TRIM)  # handlebar
	_cyl_x(b, 0.05, 0.16, Vector3(-0.48, 1.1, -0.68), FRAME)  # grips
	_cyl_x(b, 0.05, 0.16, Vector3(0.48, 1.1, -0.68), FRAME)
	_panel(b, Vector3(0.5, 0.35, 0.05), Vector3(0, 1.22, -0.74), GLASS, 0.22)  # windscreen
	_cyl_z(b, 0.11, 0.08, Vector3(0, 1.0, -0.84), LAMP)  # headlamp
	_cyl_z(b, 0.07, 0.06, Vector3(0, 0.6, 0.92), TAIL)  # taillight


## ---------------------------------------------------------------- wheels

## Tire + hub merged straight into a body builder (static ambient traffic).
static func add_merged_wheel(b: MeshTools, spec: Dictionary) -> void:
	var xf := Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), spec["pos"])
	b.add_mesh(_cyl_mesh(float(spec["r"]), float(spec["w"]), 16), xf, TIRE)
	b.add_mesh(_cyl_mesh(float(spec["r"]) * 0.52, float(spec["w"]) + 0.04, 12), xf, HUB)


## Standalone tire + hub mesh for a wheel node that spins and steers.
static func wheel_mesh(spec: Dictionary) -> ArrayMesh:
	var b := MeshTools.new()
	add_merged_wheel(b, spec)
	return b.build_mesh()


## ---------------------------------------------------------------- helpers

static func _panel(b: MeshTools, size: Vector3, pos: Vector3, color: Color, tilt_x := 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	b.add_mesh(bm, Transform3D(Basis(Vector3(1, 0, 0), tilt_x), pos), color)


static func _cyl_mesh(radius: float, height: float, segments: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	return cm


static func _cyl_x(b: MeshTools, radius: float, height: float, pos: Vector3, color: Color) -> void:
	b.add_mesh(_cyl_mesh(radius, height, 10), Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), pos), color)


static func _cyl_z(b: MeshTools, radius: float, height: float, pos: Vector3, color: Color) -> void:
	b.add_mesh(_cyl_mesh(radius, height, 12), Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), pos), color)
