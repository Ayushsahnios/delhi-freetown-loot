extends Node
## Graphics quality presets + auto-FPS fallback — issue 270.
##
## Two presets, one knob-set each, derived from the LOD budget work
## (issue 167) so weak GPUs lose fill distance, never features:
##
##   preset | LOD tiers | sun shadows            | fallback watcher
##   -------|-----------|------------------------|-----------------
##   HIGH   | 1.00x     | 120 m, 2 splits        | (auto mode only)
##   LOW    | 0.55x     |  55 m, 1 ortho map     |   drops HIGH->LOW
##
## The user-facing mode is AUTO / HIGH / LOW (pause SETTINGS). AUTO
## boots HIGH and the Watch node downgrades the session to LOW when
## real frames are sustained-low. The drop is session-only: the stored
## setting stays AUTO, so a stronger machine tomorrow still boots HIGH.
## Pinned HIGH/LOW never spawns the watcher.
##
## Headless gates: perf_check --quality low|high forces a preset for a
## measured run; quality_check.tscn asserts the full switch end-to-end.

const MODES := ["auto", "high", "low"]

const LOW_LOD_SCALE := 0.55   ## LOW keeps 55 % of every draw-distance tier
const LOW_CROWD_SCALE := 0.60  ## LOW crowd cap: ~60 % of the street bodies
const HIGH_SHADOW_MAX := 120.0
const LOW_SHADOW_MAX := 55.0

## Auto-FPS fallback thresholds: after WARMUP_S of play, FPS_FLOOR must
## be missed for BAD_WINDOWS consecutive WINDOW_S windows (~16 s of
## sustained struggle) before the single session drop fires.
const FPS_FLOOR := 30.0
const WARMUP_S := 20.0
const WINDOW_S := 8.0
const BAD_WINDOWS := 2

## perf_check override ("low"/"high"); empty = honour saved settings.
static var force_mode := ""


static func sanitize(mode: String) -> String:
	## Anything unknown (or tampered) falls back to AUTO, never breaks boot.
	return mode if mode in MODES else "auto"


static func effective_low(mode: String) -> bool:
	## force_mode wins (CI must measure an exact preset); else LOW only.
	var eff := force_mode if force_mode != "" else mode
	return eff == "low"


static func apply_sun(sun: DirectionalLight3D, low: bool) -> void:
	## LOW trades the far split band for one tight map: near actors keep
	## their shadow, the far band stops eating fill on weak GPUs.
	if sun == null:
		return
	if low:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = LOW_SHADOW_MAX
	else:
		sun.directional_shadow_mode = \
				DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = HIGH_SHADOW_MAX


class Watch:
	extends Node
	## AUTO-mode FPS sampler. Counts real frames per window (not
	## Engine.get_frames_per_second — the same average, no sampling
	## noise) and asks the game to drop to LOW after sustained misses.
	## PROCESS_MODE_INHERIT means a paused game stops counting, which is
	## correct: pause menus are not frame stress.
	var _game: Node
	var _elapsed := 0.0
	var _win_frames := 0
	var _win_elapsed := 0.0
	var _bad := 0
	var _dropped := false

	func _init(game: Node) -> void:
		_game = game

	func _process(delta: float) -> void:
		if _dropped or _game == null:
			return
		_elapsed += delta
		if _elapsed < WARMUP_S:
			return
		_win_frames += 1
		_win_elapsed += delta
		if _win_elapsed < WINDOW_S:
			return
		var fps := float(_win_frames) / maxf(_win_elapsed, 0.001)
		_win_frames = 0
		_win_elapsed = 0.0
		_consider(fps)

	func _consider(fps: float) -> bool:
		## One window verdict in; returns true when the drop fires.
		## Public-ish on purpose: quality_check drives it headless with
		## synthetic windows instead of waiting real wall-clock time.
		if _dropped or _game == null:
			return _dropped
		if fps < FPS_FLOOR:
			_bad += 1
		else:
			_bad = 0
		if _bad >= BAD_WINDOWS and _game.has_method("_auto_quality_drop"):
			_dropped = true
			_game._auto_quality_drop()
		return _dropped
