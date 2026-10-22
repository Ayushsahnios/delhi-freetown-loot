extends RefCounted
## Kahani story arcs: one-shot intro chapters for each legend.
## Sardar Ji's auto stand troubles, Riya's courier debt, Monty's CP
## hustle — each a first playable chapter with an offer conversation
## and a closing outro beat. Consumed by the mission system; all
## dialogue text original, all positions on walkable streets.

const STORY_ARCS := [
	{
		"id": "kahani_sardarji",
		"title": "Sardar Ji — Chapter 1: The Stand",
		"marker_color": Color(1.0, 0.55, 0.20),
		"lines": [
			{
				"speaker": "Chotu, stand helper",
				"text": "Bad news, bhai sahab — the board pasted a seal notice on Sardar Ji's auto stand, and his spare battery is still pawned with the lender by the Purani Dilli fort gate against last month's repair loan.",
				"color": Color(0.55, 0.85, 0.95),
			},
			{
				"speaker": "Chotu, stand helper",
				"text": "No battery, no fares, no stand. Fetch it from the lender and fit it back at the stand before the sealing squad returns on its evening round.",
				"color": Color(0.55, 0.85, 0.95),
			},
			{
				"speaker": "Chotu, stand helper",
				"text": "Sardar Ji will owe you his week's supply of chai. Rs 700 from the fare jar — will you do it?",
				"color": Color(0.55, 0.85, 0.95),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(6.0, 0.0, 64.0),
		"objectives": [
			{
				"kind": "reach",
				"label": "Collect the pawned battery — lender at Purani Dilli",
				"pos": Vector3(-88.0, 0.0, 100.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Fit the battery at Sardar Ji's stand by CP",
				"pos": Vector3(6.0, 0.0, 64.0),
				"radius": 8.0,
			},
		],
		"time": 0.0,
		"reward": 700,
		"outro": [
			{
				"speaker": "Sardar Ji",
				"text": "Oye! The meter ticks and the stand lives another day. You move like the morning shuttle, beta — take this from the fare jar.",
				"color": Color(1.0, 0.56, 0.12),
			},
			{
				"speaker": "Sardar Ji",
				"text": "But listen carefully — the sealing squad keeps a list, and my stand is only the first name on it. Chapter two will need bigger friends than a spare battery.",
				"color": Color(1.0, 0.56, 0.12),
			},
		],
	},
	{
		"id": "kahani_riya",
		"title": "Riya — Chapter 1: The Instalment",
		"marker_color": Color(1.0, 0.45, 0.55),
		"lines": [
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "You know Riya? Fastest lanes in the city — and last week her batch went down near the fort. Four bent boxes, and a finance wallah chewing my ear about the instalment.",
				"color": Color(0.70, 0.90, 0.60),
			},
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Three replacement parcels, three corners of town: the guard at India Gate, the kiosk at the CP inner circle, the spice shop in Purani Dilli. Two minutes flat.",
				"color": Color(0.70, 0.90, 0.60),
			},
			{
				"speaker": "Gupta Ji, depot manager",
				"text": "Clear those drops and the ledger wipes this month's instalment off Riya's name. Rs 800 says you ride like her.",
				"color": Color(0.70, 0.90, 0.60),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(144.0, 0.0, -126.0),
		"objectives": [
			{
				"kind": "deliver",
				"label": "Parcel 1 — the guard at India Gate",
				"pos": Vector3(-2.0, 0.0, -84.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Parcel 2 — the kiosk at the CP inner circle",
				"pos": Vector3(0.0, 0.0, 6.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Parcel 3 — the spice shop in Purani Dilli",
				"pos": Vector3(-86.0, 0.0, 98.0),
				"radius": 8.0,
			},
		],
		"time": 115.0,
		"unit": "parcels",
		"reward": 800,
		"outro": [
			{
				"speaker": "Riya",
				"text": "Gupta Ji just called — instalment cleared! The borrowed set of wheels is safe for another month because of you.",
				"color": Color(0.84, 0.20, 0.42),
			},
			{
				"speaker": "Riya",
				"text": "That last stretch into Purani Dilli was pure throttle. Next time I'm going after the depot ledger itself — that finance wallah has been skimming for months. Ride with me then?",
				"color": Color(0.84, 0.20, 0.42),
			},
		],
	},
	{
		"id": "kahani_monty",
		"title": "Monty — Chapter 1: The Passes",
		"marker_color": Color(0.70, 0.45, 1.0),
		"lines": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Partner! Golden opportunity — fifty VIP darshan passes for a celebrity gate appearance. Printed, laminated, and one hundred percent unofficial.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "One problem: the stack is still with the printer in Purani Dilli, my flyer crowd waits on the CP ring, and the star buyer collects at India Gate before his bus leaves.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Ninety seconds, three stops, and the Don's cut is Rs 900. You know I don't ask twice.",
				"color": Color(0.54, 0.17, 0.89),
				"choices": ["Take the job", "Not now"],
			},
		],
		"giver": Vector3(-40.0, 0.0, -40.0),
		"objectives": [
			{
				"kind": "deliver",
				"label": "Pick up the pass stack — printer in Purani Dilli",
				"pos": Vector3(-84.0, 0.0, 94.0),
				"radius": 8.0,
			},
			{
				"kind": "deliver",
				"label": "Drop the promo flyers at the CP ring",
				"pos": Vector3(-40.0, 0.0, -16.0),
				"radius": 8.0,
			},
			{
				"kind": "reach",
				"label": "Hand the passes to the buyer at India Gate",
				"pos": Vector3(2.0, 0.0, -86.0),
				"radius": 8.0,
			},
		],
		"time": 95.0,
		"unit": "flyers",
		"reward": 900,
		"outro": [
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "Passes delivered, buyer smiling, cash counted twice. Dilli ka Don always lands on his feet — usually on somebody else's.",
				"color": Color(0.54, 0.17, 0.89),
			},
			{
				"speaker": "Monty, Dilli ka Don",
				"text": "That buyer whispered about a bigger game running through Chandni Chowk. Chapter two will need a faster crew — stay reachable, partner.",
				"color": Color(0.54, 0.17, 0.89),
			},
		],
	},
]
