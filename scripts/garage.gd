extends RefCounted
## Kaali-Peeli garage (issue #347) — the buyable vehicle ladder, data
## first. This slice publishes the 15-rung ladder (original Delhi street
## names, prices, mission-count unlock gates, paint + tune variants) and
## the owned-vehicle state with save round-trip helpers. The garage pad
## UI and the buy->spawn cycle (next slice) read this table; nothing
## here touches the live scene tree, so the ladder can be tuned without
## touching gameplay code.

## One rung per buyable ride. "body" names a procedural builder in
## vehicles.gd (scooter/rickshaw/hatch/van/tempo/truck/tanker), "paint"
## indexes its PAINTS palette, "top"/"pickup" are speed and acceleration
## multipliers versus the stock ride, "unlock" is the mission-completion
## count required before the rung shows as buyable. Prices are the
## published showroom rates in rupees — ascending up the ladder.
const LADDER := [
	{"id": "phatphati", "name": "Phatphati", "body": "scooter",
			"paint": 3, "price": 800, "unlock": 0,
			"top": 0.85, "pickup": 0.90,
			"blurb": "Battered starter scooter; starts on the third kick."},
	{"id": "duggdugg", "name": "Dugg-Dugg", "body": "scooter",
			"paint": 5, "price": 1500, "unlock": 2,
			"top": 0.95, "pickup": 1.00,
			"blurb": "Bass-pipe exhaust, honest carburettor, morning-cold reliable."},
	{"id": "sawari_rick", "name": "Sawari Rick", "body": "rickshaw",
			"paint": 0, "price": 2400, "unlock": 2,
			"top": 0.90, "pickup": 0.95,
			"blurb": "Second-hand auto-rickshaw with a fresh meter and fresher horns."},
	{"id": "chakachak_rick", "name": "Chakachak Rick", "body": "rickshaw",
			"paint": 4, "price": 3600, "unlock": 3,
			"top": 1.00, "pickup": 1.05,
			"blurb": "Polished green-and-yellow panels, marigold on the mirror."},
	{"id": "thanda_kaali_peeli", "name": "Thanda Kaali-Peeli", "body": "hatch",
			"paint": 3, "price": 5000, "unlock": 3,
			"top": 1.05, "pickup": 1.00,
			"blurb": "First black-and-yellow hatch; AC blows cold, bills stay warm."},
	{"id": "dhaak_kaali_peeli", "name": "Dhaak Kaali-Peeli", "body": "hatch",
			"paint": 1, "price": 6800, "unlock": 4,
			"top": 1.10, "pickup": 1.08,
			"blurb": "Louder horn, tighter clutch — the rank's favourite."},
	{"id": "dulhan_van", "name": "Dulhan Van", "body": "van",
			"paint": 0, "price": 9000, "unlock": 4,
			"top": 1.00, "pickup": 0.95,
			"blurb": "Wedding-season van; tinsel rails, sevas-friendly boot."},
	{"id": "mela_van", "name": "Mela Van", "body": "van",
			"paint": 5, "price": 11500, "unlock": 5,
			"top": 1.05, "pickup": 1.05,
			"blurb": "Fair-ground workhorse with a bunk behind the seats."},
	{"id": "bazaar_tempo", "name": "Bazaar Tempo", "body": "tempo",
			"paint": 2, "price": 14500, "unlock": 5,
			"top": 1.00, "pickup": 1.00,
			"blurb": "Flat-bed tempo; half the bazaar rides in the back."},
	{"id": "jhankaar_tempo", "name": "Jhankaar Tempo", "body": "tempo",
			"paint": 4, "price": 18000, "unlock": 6,
			"top": 1.10, "pickup": 1.10,
			"blurb": "Repainted tempo with drum-thump speakers over the axle."},
	{"id": "sher_truck", "name": "Sher Truck", "body": "truck",
			"paint": 1, "price": 22000, "unlock": 6,
			"top": 1.05, "pickup": 1.00,
			"blurb": "Lion-of-the-highway loader; air horn, brass tiger on the dash."},
	{"id": "pahad_truck", "name": "Pahad Truck", "body": "truck",
			"paint": 3, "price": 26500, "unlock": 8,
			"top": 1.15, "pickup": 1.05,
			"blurb": "Hill-route truck; low gears, high morale, painted cliff scenes."},
	{"id": "matka_tanker", "name": "Matka Tanker", "body": "tanker",
			"paint": 2, "price": 31500, "unlock": 8,
			"top": 1.05, "pickup": 0.95,
			"blurb": "Water tanker; the colony's best friend in May."},
	{"id": "raja_kaali_peeli", "name": "Raja Kaali-Peeli", "body": "hatch",
			"paint": 0, "price": 37000, "unlock": 10,
			"top": 1.30, "pickup": 1.25,
			"blurb": "Garage-queen hatch: worked engine, chrome bumper, king of the rank."},
	{"id": "badshah_truck", "name": "Badshah Truck", "body": "truck",
			"paint": 5, "price": 45000, "unlock": 12,
			"top": 1.35, "pickup": 1.30,
			"blurb": "Emperor of the yard — new rubber, full service history, no stories."},
]

