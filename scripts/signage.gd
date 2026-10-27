extends RefCounted
## Bilingual signage system (issue #131): readable Devanagari + English
## painted boards across the bazaar, Purani Dilli, the thana and the
## landmarks. Art-directed from the owner's reference capture: the
## strongest single "India" signifier is the bilingual board — yellow
## station boards with black lettering on twin posts, deep-colored shop
## boards over the awnings, blue direction plates with white text.
## Devanagari renders through Noto Sans Devanagari (SIL OFL, bundled
## under assets/fonts with its license); every other part is procedural
## MeshTools geometry. Weathering: dusty ink modulate, sun-fade strip
## and grime band baked into the board meshes. Boards mount above head
## height on walls or on slim posts clear of paths.

const MeshTools := preload("res://scripts/meshtools.gd")
const HINDI := preload("res://assets/fonts/NotoSansDevanagari-Bold.ttf")

const STATION_YELLOW := Color(0.92, 0.78, 0.16)
const DIR_BLUE := Color(0.10, 0.24, 0.52)
const NAVY := Color(0.10, 0.16, 0.35)
const RED := Color(0.72, 0.16, 0.12)
const GREEN := Color(0.13, 0.42, 0.22)
const CREAM := Color(0.93, 0.89, 0.78)
const FRAME := Color(0.16, 0.14, 0.12)
const POST := Color(0.42, 0.42, 0.44)
const WHITE_INK := Color(0.97, 0.96, 0.92)
const BLACK_INK := Color(0.12, 0.10, 0.08)

## Wall-mounted boards: center, yaw (0 faces +Z), width, height, ink.
const BOARDS := [
	# Chandni Chowk gate marquee, both faces of the gate beam.
	{"p": Vector3(-57.0, 10.15, 58.57), "yaw": PI, "w": 3.6, "h": 1.15,
			"bg": STATION_YELLOW, "ink": BLACK_INK,
			"hi": "चांदनी चौक", "en": "CHANDNI CHOWK", "big": true},
	{"p": Vector3(-57.0, 10.15, 61.43), "yaw": 0.0, "w": 3.6, "h": 1.15,
			"bg": STATION_YELLOW, "ink": BLACK_INK,
			"hi": "चांदनी चौक", "en": "CHANDNI CHOWK", "big": true},
	# Bazaar shop row 1 (west building, faces the market lane +X).
	{"p": Vector3(-68.93, 4.30, 63.0), "yaw": PI / 2.0, "w": 2.1, "h": 0.72,
			"bg": RED, "ink": WHITE_INK, "hi": "चाय की दुकान", "en": "CHAI SHOP"},
	{"p": Vector3(-68.93, 4.30, 69.0), "yaw": PI / 2.0, "w": 2.1, "h": 0.72,
			"bg": GREEN, "ink": WHITE_INK, "hi": "मिठाई भंडार", "en": "SWEET SHOP"},
	{"p": Vector3(-68.93, 4.30, 74.0), "yaw": PI / 2.0, "w": 2.1, "h": 0.72,
			"bg": CREAM, "ink": BLACK_INK, "hi": "साड़ी घर", "en": "SAREE HOUSE"},
	# Bazaar shop row 2 (south building, faces the lane +X).
	{"p": Vector3(-63.93, 3.90, 88.2), "yaw": PI / 2.0, "w": 1.9, "h": 0.66,
			"bg": NAVY, "ink": WHITE_INK, "hi": "किराना स्टोर", "en": "KIRANA STORE"},
	{"p": Vector3(-63.93, 3.90, 91.6), "yaw": PI / 2.0, "w": 1.9, "h": 0.66,
			"bg": RED, "ink": WHITE_INK, "hi": "पान शॉप", "en": "PAAN SHOP"},
	# Purani Dilli shop strip (street face, -Z).
	{"p": Vector3(-117.0, 4.50, 58.43), "yaw": PI, "w": 2.3, "h": 0.75,
			"bg": STATION_YELLOW, "ink": BLACK_INK,
			"hi": "पुरानी दिल्ली", "en": "PURANI DILLI"},
	{"p": Vector3(-109.0, 4.50, 58.43), "yaw": PI, "w": 2.1, "h": 0.72,
			"bg": GREEN, "ink": WHITE_INK, "hi": "मंदिर की गली", "en": "TEMPLE LANE"},
	{"p": Vector3(-101.0, 4.50, 58.43), "yaw": PI, "w": 2.1, "h": 0.72,
			"bg": CREAM, "ink": BLACK_INK, "hi": "ढाबा", "en": "DHABA"},
	# Thana hall band (entrance face, +Z).
	{"p": Vector3(75.0, 7.25, -19.43), "yaw": 0.0, "w": 2.6, "h": 0.80,
			"bg": NAVY, "ink": WHITE_INK, "hi": "पुलिस थाना", "en": "POLICE STATION"},
]

