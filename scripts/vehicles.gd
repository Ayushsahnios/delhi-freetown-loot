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
const TREAD := Color(0.05, 0.06, 0.07)
const HUB := Color(0.68, 0.70, 0.74)
const TRIM := Color(0.16, 0.17, 0.19)
const FRAME := Color(0.12, 0.13, 0.14)
const LAMP := Color(0.98, 0.93, 0.70)
const TAIL := Color(0.85, 0.10, 0.10)
const SEAT := Color(0.30, 0.20, 0.14)

## Driver figures + decor (issue #125): skin/shirt tones for low-poly
## drivers, marigold garland + fringe colors for rickshaw personality.
const SKIN_A := Color(0.66, 0.46, 0.31)
const SKIN_B := Color(0.55, 0.38, 0.26)
const SHIRT_A := Color(0.90, 0.88, 0.80)
const SHIRT_B := Color(0.55, 0.15, 0.14)
const SHIRT_C := Color(0.25, 0.45, 0.30)
const CAP := Color(0.15, 0.15, 0.17)
const DASH := Color(0.16, 0.16, 0.18)
const SEAT_DARK := Color(0.22, 0.20, 0.19)
const MARIGOLD := Color(0.96, 0.63, 0.08)
const FRINGE_RED := Color(0.80, 0.15, 0.12)
const FRINGE_GREEN := Color(0.15, 0.45, 0.25)
const PLATE := Color(0.95, 0.93, 0.88)

