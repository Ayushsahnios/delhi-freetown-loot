extends Node
## Garage ladder gate (issue #347) — headless check that the published
## Kaali-Peeli ladder stays internally consistent and that the owned-
## vehicle state behaves: unique ids, strictly ascending prices, non-
## decreasing unlock gates, every body/paint/tune inside the ranges the
## procedural vehicle builders and the garage pad UI (next slice) rely
## on, buy-gate verdicts (locked / broke / owned / unknown) and the
## save round-trip. Exits 0 when every expectation holds, 2 otherwise.
## Usage:
##   godot --headless --path . res://scenes/garage_check.tscn

const Garage := preload("res://scripts/garage.gd")
const AutoScript := preload("res://scripts/auto.gd")

const BODIES := ["scooter", "rickshaw", "hatch", "van", "tempo", "truck", "tanker"]

var _problems: Array[String] = []


func _ready() -> void:
	_ladder_shape()
	_ladder_values()
	_lookup_helpers()
	_buy_gate_verdicts()
	_purchase_and_select()
	_auto_kind_mapping()
	_buy_spawn_save_reload()
	_save_round_trip()

	if _problems.is_empty():
		print("garage_check: PASS %d rungs, gates + rollout + save round-trip green" \
				% Garage.rung_count())
	else:
		for problem in _problems:
			print("garage_check: FAILED %s" % problem)
	get_tree().quit(0 if _problems.is_empty() else 2)


func _fail(problem: String) -> void:
	_problems.append(problem)


func _ladder_shape() -> void:
	if Garage.rung_count() != 15:
		_fail("ladder must have 15 rungs, has %d" % Garage.rung_count())
	var seen := {}
	for i in Garage.rung_count():
		var entry: Dictionary = Garage.rung(i)
		var id := String(entry.get("id", ""))
		if id == "" or id != id.to_snake_case():
			_fail("rung %d id '%s' is not snake_case" % [i, id])
		if seen.has(id):
			_fail("duplicate id '%s' at rung %d" % [id, i])
		seen[id] = true
		if String(entry.get("name", "")) == "":
			_fail("rung %d ('%s') has no display name" % [i, id])
		if String(entry.get("blurb", "")) == "":
			_fail("rung %d ('%s') has no blurb" % [i, id])


func _ladder_values() -> void:
	var last_price := -1
	var last_unlock := -1
	for i in Garage.rung_count():
		var entry: Dictionary = Garage.rung(i)
		var price := int(entry["price"])
		var unlock := int(entry["unlock"])
		if price <= 0:
			_fail("rung %d price %d not positive" % [i, price])
		if price <= last_price:
			_fail("price not strictly ascending at rung %d (%d after %d)" \
					% [i, price, last_price])
		if unlock < 0 or unlock > 20:
			_fail("rung %d unlock %d outside 0..20" % [i, unlock])
		if unlock < last_unlock:
			_fail("unlock gate drops at rung %d (%d after %d)" \
					% [i, unlock, last_unlock])
		last_price = price
		last_unlock = unlock
		if not BODIES.has(String(entry["body"])):
			_fail("rung %d body '%s' not a builder" % [i, String(entry["body"])])
		var paint := int(entry["paint"])
		if paint < 0 or paint > 5:
			_fail("rung %d paint %d outside PAINTS 0..5" % [i, paint])
		for key in ["top", "pickup"]:
			var tune := float(entry[key])
			if tune < 0.8 or tune > 1.4:
				_fail("rung %d %s %.2f outside 0.8..1.4" % [i, key, tune])


func _lookup_helpers() -> void:
	if Garage.by_id("no_such_ride") != {}:
		_fail("by_id on unknown id must be empty")
	if Garage.price_of("no_such_ride") != -1:
		_fail("price_of on unknown id must be -1")
	if Garage.unlock_of("no_such_ride") != -1:
		_fail("unlock_of on unknown id must be -1")
	if Garage.index_of("phatphati") != 0:
		_fail("index_of('phatphati') must be 0")
	if Garage.price_of("badshah_truck") <= Garage.price_of("phatphati"):
		_fail("top rung must outprice the starter")


