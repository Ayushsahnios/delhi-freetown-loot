extends RefCounted
## Legend finale arcs (issue #264): each legend's closing chapter — a
## three-mission chain that pays off their identity, offered only to
## that legend once the shared #96 finale has closed and the street
## résumé hits the missions-completed threshold ("need_done": total
## completions). The last mission of every chain carries a "payoff"
## key the mission system converts into a persistent unlock:
##   Sardar Ji — Dhaba Empire: the stand grows a permanent named
##     eatery sign (world prop, spawns with the payoff and survives
##     saves).
##   Riya — Franchise Rider: courier streak cap doubles (6 -> 12) and
##     the branded franchise jacket unlocks at the tailor, free.
##   Monty — Dilli ka Don: the beat cops' respect — every heat rise is
##     discounted one star — plus the gold chain look at the tailor.
## All dialogue text original; every position sits on walkable street
## spots already used by the mission table.

const LEGEND_FINALE_ARCS := [
	# ---------------- Sardar Ji — Dhaba Empire ----------------
	{
		"id": "empire_1_licence",
		"title": "Dhaba Empire I — The Licence",
		"requires": "sardarji",
		"after": ["finale_monty"],
		"need_done": 8,
		"marker_color": Color(1.0, 0.56, 0.12),
		"lines": [
			{
				"speaker": "Chotu, stand helper",
				"text": "Sardar Ji, the committee liked the protest so much they asked the question every cook dreams of: why is the stand still a stand? A dhaba licence needs one form, one sponsor, one chai break.",
				"color": Color(0.55, 0.85, 0.95),
			},
			{
				"speaker": "Chotu, stand helper",
				"text": "Grab the form from the CP kiosk, get the market committee's stamp in Purani Dilli, and bring it back before the clerk's chai goes cold. Rs 900 from the jar that keeps growing.",
				"color": Color(0.55, 0.85, 0.95),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(6.0, 0.0, 64.0),
		"objectives": [
			{
				"kind": "reach",
				"label": "Lift the licence form — kiosk at the CP inner circle",
				"pos": Vector3(0.0, 0.0, 6.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Committee stamp — the market office in Purani Dilli",
				"pos": Vector3(-84.0, 0.0, 94.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "File it back at Sardar Ji's stand",
				"pos": Vector3(6.0, 0.0, 64.0),
				"radius": 8.0,
			},
		],
		"time": 0.0,
		"reward": 900,
		"outro": [
			{
				"speaker": "Sardar Ji",
				"text": "Stamped, filed, and the clerk smiled! Beta, a dhaba is not a stand with a roof — it is a tandoor, a name board, and a queue. The tandoor comes next.",
				"color": Color(1.0, 0.56, 0.12),
			},
		],
	},
	{
		"id": "empire_2_tandoor",
		"title": "Dhaba Empire II — The Tandoor",
		"requires": "sardarji",
		"after": ["empire_1_licence"],
		"marker_color": Color(1.0, 0.56, 0.12),
		"lines": [
			{
				"speaker": "Chotu, stand helper",
				"text": "The metalwallah in Purani Dilli finished the tandoor drum — clay lining, brass rim, still warm from the kiln. He wants it gone before his lane fills up for the evening bazaar.",
				"color": Color(0.55, 0.85, 0.95),
			},
			{
				"speaker": "Chotu, stand helper",
				"text": "Drum first, then a bundle of skewers from the halwai lane, both to the stand — the bazaar chowki closes its eyes for ninety seconds, not one more. Rs 1100.",
				"color": Color(0.55, 0.85, 0.95),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(6.0, 0.0, 64.0),
		"objectives": [
			{
				"kind": "pickup",
				"label": "The tandoor drum — metalwallah, Purani Dilli",
				"pos": Vector3(-92.0, 0.0, 104.0),
				"radius": 8.0,
			},
			{
				"kind": "pickup",
				"label": "Skewer bundle — the halwai lane",
				"pos": Vector3(-74.0, 0.0, 68.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Set the tandoor at Sardar Ji's stand",
				"pos": Vector3(6.0, 0.0, 64.0),
				"radius": 8.0,
			},
		],
		"time": 95.0,
		"unit": "pieces",
		"fail": "the bazaar chowki reopened the lane",
		"reward": 1100,
		"outro": [
			{
				"speaker": "Sardar Ji",
				"text": "The drum sits, the skewers shine, and the whole street can smell tomorrow's menu! One thing left, beta — a dhaba without a name is just smoke. The board is next.",
				"color": Color(1.0, 0.56, 0.12),
			},
		],
	},
	{
		"id": "empire_3_name",
		"title": "Dhaba Empire III — The Name",
		"requires": "sardarji",
		"after": ["empire_2_tandoor"],
		"marker_color": Color(1.0, 0.56, 0.12),
		"lines": [
			{
				"speaker": "Chotu, stand helper",
				"text": "The sign painter needs three things and he needs them in one round: marigold string from the flower cart, a tin of saffron paint from the spice shop, and the painter himself — he refuses to leave his chai spot.",
				"color": Color(0.55, 0.85, 0.95),
			},
			{
				"speaker": "Chotu, stand helper",
				"text": "Everything back to the stand, and the name goes up before the evening crowd. Sardar Ji already knows the words — he just wants you standing there when they light up. Rs 1500.",
				"color": Color(0.55, 0.85, 0.95),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(6.0, 0.0, 64.0),
		"objectives": [
			{
				"kind": "pickup",
				"label": "Marigold string — flower cart, Purani Dilli",
				"pos": Vector3(-100.0, 0.0, 96.0),
				"radius": 8.0,
			},
			{
				"kind": "pickup",
				"label": "Saffron paint tin — the spice shop",
				"pos": Vector3(-86.0, 0.0, 98.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Collect the painter — CP green",
				"pos": Vector3(-17.0, 0.0, -17.0),
				"radius": 10.0,
			},
			{
				"kind": "reach",
				"label": "Stand with Sardar Ji for the unveiling",
				"pos": Vector3(6.0, 0.0, 64.0),
				"radius": 8.0,
			},
		],
		"time": 0.0,
		"reward": 1500,
		"payoff": {
			"kind": "dhaba_empire",
			"label": "DHABA EMPIRE — the stand is a named eatery now",
		},
		"outro": [
			{
				"speaker": "Sardar Ji",
				"text": "Look at it, beta — SARDAR JI DA DHABA, painted in saffron, lit against the evening! From one pawned battery to a name the whole ring knows. Your chai is free forever.",
				"color": Color(1.0, 0.56, 0.12),
			},
		],
	},
	# ---------------- Riya — Franchise Rider ----------------
	{
		"id": "franchise_1_pitch",
		"title": "Franchise I — The Pitch",
		"requires": "riya",
		"after": ["finale_monty"],
		"need_done": 8,
		"marker_color": Color(0.84, 0.20, 0.42),
		"lines": [
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Riya beti, the ledger win travelled! Three shopkeepers want their OWN delivery counter under our name — a franchise! But franchise means folders: the pitch, the rates, the promise.",
				"color": Color(0.70, 0.90, 0.60),
			},
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Three folders, three corners: the gate guard, the CP kiosk, the spice shop. The shopkeepers shut their shutters for lunch — two minutes flat. Rs 1000 says the fastest lanes in the city still holds.",
				"color": Color(0.70, 0.90, 0.60),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(144.0, 0.0, -126.0),
		"objectives": [
			{
				"kind": "deliver",
				"label": "Folder 1 — the gate guard at India Gate",
				"pos": Vector3(-2.0, 0.0, -84.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Folder 2 — the kiosk at the CP inner circle",
				"pos": Vector3(0.0, 0.0, 6.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Folder 3 — the spice shop in Purani Dilli",
				"pos": Vector3(-86.0, 0.0, 98.0),
				"radius": 8.0,
			},
		],
		"time": 115.0,
		"unit": "folders",
		"reward": 1000,
		"outro": [
			{
				"speaker": "Riya",
				"text": "Three yeses before the shutters even creaked! Gupta Ji is already talking about a trial fleet — branded crates, branded everything. Ride the next one with me?",
				"color": Color(0.84, 0.20, 0.42),
			},
		],
	},
	{
		"id": "franchise_2_fleet",
		"title": "Franchise II — The Trial Fleet",
		"requires": "riya",
		"after": ["franchise_1_pitch"],
		"marker_color": Color(0.84, 0.20, 0.42),
		"lines": [
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "The trial crates are wrapped at three corners — marigold lane, the CP green, the park gate — and the depot floor must be stacked before the inspectors walk it.",
				"color": Color(0.70, 0.90, 0.60),
			},
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Three pickups, one drop, one clock. This is the run that decides whether the name goes on the jackets. Rs 1200 — and the throttle is all yours.",
				"color": Color(0.70, 0.90, 0.60),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(144.0, 0.0, -126.0),
		"objectives": [
			{
				"kind": "pickup",
				"label": "Crate 1 — marigold lane, Purani Dilli",
				"pos": Vector3(-100.0, 0.0, 96.0),
				"radius": 8.0,
			},
			{
				"kind": "pickup",
				"label": "Crate 2 — the CP green",
				"pos": Vector3(-17.0, 0.0, -17.0),
				"radius": 10.0,
			},
			{
				"kind": "pickup",
				"label": "Crate 3 — the park gate",
				"pos": Vector3(138.0, 0.0, -126.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Stack the crates at the depot",
				"pos": Vector3(144.0, 0.0, -126.0),
				"radius": 10.0,
			},
		],
		"time": 150.0,
		"unit": "crates",
		"fail": "the inspectors walked an empty floor",
		"reward": 1200,
		"outro": [
			{
				"speaker": "Riya",
				"text": "Stacked, counted, inspected — passed! Gupta Ji has the signing sheet ready and a jacket with my own logo on the back. One more run to make it official.",
				"color": Color(0.84, 0.20, 0.42),
			},
		],
	},
	{
		"id": "franchise_3_signing",
		"title": "Franchise III — The Signing",
		"requires": "riya",
		"after": ["franchise_2_fleet"],
		"marker_color": Color(0.84, 0.20, 0.42),
		"lines": [
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Beti, today the depot stops being a depot on paper — counters across the city, our name over the door, your name on the rider roll. The pen is at the kiosk and the witness is the chai uncle by CP.",
				"color": Color(0.70, 0.90, 0.60),
			},
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Pen, witness, then the depot board — and the franchise jacket is yours the moment the ink dries. Rs 1600 and a name that rides ahead of you.",
				"color": Color(0.70, 0.90, 0.60),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(144.0, 0.0, -126.0),
		"objectives": [
			{
				"kind": "reach",
				"label": "Collect the pen — kiosk at the CP inner circle",
				"pos": Vector3(0.0, 0.0, 6.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Bring the witness — chai uncle by CP",
				"pos": Vector3(6.0, 0.0, -16.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Sign at the depot board",
				"pos": Vector3(144.0, 0.0, -126.0),
				"radius": 10.0,
			},
		],
		"time": 0.0,
		"reward": 1600,
		"payoff": {
			"kind": "franchise",
			"label": "FRANCHISE RIDER — streak caps doubled, branded jacket unlocked",
		},
		"outro": [
			{
				"speaker": "Riya",
				"text": "Signed! Double streak caps for every franchise rider and a jacket with the logo — I wore it home the long way, past every lane I ever raced. From instalments to a franchise, and you in every chapter of it.",
				"color": Color(0.84, 0.20, 0.42),
			},
		],
	},
	# ---------------- Monty — Dilli ka Don ----------------
	{
		"id": "don_1_round",
		"title": "Dilli ka Don I — The Round",
		"requires": "monty",
		"after": ["finale_monty"],
		"need_done": 8,
		"marker_color": Color(0.54, 0.17, 0.89),
		"lines": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Partner, honest rubber stamps pay honest chai money — but respect? Respect still walks the streets, and the Don's respect round has three stops and no shortcuts.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Mithai for the fort-gate chowkidar, a blade for the halwai's grinder, and the photographer's prints back at India Gate. Small things — the Don never forgets small things. Rs 950.",
				"color": Color(0.54, 0.17, 0.89),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(-40.0, 0.0, -40.0),
		"objectives": [
			{
				"kind": "deliver",
				"label": "Mithai box — the fort-gate chowkidar",
				"pos": Vector3(-88.0, 0.0, 100.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Grinder blade — the halwai lane",
				"pos": Vector3(-74.0, 0.0, 68.0),
				"radius": 8.0,
			},
			{
				"kind": "reach",
				"label": "Return the prints — the photographer at India Gate",
				"pos": Vector3(2.0, 0.0, -86.0),
				"radius": 8.0,
			},
		],
		"time": 0.0,
		"reward": 950,
		"outro": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Three stops, three smiles, zero police — THAT is a Don's day. But a young pocketmaar in my old lane is spending respect he never earned. The Don folds that kind himself.",
				"color": Color(0.54, 0.17, 0.89),
			},
		],
	},
	{
		"id": "don_2_fold",
		"title": "Dilli ka Don II — The Fold",
		"requires": "monty",
		"after": ["don_1_round"],
		"marker_color": Color(0.54, 0.17, 0.89),
		"lines": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "There he is — green cap, yellow bag, grinning like Diwali came early. He lifted a pension envelope off the spice shop's grandmother and thinks the bazaar is his gully.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "The Don's fold is simple: catch him, keep the envelope safe, and let him RUN to the grandmother with the apology before he stops breathing. Rs 1100 — and no cops, ever.",
				"color": Color(0.54, 0.17, 0.89),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(-74.0, 0.0, 44.0),
		"objectives": [
			{
				"kind": "chase",
				"label": "Catch the pocketmaar",
				"pos": Vector3(-86.0, 0.0, 52.0),
				"radius": 3.0,
				"time": 90.0,
			},
		],
		"chase": {
			"path": [
				Vector3(-86.0, 0.0, 52.0),
				Vector3(-40.0, 0.0, 52.0),
				Vector3(-40.0, 0.0, 98.0),
				Vector3(-86.0, 0.0, 98.0),
			],
			"speed": 9.0,
		},
		"fail": "the pocketmaar melted into the bazaar",
		"reward": 1100,
		"outro": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Envelope returned, apology delivered, and the boy now runs errands for the grandmother free of charge. A fold done right stays folded. One stop left, partner — the word itself.",
				"color": Color(0.54, 0.17, 0.89),
			},
		],
	},
	{
		"id": "don_3_word",
		"title": "Dilli ka Don III — The Word",
		"requires": "monty",
		"after": ["don_2_fold"],
		"marker_color": Color(0.54, 0.17, 0.89),
		"lines": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "The word goes out at the CP ring tonight: the Don's name now opens doors the legal way. Every beat constable from the fort to the gate has been told whose crew walks these streets.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Walk the ring with me while the word lands — and keep the gold close, because the Don's chain is the receipt. Rs 2000, partner. Dilli ka Don, indeed.",
				"color": Color(0.54, 0.17, 0.89),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(-40.0, 0.0, -40.0),
		"objectives": [
			{
				"kind": "reach",
				"label": "Walk the ring — south-west corner, CP",
				"pos": Vector3(-40.0, 0.0, 6.0),
				"radius": 8.0,
			},
			{
				"kind": "reach",
				"label": "Walk the ring — north-east corner, CP",
				"pos": Vector3(6.0, 0.0, -40.0),
				"radius": 8.0,
			},
			{
				"kind": "reach",
				"label": "Stand on the marker with the Don",
				"pos": Vector3(-40.0, 0.0, -40.0),
				"radius": 8.0,
			},
		],
		"time": 0.0,
		"reward": 2000,
		"payoff": {
			"kind": "respect",
			"label": "DON RESPECT — one-star heat discount, gold chain unlocked",
		},
		"outro": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Feel that, partner? Heat that starts a star lower and a chain that says the streets settled their account. From laminate hustles to a name the constables salute — the Don's last word, and it's a good one.",
				"color": Color(0.54, 0.17, 0.89),
			},
		],
	},
]