## Wheel layout per vehicle: position, radius, width, steers (front).
const RICKSHAW_WHEELS := [
	{"pos": Vector3(0, 0.55, -1.62), "r": 0.55, "w": 0.32, "steer": true},
	{"pos": Vector3(-1.0, 0.55, 1.42), "r": 0.55, "w": 0.36, "steer": false},
	{"pos": Vector3(1.0, 0.55, 1.42), "r": 0.55, "w": 0.36, "steer": false},
]
const HATCH_WHEELS := [
	{"pos": Vector3(-0.95, 0.48, -1.32), "r": 0.48, "w": 0.30, "steer": true},
	{"pos": Vector3(0.95, 0.48, -1.32), "r": 0.48, "w": 0.30, "steer": true},
	{"pos": Vector3(-0.95, 0.48, 1.32), "r": 0.48, "w": 0.30, "steer": false},
	{"pos": Vector3(0.95, 0.48, 1.32), "r": 0.48, "w": 0.30, "steer": false},
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

## Fleet variety (issue #269): the heavy three — shared wheel layouts.
## Tempo rides on van-sized rubber; the truck and tanker roll bigger,
## wider drums and expose them proud of the body sides.
const TEMPO_WHEELS := [
	{"pos": Vector3(-1.0, 0.52, -1.85), "r": 0.52, "w": 0.34, "steer": true},
	{"pos": Vector3(1.0, 0.52, -1.85), "r": 0.52, "w": 0.34, "steer": true},
	{"pos": Vector3(-1.0, 0.58, 1.95), "r": 0.58, "w": 0.40, "steer": false},
	{"pos": Vector3(1.0, 0.58, 1.95), "r": 0.58, "w": 0.40, "steer": false},
]
const TRUCK_WHEELS := [
	{"pos": Vector3(-1.08, 0.62, -2.15), "r": 0.62, "w": 0.44, "steer": true},
	{"pos": Vector3(1.08, 0.62, -2.15), "r": 0.62, "w": 0.44, "steer": true},
	{"pos": Vector3(-1.1, 0.62, 2.35), "r": 0.62, "w": 0.48, "steer": false},
	{"pos": Vector3(1.1, 0.62, 2.35), "r": 0.62, "w": 0.48, "steer": false},
]
const TANKER_WHEELS := [
	{"pos": Vector3(-1.08, 0.62, -2.15), "r": 0.62, "w": 0.44, "steer": true},
	{"pos": Vector3(1.08, 0.62, -2.15), "r": 0.62, "w": 0.44, "steer": true},
	{"pos": Vector3(-1.1, 0.62, 1.35), "r": 0.62, "w": 0.48, "steer": false},
	{"pos": Vector3(1.1, 0.62, 1.35), "r": 0.62, "w": 0.48, "steer": false},
	{"pos": Vector3(-1.1, 0.62, 3.05), "r": 0.62, "w": 0.48, "steer": false},
	{"pos": Vector3(1.1, 0.62, 3.05), "r": 0.62, "w": 0.48, "steer": false},
]

## Tailpipe tip offsets per kind (issue #166): where idle exhaust puffs
## are born, in vehicle-local space (front = -Z).
const EXHAUST_POS := {
	"auto": Vector3(0.55, 0.42, 1.98),
	"car": Vector3(-0.55, 0.36, 2.08),
	"van": Vector3(-0.62, 0.50, 2.18),
	"scooter": Vector3(0.12, 0.30, 1.0),
	# Issue #269: the heavy three — tempo puffs low at the back like the
	# van; the truck and tanker carry vertical stacks behind the cab, so
	# their puffs are born high, at the stack mouth.
	"tempo": Vector3(-0.62, 0.48, 3.32),
	"truck": Vector3(-0.95, 2.75, -1.05),
	"tanker": Vector3(0.95, 2.75, -1.05),
}


## ---------------------------------------------------------------- bodies

static func build_rickshaw_body(b: MeshTools, decor := true) -> void:
	## Green-and-yellow three-wheeler: open sides, passenger bench, canvas
	## canopy, front cowl with handlebar steering and one front wheel.
	## Issue #125: optional personality decor — canopy fringe, marigold
	## garland, painted pinstripes, name plate, mudflaps, nose ornament.
	## Issue #166: enamel gloss on the yellow tin, sun-dulled satin green,
	## a lower canopy line and a proper tailpipe — closer to the
	## reference-era silhouette; driver and decor untouched.
	_panel(b, Vector3(1.8, 0.16, 3.0), Vector3(0, 0.62, 0.1), FRAME)  # floor
	_panel(b, Vector3(0.07, 0.85, 2.7), Vector3(-0.9, 1.05, 0.3), RICK_GREEN, 0.0, MeshTools.FINISH_SATIN)  # side panels
	_panel(b, Vector3(0.07, 0.85, 2.7), Vector3(0.9, 1.05, 0.3), RICK_GREEN, 0.0, MeshTools.FINISH_SATIN)
	_panel(b, Vector3(1.75, 0.8, 0.07), Vector3(0, 1.03, 1.72), RICK_GREEN, 0.0, MeshTools.FINISH_SATIN)  # rear panel
	_panel(b, Vector3(1.7, 0.72, 0.1), Vector3(0, 1.08, -0.5), RICK_GREEN, 0.0, MeshTools.FINISH_SATIN)  # bulkhead
	_panel(b, Vector3(1.5, 0.3, 0.7), Vector3(0, 0.93, 1.0), SEAT)  # bench
	_panel(b, Vector3(1.5, 0.55, 0.14), Vector3(0, 1.28, 1.38), SEAT)  # backrest
	_canopy_shell(b)  # ribbed half-cylinder canopy (issue #237)
	_panel(b, Vector3(1.66, 0.66, 0.05), Vector3(0, 1.67, -1.13), GLASS, 0.18, MeshTools.FINISH_GLOSS)  # windshield
	_panel(b, Vector3(0.06, 0.7, 0.06), Vector3(-0.8, 1.68, -1.11), RICK_YELLOW, 0.18, MeshTools.FINISH_GLOSS)  # posts
	_panel(b, Vector3(0.06, 0.7, 0.06), Vector3(0.8, 1.68, -1.11), RICK_YELLOW, 0.18, MeshTools.FINISH_GLOSS)
	b.add_loft(MeshTools.chamfer_footprint(0.52, 0.55, 0.16),
			MeshTools.chamfer_footprint(0.34, 0.14, 0.06),
			Vector3(0, 0, -1.45), 0.50, 1.38, RICK_YELLOW, MeshTools.FINISH_GLOSS)  # tapered cowl hull (issue #237)
	_arch_lip(b, Vector3(0, 0.55, -1.62), 0.64, 0.40, RICK_YELLOW, 1.5)  # nose fender arc
	b.add_mesh(_cyl_mesh(0.045, 0.7, 8), Transform3D(Basis(Vector3(1, 0, 0), -0.89), Vector3(0, 1.55, -1.4)), TRIM)  # steering column
	_cyl_x(b, 0.04, 1.1, Vector3(0, 1.76, -1.66), TRIM)  # handlebar
	_cyl_x(b, 0.055, 0.2, Vector3(-0.55, 1.76, -1.66), FRAME)  # grips
	_cyl_x(b, 0.055, 0.2, Vector3(0.55, 1.76, -1.66), FRAME)
	_cyl_z(b, 0.13, 0.09, Vector3(0, 1.02, -1.80), LAMP, MeshTools.FINISH_GLOSS)  # headlamp
	_panel(b, Vector3(0.16, 0.14, 0.42), Vector3(0.55, 0.40, 1.55), TRIM)  # muffler (issue #166)
	_cyl_z(b, 0.045, 0.4, Vector3(0.55, 0.40, 1.78), TRIM)  # tailpipe
	if decor:
		add_rickshaw_decor(b)


static func build_hatchback_body(b: MeshTools, paint: Color, interior := true) -> void:
	## Small city hatchback: one-box silhouette, raked windshield, hatch
	## rear glass, bumpers, grille, headlights and taillights. Issue #125:
	## the front door windows stay open (B-pillar + rear glass) so the
	## driver and interior read at street level; dash, wheel and seats
	## behind the opening. Issue #166: wider lower greenhouse on bigger
	## wheels, gloss paint and glass against matte bumpers and trim.
	# Beveled, tapered hull (issue #237): lofted from chamfered footprints —
	# sill-to-belt mass, then a greenhouse lofting into the roof.
	b.add_loft(MeshTools.chamfer_footprint(0.95, 1.95, 0.16),
			MeshTools.chamfer_footprint(0.92, 1.90, 0.22),
			Vector3(0, 0, 0), 0.40, 1.08, paint, MeshTools.FINISH_GLOSS)  # body hull
	b.add_loft(MeshTools.chamfer_footprint(0.90, 1.60, 0.14),
			MeshTools.chamfer_footprint(0.60, 1.02, 0.24),
			Vector3(0, 0, 0.30), 1.08, 1.62, paint, MeshTools.FINISH_GLOSS)  # tapered greenhouse
	for wz in [-1.32, 1.32]:
		for sx in [-1.0, 1.0]:
			_arch_lip(b, Vector3(0.93 * sx, 0.48, wz), 0.60, 0.12, TRIM, 2.6)  # wheel-arch fender lips (issue #237)
	_panel(b, Vector3(1.34, 0.60, 0.06), Vector3(0, 1.35, -1.00), GLASS, 0.55, MeshTools.FINISH_GLOSS)  # windshield
	_panel(b, Vector3(1.15, 0.55, 0.06), Vector3(0, 1.34, 1.55), GLASS, -0.50, MeshTools.FINISH_GLOSS)  # hatch glass
	_panel(b, Vector3(0.05, 0.38, 0.95), Vector3(-0.74, 1.38, 0.78), GLASS, 0.0, MeshTools.FINISH_GLOSS)  # side glass (rear)
	_panel(b, Vector3(0.05, 0.38, 0.95), Vector3(0.74, 1.38, 0.78), GLASS, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.05, 0.38, 0.07), Vector3(-0.75, 1.38, 0.15), TRIM)  # B-pillars
	_panel(b, Vector3(0.05, 0.38, 0.07), Vector3(0.75, 1.38, 0.15), TRIM)
	_panel(b, Vector3(1.94, 0.28, 0.28), Vector3(0, 0.44, -1.97), TRIM)  # bumpers
	_panel(b, Vector3(1.94, 0.28, 0.28), Vector3(0, 0.44, 1.97), TRIM)
	_panel(b, Vector3(0.85, 0.13, 0.06), Vector3(0, 0.62, -1.96), FRAME)  # grille
	_panel(b, Vector3(0.36, 0.16, 0.07), Vector3(-0.6, 0.84, -1.955), LAMP, 0.0, MeshTools.FINISH_GLOSS)  # headlights
	_panel(b, Vector3(0.36, 0.16, 0.07), Vector3(0.6, 0.84, -1.955), LAMP, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.3, 0.14, 0.07), Vector3(-0.58, 0.92, 1.955), TAIL, 0.0, MeshTools.FINISH_GLOSS)  # taillights
	_panel(b, Vector3(0.3, 0.14, 0.07), Vector3(0.58, 0.92, 1.955), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.4, 0.16, 0.3), Vector3(-0.5, 0.33, 1.65), TRIM)  # muffler (issue #166)
	_cyl_z(b, 0.045, 0.35, Vector3(-0.55, 0.34, 1.9), TRIM)  # tailpipe
	if interior:
		add_car_interior(b)


