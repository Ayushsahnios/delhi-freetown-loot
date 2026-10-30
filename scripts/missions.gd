extends Node
## Mission system: data-driven mission table, glowing street markers,
## typewriter dialogue offers with take-it-or-leave-it choices,
## multi-stage reach / timed-delivery objectives, rival racers, fail
## flow, cash rewards. All visuals procedural — zero assets.
## First two real jobs: the chai run (three stops before it cools) and
## the CP ring race (checkpoints against two AI rickshaws).
## Issue #190 variety pack: hot-box timed delivery with speed-tier
## bonuses, the bazaar chor chase (moving objective), and the shaadi
## collect arc (multi-stop pickups + finale bonus).

const DialogueScript := preload("res://scripts/dialogue.gd")
const StoryArcs := preload("res://scripts/story_arcs.gd")

signal mission_completed(title: String, reward: int)
signal mission_failed(title: String)

const TRIGGER_R := 3.5
const OFFER_EXIT_R := 5.5
const MARKER_CD := 4.0
const LEGEND_NAMES := {"sardarji": "Sardar Ji", "riya": "Riya", "monty": "Monty"}

var cash := 0
## Session stats (issue #211): counters since this legend took the
## street — they reset on scene load and never persist with the save.
var session_earned := 0
var session_fares := 0
var session_missions := 0
var enabled := true
## Day ledger (issue #219): today's earnings by source (missions/fares/
## finds) — closed out at the midnight rent tick, carried in the save.
var ledger := {}
## Mission id -> times completed; persisted in the save file.
var completed := {}

var _player: CharacterBody3D = null
var _defs: Array[Dictionary] = []
var _states := {}
var _cds := {}
var _givers := {}
var _offer_def: Dictionary = {}
var _active := {}
var _t := 0.0
var _toast_t := 0.0
## Finale arc (issue #96): the ending card waits for the final outro
## to close, and a wrong-legend visitor at a finale marker gets a
## pointed hint toast instead of a job offer.
var _ending_pending := false
var _pending_ending: Dictionary = {}
var _legend_hint_cd := 0.0
var _ending_layer: CanvasLayer = null
var _ending_title: Label = null
var _ending_lines: VBoxContainer = null

var _ui: CanvasLayer
var _dlg: CanvasLayer
var _obj_hud: Label
var _toast: Label
var _cash_hud: Label
var _obj_ring: MeshInstance3D = null
var _obj_beam: MeshInstance3D = null
var _racers: Array[Dictionary] = []
var _thief: Dictionary = {}
const RACER_CANOPIES := [Color(0.95, 0.35, 0.15), Color(0.25, 0.55, 0.95)]


func _ready() -> void:
	_build_defs()
	for def in _defs:
		if def.has("objectives"):
			def["objs"] = def["objectives"]
			if not def.has("time"):
				def["time"] = 0.0
		else:
			def["objs"] = [def["objective"]]
			if not def.has("time"):
				def["time"] = float(def["objective"].get("time", 0.0))
	_build_ui()
	for def in _defs:
		_spawn_giver(def)
	_refresh_finale_gates()


# ---------------------------------------------------------------- public API

func register_player(p: CharacterBody3D) -> void:
	_player = p


func active_target() -> Vector3:
	## World position of the current objective marker, for the minimap.
	## Vector3.INF when no mission is running.
	if _active.is_empty():
		return Vector3.INF
	var objs: Array = _active["def"]["objs"]
	return objs[int(_active["stage"])]["pos"]


func abort_active(reason: String) -> void:
	## Called by the main scene when the player goes down: fail any
	## running mission, drop any open offer dialogue, and pause new
	## offers until respawn completes.
	if not _active.is_empty():
		_fail_mission(reason)
	if not _offer_def.is_empty():
		_offer_def = {}
	if _dlg.is_running():
		_dlg.cancel()
	enabled = false


func resume() -> void:
	enabled = true


func charge_fine(amount: int) -> int:
	## Busted: the police take their cut. Never drops below zero;
	## returns what was actually taken so the HUD message is honest.
	var taken := mini(maxi(amount, 0), cash)
	cash -= taken
	_cash_hud.text = "Rs %d" % cash
	return taken


func spend(amount: int) -> bool:
	## Street purchases (food stalls): pay only if the wallet covers it.
	if amount <= 0 or cash < amount:
		return false
	cash -= amount
	_cash_hud.text = "Rs %d" % cash
	return true


func earn(amount: int, source := "finds") -> void:
	## Side hustles (issue #99): metered fares and courier payouts land
	## in the same wallet, so they persist with the save. Source tags the
	## day ledger (issue #219); default keeps old callers on "finds".
	if amount <= 0:
		return
	session_earned += amount
	if source == "fares":
		session_fares += 1
	cash += amount
	_ledger_add(source, amount)
	_cash_hud.text = "Rs %d" % cash