## Owned-vehicle state for one save slot. The wallet itself lives in
## missions.gd; purchase() only records ownership once the caller has
## spent the cash, so money math stays in one place.
var owned := {}
var selected := ""


static func rung_count() -> int:
	return LADDER.size()


static func rung(index: int) -> Dictionary:
	return LADDER[clampi(index, 0, LADDER.size() - 1)]


static func by_id(id: String) -> Dictionary:
	for entry in LADDER:
		if String(entry["id"]) == id:
			return entry
	return {}


static func index_of(id: String) -> int:
	for i in LADDER.size():
		if String(LADDER[i]["id"]) == id:
			return i
	return -1


static func price_of(id: String) -> int:
	var entry := by_id(id)
	return int(entry.get("price", 0)) if not entry.is_empty() else -1


static func unlock_of(id: String) -> int:
	var entry := by_id(id)
	return int(entry.get("unlock", 0)) if not entry.is_empty() else -1


static func auto_kind(body: String) -> String:
	## Ladder body name -> auto.gd builder kind. The ladder speaks
	## showroom (rickshaw/hatch); the street fleet speaks chassis
	## (auto/car). Unknown bodies map to "" so callers can gate.
	match body:
		"rickshaw":
			return "auto"
		"hatch":
			return "car"
		"scooter", "van", "tempo", "truck", "tanker":
			return body
		_:
			return ""


func buy_gate(id: String, cash: int, missions_done: int) -> String:
	## "" = buyable. Reasons: "unknown" id, "locked" (unlock gate),
	## "broke" (wallet short), "owned" (already in the garage).
	var entry := by_id(id)
	if entry.is_empty():
		return "unknown"
	if missions_done < int(entry["unlock"]):
		return "locked"
	if owned.has(id):
		return "owned"
	if cash < int(entry["price"]):
		return "broke"
	return ""


func purchase(id: String) -> bool:
	## Records a completed sale (caller has already deducted the cash)
	## and makes the new ride the selected one. Unknown id -> no-op.
	if by_id(id).is_empty():
		return false
	owned[id] = true
	selected = id
	return true


func select(id: String) -> bool:
	## The active ride must be one you own; starter rides can be
	## re-selected any time.
	if not owned.has(id):
		return false
	selected = id
	return true


func snapshot() -> Dictionary:
	## Save piggyback: owned ids + the selected ride, plain data only.
	var ids: Array[String] = []
	for id in owned:
		ids.append(String(id))
	return {"owned": ids, "selected": selected}


func restore(saved: Dictionary) -> void:
	## Load path: accepts a snapshot() dictionary; junk is ignored.
	owned = {}
	selected = String(saved.get("selected", ""))
	for id in saved.get("owned", []):
		if by_id(String(id)).is_empty():
			continue
		owned[String(id)] = true
	if selected != "" and not owned.has(selected):
		selected = ""