static func build_van_body(b: MeshTools, paint: Color, interior := true) -> void:
	## Delivery van: painted cab up front, tall cargo box behind. Issue
	## #125: cab side windows + interior, so the leaning driver reads.
	## Issue #166: gloss cab paint against a satin cargo box, plus a
	## tailpipe and muffler under the rear overhang.
	# Lofted cab + cargo hulls with a cornice lip (issue #237) — no bare
	# boxes left in the silhouette.
	b.add_loft(MeshTools.chamfer_footprint(1.07, 0.68, 0.14),
			MeshTools.chamfer_footprint(0.94, 0.52, 0.18),
			Vector3(0, 0, -1.62), 0.55, 1.98, paint, MeshTools.FINISH_GLOSS)  # cab hull
	b.add_loft(MeshTools.chamfer_footprint(1.15, 1.50, 0.15),
			MeshTools.chamfer_footprint(1.11, 1.46, 0.22),
			Vector3(0, 0, 0.55), 0.50, 2.50, CARGO, MeshTools.FINISH_SATIN)  # cargo hull
	b.add_prism(MeshTools.chamfer_footprint(1.18, 1.53, 0.15),
			Vector3(0, 0, 0.55), 2.50, 2.66, CARGO, MeshTools.FINISH_SATIN)  # roof cornice lip
	for wz in [-1.55, 1.75]:
		for sx in [-1.0, 1.0]:
			var wx: float = 1.02 * sx if wz < 0.0 else 1.05 * sx
			_arch_lip(b, Vector3(wx, 0.55, wz), 0.64, 0.12, TRIM, 2.6)  # wheel-arch lips (issue #237)
	_panel(b, Vector3(1.8, 0.58, 0.06), Vector3(0, 1.62, -2.27), GLASS, 0.18, MeshTools.FINISH_GLOSS)  # windshield
	_panel(b, Vector3(2.2, 0.3, 0.28), Vector3(0, 0.45, -2.0), TRIM)  # bumpers
	_panel(b, Vector3(2.32, 0.3, 0.28), Vector3(0, 0.45, 2.1), TRIM)
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(-0.72, 0.85, -2.33), LAMP, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(0.72, 0.85, -2.33), LAMP, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.28, 0.16, 0.07), Vector3(-0.88, 1.0, 2.06), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.28, 0.16, 0.07), Vector3(0.88, 1.0, 2.06), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.03, 0.30, 0.50), Vector3(-0.965, 1.90, -1.62), GLASS, 0.0, MeshTools.FINISH_GLOSS)  # cab windows
	_panel(b, Vector3(0.03, 0.30, 0.50), Vector3(0.965, 1.90, -1.62), GLASS, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.35, 0.16, 0.35), Vector3(-0.58, 0.46, 1.8), TRIM)  # muffler (issue #166)
	_cyl_z(b, 0.05, 0.4, Vector3(-0.62, 0.48, 2.0), TRIM)  # tailpipe
	if interior:
		add_van_interior(b)


static func build_scooter_body(b: MeshTools, paint: Color) -> void:
	## Issue #98: step-through two-wheeler — floorboard, front apron,
	## under-seat body, bench seat, rear rack, raked steering column with
	## handlebar and a small windscreen. Original design, no badges.
	## Issue #166: gloss body panels and a tiny tailpipe.
	_panel(b, Vector3(0.5, 0.08, 0.65), Vector3(0, 0.36, 0.18), FRAME)  # floorboard
	b.add_loft(MeshTools.chamfer_footprint(0.30, 0.24, 0.09),
			MeshTools.chamfer_footprint(0.22, 0.15, 0.07),
			Vector3(0, 0, -0.52), 0.40, 0.86, paint, MeshTools.FINISH_GLOSS)  # apron hull (issue #237)
	_leg_shield(b, paint)  # sculpted leg-shield curve (issue #237)
	b.add_loft(MeshTools.chamfer_footprint(0.27, 0.50, 0.10),
			MeshTools.chamfer_footprint(0.23, 0.42, 0.12),
			Vector3(0, 0, 0.42), 0.40, 0.76, paint, MeshTools.FINISH_GLOSS)  # under-seat hull
	b.add_mesh(_capsule_mesh(0.10, 0.60), Transform3D(
			Basis.from_scale(Vector3(1.0, 0.8, 1.0)) * Basis(Vector3(0, 1, 0), PI / 2.0),
			Vector3(0, 0.82, 0.30)), SEAT)  # rounded bench seat (issue #237)
	_panel(b, Vector3(0.46, 0.05, 0.4), Vector3(0, 0.74, 0.92), TRIM)  # rear rack
	_arch_lip(b, Vector3(0, 0.30, -0.95), 0.42, 0.40, paint, 2.0)  # front fender arc (issue #237)
	b.add_mesh(_cyl_mesh(0.045, 0.62, 8), Transform3D(Basis(Vector3(1, 0, 0), -0.28), Vector3(0, 0.85, -0.6)), TRIM)  # steering column
	_cyl_x(b, 0.035, 0.95, Vector3(0, 1.1, -0.68), TRIM)  # handlebar
	_cyl_x(b, 0.05, 0.16, Vector3(-0.48, 1.1, -0.68), FRAME)  # grips
	_cyl_x(b, 0.05, 0.16, Vector3(0.48, 1.1, -0.68), FRAME)
	_panel(b, Vector3(0.5, 0.35, 0.05), Vector3(0, 1.22, -0.74), GLASS, 0.22, MeshTools.FINISH_GLOSS)  # windscreen
	_cyl_z(b, 0.11, 0.08, Vector3(0, 1.0, -0.84), LAMP, MeshTools.FINISH_GLOSS)  # headlamp
	_cyl_z(b, 0.07, 0.06, Vector3(0, 0.6, 0.92), TAIL, MeshTools.FINISH_GLOSS)  # taillight
	_cyl_z(b, 0.03, 0.3, Vector3(0.12, 0.28, 0.85), TRIM)  # tailpipe (issue #166)