## Freestanding yellow station board on twin posts (India Gate lawn
## corner) + blue direction plates on single posts.
const STATION_BOARD := {"p": Vector3(-25.0, 2.55, -122.0), "yaw": PI,
	"w": 3.2, "h": 0.95, "hi": "नई दिल्ली", "en": "NEW DELHI"}
const DIRECTION_BOARDS := [
	{"p": Vector3(-2.4, 2.60, -13.0), "yaw": PI / 2.0,
			"hi": "इंडिया गेट", "en": "INDIA GATE"},
	{"p": Vector3(-66.0, 2.60, 58.9), "yaw": PI,
			"hi": "रेलवे स्टेशन", "en": "RAILWAY STATION"},
]


static func build(_world: float, _pitch: float, _road_w: float) -> Node3D:
	## One root: merged board/post/frame mesh + one Devanagari and one
	## English Label3D per board. Fixed specs — identical every launch.
	var b := MeshTools.new()
	var root := Node3D.new()
	root.name = "Signage"
	for s: Dictionary in BOARDS:
		_board(b, root, s, s["bg"] as Color, false)
	for s: Dictionary in DIRECTION_BOARDS:
		_board(b, root, s, DIR_BLUE, true)
	var sb: Dictionary = STATION_BOARD
	var p: Vector3 = sb["p"]
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, sb["yaw"])
	var across := fwd.cross(Vector3.UP)
	for off in [-1.25, 1.25]:
		var post := CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.06
		post.height = 2.5
		b.add_mesh(post, Transform3D(Basis(),
				p + across * off + Vector3(0, -1.3, 0)), POST)
	_board(b, root, {"p": p, "yaw": sb["yaw"], "w": sb["w"], "h": sb["h"],
			"bg": STATION_YELLOW, "ink": BLACK_INK, "hi": sb["hi"],
			"en": sb["en"], "big": true}, STATION_YELLOW, false)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


static func _board(b: MeshTools, root: Node3D, s: Dictionary,
		bg: Color, dir_style: bool) -> void:
	## Frame + panel + sun-fade strip + grime band (+ chevrons on the
	## blue direction plates), then the two Label3D type lines.
	var p: Vector3 = s["p"]
	var yaw: float = s["yaw"]
	var w := float(s.get("w", 1.7))
	var h := float(s.get("h", 0.62))
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var across := fwd.cross(Vector3.UP)
	var ink: Color = s.get("ink", WHITE_INK)
	# Panel is wide along `across`, thin along `fwd`.
	b.add_box(_panel_size(across, fwd, w + 0.14, h + 0.14, 0.08), p, FRAME)
	b.add_box(_panel_size(across, fwd, w, h, 0.05), p + fwd * 0.02, bg)
	b.add_box(_panel_size(across, fwd, w, 0.06, 0.012),
			p + fwd * 0.048 + Vector3(0, h * 0.42, 0), bg.lightened(0.18))
	b.add_box(_panel_size(across, fwd, w, 0.09, 0.012),
			p + fwd * 0.048 + Vector3(0, -h * 0.42, 0), bg.darkened(0.35))
	if dir_style:
		for ang in [-0.7, 0.7]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.34, 0.06, 0.03)
			b.add_mesh(bar, Transform3D(
					Basis(fwd, ang) * Basis(Vector3.UP, yaw),
					p + fwd * 0.055 + Vector3(0, h * 0.20, 0)), WHITE_INK)
		# Single slim post under the plate.
		var post := CylinderMesh.new()
		post.top_radius = 0.045
		post.bottom_radius = 0.055
		post.height = 2.2
		b.add_mesh(post, Transform3D(Basis(),
				p + Vector3(0, -1.35, 0)), POST)
	# Type: Devanagari line over the English line, dusty ink.
	var big: bool = s.get("big", false)
	var hi := Label3D.new()
	hi.text = s["hi"]
	hi.font = HINDI
	hi.font_size = 84 if big else 56
	hi.modulate = ink.darkened(0.06)
	hi.pixel_size = 0.005
	hi.rotation = Vector3(0, yaw, 0)
	hi.position = p + fwd * 0.06 + Vector3(0, h * 0.14, 0)
	root.add_child(hi)
	var en := Label3D.new()
	en.text = s["en"]
	en.font_size = 46 if big else 30
	en.modulate = ink.darkened(0.06)
	en.pixel_size = 0.005
	en.rotation = Vector3(0, yaw, 0)
	en.position = p + fwd * 0.06 + Vector3(0, -h * 0.24, 0)
	root.add_child(en)


static func _panel_size(across: Vector3, fwd: Vector3, w: float,
		h: float, thick: float) -> Vector3:
	## Board extents: width along `across`, height up, thickness `fwd`.
	return Vector3(absf(across.x) * w + absf(fwd.x) * thick, h,
			absf(across.z) * w + absf(fwd.z) * thick)
