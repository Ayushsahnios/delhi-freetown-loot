extends CanvasLayer
## Full-screen busted/wasted parody cards (issue #349).
## Arrest -> "PAKDE GAYE" (caught) with a two-tone police-sting wail and
## red/blue edge bars; death -> "GAYA" with a desaturating grey wash and a
## low thud. Own words, own type treatment, zero third-party assets — both
## stings are synthesized into AudioStreamWAV buffers at _ready like the
## rest of the city audio. main.gd drives show/hide around its existing
## fade-to-black respawn beats, so the card sits on top of the fade
## (layer 25) but under the pause menu (layer 30).

const MIX_RATE := 22050
const CARD_TITLE_PT := 118
const CARD_SUB_PT := 17

var _root: Control
var _dim: ColorRect
var _desat: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _title: Label
var _sub: Label
var _sting_player: AudioStreamPlayer
var _thud_player: AudioStreamPlayer
var _pulse: Tween


func _ready() -> void:
	layer = 25
	_build()
	visible = false


func is_showing() -> bool:
	return visible


func show_busted(stars: int, fine: int) -> void:
	## PAKDE GAYE — arrest card. Mirrors the old centre-text beat's info
	## (stars, fine) in the card's own sub-line.
	_set_card_mode(true)
	_title.text = "PAKDE GAYE"
	var wallet := ("Rs %d fine" % fine) if fine > 0 else "pockets empty"
	_sub.text = "Caught at %d-star heat \u00b7 %s \u00b7 heat cleared\nReleased outside the police station" % [stars, wallet]
	_flash_in()
	if _sting_player != null:
		_sting_player.play()


func show_wasted() -> void:
	## GAYA — down-and-out card with a desaturating wash + thud.
	_set_card_mode(false)
	_title.text = "GAYA"
	_sub.text = "The street knocked you out.\nJob dropped \u00b7 cash safe \u00b7 waking at the nearest landmark"
	_flash_in()
	if _thud_player != null:
		_thud_player.play()


func hide_card() -> void:
	## Called by main.gd while the fade is fully black, so the card never
	## pops mid-frame over live gameplay.
	visible = false
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	if _sting_player != null:
		_sting_player.stop()
	if _thud_player != null:
		_thud_player.stop()


# ---------------------------------------------------------------- build

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.74)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# GAYA only: grey wash laid over the dim reads as the world draining
	# of colour; tweened up in _flash_in, never a post-process pass.
	_desat = ColorRect.new()
	_desat.color = Color(0.55, 0.56, 0.60, 0.0)
	_desat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_desat)

	# PAKDE GAYE only: thin police-light bars framing the card.
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.85, 0.08, 0.08, 0.0)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 16.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color(0.15, 0.30, 0.95, 0.0)
	_bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = -16.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bottom)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", CARD_TITLE_PT)
	_title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)

	_sub = Label.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.offset_top = 96.0
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", CARD_SUB_PT)
	_sub.add_theme_color_override("font_color", Color(0.93, 0.93, 0.86))
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sub)

	_sting_player = AudioStreamPlayer.new()
	_sting_player.stream = _make_sting()
	_sting_player.volume_db = -8.0
	add_child(_sting_player)
	_thud_player = AudioStreamPlayer.new()
	_thud_player.stream = _make_thud()
	_thud_player.volume_db = -6.0
	add_child(_thud_player)


func _set_card_mode(busted: bool) -> void:
	_bar_top.visible = busted
	_bar_bottom.visible = busted
	_desat.visible = not busted
	if busted:
		_bar_top.color.a = 0.0
		_bar_bottom.color.a = 0.0
	else:
		_desat.color.a = 0.0


func _flash_in() -> void:
	visible = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_title.modulate = Color(1, 1, 1, 0.0)
	_title.scale = Vector2(1.12, 1.12)
	_pulse = create_tween()
	_pulse.set_parallel(true)
	_pulse.tween_property(_title, "modulate:a", 1.0, 0.14)
	_pulse.tween_property(_title, "scale", Vector2.ONE, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _bar_top.visible and _bar_bottom.visible:
		_pulse.chain().tween_property(_bar_top, "color:a", 0.9, 0.12)
		_pulse.chain().tween_property(_bar_bottom, "color:a", 0.9, 0.12)
		# Slow reciprocal breathing — the bars never both sit at full.
		var breath := _pulse.chain()
		breath.tween_property(_bar_top, "color:a", 0.45, 0.5)
		breath.parallel().tween_property(_bar_bottom, "color:a", 1.0, 0.5)
	if _desat.visible:
		_pulse.chain().tween_property(_desat, "color:a", 0.42, 0.6)


# ---------------------------------------------------------------- stings

func _make_sting() -> AudioStreamWAV:
	## Two-tone police wail (~1.0 s): alternating 720/940 Hz voices with
	## a couple of harmonics, soft-clipped so it cuts through without
	## ever spiking painful. Synthesized once, like every audio.gd voice.
	var samples := int(MIX_RATE * 1.0)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t := float(i) / MIX_RATE
		var f := 940.0 if fmod(t, 0.24) < 0.12 else 720.0
		phase += TAU * f / MIX_RATE
		var env := 1.0
		if t < 0.02:
			env = t / 0.02
		elif t > 0.85:
			env = maxf(1.0 - (t - 0.85) / 0.15, 0.0)
		var s := sin(phase) + 0.35 * sin(2.0 * phase) + 0.15 * sin(3.0 * phase)
		s = tanh(1.6 * s) * 0.45 * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _make_thud() -> AudioStreamWAV:
	## Low body-hit thud (~0.45 s): a sine sweeping 130 -> 42 Hz with an
	## exponential decay — the same family as the speed-bump thunk, an
	## octave down and alone.
	var samples := int(MIX_RATE * 0.45)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in samples:
		var t := float(i) / MIX_RATE
		var f := lerpf(130.0, 42.0, clampf(t / 0.45, 0.0, 1.0))
		phase += TAU * f / MIX_RATE
		var env := exp(-6.0 * t)
		var s := tanh(1.3 * sin(phase)) * 0.7 * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