static func build_tempo_body(b: MeshTools, paint: Color, interior := true) -> void:
	## Issue #269: shared passenger tempo — long lofted hull with a tall
	## window band, benches inside, and a roof rack of luggage bundles
	## (capsules, never boxes). Original colours, no liveries.
	b.add_loft(MeshTools.chamfer_footprint(1.06, 2.18, 0.16),
			MeshTools.chamfer_footprint(1.02, 2.12, 0.22),
			Vector3(0, 0, 0.1), 0.42, 1.22, paint, MeshTools.FINISH_GLOSS)  # lower hull
	b.add_loft(MeshTools.chamfer_footprint(1.0, 2.05, 0.14),
			MeshTools.chamfer_footprint(0.86, 1.62, 0.22),
			Vector3(0, 0, 0.16), 1.22, 1.98, paint, MeshTools.FINISH_GLOSS)  # greenhouse
	for wz in [-1.85, 1.95]:
		for sx in [-1.0, 1.0]:
			_arch_lip(b, Vector3(1.0 * sx, 0.55, wz), 0.66, 0.12, TRIM, 2.6)  # arch lips
	_panel(b, Vector3(1.9, 0.62, 0.06), Vector3(0, 1.62, -1.95), GLASS, 0.22, MeshTools.FINISH_GLOSS)  # windshield
	for side in [-1.0, 1.0]:
		for wz in [-0.9, 0.3, 1.5]:  # three windows a side; the right
			# front bay is the blank sliding-door face, driver glass opposite
			if wz == -0.9 and side > 0.0:
				_panel(b, Vector3(0.05, 0.56, 0.98), Vector3(1.0 * side, 1.6, wz), paint, 0.0, MeshTools.FINISH_GLOSS)
			else:
				_panel(b, Vector3(0.05, 0.56, 0.98), Vector3(1.0 * side, 1.6, wz), GLASS, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(1.55, 0.5, 0.06), Vector3(0, 1.58, 2.26), GLASS, -0.1, MeshTools.FINISH_GLOSS)  # rear glass
	_panel(b, Vector3(2.24, 0.3, 0.3), Vector3(0, 0.6, -2.18), TRIM)  # bumpers
	_panel(b, Vector3(2.24, 0.3, 0.3), Vector3(0, 0.6, 2.34), TRIM)
	_panel(b, Vector3(0.7, 0.16, 0.06), Vector3(0, 0.95, -2.26), FRAME)  # grille
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(-0.62, 1.05, -2.28), LAMP, 0.0, MeshTools.FINISH_GLOSS)  # headlights
	_panel(b, Vector3(0.34, 0.16, 0.07), Vector3(0.62, 1.05, -2.28), LAMP, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(-0.7, 1.1, 2.42), TAIL, 0.0, MeshTools.FINISH_GLOSS)  # taillights
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(0.7, 1.1, 2.42), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_tempo_roof_rack(b)
	_cyl_z(b, 0.05, 0.42, Vector3(-0.75, 0.55, 2.2), TRIM)  # tailpipe
	if interior:
		add_tempo_interior(b)


static func _tempo_roof_rack(b: MeshTools) -> void:
	## Roof rack (issue #269): side rails + crossbars of slim lofts, then
	## luggage that reads soft — capsules and a rolled tarp cylinder.
	for side in [-1.0, 1.0]:
		b.add_loft(MeshTools.chamfer_footprint(0.05, 1.5, 0.02),
				MeshTools.chamfer_footprint(0.05, 1.5, 0.02),
				Vector3(0.92 * side, 0, 0.35), 1.98, 2.18, TRIM)  # side rails
	for wz in [-1.0, -0.1, 0.8, 1.7]:
		b.add_loft(MeshTools.chamfer_footprint(0.95, 0.04, 0.02),
				MeshTools.chamfer_footprint(0.95, 0.04, 0.02),
				Vector3(0, 0, wz), 1.98, 2.18, TRIM)  # crossbars
	b.add_mesh(_capsule_mesh(0.16, 1.7), Transform3D(
			Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(-0.35, 2.28, 0.2)), SEAT)  # holdall
	b.add_mesh(_capsule_mesh(0.14, 1.5), Transform3D(
			Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0.38, 2.24, 0.3)), SHIRT_B)  # sack
	b.add_mesh(_cyl_mesh(0.13, 2.6, 10), Transform3D(
			Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 2.24, -0.85)), FRINGE_GREEN)  # rolled tarp


static func add_tempo_interior(b: MeshTools) -> void:
	## Benches + front seat behind the open door glass, dash and wheel.
	_panel(b, Vector3(1.8, 0.16, 0.3), Vector3(0, 1.28, -1.45), DASH)
	b.add_mesh(_cyl_mesh(0.16, 0.03, 12),
			Transform3D(Basis(Vector3(1, 0, 0), 1.15), Vector3(-0.5, 1.42, -1.32)),
			Color(0.12, 0.12, 0.13))
	_panel(b, Vector3(0.55, 0.14, 0.5), Vector3(-0.5, 0.98, -1.1), SEAT_DARK)  # front seat
	_panel(b, Vector3(0.55, 0.5, 0.12), Vector3(-0.5, 1.22, -0.88), SEAT_DARK)
	for wz in [-0.25, 0.95, 1.9]:  # passenger benches facing inward
		_panel(b, Vector3(0.5, 0.12, 1.15), Vector3(-0.55, 1.02, wz), SEAT)
		_panel(b, Vector3(0.5, 0.12, 1.15), Vector3(0.55, 1.02, wz), SEAT)


