extends Node
## Economy curve gate (issue #210) — headless check that the tuned
## earn/spend curve holds its milestones over a scripted 30-minute
## median hustle. Reads the LIVE constants from taxi.gd, courier.gd,
## food.gd and main.gd, so a future retune that breaks the ~20-min
## first-upgrade promise fails this gate in CI.
##
## Sim model (median player, deterministic seed):
##   - 70% taxi cycles / 30% courier runs over the landmark trip mix
##   - tips: gold 30% of rides, silver 45%, none 20% (clean/fast odds)
##   - food stop every 6 min at the median cart price (rain premium
##     over a quarter of the stops), rent every in-game day
##   - one-shot content: missions Rs 350 @ 12 min and Rs 500 @ 22 min,
##     first story arc Rs 700 @ 26 min (matches the first-hour cadence)
## Acceptance milestones (issue #210):
##   10 min >= Rs 500    curve rising past food + rent
##   20 min >= Rs 1500   first upgrade tier affordable (~20-min target)
##   30 min >= Rs 2500   second tier + arc money banked
##   rent-shortfall days == 0 (a day's hustle always covers the stand)
## Usage:
##   godot --headless --path . res://scenes/econ_check.tscn
## Exits 0 with verdict=PASS, 2 otherwise.

const TaxiScript := preload("res://scripts/taxi.gd")
const CourierScript := preload("res://scripts/courier.gd")
const FoodScript := preload("res://scripts/food.gd")
const MainScript := preload("res://scripts/main.gd")

const SIM_SECONDS := 1800.0
const SIM_SEED := 210
## Landmark trip mix (metres, weight) sampled from the street grid the
## hail spots actually span (≈120-300 m hops between landmarks).
const TRIP_MIX := [[120.0, 0.2], [180.0, 0.35], [240.0, 0.3], [300.0, 0.15]]
const TAXI_SHARE := 0.7
const DRIVE_SPEED := 7.0   # m/s city average incl. corners and braking
const HAIL_GAP := 12.0     # s waiting on the next hail or radio call
const BOARD_DROP := 18.0   # s boarding, dropping off, repositioning
const FIND_DEPOT := 10.0   # s spotting the next crate
const GOLD_ODDS := 0.35
const SILVER_EXTRA := 0.45 # silver odds = GOLD..GOLD+SILVER_EXTRA
const FAST_ODDS := 0.6
const STREAK_BREAK := 0.15
const FOOD_EVERY := 360.0
const RAIN_SHARE := 0.25
const MISSION_HITS := {720.0: 350, 1320.0: 500, 1560.0: 700}
const MILESTONES := [
	{"t": 600.0, "min": 500, "why": "10 min: rising past food + rent"},
	{"t": 1200.0, "min": 1500, "why": "20 min: first upgrade tier in reach"},
	{"t": 1800.0, "min": 2500, "why": "30 min: second tier + arc banked"},
]


func _ready() -> void:
	seed(SIM_SEED)
	print("econ gate · live constants:")
	print("  start cash Rs %d · rent Rs %d/day (%.0f s day) · cart surge +%d%%"
			% [int(MainScript.START_CASH), int(MainScript.AUTO_STAND_RENT),
				float(MainScript.DAY_LEN), int(round(FoodScript.SURGE_MULT * 100.0))])
	print("  taxi Rs %d + %.2f/m (tips +%.0f%%/+%.0f%%) · courier Rs %d + %.2f/m"
			% [int(TaxiScript.BASE_FARE), float(TaxiScript.RATE_PER_M),
				float(TaxiScript.TIP_GOLD * 100.0), float(TaxiScript.TIP_SILVER * 100.0),
				int(CourierScript.BASE_PAY), float(CourierScript.PER_M)])

	var events := _schedule()
	var cash := int(MainScript.START_CASH)
	var snapshots := {}
	var shortfall_days := 0
	var ei := 0
	var t := 0.0

	while ei < events.size() or t < SIM_SECONDS:
		var cyc := _cycle()
		var t_end := t + float(cyc["dur"])
		while ei < events.size() and float(events[ei]["t"]) <= t_end:
			var e: Dictionary = events[ei]
			match String(e["kind"]):
				"rent":
					if cash < int(e["amount"]):
						shortfall_days += 1
					cash = maxi(cash - int(e["amount"]), 0)
				"food":
					cash = maxi(cash - int(e["amount"]), 0)
				"mission":
					cash += int(e["amount"])
				"mark":
					snapshots[int(e["t"])] = cash
					print("  %4.0f s  cash Rs %d  (%s)"
							% [float(e["t"]), cash, String(e["label"])])
			ei += 1
		if t_end >= SIM_SECONDS:
			break
		cash += int(cyc["take"])
		t = t_end

	var problems: Array[String] = []
	for m in MILESTONES:
		var at := int(m["t"])
		if not snapshots.has(at):
			problems.append("milestone at %d s never snapped" % at)
			continue
		var got := int(snapshots[at])
		if got < int(m["min"]):
			problems.append("%s — Rs %d < Rs %d" % [String(m["why"]), got, int(m["min"])])
	if shortfall_days > 0:
		problems.append("rent exceeded the wallet on %d day(s) — day income too thin"
				% shortfall_days)

	if problems.is_empty():
		print("verdict=PASS · 30-min curve holds, rent always coverable")
		get_tree().quit(0)
	else:
		for p in problems:
			print("FAILED: " + p)
		print("verdict=FAIL")
		get_tree().quit(2)


