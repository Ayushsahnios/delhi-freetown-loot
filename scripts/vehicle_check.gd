extends Node
## Vehicle polish check (issue #166) — headless gate for the fleet
## refresh: spoked wheels with a tread band, the matte/gloss material
## split, the dusk lamp-glow curve, per-kind exhaust offsets, and
## the issue #269 heavy-three meshes (surfaces, gloss, tri counts).
## Issue #294 Part 1a: also gates the panelled street trio — every
## lofted hull must carry number plates (≥ 2 PLATE surfaces).
## Usage:
##   godot --headless --path . res://scenes/vehicle_check.tscn
## Exits 0 when everything passes, 2 with a FAILED report otherwise.

const MeshTools := preload("res://scripts/meshtools.gd")
const Vehicles := preload("res://scripts/vehicles.gd")

func _ready() -> void:
	var problems: Array[String] = []

	# 1. Wheels: tyre + tread + spoked hub surfaces all present.
	var wb := MeshTools.new()
	Vehicles.add_merged_wheel(wb, Vehicles.HATCH_WHEELS[0])
	var wmesh := wb.build_mesh()
	if wmesh.get_surface_count() < 3:
		problems.append("wheel mesh has %d surfaces — expected ≥ 3 (tyre, tread, hub+spokes)"
				% wmesh.get_surface_count())

	# 2. Matte-vs-gloss split: the painted car carries a clearcoat gloss
	# surface; the tyre stays fully matte.
	var cb := MeshTools.new()
	Vehicles.build_hatchback_body(cb, Vehicles.PAINTS[0], false)
	var cmesh := cb.build_mesh()
	var has_gloss := false
	for i in cmesh.get_surface_count():
		var m: StandardMaterial3D = cmesh.surface_get_material(i)
		if m != null and m.clearcoat_enabled:
			has_gloss = true
	if not has_gloss:
		problems.append("car body has no clearcoat gloss surface — paint finish missing")

	# 3. Lamp glow curve: night ≥ 1.2 head / 0.8 tail, noon exactly off.
	Vehicles.set_lamp_glow(1.0)
	var head := MeshTools.shared_material(Vehicles.LAMP, MeshTools.FINISH_GLOSS)
	var tail := MeshTools.shared_material(Vehicles.TAIL, MeshTools.FINISH_GLOSS)
	if head.emission_energy_multiplier < 1.2 or tail.emission_energy_multiplier < 0.8:
		problems.append("lamp emission at night head %.2f tail %.2f — expected ≥ 1.2 / ≥ 0.8"
				% [head.emission_energy_multiplier, tail.emission_energy_multiplier])
	Vehicles.set_lamp_glow(0.0)
	if not is_zero_approx(head.emission_energy_multiplier) \
			or not is_zero_approx(tail.emission_energy_multiplier):
		problems.append("lamp emission at noon head %.2f tail %.2f — expected 0"
				% [head.emission_energy_multiplier, tail.emission_energy_multiplier])

	# 4. Exhaust offsets exist for every fleet kind.
	for kind in ["auto", "car", "van", "scooter", "tempo", "truck", "tanker"]:
		if not Vehicles.EXHAUST_POS.has(kind):
			problems.append("no exhaust offset for kind " + kind)

	# 5. Issue #269 heavy fleet: tempo / truck / tanker build with a
	# gloss paint surface and report triangle counts for the de-box
	# budget (published in the PR body).
	for kind in ["tempo", "truck", "tanker"]:
		var hb := MeshTools.new()
		if kind == "tempo":
			Vehicles.build_tempo_body(hb, Vehicles.PAINTS[2])
		elif kind == "truck":
			Vehicles.build_truck_body(hb, Vehicles.PAINTS[0])
		else:
			Vehicles.build_tanker_body(hb, Vehicles.PAINTS[3])
		var hmesh := hb.build_mesh()
		if hmesh.get_surface_count() < 3:
			problems.append("heavy kind %s mesh has %d surfaces — expected ≥ 3"
					% [kind, hmesh.get_surface_count()])
		var heavy_gloss := false
		var tris := 0
		for i in hmesh.get_surface_count():
			var m: StandardMaterial3D = hmesh.surface_get_material(i)
			if m != null and m.clearcoat_enabled:
				heavy_gloss = true
			var idx = hmesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
			if idx != null:
				tris += int(idx.size() / 3.0)
		if not heavy_gloss:
			problems.append("heavy kind " + kind + " has no clearcoat gloss surface")
		print("heavy %s: %d surfaces, %d tris" % [kind, hmesh.get_surface_count(), tris])

	# 6. Issue #294 Part 1a: the panelled street trio — hatchback, van
	# and tempo each carry number plates. Surfaces merge by material, so
	# the gate reads the PLATE surface triangle budget: one plate box is
	# 12 tris — ≥ 24 means front + rear are both present.
	for kind in ["hatch", "van", "tempo"]:
		var tb := MeshTools.new()
		if kind == "hatch":
			Vehicles.build_hatchback_body(tb, Vehicles.PAINTS[0], false)
		elif kind == "van":
			Vehicles.build_van_body(tb, Vehicles.PAINTS[1], false)
		else:
			Vehicles.build_tempo_body(tb, Vehicles.PAINTS[2], false)
		var tm := tb.build_mesh()
		var plate_tris := 0
		var street_tris := 0
		for i in tm.get_surface_count():
			var sm: StandardMaterial3D = tm.surface_get_material(i)
			var sidx = tm.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
			if sidx != null:
				street_tris += int(sidx.size() / 3.0)
			if sm != null and sm.albedo_color.is_equal_approx(Vehicles.PLATE):
				plate_tris += int(sidx.size() / 3.0)
		if plate_tris < 24:
			problems.append("kind %s plate surface has %d tris — expected ≥ 24 (front + rear plates)"
					% [kind, plate_tris])
		print("street %s: %d tris, plate geometry %d tris" % [kind, street_tris, plate_tris])

	if problems.is_empty():
		print("VEHICLE CHECK PASS — wheels, gloss split, lamp glow, exhaust offsets, heavy fleet, street trio plates")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		get_tree().quit(2)