static func _truck_cab(b: MeshTools, paint: Color, stack_side := -1.0) -> void:
	## Shared heavy cab (issue #269): tall lofted two-piece hull with a
	## deep windshield band, air-deflector roof spine and a vertical
	## exhaust stack — truck ahead, tanker behind.
	b.add_loft(MeshTools.chamfer_footprint(1.12, 1.18, 0.15),
			MeshTools.chamfer_footprint(1.06, 0.92, 0.2),
			Vector3(0, 0, -2.35), 0.82, 1.85, paint, MeshTools.FINISH_GLOSS)  # cab lower hull
	b.add_loft(MeshTools.chamfer_footprint(1.06, 0.95, 0.14),
			MeshTools.chamfer_footprint(0.9, 0.6, 0.22),
			Vector3(0, 0, -2.45), 1.85, 2.62, paint, MeshTools.FINISH_GLOSS)  # cab greenhouse
	b.add_prism(MeshTools.chamfer_footprint(0.5, 0.7, 0.12),
			Vector3(0, 0, -2.4), 2.62, 2.86, paint, MeshTools.FINISH_GLOSS)  # roof deflector spine
	_panel(b, Vector3(2.0, 0.72, 0.07), Vector3(0, 2.14, -3.34), GLASS, 0.14, MeshTools.FINISH_GLOSS)  # windshield
	for side in [-1.0, 1.0]:
		_panel(b, Vector3(0.06, 0.55, 0.85), Vector3(1.02 * side, 2.12, -2.55), GLASS, 0.0, MeshTools.FINISH_GLOSS)  # side glass
	_panel(b, Vector3(2.3, 0.36, 0.3), Vector3(0, 0.7, -3.4), TRIM)  # bumpers
	_panel(b, Vector3(0.9, 0.2, 0.07), Vector3(0, 1.05, -3.5), FRAME)  # grille
	_panel(b, Vector3(0.36, 0.18, 0.08), Vector3(-0.72, 1.35, -3.44), LAMP, 0.0, MeshTools.FINISH_GLOSS)  # headlights
	_panel(b, Vector3(0.36, 0.18, 0.08), Vector3(0.72, 1.35, -3.44), LAMP, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.3, 0.16, 0.08), Vector3(-0.82, 1.5, -1.28), TAIL, 0.0, MeshTools.FINISH_GLOSS)  # rear cab markers
	_panel(b, Vector3(0.3, 0.16, 0.08), Vector3(0.82, 1.5, -1.28), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_cyl_y(b, 0.06, 1.7, Vector3(0.95 * stack_side, 1.9, -1.05), TRIM)  # exhaust stack behind cab
	_cyl_y(b, 0.08, 0.1, Vector3(0.95 * stack_side, 2.75, -1.05), HUB, MeshTools.FINISH_GLOSS)  # stack mouth
	_cyl_x(b, 0.12, 0.55, Vector3(1.14, 2.1, -3.2), TRIM)  # mirror arm + blade
	_panel(b, Vector3(0.04, 0.26, 0.16), Vector3(1.38, 2.12, -3.2), TRIM)
	for wz in [-2.15, -1.15]:
		for sx in [-1.0, 1.0]:
			var wx: float = 1.08 * sx
			_arch_lip(b, Vector3(wx, 0.62, wz), 0.72, 0.14, TRIM, 2.6)  # arch lips


static func build_truck_body(b: MeshTools, paint: Color, cargo := true) -> void:
	## Issue #269: flatbed truck — chamfered deck with low lofted side
	## rails, chassis rails, side fuel tank, and soft cargo (pipe bundle,
	## tarp roll) strapped on. Occasionally one parks kerbside with
	## hazards (breakdown.gd).
	_truck_cab(b, paint)
	# Chassis: two rails the whole wheelbase, crossmember at the tail.
	for side in [-1.0, 1.0]:
		b.add_loft(MeshTools.chamfer_footprint(0.14, 2.3, 0.05),
				MeshTools.chamfer_footprint(0.14, 2.3, 0.05),
				Vector3(0.5 * side, 0, 0.9), 0.68, 0.95, FRAME)
	_panel(b, Vector3(2.0, 0.22, 0.14), Vector3(0, 0.78, 2.82), FRAME)  # tail crossmember
	_cyl_x(b, 0.05, 1.9, Vector3(0, 0.55, 2.9), TRIM)  # underride bar
	_cyl_z(b, 0.22, 1.1, Vector3(-1.05, 0.78, 0.3), TRIM)  # side fuel tank
	# Deck: chamfered prism plate proud of the rails.
	b.add_prism(MeshTools.chamfer_footprint(1.08, 2.0, 0.1),
			Vector3(0, 0, 0.85), 0.95, 1.12, CARGO, MeshTools.FINISH_SATIN)
	# Side rails: slim lofted walls with stake posts, drop-down tail.
	for side in [-1.0, 1.0]:
		b.add_loft(MeshTools.chamfer_footprint(0.06, 1.98, 0.03),
				MeshTools.chamfer_footprint(0.06, 1.98, 0.03),
				Vector3(1.06 * side, 0, 0.85), 1.12, 1.48, paint, MeshTools.FINISH_SATIN)
		for wz in [-0.75, 0.3, 1.35, 2.4]:
			_panel(b, Vector3(0.05, 0.4, 0.07), Vector3(1.06 * side, 1.28, wz), FRAME)  # stakes
	b.add_loft(MeshTools.chamfer_footprint(1.04, 0.06, 0.03),
			MeshTools.chamfer_footprint(1.04, 0.06, 0.03),
			Vector3(0, 0, 2.78), 1.12, 1.44, paint, MeshTools.FINISH_SATIN)  # tail gate rail
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(-0.9, 1.3, 2.9), TAIL, 0.0, MeshTools.FINISH_GLOSS)  # tail lights
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(0.9, 1.3, 2.9), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	if cargo:
		# Cargo (issue #269): a strapped bundle of PVC pipes (cylinders)
		# plus a rolled tarp — soft shapes, zero boxes.
		for i in 3:
			b.add_mesh(_cyl_mesh(0.14, 3.1, 10), Transform3D(
					Basis(Vector3(1, 0, 0), PI / 2.0),
					Vector3(-0.45 + 0.45 * i, 1.32 + 0.06 * i, 0.6)), CARGO)
		b.add_mesh(_cyl_mesh(0.16, 2.7, 10), Transform3D(
					Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 1.62, 0.7)), FRINGE_GREEN)
		for wz in [0.0, 1.4]:  # straps: arcs across the load, thin along Z
			var strap := PackedVector2Array()
			for i in 5:
				var t := PI * float(i) / 4.0
				strap.append(Vector2(cos(t) * 0.55, 1.5 + sin(t) * 0.55))
			b.add_shell(strap, wz - 0.04, wz + 0.04, Vector3.ZERO, true, TRIM)


