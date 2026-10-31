extends Node
## Static draw-distance (LOD) tiers — issue 167.
##
## Godot's per-instance visibility ranges cull geometry on the renderer
## side for free: a hidden instance costs no draw call and no fill. The
## city is built once at startup, so a single pass over each static
## container is all that is needed — there is no per-frame LOD script
## burning frames to save frames.
##
## Tier distances (metres) against the 506 m city diagonal:
##   SMALL  90  — clutter, signage, street-level detail that is
##                unreadable pixels long before 90 m
##   MID   160  — dressing, furniture, trees: street shaping that
##                still reads at a block or two away
##   BIG   320  — merged per-district buildings: the mass you must be
##                able to see across town, culled only past half the
##                map, whole districts at a time
## Everything dither-fades over a 12 % margin so nothing hard-pops.
## Landmarks, roads, ground and the sky are deliberately left untiered.

const SMALL := 90.0
const MID := 160.0
const BIG := 320.0
const MARGIN := 0.12

## perf_check --no-lod flips this before the main scene is built so the
## baseline (untiered) frame cost can be measured on the same binary.
static var disabled := false

## Draw-distance multiplier (issue 270): the LOW graphics preset boots
## the city at 0.55x tiers. Set before the world build; runtime preset
## switches go through rescale() instead.
static var tier_scale := 1.0


static func tier(root: Node, end_m: float) -> int:
	## Give every GeometryInstance3D under `root` (that does not already
	## have a range) a draw-distance cull. Returns the instance count.
	if disabled or root == null:
		return 0
	var count := 0
	for child in root.get_children():
		count += _walk(child, end_m)
	return count


static func _walk(node: Node, end_m: float) -> int:
	var count := 0
	var gi := node as GeometryInstance3D
	if gi != null and gi.visibility_range_end <= 0.0:
		var end := end_m * tier_scale
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = end * MARGIN
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.set_meta("lod_end_base", end_m)
		count += 1
	for child in node.get_children():
		count += _walk(child, end_m)
	return count


static func rescale(root: Node, scale: float) -> int:
	## Runtime preset switch (issue 270): re-tier everything this script
	## originally tiered, from the stashed base distance x `scale`.
	## Untiered geometry (landmarks, roads, sky) and ranges set by other
	## systems (no lod_end_base meta) are left untouched — a LOW->HIGH
	## round trip therefore restores exact HIGH values, no drift.
	if disabled or root == null:
		return 0
	var count := 0
	for child in root.get_children():
		count += _rescale_walk(child, scale)
	return count


static func _rescale_walk(node: Node, scale: float) -> int:
	var count := 0
	var gi := node as GeometryInstance3D
	if gi != null and gi.has_meta("lod_end_base"):
		var base: float = gi.get_meta("lod_end_base")
		var end := base * scale
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = end * MARGIN
		count += 1
	for child in node.get_children():
		count += _rescale_walk(child, scale)
	return count
