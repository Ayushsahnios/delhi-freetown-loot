extends Node
## Procedural city audio — horn + ambient street bed, zero asset files.
## All streams are synthesized into AudioStreamWAV buffers at setup().

const MIX_RATE := 22050
const AMBIENT_SECONDS := 6.0
const RAIN_SECONDS := 4.0
const XFADE_SECONDS := 0.25
const DISTANT_MIN_GAP := 5.0
const DISTANT_MAX_GAP := 13.0

# Mix pass (issue #94): every channel's level lives here as a named dB
# constant so the loudness check can assert the balance stays put.
const HORN_DB := -5.0          # audible over the bed, never painful
const AMBIENT_DB := -7.0       # street bed under speech and music
const RAIN_TOP_DB := -9.0      # full downpour bed
const THUNDER_MIN_DB := -12.0  # soft-clipped one-shot, kept under the horn
const THUNDER_MAX_DB := -8.0
const THUNK_MIN_DB := -15.0    # speed-bump thud scales with crossing speed
const THUNK_MAX_DB := -5.0
const DISTANT_MIN_DB := -18.0  # phantom traffic honking inside the bed
const DISTANT_MAX_DB := -11.0
const DIALOGUE_DUCK_DB := 9.0   # beds dip while a dialogue box is up
const DUCK_RAMP_S := 0.15

var _horn_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _thunk_player: AudioStreamPlayer
var _distant_players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _distant_cd := 3.0
var _ambient_on := false
var _duck := 0.0  # 0 = normal mix, 1 = fully ducked for dialogue


func setup() -> void:
	_rng.randomize()
	var horn := _make_horn()
	_horn_player = AudioStreamPlayer.new()
	_horn_player.stream = horn
	_horn_player.volume_db = HORN_DB
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
	_ambient_player.volume_db = AMBIENT_DB
	add_child(_ambient_player)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.stream = _make_rain()
	_rain_player.volume_db = -60.0
	add_child(_rain_player)
	_thunder_player = AudioStreamPlayer.new()
	_thunder_player.stream = _make_thunder()
	add_child(_thunder_player)
	_thunk_player = AudioStreamPlayer.new()
	_thunk_player.stream = _make_thunk()
	add_child(_thunk_player)
	# Settings sliders scale the Ambient bus, never these players directly.
	for p in [_horn_player, _ambient_player, _rain_player, _thunder_player,
			_thunk_player] + _distant_players:
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
		_rain_player.volume_db = -60.0 if l <= 0.03 else lerpf(-34.0, RAIN_TOP_DB, l)


func thunder() -> void:
	if _thunder_player == null:
		return
	_thunder_player.pitch_scale = _rng.randf_range(0.8, 1.15)
	_thunder_player.volume_db = _rng.randf_range(THUNDER_MIN_DB, THUNDER_MAX_DB)
	_thunder_player.play()


func thunk(strength := 1.0) -> void:
	## Chassis taking a speed bump (issue #69): low thud behind a click,
	## heavier and louder the faster the crossing.
	if _thunk_player == null:
		return
	var s := clampf(strength, 0.0, 1.0)
	_thunk_player.pitch_scale = lerpf(0.75, 1.15, s)
	_thunk_player.volume_db = lerpf(THUNK_MIN_DB, THUNK_MAX_DB, s)
	_thunk_player.play()


func _process(delta: float) -> void:
	if not _ambient_on:
		return
	_duck = move_toward(_duck, 1.0 if _wants_duck() else 0.0, delta / DUCK_RAMP_S)
	_ambient_player.volume_db = AMBIENT_DB - _duck * DIALOGUE_DUCK_DB
	_distant_cd -= delta
	if _distant_cd > 0.0:
		return
	_distant_cd = _rng.randf_range(DISTANT_MIN_GAP, DISTANT_MAX_GAP)
	for p in _distant_players:
		if p.playing:
			continue
		p.volume_db = _rng.randf_range(DISTANT_MIN_DB, DISTANT_MAX_DB) \
				- _duck * DIALOGUE_DUCK_DB
		p.pitch_scale = _rng.randf_range(0.55, 0.85)
		p.play()
		break


func _wants_duck() -> bool:
	## Any running dialogue box ducks the street beds (issue #94).
	for d in get_tree().get_nodes_in_group("dialogue"):
		if d.has_method("is_running") and d.is_running():
			return true
	return false


func loudness_profile() -> Array:
	## Worst-case per-channel levels for the scripted loudness check:
	## {name, peak_db, rms_db} measured on the synthesized buffers with
	## the channel's loudest volume_db applied (rain at full downpour,
	## thunder at THUNDER_MAX_DB, distant honks at DISTANT_MAX_DB).
	if _ambient_player == null:
		return []
	return [
		_measure("horn", _horn_player.stream, HORN_DB),
		_measure("thunder", _thunder_player.stream, THUNDER_MAX_DB),
		_measure("thunk", _thunk_player.stream, THUNK_MAX_DB),
		_measure("ambient", _ambient_player.stream, AMBIENT_DB),
		_measure("rain", _rain_player.stream, RAIN_TOP_DB),
		_measure("distant_horn", _distant_players[0].stream, DISTANT_MAX_DB),
	]


func _measure(name: String, wav: AudioStreamWAV, channel_db: float) -> Dictionary:
	var data := wav.data
	var frames := data.size() / 2
	var peak := 0.0
	var sum_sq := 0.0
	for i in frames:
		var v := float(data.decode_s16(i * 2)) / 32768.0
		peak = maxf(peak, absf(v))
		sum_sq += v * v
	var rms := sqrt(sum_sq / maxf(frames, 1.0))
	return {
		"name": name,
		"peak_db": 20.0 * log(maxf(peak, 1e-6)) / log(10.0) + channel_db,
		"rms_db": 20.0 * log(maxf(rms, 1e-6)) / log(10.0) + channel_db,
	}


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
		# Soft saturation instead of a hard clamp so a near-bolt crack
		# rounds off instead of digitally clipping (issue #94).
		var sample := int(clampf(tanh((brown * 2.2 + sub) * env * 0.5) * 0.9,
				-1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


func _make_thunk() -> AudioStreamWAV:
	## One-shot suspension thud (issue #69): an 80-to-44 Hz sine drop
	## behind a short noise click, decaying over 160 ms.
	var frames := int(MIX_RATE * 0.16)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(82.0, 44.0, t / 0.16) / MIX_RATE
		var env := pow(maxf(1.0 - t / 0.16, 0.0), 2.6)
		var click := 0.0
		if t < 0.012:
			click = _rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.012) * 0.8
		var sample := int(clampf((sin(phase) * 0.85 + click) * env * 0.55,
				-1.0, 1.0) * 32767.0)
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