static func build_tanker_body(b: MeshTools, paint: Color) -> void:
	## Issue #269: water tanker — same heavy cab, then a lying capsule
	## tank with band rings, a top catwalk, rear hose reel and access
	## ladder. All curves, no boxes.
	_truck_cab(b, paint, 1.0)
	for side in [-1.0, 1.0]:
		b.add_loft(MeshTools.chamfer_footprint(0.14, 2.3, 0.05),
				MeshTools.chamfer_footprint(0.14, 2.3, 0.05),
				Vector3(0.5 * side, 0, 1.25), 0.68, 0.95, FRAME)  # chassis rails
	_cyl_x(b, 0.05, 1.9, Vector3(0, 0.55, 3.3), TRIM)  # underride bar
	_cyl_z(b, 0.22, 1.1, Vector3(-1.05, 0.78, 0.35), TRIM)  # side fuel tank
	# Tank: lying capsule (domed ends), silver, gloss.
	b.add_mesh(_capsule_mesh(1.05, 3.6), Transform3D(
			Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 2.0, 1.1)),
			Color(0.70, 0.72, 0.75), MeshTools.FINISH_GLOSS)
	for wz in [-0.2, 1.0, 2.2]:  # band rings slightly proud of the shell
		b.add_mesh(_cyl_mesh(1.07, 0.16, 18), Transform3D(
				Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 2.0, wz)),
			Color(0.16, 0.35, 0.55), MeshTools.FINISH_SATIN)
	b.add_loft(MeshTools.chamfer_footprint(0.35, 1.5, 0.06),
			MeshTools.chamfer_footprint(0.35, 1.5, 0.06),
			Vector3(0, 0, 1.1), 3.05, 3.14, TRIM)  # top catwalk strip
	_cyl_z(b, 0.12, 0.3, Vector3(0, 3.14, 1.1), HUB)  # fill cap
	_cyl_x(b, 0.28, 0.34, Vector3(0, 1.35, 3.18), TRIM)  # hose reel
	_panel(b, Vector3(0.55, 0.4, 0.08), Vector3(0, 1.3, 3.22), TRIM)  # valve chest
	for i in 5:  # rear access ladder rungs
		_cyl_x(b, 0.035, 0.8, Vector3(0, 1.0 + i * 0.38, 2.62), HUB)
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(-0.9, 1.1, 3.35), TAIL, 0.0, MeshTools.FINISH_GLOSS)
	_panel(b, Vector3(0.3, 0.15, 0.07), Vector3(0.9, 1.1, 3.35), TAIL, 0.0, MeshTools.FINISH_GLOSS)


## ---------------------------------------------------------------- drivers + decor

## Ambient driver figure for one vehicle kind (issue #125): low-poly
## head + torso (+ arms where the pose shows) at that vehicle's controls.
## Only traffic calls this — the player IS the driver of a taken vehicle.
static func add_driver(b: MeshTools, kind: String) -> void:
	match kind:
		"auto":
			_rick_driver(b)
		"car":
			_car_driver(b)
		"van":
			_van_driver(b)
		"scooter":
			_scooter_rider(b)
		"tempo":
			_tempo_driver(b)
		"truck":
			_truck_driver(b)
		"tanker":
			_truck_driver(b)


static func _rick_driver(b: MeshTools) -> void:
	## Seated at the handlebar: white kurta, dark cap, arms reaching the
	## grips. Legs hide behind the cowl and bulkhead.
	_panel(b, Vector3(0.44, 0.5, 0.26), Vector3(0, 1.05, -0.95), SHIRT_A)
	_panel(b, Vector3(0.2, 0.2, 0.2), Vector3(0, 1.42, -0.95), SKIN_B)
	_panel(b, Vector3(0.24, 0.08, 0.24), Vector3(0, 1.55, -0.95), CAP)
	_panel(b, Vector3(0.09, 0.09, 0.42), Vector3(-0.2, 1.3, -1.15), SHIRT_A, 1.1)
	_panel(b, Vector3(0.09, 0.09, 0.42), Vector3(0.2, 1.3, -1.15), SHIRT_A, 1.1)


static func _car_driver(b: MeshTools) -> void:
	## Driver in the open front-door window (left), passenger on the
	## right — heads above the sill line, shoulders below the roof.
	_panel(b, Vector3(0.19, 0.19, 0.19), Vector3(-0.5, 1.52, -0.12), SKIN_A)
	_panel(b, Vector3(0.4, 0.26, 0.22), Vector3(-0.5, 1.3, -0.12), SHIRT_B)
	_panel(b, Vector3(0.19, 0.19, 0.19), Vector3(0.5, 1.52, -0.12), SKIN_B)
	_panel(b, Vector3(0.4, 0.26, 0.22), Vector3(0.5, 1.3, -0.12), SHIRT_C)


static func _van_driver(b: MeshTools) -> void:
	## Leaning out of the cab window — head half-proud of the glass,
	## forearm on the sill (truck-driver style).
	_panel(b, Vector3(0.19, 0.19, 0.19), Vector3(-0.97, 1.90, -1.62), SKIN_B)
	_panel(b, Vector3(0.08, 0.08, 0.38), Vector3(-0.95, 1.76, -1.45), SHIRT_A)