func set_cash(amount: int) -> void:
	## Character-switch entry point: swap the visible wallet without
	## touching mission completion records.
	cash = maxi(amount, 0)
	_cash_hud.text = "Rs %d" % cash


func day_close(rent: int) -> Dictionary:
	## Midnight (issue #219): the auto-stand rent comes off, today's
	## books close and reset. Returns the day's ledger for the card.
	## A shortfall warns — it never takes health or kills.
	var books := {"sources": ledger.duplicate(), "rent": maxi(rent, 0),
			"shortfall": maxi(rent - cash, 0), "cash_before": cash}
	cash = maxi(cash - maxi(rent, 0), 0)
	_cash_hud.text = "Rs %d" % cash
	ledger = {}
	return books


func ledger_snapshot() -> Dictionary:
	## Save piggyback (issue #219): today's running ledger, plain ints.
	return ledger.duplicate()


func restore_ledger(saved: Dictionary) -> void:
	ledger = {}
	for key in saved:
		var amt := maxi(int(saved[key]), 0)
		if amt > 0:
			ledger[String(key)] = amt


func _ledger_add(source: String, amount: int) -> void:
	ledger[source] = int(ledger.get(source, 0)) + maxi(amount, 0)


func restore(saved_cash: int, saved_completed: Dictionary) -> void:
	## Load-from-save entry point: cash, HUD, completion records.
	## Repeatable missions stay at their markers; any one-shot mission
	## completed in a past session stays done and hidden.
	cash = maxi(saved_cash, 0)
	_cash_hud.text = "Rs %d" % cash
	completed = {}
	for key in saved_completed:
		completed[String(key)] = maxi(int(saved_completed[key]), 0)
	for def in _defs:
		var id := String(def["id"])
		if int(completed.get(id, 0)) > 0 and not bool(def.get("repeatable", false)):
			_states[id] = "done"
			_show_giver(id, false)
	_refresh_finale_gates()


# ---------------------------------------------------------------- data

