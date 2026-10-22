extends Node
## Procedural city audio — horn + ambient street bed, zero asset files.
## All streams are synthesized into AudioStreamWAV buffers at setup().

const MIX_RATE := 22050
const AMBIENT_SECONDS := 6.0
const RAIN_SECONDS := 4.0
const XFADE_SECONDS := 0.25
const DISTANT_MIN_GAP := 5.0
const DISTANT_MAX_GAP := 13.0

var _horn_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _distant_players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _distant_cd := 3.0
var _ambient_on := false


func setup() -> void:
	_rng.randomize()
	var horn := _make_horn()
	_horn_player = AudioStreamPlayer.new()
	_horn_player.stream = horn
	add_child(_horn_player)
	# Spare players replay the same horn pitch-shifted and quiet,
	# as distant traffic honking inside the ambience.
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.stream = horn
		add_child(p)
		_distant_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = _make_ambient()
	_ambient_player.volume_db = -7.0
	add_child(_ambient_player)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.stream = _make_rain()
	_rain_player.volume_db = -60.0
	add_child(_rain_player)
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.stream = _make_thunder()
	add_child(_thunder_player)
	# Settings sliders scale the Ambient bus, never these players directly.
	for p in [_horn_player, _ambient_player, _rain_player, _thunder_player] \
			+ _distant_players:
		p.bus = "Ambient"


func horn() -> void:
	if _horn_player != null:
		_horn_player.play()


func start_ambient() -> void:
	if _ambient_player != null and not _ambient_on:
		_ambient_on = true
		_ambient_player.play()
	if _rain_player != null and not _rain_player.playing:
		_rain_player.play()


func set_rain(level: float) -> void:
	## Rain bed volume follows the weather intensity (silent when dry).
	var l := clampf(level, 0.0, 1.0)
	if _rain_player != null:
		_rain_player.volume_db = -60.0 if l <= 0.03 else lerpf(-34.0, -9.0, l)


func thunder() -> void:
	if _thunder_player == null:
		return
	_thunder_player.pitch_scale = _rng.randf_range(0.8, 1.15)
	_thunder_player.volume_db = _rng.randf_range(-10.0, -5.0)
	_thunder_player.play()


func _process(delta: float) -> void:
	if not _ambient_on:
		return
	_distant_cd -= delta
	if _distant_cd > 0.0:
		return
	_distant_cd = _rng.randf_range(DISTANT_MIN_GAP, DISTANT_MAX_GAP)
	for p in _distant_players:
		if p.playing:
			continue
		p.volume_db = _rng.randf_range(-16.0, -9.0)
		p.pitch_scale = _rng.randf_range(0.55, 0.85)
		p.play()
		break


# ---------------------------------------------------------------- synthesis

func _make_horn() -> AudioStreamWAV:
	## Delhi e-rickshaw two-tone: a buzzy B4 blast then a D5 blast.
	var frames := int(MIX_RATE * 0.55)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var freq := 494.0 if t < 0.22 else 587.0
		phase += TAU * freq / MIX_RATE
		# Square for the cheap-speaker buzz, detuned sine for body.
		var wave := signf(sin(phase)) * 0.6 + sin(phase * 1.004) * 0.4
		var env := 1.0
		var attack: float = MIX_RATE * 0.008
		var release: float = MIX_RATE * 0.07
		if i < attack:
			env = i / attack
		elif i > frames - release:
			env = (frames - i) / release
		var sample := int(clampf(wave * env * 0.45, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


func _make_ambient() -> AudioStreamWAV:
	## Loopable street bed: leaky-integrated noise low-passed into a rumble,
	## with a slow swell. Head crossfades with tail material for a seamless loop.
	var loop_len := int(MIX_RATE * AMBIENT_SECONDS)
	var xfade := int(MIX_RATE * XFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + xfade)
	var brown := 0.0
	var lp := 0.0
	for i in raw.size():
		brown += _rng.randf_range(-1.0, 1.0) * 0.045
		brown *= 0.997
		lp += (brown - lp) * 0.04
		var t := float(i) / MIX_RATE
		var swell := 0.72 + 0.28 * sin(TAU * t / 3.7 + 1.3)
		raw[i] = lp * swell
	var peak := 0.001
	for v in raw:
		peak = maxf(peak, absf(v))
	var gain := 0.32 / peak
	var bytes := PackedByteArray()
	bytes.resize(loop_len * 2)
	for i in loop_len:
		var v: float = raw[i]
		if i < xfade:
			var w := float(i) / xfade
			v = raw[i] * w + raw[i + loop_len] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * gain, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)


func _make_rain() -> AudioStreamWAV:
	## Loopable downpour bed: soft broadband hiss with a slow shimmer.
	## Head crossfades with tail material for a seamless loop.
	var loop_len := int(MIX_RATE * RAIN_SECONDS)
	var xfade := int(MIX_RATE * XFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + xfade)
	var lp := 0.0
	for i in raw.size():
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.3
		var t := float(i) / MIX_RATE
		var shimmer := 0.72 + 0.28 * sin(TAU * t / 2.9 + 0.4)
		raw[i] = (n * 0.4 + lp * 0.6) * shimmer
	var peak := 0.001
	for v in raw:
		peak = maxf(peak, absf(v))
	var gain := 0.3 / peak
	var bytes := PackedByteArray()
	bytes.resize(loop_len * 2)
	for i in loop_len:
		var v: float = raw[i]
		if i < xfade:
			var w := float(i) / xfade
			v = raw[i] * w + raw[i + loop_len] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * gain, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)


func _make_thunder() -> AudioStreamWAV:
	## One-shot rolling crack: brown-noise burst over a 50 Hz sub rumble.
	var frames := int(MIX_RATE * 3.2)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var brown := 0.0
	var attack := float(MIX_RATE * 0.03)
	for i in frames:
		var t := float(i) / MIX_RATE
		brown += _rng.randf_range(-1.0, 1.0) * 0.06
		brown *= 0.994
		var env: float = minf(i / attack, 1.0) * pow(maxf(1.0 - t / 3.2, 0.0), 2.3)
		var sub := sin(TAU * 50.0 * t) * env * 0.5
		var sample := int(clampf((brown * 2.2 + sub) * env * 0.5, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


func _wav(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = bytes.size() / 2
	return wav