static func _scooter_rider(b: MeshTools) -> void:
	## Astride the bench: torso, cap, thighs along the board, arms to the
	## handlebar.
	_panel(b, Vector3(0.34, 0.45, 0.22), Vector3(0, 1.08, 0.3), SHIRT_B)
	_panel(b, Vector3(0.17, 0.17, 0.17), Vector3(0, 1.4, 0.3), SKIN_A)
	_panel(b, Vector3(0.2, 0.07, 0.2), Vector3(0, 1.51, 0.3), CAP)
	_panel(b, Vector3(0.13, 0.1, 0.42), Vector3(-0.15, 0.9, 0.02), TRIM)
	_panel(b, Vector3(0.13, 0.1, 0.42), Vector3(0.15, 0.9, 0.02), TRIM)
	_panel(b, Vector3(0.08, 0.08, 0.4), Vector3(-0.2, 1.15, -0.35), SHIRT_B, 0.9)
	_panel(b, Vector3(0.08, 0.08, 0.4), Vector3(0.2, 1.15, -0.35), SHIRT_B, 0.9)


static func _tempo_driver(b: MeshTools) -> void:
	## Issue #269: seated at the wheel in the tall cab — kurta, cap,
	## forearms to the rim.
	_panel(b, Vector3(0.42, 0.5, 0.24), Vector3(-0.5, 1.15, -1.1), SHIRT_A)
	_panel(b, Vector3(0.19, 0.19, 0.19), Vector3(-0.5, 1.52, -1.12), SKIN_B)
	_panel(b, Vector3(0.23, 0.08, 0.23), Vector3(-0.5, 1.65, -1.12), CAP)
	_panel(b, Vector3(0.08, 0.08, 0.34), Vector3(-0.68, 1.3, -1.25), SHIRT_A, 1.0)
	_panel(b, Vector3(0.08, 0.08, 0.34), Vector3(-0.32, 1.3, -1.25), SHIRT_A, 1.0)


static func _truck_driver(b: MeshTools) -> void:
	## Issue #269: elbow on the sill, half out of the side glass —
	## heads above the windshield base line so it reads at street level.
	_panel(b, Vector3(0.19, 0.19, 0.19), Vector3(-0.98, 2.22, -2.5), SKIN_B)
	_panel(b, Vector3(0.24, 0.08, 0.24), Vector3(-0.98, 2.36, -2.5), CAP)
	_panel(b, Vector3(0.08, 0.08, 0.44), Vector3(-0.9, 2.02, -2.32), SHIRT_C, 0.35)


## Rickshaw personality (issue #125): marigold garland across the
## windshield, canopy fringe, painted pinstripe, rear name plate,
## striped mudflaps and a nose ornament. Original decorations — no
## real liveries or slogans.
static func add_rickshaw_decor(b: MeshTools) -> void:
	var fringe := [MARIGOLD, FRINGE_RED, FRINGE_GREEN]
	var i := 0
	for x in range(-3, 4):
		_panel(b, Vector3(0.07, 0.16, 0.05), Vector3(x * 0.25, 1.93, -1.06), fringe[i % 3])
		i += 1
	i = 0
	for z in range(-3, 7):
		_panel(b, Vector3(0.05, 0.16, 0.07), Vector3(-0.90, 1.81, z * 0.25), fringe[i % 3])
		_panel(b, Vector3(0.05, 0.16, 0.07), Vector3(0.90, 1.81, z * 0.25), fringe[i % 3])
		i += 1
	for x in range(-4, 5):
		_panel(b, Vector3(0.06, 0.06, 0.06), Vector3(x * 0.15, 2.0, -1.07),
				MARIGOLD if x % 2 == 0 else RICK_YELLOW)
	_panel(b, Vector3(0.02, 0.06, 2.5), Vector3(-0.945, 1.02, 0.3), RICK_YELLOW)
	_panel(b, Vector3(0.02, 0.06, 2.5), Vector3(0.945, 1.02, 0.3), RICK_YELLOW)
	_panel(b, Vector3(0.5, 0.16, 0.04), Vector3(0, 1.3, 1.775), PLATE)
	for x in [-1.0, 1.0]:
		_panel(b, Vector3(0.3, 0.22, 0.04), Vector3(x, 0.35, 1.72), CAP)
		_panel(b, Vector3(0.3, 0.05, 0.045), Vector3(x, 0.3, 1.72), RICK_YELLOW)
	_panel(b, Vector3(0.08, 0.08, 0.08), Vector3(0, 1.18, -1.70), HUB)


## Basic car interior (issue #125): dash, tilted steering wheel, two
## front seats and a rear bench — visible through the open door windows.
static func add_car_interior(b: MeshTools) -> void:
	_panel(b, Vector3(1.5, 0.18, 0.3), Vector3(0, 1.12, -0.52), DASH)
	b.add_mesh(_cyl_mesh(0.16, 0.03, 12),
			Transform3D(Basis(Vector3(1, 0, 0), 1.15), Vector3(-0.45, 1.28, -0.38)),
			Color(0.12, 0.12, 0.13))
	for x in [-0.45, 0.45]:
		_panel(b, Vector3(0.42, 0.12, 0.45), Vector3(x, 0.98, -0.1), SEAT_DARK)
		_panel(b, Vector3(0.42, 0.5, 0.12), Vector3(x, 1.2, 0.12), SEAT_DARK)
	_panel(b, Vector3(1.4, 0.12, 0.5), Vector3(0, 0.98, 0.85), SEAT_DARK)
	_panel(b, Vector3(1.4, 0.48, 0.12), Vector3(0, 1.18, 1.05), SEAT_DARK)


## Van cab interior (issue #125): single seat, dash, steering wheel.
static func add_van_interior(b: MeshTools) -> void:
	_panel(b, Vector3(2.0, 0.2, 0.35), Vector3(0, 1.32, -2.02), DASH)
	b.add_mesh(_cyl_mesh(0.16, 0.03, 12),
			Transform3D(Basis(Vector3(1, 0, 0), 1.15), Vector3(-0.5, 1.5, -1.88)),
			Color(0.12, 0.12, 0.13))
	_panel(b, Vector3(0.5, 0.14, 0.5), Vector3(-0.5, 1.28, -1.45), SEAT_DARK)
	_panel(b, Vector3(0.5, 0.6, 0.12), Vector3(-0.5, 1.6, -1.2), SEAT_DARK)