# ---------------------------------------------------------------- sim

func _schedule() -> Array:
	## Fixed clock events, chronological: midnight rent, food stops,
	## one-shot content, milestone snapshots.
	var ev := []
	var day := float(MainScript.DAY_LEN)
	while day <= SIM_SECONDS:
		ev.append({"t": day, "kind": "rent", "amount": int(MainScript.AUTO_STAND_RENT)})
		day += float(MainScript.DAY_LEN)
	var food_t := FOOD_EVERY
	var cart_median := (float(FoodScript.CHAI["price"]) + float(FoodScript.SAMOSA["price"])) / 2.0
	var food_cost := int(round(cart_median * (1.0 + FoodScript.SURGE_MULT * RAIN_SHARE)))
	while food_t <= SIM_SECONDS:
		ev.append({"t": food_t, "kind": "food", "amount": food_cost})
		food_t += FOOD_EVERY
	for k in MISSION_HITS:
		ev.append({"t": float(k), "kind": "mission", "amount": int(MISSION_HITS[k])})
	for m in MILESTONES:
		ev.append({"t": float(m["t"]), "kind": "mark", "label": String(m["why"])})
	ev.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return ev


func _cycle() -> Dictionary:
	## One hustle cycle: duration and take, straight from the live
	## fare formulas a player would hit.
	if randf() < TAXI_SHARE:
		var d := _trip()
		var fare := int(round(TaxiScript.BASE_FARE + d * TaxiScript.RATE_PER_M))
		var tip := 0
		var r := randf()
		if r < GOLD_ODDS:
			tip = _round5(fare * TaxiScript.TIP_GOLD)
		elif r < GOLD_ODDS + SILVER_EXTRA:
			tip = _round5(fare * TaxiScript.TIP_SILVER)
		return {"dur": HAIL_GAP + d / DRIVE_SPEED + BOARD_DROP, "take": fare + tip}
	var d2 := _trip()
	var par := CourierScript.BASE_TIME + CourierScript.TIME_PER_M * d2
	var fast := randf() < FAST_ODDS
	var pay := CourierScript.PER_M * d2 + CourierScript.BASE_PAY
	var mult := 1.0 + CourierScript.FAST_BONUS if fast else 1.0
	var streak_cap := float(CourierScript.STREAK_CAP) * CourierScript.STREAK_STEP
	_streak = minf(_streak + CourierScript.STREAK_STEP, streak_cap)
	if randf() < STREAK_BREAK:
		_streak = 0.0
	return {"dur": FIND_DEPOT + par * (0.85 if fast else 1.05),
			"take": int(round(pay * (mult + _streak)))}


var _streak := 0.0


func _trip() -> float:
	var roll := randf()
	var acc := 0.0
	for pair in TRIP_MIX:
		acc += float(pair[1])
		if roll <= acc:
			return float(pair[0])
	return float(TRIP_MIX[0][0])


func _round5(x: float) -> int:
	return int(round(x / 5.0) * 5.0)