func _build_defs() -> void:
	_defs = [
		{
			"id": "gate_stroll",
			"title": "Street test: Gate run",
			"lines": [
				{
					"speaker": "Street marshal",
					"text": "Fresh legs! The loop crew wants proof you can move. Get from this corner to India Gate and stand under the arch — walk it, sprint it, or grab an auto.",
					"color": Color(1.0, 0.86, 0.3),
				},
				{
					"speaker": "Street marshal",
					"text": "Straight up the mall road, you can't miss it. Rs 250 on your return.",
					"color": Color(1.0, 0.86, 0.3),
					"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(8.0, 0.0, 50.0),
			"intro": true,
			"objective": {
				"kind": "reach",
				"label": "Reach India Gate",
				"pos": Vector3(0.0, 0.0, -82.0),
				"radius": 7.0,
				"time": 0.0,
			},
			"reward": 250,
			"repeatable": true,
		},
		{
			"id": "cp_crate",
			"title": "Street test: CP crate run",
			"lines": [
				{
					"speaker": "Dhaba owner",
					"text": "Arre beta, my dal crate is sitting by the CP green and the fort-gate chowkidar in Purani Dilli won't wait forever.",
					"color": Color(0.55, 0.9, 0.5),
				},
				{
					"speaker": "Dhaba owner",
					"text": "Seventy seconds before it boils over — Rs 450, cash, no arguments.",
					"color": Color(0.55, 0.9, 0.5),
					"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(14.0, 0.0, 14.0),
			"objective": {
				"kind": "deliver",
				"label": "Deliver the crate to Purani Dilli",
				"pos": Vector3(-92.0, 0.0, 104.0),
				"radius": 8.0,
				"time": 70.0,
			},
			"reward": 450,
			"repeatable": true,
		},
		{
			"id": "chai_run",
			"title": "Chai run: three cups, one flask",
			"lines": [
				{
					"speaker": "Chai stall uncle",
					"text": "Chotu called in sick and the flask is full to the brim. Three cups, three corners of town: the guard at India Gate, the chowkidar at Purani Dilli, the joggers at Neighbourhood Park.",
					"color": Color(1.0, 0.6, 0.3),
				},
				{
					"speaker": "Chai stall uncle",
					"text": "The chai cools in about two minutes, so an auto is strongly advised. Rs 600 when the last cup lands.",
					"color": Color(1.0, 0.6, 0.3),
					"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(6.0, 0.0, -16.0),
			"objectives": [
				{
					"kind": "deliver",
					"label": "Cup 1 — the guard at India Gate",
					"pos": Vector3(0.0, 0.0, -82.0),
					"radius": 8.0,
				},
				{
					"kind": "deliver",
					"label": "Cup 2 — the chowkidar at Purani Dilli",
					"pos": Vector3(-92.0, 0.0, 104.0),
					"radius": 8.0,
				},
				{
					"kind": "deliver",
					"label": "Cup 3 — the joggers at Neighbourhood Park",
					"pos": Vector3(138.0, 0.0, -126.0),
					"radius": 8.0,
				},
			],
			"time": 130.0,
			"unit": "cups",
			"reward": 600,
			"repeatable": true,
		},
		{
			"id": "skyline_ring",
			"title": "Skyline ring: Gate to Lotus",
			"lines": [
				{
					"speaker": "Photo-stringer Raju",
					"text": "Two new postcard spots, beta — the Victory Gate roundabout and the Lotus Court dome. Two frames before the light goes, one loop across town. Rs 500.",
					"color": Color(0.60, 0.85, 1.0),
				},
				{
					"speaker": "Photo-stringer Raju",
					"text": "Stand under the arch for frame one, then the dome steps for frame two. Walk it, sprint it, or grab an auto — the light waits for no one.",
					"color": Color(0.60, 0.85, 1.0),
					"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(-7.0, 0.0, -11.0),
			"objectives": [
				{
					"kind": "reach",
					"label": "Frame 1 — under the Victory Gate arch",
					"pos": Vector3(167.0, 0.0, -201.0),
					"radius": 7.0,
				},
				{
					"kind": "reach",
					"label": "Frame 2 — the Lotus Court dome steps",
					"pos": Vector3(-201.0, 0.0, 167.0),
					"radius": 7.0,
				},
			],
			"reward": 500,
			"repeatable": true,
		},
		{
			"id": "cp_race",
			"title": "CP ring race: rickshaw rally",
			"lines": [
				{
					"speaker": "Rival puller",
					"text": "Oye hero! We lap the CP ring before your meter even beeps. You think you can keep up through all four crossings?",
					"color": Color(0.95, 0.4, 0.35),
				},
				{
					"speaker": "Rival puller",
					"text": "Grab an auto, tag the start line on the west road, and beat us around. Rs 650 says you can't.",
					"color": Color(0.95, 0.4, 0.35),
					"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(-30.0, 0.0, 6.0),
			"objectives": [
				{
					"kind": "reach",
					"label": "Tag the start line",
					"pos": Vector3(-40.0, 0.0, 6.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — north-west crossing",
					"pos": Vector3(-40.0, 0.0, -40.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — north-east crossing",
					"pos": Vector3(6.0, 0.0, -40.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Checkpoint — south-east crossing",
					"pos": Vector3(6.0, 0.0, 6.0),
					"radius": 8.0,
				},
				{
					"kind": "reach",
					"label": "Finish — back to the start line",
					"pos": Vector3(-40.0, 0.0, 6.0),
					"radius": 8.0,
				},
			],
			"race": {
				"corners": [
					Vector3(-40.0, 0.0, 6.0),
					Vector3(-40.0, 0.0, -40.0),
					Vector3(6.0, 0.0, -40.0),
					Vector3(6.0, 0.0, 6.0),
					],
				"rivals": [13.5, 15.0],
			},
			"reward": 650,
			"repeatable": true,
		},
		{
			"id": "hot_box",
			"title": "Hot box sprint: samosas to CP",
			"lines": [
				{
				"speaker": "Halwai counter",
				"text": "Sixty samosas, frying hot, boxed for a CP office party. They lose their crunch in forty-five seconds flat.",
				"color": Color(0.95, 0.72, 0.30),
				},
				{
				"speaker": "Halwai counter",
				"text": "Run it to the CP green before they cool — Rs 350 base, and a real tip if you sprint it. Bonus tiers on the clock left!",
				"color": Color(0.95, 0.72, 0.30),
				"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(-74.0, 0.0, 68.0),
			"marker_color": Color(1.0, 0.55, 0.25),
			"objective": {
				"kind": "deliver",
				"label": "Deliver the hot box to the CP green",
				"pos": Vector3(-17.0, 0.0, -17.0),
				"radius": 10.0,
				"time": 45.0,
			},
			"tiers": [
				{"name": "GOLD", "min": 0.45, "bonus": 200},
				{"name": "SILVER", "min": 0.25, "bonus": 100},
			],
			"fail": "the samosas went cold",
			"reward": 350,
			"repeatable": true,
		},
		{
			"id": "chor_chase",
			"title": "Chor in the bazaar: catch the till-thief",
			"lines": [
				{
				"speaker": "Bazaar shopkeeper",
				"text": "CHOooR! He grabbed my whole till and took off down the market lane — red shirt, red bag, fast little devil.",
				"color": Color(0.95, 0.45, 0.30),
				},
				{
				"speaker": "Bazaar shopkeeper",
				"text": "He's lapping the bazaar streets, but he tires. Catch him before he melts into the crowd — Rs 450, cash, no police report.",
				"color": Color(0.95, 0.45, 0.30),
				"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(-74.0, 0.0, 44.0),
			"marker_color": Color(0.9, 0.25, 0.2),
			"objective": {
				"kind": "chase",
				"label": "Catch the chor",
				"pos": Vector3(-86.0, 0.0, 52.0),
				"radius": 3.0,
				"time": 90.0,
			},
			"chase": {
				"path": [
					Vector3(-86.0, 0.0, 52.0),
					Vector3(-40.0, 0.0, 52.0),
					Vector3(-40.0, 0.0, 98.0),
					Vector3(-86.0, 0.0, 98.0),
				],
				"speed": 10.0,
			},
			"fail": "the chor melted into the crowd",
			"reward": 450,
			"repeatable": true,
		},
		{
			"id": "shaadi_run",
			"title": "Shaadi run: three parcels, one banquet",
			"lines": [
				{
				"speaker": "Wedding planner",
				"text": "Tonight's shaadi at Hauz Khas and NOTHING has arrived! Marigold garlands from the flower cart at Purani Dilli, the sweets box from the CP confectioner, the silk roll from the park-side tailor.",
				"color": Color(0.92, 0.5, 0.72),
				},
				{
				"speaker": "Wedding planner",
				"text": "Everything back to the banquet before the baraat rolls — Rs 500 base, and a finale bonus if you beat my clock properly. An auto is strongly advised!",
				"color": Color(0.92, 0.5, 0.72),
				"choices": ["Take the job", "Not now"],
				},
			],
			"giver": Vector3(-149.0, 0.0, 121.0),
			"marker_color": Color(0.9, 0.45, 0.7),
			"objectives": [
				{
					"kind": "pickup",
					"label": "Garlands — flower cart, Purani Dilli",
					"pos": Vector3(-100.0, 0.0, 96.0),
					"radius": 8.0,
				},
				{
					"kind": "pickup",
					"label": "Sweets box — CP confectioner",
					"pos": Vector3(-24.0, 0.0, -24.0),
					"radius": 8.0,
				},
				{
					"kind": "pickup",
					"label": "Silk roll — park-side tailor",
					"pos": Vector3(132.0, 0.0, -140.0),
					"radius": 8.0,
				},
				{
					"kind": "deliver",
					"label": "Finale — all parcels to the banquet",
					"pos": Vector3(-155.0, 0.0, 121.0),
					"radius": 10.0,
				},
			],
			"time": 200.0,
			"unit": "parcels",
			"tiers": [
				{"name": "FINALE GOLD", "min": 0.30, "bonus": 200},
				{"name": "FINALE SILVER", "min": 0.15, "bonus": 100},
			],
			"fail": "the baraat left without its parcels",
			"reward": 500,
			"repeatable": true,
		},
	]
	# Story arcs come from a const (read-only) dictionary — duplicate them
	# so the runtime state fields written in _ready() never hit the shared
	# read-only source definitions (which aborts mission setup on fresh start).
	for arc in StoryArcs.STORY_ARCS:
		_defs.append(arc.duplicate(true))
	# Finale arc (issue #96): three chained one-shot missions gated on
	# mission completions ("after") and the named legend ("requires").
	for fin in StoryArcs.STORY_FINALE:
		_defs.append(fin.duplicate(true))


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_t += delta
	if _toast_t > 0.0:
		_toast_t = maxf(_toast_t - delta, 0.0)
		if _toast_t <= 0.0:
			_toast.visible = false
	for def in _defs:
		var id := String(def["id"])
		var g: Dictionary = _givers[id]
		if g["ring"].visible:
			g["ring"].rotate_y(delta * 1.4)
			g["beam"].position.y = float(def["giver"].y) + 4.6 + sin(_t * 2.2) * 0.35
			var lb: Label3D = g["label"]
			if lb != null:
				# START HERE tag: only until the intro job is run once
				lb.visible = int(completed.get(id, 0)) == 0
		match String(_states[id]):
			"cooldown":
				_cds[id] = float(_cds[id]) - delta
				if float(_cds[id]) <= 0.0:
					_states[id] = "available"
					_show_giver(id, true)
			"available":
				var near := enabled and _player != null \
						and _flat_dist(_player.global_position, def["giver"]) < TRIGGER_R
				if near and def.has("requires") and not _legend_matches(def):
					# Finale jobs offer only to their named legend; anyone
					# else on the marker gets a pointed hint instead.
					if _legend_hint_cd <= 0.0:
						_legend_hint_cd = 6.0
						_toast.add_theme_color_override("font_color", Color(1.0, 0.72, 0.20))
						_toast.text = "THE FINALE WAITS FOR %s  ·  TAB SWITCH" % String(LEGEND_NAMES.get(String(def["requires"]), String(def["requires"]))).to_upper()
						_toast.visible = true
						_toast_t = 2.2
				elif near and _active.is_empty() and _offer_def.is_empty() and not _dlg.is_running():
					_states[id] = "offered"
					_offer_def = def
					_dlg.start(def["lines"])
			"offered":
				if _player == null or _flat_dist(_player.global_position, def["giver"]) > OFFER_EXIT_R:
					_states[id] = "available"
					_offer_def = {}
					_dlg.cancel()
	if not _active.is_empty():
		_tick_active(delta)
	if _legend_hint_cd > 0.0:
		_legend_hint_cd = maxf(_legend_hint_cd - delta, 0.0)
	if _ending_layer != null and _ending_layer.visible:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			_ending_layer.visible = false
		return
	if _obj_ring != null and _obj_ring.visible:
		var pulse := 0.9 + 0.1 * sin(_t * 5.0)
		_obj_ring.scale = Vector3(pulse, 1.0, pulse)
		_obj_ring.rotate_y(delta * 2.0)


func _tick_active(delta: float) -> void:
	var def: Dictionary = _active["def"]
	var objs: Array = def["objs"]
	var stage := int(_active["stage"])
	var obj: Dictionary = objs[stage]
	if String(obj.get("kind", "")) == "chase" and not _thief.is_empty():
		# Moving objective (issue #190): the chor keeps sprinting, and the
		# HUD, minimap and route arrow all track him live via obj["pos"].
		_tick_thief(delta)
		obj["pos"] = _thief["node"].global_position
	if float(_active["time"]) > 0.0:
		_active["left"] = float(_active["left"]) - delta
		if float(_active["left"]) <= 0.0:
			_fail_mission(String(def.get("fail", "the chai went cold")))
			return
	if def.has("race"):
		if _tick_racers(delta):
			_fail_mission("a rival crossed the line first")
			return
	var d := _flat_dist(_player.global_position, obj["pos"])
	var txt := "> %s  (%d/%d)  ·  %d m" % [String(obj["label"]), stage + 1, objs.size(), int(round(d))]
	if float(_active["time"]) > 0.0:
		txt += "  ·  " + _fmt_time(float(_active["left"]))
	_obj_hud.text = txt
	if d <= float(obj["radius"]):
		if stage == objs.size() - 1:
			_complete_mission()
		else:
			_advance_stage(objs, stage)


# ---------------------------------------------------------------- flow

func _on_dialogue_finished(picked: int) -> void:
	## Offer dialogue closed: 0 = take the job, 1 = turned down to the
	## giver's face (short sulk cooldown), anything else = available.
	if _offer_def.is_empty():
		## Outro closing with the ending card queued (issue #96): the
		## story ends once the finale's last conversation beat closes.
		if _ending_pending:
			_ending_pending = false
			var ending: Dictionary = _pending_ending
			_pending_ending = {}
			_show_ending_card(ending)
		return
	var def: Dictionary = _offer_def
	_offer_def = {}
	var id := String(def["id"])
	if picked == 0 and enabled:
		_start_mission(def)
	elif picked == 1:
		_states[id] = "cooldown"
		_cds[id] = MARKER_CD
		_show_giver(id, false)
	else:
		_states[id] = "available"


func _start_mission(def: Dictionary) -> void:
	var id := String(def["id"])
	_states[id] = "active"
	_show_giver(id, false)
	_active = {"def": def, "stage": 0, "time": float(def["time"]), "left": float(def["time"])}
	if def.has("race"):
		_spawn_racers(def)
	if def.has("chase"):
		_spawn_thief(def)
	_spawn_objective(def["objs"][0])
	_obj_hud.visible = true
	_toast.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_toast.text = "JOB — %s" % String(def["title"]).to_upper()
	_toast.visible = true
	_toast_t = 1.6


func _advance_stage(objs: Array, stage: int) -> void:
	_active["stage"] = stage + 1
	_spawn_objective(objs[stage + 1])
	_toast.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	if _active["def"].has("race"):
		_toast.text = "CHECKPOINT %d/%d" % [stage + 1, objs.size() - 1]
	else:
		var verb := "DELIVERED"
		if String(objs[stage].get("kind", "")) == "pickup":
			verb = "PICKED UP"
		_toast.text = "%s  ·  %d of %d %s" % [verb, stage + 1, objs.size(), String(_active["def"].get("unit", "stops"))]
	_toast.visible = true
	_toast_t = 1.2


func _complete_mission() -> void:
	var def: Dictionary = _active["def"]
	var reward := int(def["reward"])
	var tier_note := ""
	if def.has("tiers") and float(_active["time"]) > 0.0:
		# Speed-tier bonus (issue #190): the more clock left, the fatter
		# the tip — first matching tier wins (listed best-first).
		var ratio := float(_active["left"]) / float(_active["time"])
		for tier in def["tiers"]:
			if ratio >= float(tier["min"]):
				reward += int(tier["bonus"])
				tier_note = "  ·  %s +Rs %d" % [String(tier["name"]), int(tier["bonus"])]
				break
	cash += reward
	_ledger_add("missions", reward)
	_cash_hud.text = "Rs %d" % cash
	var id := String(def["id"])
	completed[id] = int(completed.get(id, 0)) + 1
	session_missions += 1
	session_earned += reward
	_toast.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	_toast.text = "MISSION COMPLETE  ·  + Rs %d%s" % [reward, tier_note]
	_toast.visible = true
	_toast_t = 2.5
	mission_completed.emit(String(def["title"]), reward)
	_refresh_finale_gates()
	_end_mission(def)
	if def.has("outro"):
		## Story missions close with a final conversation beat.
		if def.has("ending"):
			_ending_pending = true
			_pending_ending = def["ending"]
		_dlg.start(def["outro"])


func _fail_mission(reason: String) -> void:
	var def: Dictionary = _active["def"]
	_toast.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_toast.text = "MISSION FAILED  ·  %s" % reason
	_toast.visible = true
	_toast_t = 2.5
	mission_failed.emit(String(def["title"]))
	_end_mission(def)


func _end_mission(def: Dictionary) -> void:
	var id := String(def["id"])
	_clear_marker()
	for r in _racers:
		r["node"].queue_free()
	_racers.clear()
	if not _thief.is_empty():
		_thief["node"].queue_free()
		_thief = {}
	_obj_hud.visible = false
	_active = {}
	if bool(def.get("repeatable", false)):
		_states[id] = "cooldown"
		_cds[id] = MARKER_CD
	else:
		_states[id] = "done"
		_show_giver(id, false)


# ---------------------------------------------------------------- world

func _spawn_giver(def: Dictionary) -> void:
	var pos: Vector3 = def["giver"]
	var mc: Color = def.get("marker_color", Color(1.0, 0.84, 0.25))
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 2.2
	rm.bottom_radius = 2.2
	rm.height = 2.6
	rm.material = _xmat(mc, 0.42)
	ring.mesh = rm
	ring.position = pos + Vector3(0.0, 1.3, 0.0)
	add_child(ring)
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.25
	bm.bottom_radius = 0.25
	bm.height = 9.0
	bm.material = _xmat(mc.lightened(0.3), 0.55)
	beam.mesh = bm
	beam.position = pos + Vector3(0.0, 4.5, 0.0)
	add_child(beam)
	var label: Label3D = null
	if bool(def.get("intro", false)):
		# Issue #95: the first mission giver carries a billboarded
		# START HERE tag so a fresh player knows exactly where job one is.
		label = Label3D.new()
		label.text = "START HERE"
		label.font_size = 44
		label.outline_size = 12
		label.modulate = Color(1.0, 0.92, 0.45)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.no_depth_test = true
		label.position = pos + Vector3(0.0, 8.6, 0.0)
		add_child(label)
	_states[String(def["id"])] = "available"
	_givers[String(def["id"])] = {"ring": ring, "beam": beam, "label": label}
	if def.has("after"):
		# Finale chain: locked until every prerequisite mission is done.
		_states[String(def["id"])] = "locked"
		_show_giver(String(def["id"]), false)


func _spawn_objective(obj: Dictionary) -> void:
	_clear_marker()
	if String(obj.get("kind", "")) == "chase":
		# No static ring for a moving target — the thief figure and his
		# CHOR tag are the marker (issue #190).
		return
	var pos: Vector3 = obj["pos"]
	var radius := float(obj["radius"])
	_obj_ring = MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = radius * 0.85
	rm.bottom_radius = radius * 0.85
	rm.height = 0.4
	rm.material = _xmat(Color(0.3, 1.0, 0.6), 0.35)
	_obj_ring.mesh = rm
	_obj_ring.position = pos + Vector3(0.0, 0.25, 0.0)
	add_child(_obj_ring)
	_obj_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 0.6
	bm.height = 60.0
	bm.material = _xmat(Color(0.3, 1.0, 0.6), 0.22)
	_obj_beam.mesh = bm
	_obj_beam.position = pos + Vector3(0.0, 30.0, 0.0)
	add_child(_obj_beam)


func _clear_marker() -> void:
	if _obj_ring != null:
		_obj_ring.queue_free()
		_obj_ring = null
	if _obj_beam != null:
		_obj_beam.queue_free()
		_obj_beam = null


func _spawn_racers(def: Dictionary) -> void:
	## Two rival rickshaws lap the circuit analytically, corner to corner
	## along the road ring — kinematic, like traffic, so they never get
	## stuck on geometry.
	var race: Dictionary = def["race"]
	var corners: Array = race["corners"]
	var from: Vector3 = corners[0]
	var to: Vector3 = corners[1]
	var lane := (to - from).normalized().cross(Vector3.UP)
	for i in range(race["rivals"].size()):
		var node := Node3D.new()
		_build_racer_visual(node, RACER_CANOPIES[i % RACER_CANOPIES.size()])
		add_child(node)
		node.position = from + lane * (2.8 * i - 1.4)
		node.look_at(node.position + (to - from), Vector3.UP)
		_racers.append({
			"node": node,
			"corners": corners,
			"at": 0,
			"remain": from.distance_to(to),
			"speed": float(race["rivals"][i]),
			"legs": 0,
		})


func _tick_racers(delta: float) -> bool:
	## Advances every rival; returns true once one has finished the lap.
	var won := false
	for r in _racers:
		if bool(r.get("done", false)):
			continue
		r["remain"] = float(r["remain"]) - float(r["speed"]) * delta
		var corners: Array = r["corners"]
		var at := int(r["at"])
		var from: Vector3 = corners[at]
		var to: Vector3 = corners[(at + 1) % corners.size()]
		var dir := (to - from).normalized()
		r["node"].position = to - dir * maxf(float(r["remain"]), 0.0)
		r["node"].look_at(r["node"].position + dir, Vector3.UP)
		while float(r["remain"]) <= 0.0:
			r["legs"] = int(r["legs"]) + 1
			if int(r["legs"]) >= corners.size():
				r["done"] = true
				r["node"].position = to
				won = true
				break
			var overshoot := -float(r["remain"])
			r["at"] = (at + 1) % corners.size()
			from = corners[int(r["at"])]
			to = corners[(int(r["at"]) + 1) % corners.size()]
			r["remain"] = from.distance_to(to) - overshoot
			dir = (to - from).normalized()
			r["node"].position = to - dir * maxf(float(r["remain"]), 0.0)
			r["node"].look_at(r["node"].position + dir, Vector3.UP)
	return won


func _build_racer_visual(parent: Node3D, canopy: Color) -> void:
	parent.add_child(_rbox(Vector3(2.4, 1.3, 3.4), Color(0.18, 0.55, 0.20), Vector3(0, 1.0, 0)))
	parent.add_child(_rbox(Vector3(2.4, 1.4, 2.2), canopy, Vector3(0, 2.2, 0.2)))
	parent.add_child(_rbox(Vector3(1.6, 1.1, 0.9), canopy, Vector3(0, 1.35, -1.9)))
	for spec in [Vector3(-1.05, 0.55, -1.6), Vector3(1.05, 0.55, -1.6), Vector3(0, 0.55, 1.5)]:
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.4
		cm.material = _omat(Color(0.1, 0.11, 0.13))
		w.mesh = cm
		w.rotation.z = PI / 2.0
		w.position = spec
		parent.add_child(w)


func _spawn_thief(def: Dictionary) -> void:
	## Issue #190: the chor sprints a fixed street loop — kinematic like
	## the racers, so he never snags on market-lane geometry.
	var chase: Dictionary = def["chase"]
	var path: Array = chase["path"]
	var node := Node3D.new()
	_build_thief_visual(node)
	add_child(node)
	var from: Vector3 = path[0]
	var to: Vector3 = path[1]
	node.position = from
	node.look_at(to, Vector3.UP)
	_thief = {"node": node, "path": path, "at": 0,
			"remain": from.distance_to(to), "speed": float(chase["speed"]),
			"run": 0.0}


func _tick_thief(delta: float) -> void:
	## Laps the circuit forever with a running bob; the mission clock is
	## the only thing that stops him (or the player's hands).
	var node: Node3D = _thief["node"]
	var path: Array = _thief["path"]
	_thief["remain"] = float(_thief["remain"]) - float(_thief["speed"]) * delta
	var at := int(_thief["at"])
	var from: Vector3 = path[at]
	var to: Vector3 = path[(at + 1) % path.size()]
	var dir := (to - from).normalized()
	node.position = to - dir * maxf(float(_thief["remain"]), 0.0)
	while float(_thief["remain"]) <= 0.0:
		var overshoot := -float(_thief["remain"])
		_thief["at"] = (at + 1) % path.size()
		from = path[int(_thief["at"])]
		to = path[(int(_thief["at"]) + 1) % path.size()]
		_thief["remain"] = from.distance_to(to) - overshoot
		dir = (to - from).normalized()
		node.position = to - dir * maxf(float(_thief["remain"]), 0.0)
	_thief["run"] = float(_thief["run"]) + delta
	node.position.y = absf(sin(float(_thief["run"]) * 11.0)) * 0.12
	node.look_at(node.position + dir, Vector3.UP)


func _build_thief_visual(parent: Node3D) -> void:
	## Small runner: red shirt, pale cap, red loot sack, CHOR tag.
	parent.add_child(_rbox(Vector3(0.52, 0.62, 0.30), Color(0.72, 0.18, 0.14), Vector3(0, 0.95, 0)))
	parent.add_child(_rbox(Vector3(0.30, 0.30, 0.30), Color(0.78, 0.58, 0.42), Vector3(0, 1.45, 0)))
	parent.add_child(_rbox(Vector3(0.34, 0.10, 0.34), Color(0.92, 0.90, 0.82), Vector3(0, 1.63, 0)))
	parent.add_child(_rbox(Vector3(0.36, 0.42, 0.24), Color(0.82, 0.22, 0.16), Vector3(0.27, 0.88, -0.14)))
	for side in [-0.16, 0.16]:
		parent.add_child(_rbox(Vector3(0.16, 0.55, 0.16), Color(0.13, 0.14, 0.16), Vector3(side, 0.32, 0)))
	var label := Label3D.new()
	label.text = "CHOR"
	label.font_size = 48
	label.outline_size = 10
	label.modulate = Color(1.0, 0.35, 0.25)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.position = Vector3(0, 2.3, 0)
	parent.add_child(label)


func _rbox(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _omat(color)
	m.mesh = bm
	m.position = pos
	return m


func _omat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _show_giver(id: String, on: bool) -> void:
	var g: Dictionary = _givers[id]
	g["ring"].visible = on
	g["beam"].visible = on
	var lb: Label3D = g["label"]
	if lb != null:
		lb.visible = on


func _xmat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fmt_time(s: float) -> String:
	var t := int(ceil(maxf(s, 0.0)))
	return "%d:%02d" % [int(t / 60.0), t % 60]


func _refresh_finale_gates() -> void:
	## Finale missions (issue #96) unlock in order: a locked finale
	## flips available once every mission in its "after" list is done.
	for def in _defs:
		if not def.has("after"):
			continue
		var fid := String(def["id"])
		if String(_states.get(fid, "")) != "locked":
			continue
		var ready := true
		for pre in def["after"]:
			if int(completed.get(String(pre), 0)) == 0:
				ready = false
				break
		if ready:
			_states[fid] = "available"
			_show_giver(fid, true)


func _legend_matches(def: Dictionary) -> bool:
	var need := String(def.get("requires", ""))
	return need.is_empty() or String(Game.selected_character.get("id", "")) == need


func show_ending_preview() -> void:
	## Capture helper: render the finale ending card (screenshot tool).
	for def in _defs:
		if def.has("ending"):
			_show_ending_card(def["ending"])
			return


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	add_child(_ui)

	_cash_hud = Label.new()
	_cash_hud.position = Vector2(1004, 46)
	_cash_hud.add_theme_font_size_override("font_size", 18)
	_cash_hud.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_cash_hud.text = "Rs 0"
	_ui.add_child(_cash_hud)

	_obj_hud = Label.new()
	_obj_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_obj_hud.offset_top = 12.0
	_obj_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_hud.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_obj_hud.add_theme_font_size_override("font_size", 20)
	_obj_hud.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_obj_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_hud.visible = false
	_ui.add_child(_obj_hud)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 32)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_ui.add_child(_toast)

	_dlg = DialogueScript.new()
	add_child(_dlg)
	_dlg.finished.connect(_on_dialogue_finished)


func _show_ending_card(ending: Dictionary) -> void:
	## Issue #96: full-screen finale card once the last outro closes.
	if _ending_layer == null:
		_build_ending_card()
	_ending_title.text = String(ending.get("title", "THE END"))
	for l in _ending_lines.get_children():
		l.queue_free()
	for line in ending.get("lines", []):
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 21)
		lb.add_theme_color_override("font_color", Color(0.93, 0.90, 0.80))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(760.0, 0.0)
		_ending_lines.add_child(lb)
		lb.text = String(line)
	_ending_layer.visible = true


func _build_ending_card() -> void:
	## Above the dialogue box (20), below pause (30). All procedural.
	_ending_layer = CanvasLayer.new()
	_ending_layer.layer = 25
	add_child(_ending_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.05, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_layer.add_child(box)
	_ending_title = Label.new()
	_ending_title.add_theme_font_size_override("font_size", 40)
	_ending_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.25))
	_ending_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_ending_title)
	_ending_lines = VBoxContainer.new()
	_ending_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_ending_lines.add_theme_constant_override("separation", 8)
	_ending_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_ending_lines)
	var hint := Label.new()
	hint.text = "Space — continue >"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_ending_layer.visible = false