## ---------------------------------------------------------------- wheels

## Tyre + hub merged straight into a body builder (static ambient
## traffic). Issue #166: the wheel reads in three parts — rubber
## sidewall, a darker tread band slightly proud of it, and a spoked
## steel hub with a chrome centre cap — instead of two flat discs.
static func add_merged_wheel(b: MeshTools, spec: Dictionary) -> void:
	var xf := Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), spec["pos"])
	var r := float(spec["r"])
	var w := float(spec["w"])
	b.add_mesh(_cyl_mesh(r, w, 14), xf, TIRE)
	b.add_mesh(_cyl_mesh(r * 1.02, w * 1.10, 14), xf, TREAD)
	var n := 5 if r > 0.4 else 4
	for i in n:
		var ang := TAU * i / n
		var spoke := BoxMesh.new()
		spoke.size = Vector3(r * 0.72, w * 1.14, r * 0.12)
		var local := Transform3D(Basis(Vector3.UP, -ang),
				Vector3(cos(ang), 0.0, sin(ang)) * r * 0.30)
		b.add_mesh(spoke, xf * local, HUB, MeshTools.FINISH_SATIN)
	b.add_mesh(_cyl_mesh(r * 0.26, w * 1.20, 10), xf, HUB, MeshTools.FINISH_GLOSS)


## Standalone tire + hub mesh for a wheel node that spins and steers.
static func wheel_mesh(spec: Dictionary) -> ArrayMesh:
	var b := MeshTools.new()
	add_merged_wheel(b, spec)
	return b.build_mesh()


## Dusk switch for the whole fleet at once (issue #166): the shared
## head- and taillight materials carry an emission ramp driven by
## nightfall — parked, driven and ambient traffic all light up together.
static func set_lamp_glow(night: float) -> void:
	var head := MeshTools.shared_material(LAMP, MeshTools.FINISH_GLOSS)
	var tail := MeshTools.shared_material(TAIL, MeshTools.FINISH_GLOSS)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.95, 0.80)
	head.emission_energy_multiplier = 1.7 * night
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.10, 0.06)
	tail.emission_energy_multiplier = 1.2 * night


## ---------------------------------------------------------------- helpers

static func _panel(b: MeshTools, size: Vector3, pos: Vector3, color: Color, tilt_x := 0.0, finish := MeshTools.FINISH_MATTE) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	b.add_mesh(bm, Transform3D(Basis(Vector3(1, 0, 0), tilt_x), pos), color, finish)


static func _cyl_mesh(radius: float, height: float, segments: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	return cm


## Ribbed half-cylinder canopy (issue #237): one curved yellow shell
## rail-to-rail with dark frame ribs proud of the fabric and a canvas
## rear curtain — replaces the flat canopy roof + box rails.
static func _canopy_shell(b: MeshTools) -> void:
	var arc := PackedVector2Array()
	for i in 7:
		var t := PI * float(i) / 6.0
		arc.append(Vector2(cos(t) * 0.96, 1.70 + sin(t) * 0.34))
	b.add_shell(arc, -1.05, 1.85, Vector3.ZERO, true, RICK_YELLOW, MeshTools.FINISH_GLOSS)
	for z in [-0.55, 0.0, 0.55, 1.1, 1.65]:
		var rib := PackedVector2Array()
		for i in 7:
			var t := PI * float(i) / 6.0
			rib.append(Vector2(cos(t) * 0.99, 1.70 + sin(t) * 0.36))
		b.add_shell(rib, z - 0.035, z + 0.035, Vector3.ZERO, true, FRAME)
	_panel(b, Vector3(1.86, 0.38, 0.05), Vector3(0, 1.89, 1.84), RICK_YELLOW, 0.0, MeshTools.FINISH_GLOSS)  # rear curtain


## Fender lip (issue #237): a curved double-sided shell arc hugging the
## wheel at `pos` at radius `r`, swept across `width` along X. `cover` is
## the arc span in radians centred on top of the wheel.
static func _arch_lip(b: MeshTools, pos: Vector3, r: float, width: float,
		color: Color, cover := 2.4) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var t := PI / 2.0 + cover * (0.5 - float(i) / 8.0)
		pts.append(Vector2(cos(t) * r + pos.z, sin(t) * r + pos.y))
	b.add_shell(pts, pos.x - width * 0.5, pos.x + width * 0.5,
			Vector3.ZERO, false, color)


## Sculpted leg shield (issue #237): a curved double-sided shell sweeping
## from the floorboard up to the apron crest — replaces the flat tilted
## panel. Profile runs in the ZY plane, swept across the width.
static func _leg_shield(b: MeshTools, paint: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(-0.80, 0.38),
		Vector2(-0.76, 0.56),
		Vector2(-0.68, 0.72),
		Vector2(-0.56, 0.84),
		Vector2(-0.42, 0.90),
	])
	b.add_shell(pts, -0.30, 0.30, Vector3.ZERO, false, paint, MeshTools.FINISH_GLOSS)


static func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 4
	return cm


static func _cyl_x(b: MeshTools, radius: float, height: float, pos: Vector3, color: Color) -> void:
	b.add_mesh(_cyl_mesh(radius, height, 10), Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), pos), color)


## Vertical cylinder (issue #269): exhaust stacks and similar.
static func _cyl_y(b: MeshTools, radius: float, height: float, pos: Vector3, color: Color, finish := MeshTools.FINISH_MATTE) -> void:
	b.add_mesh(_cyl_mesh(radius, height, 10), Transform3D(Basis(), pos), color, finish)


static func _cyl_z(b: MeshTools, radius: float, height: float, pos: Vector3, color: Color, finish := MeshTools.FINISH_MATTE) -> void:
	b.add_mesh(_cyl_mesh(radius, height, 12), Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), pos), color, finish)