func _buy_gate_verdicts() -> void:
	var garage := Garage.new()
	# Starter rung: affordable from rupee zero, no missions needed.
	if garage.buy_gate("phatphati", 0, 0) != "broke":
		_fail("starter at cash 0 must read 'broke'")
	if garage.buy_gate("phatphati", 800, 0) != "":
		_fail("starter at cash 800 must be buyable")
	# Unlock gate blocks even a full wallet.
	if garage.buy_gate("badshah_truck", 100000, 0) != "locked":
		_fail("locked rung must read 'locked'")
	if garage.buy_gate("badshah_truck", 100000, 12) != "":
		_fail("unlocked rung with cash must be buyable")
	# Unknown id.
	if garage.buy_gate("no_such_ride", 100000, 99) != "unknown":
		_fail("unknown id must read 'unknown'")


func _purchase_and_select() -> void:
	var garage := Garage.new()
	if garage.purchase("no_such_ride"):
		_fail("purchase of unknown id must fail")
	if !garage.purchase("sawari_rick"):
		_fail("purchase of a valid id must succeed")
	if garage.selected != "sawari_rick":
		_fail("purchase must auto-select the new ride")
	if garage.buy_gate("sawari_rick", 100000, 99) != "owned":
		_fail("owned rung must read 'owned'")
	if !garage.purchase("phatphati"):
		_fail("second purchase must succeed")
	if garage.select("phatphati") != true or garage.selected != "phatphati":
		_fail("select of an owned ride must switch")
	if garage.select("matka_tanker"):
		_fail("select of an unowned ride must fail")


func _auto_kind_mapping() -> void:
	## Slice 2: every ladder body must resolve onto a real auto.gd
	## KINDS spec — the pad rolls rungs out through that builder table.
	for i in Garage.rung_count():
		var entry: Dictionary = Garage.rung(i)
		var kind := Garage.auto_kind(String(entry["body"]))
		if not AutoScript.KINDS.has(kind):
			_fail("rung %d body '%s' has no auto.gd kind" % [i, String(entry["body"])])
	if Garage.auto_kind("no_such_ride") != "":
		_fail("unknown body must map to an empty kind")


func _buy_spawn_save_reload() -> void:
	## Slice-2 contract the pad + main save fold rely on: gate passes
	## -> sale recorded -> the rung rolls out through the street-fleet
	## builder (paint pin, kind map, tune multipliers) -> snapshot ->
	## restore keeps the garage.
	var garage := Garage.new()
	if garage.buy_gate("dhaak_kaali_peeli", 7000, 4) != "":
		_fail("hatch rung at cash 7000 / 4 missions must be buyable")
	if not garage.purchase("dhaak_kaali_peeli"):
		_fail("purchase of the hatch rung must succeed")
	var rung: Dictionary = Garage.by_id("dhaak_kaali_peeli")
	var ride := AutoScript.new()
	ride.set_paint(int(rung["paint"]))
	ride.setup(Vector3(6.0, 1.0, 58.0), 0.0,
			Garage.auto_kind(String(rung["body"])))
	ride.tune(float(rung["top"]), float(rung["pickup"]))
	if ride.kind != "car":
		_fail("hatch rung must roll out on the 'car' builder, got '%s'" % ride.kind)
	ride.free()
	var reloaded := Garage.new()
	reloaded.restore(garage.snapshot())
	if not reloaded.owned.has("dhaak_kaali_peeli") \
				or reloaded.selected != "dhaak_kaali_peeli":
		_fail("restore must keep the bought ride owned and selected")
	if not reloaded.select("dhaak_kaali_peeli"):
		_fail("re-select of the restored ride must succeed")


func _save_round_trip() -> void:
	var garage := Garage.new()
	garage.purchase("phatphati")
	garage.purchase("duggdugg")
	garage.purchase("mela_van")
	garage.select("duggdugg")
	var snap := garage.snapshot()
	if String(snap["selected"]) != "duggdugg":
		_fail("snapshot must carry the selected ride")
	var loaded := Garage.new()
	loaded.restore(snap)
	if loaded.owned.size() != 3 or !loaded.owned.has("mela_van"):
		_fail("restore must rebuild the owned set")
	if loaded.selected != "duggdugg":
		_fail("restore must rebuild the selection")
	# Junk tolerance: unknown ids dropped, dangling selection cleared.
	var junk := Garage.new()
	junk.restore({"owned": ["phatphati", "no_such_ride"],
			"selected": "no_such_ride"})
	if junk.owned.size() != 1 or junk.selected != "":
		_fail("restore must drop junk and clear a dangling selection")
