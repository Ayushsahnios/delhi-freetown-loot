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
const MURMUR_SECONDS := 7.0
const MURMUR_DB := -13.0        # crowd bed, full at the bazaar core
const MURMUR_FULL_M := 8.0      # full murmur inside this radius
const MURMUR_ZERO_M := 30.0     # faded to silence beyond
const CLATTER_MIN_DB := -22.0
const CLATTER_MAX_DB := -10.0   # chai glass + spoon right at the stall
const STALL_NEAR_M := 9.0
const CALL_MIN_DB := -22.0
const CALL_MAX_DB := -16.0      # vendor sing-song call, daytime only
const SPATIAL_HORN_MIN_DB := -20.0
const SPATIAL_HORN_MAX_DB := -8.0  # reactive honk from a real nearby auto
const TRAFFIC_SWELL_MAX_DB := 2.5  # bed swells as traffic breathes past
const EVENING_DROP_DB := 4.5    # the whole street quiets after dusk

var _horn_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _thunk_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer
var _distant_players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _distant_cd := 3.0
var _ambient_on := false
var _duck := 0.0  # 0 = normal mix, 1 = fully ducked for dialogue
var _murmur_player: AudioStreamPlayer
var _clatter_player: AudioStreamPlayer
var _call_player: AudioStreamPlayer
var _spatial_horns: Array[AudioStreamPlayer3D] = []
var _player: Node3D = null
var _food: Node = null
var _traffic: Node = null
var _stall_positions: Array[Vector3] = []
var _bazaar_center := Vector3.ZERO
var _ctx_cd := 0.0
var _clatter_cd := 3.0
var _call_cd := 14.0
var _reactive_cd := 5.0
var _day_gain_db := 0.0
var _night_f := 0.0
var _traffic_swell_db := 0.0
var _murmur_target_db := -60.0


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
	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.stream = _make_jingle()
	add_child(_jingle_player)
	_murmur_player = AudioStreamPlayer.new()
	_murmur_player.stream = _make_murmur()
	_murmur_player.volume_db = -60.0
	add_child(_murmur_player)
	_clatter_player = AudioStreamPlayer.new()
	_clatter_player.stream = _make_clatter()
	add_child(_clatter_player)
	_call_player = AudioStreamPlayer.new()
	_call_player.stream = _make_call()
	add_child(_call_player)
	# Reactive street horns (issue #165): one-shot 3D players positioned
	# at the actual honking auto, so panning and distance come free.
	var spatial_root := Node3D.new()
	add_child(spatial_root)
	for i in 2:
		var sp := AudioStreamPlayer3D.new()
		sp.stream = horn
		sp.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		sp.unit_size = 9.0
		sp.max_distance = 80.0
		spatial_root.add_child(sp)
		_spatial_horns.append(sp)
	# Settings sliders scale the Ambient bus, never these players directly.
	for p in [_horn_player, _ambient_player, _rain_player, _thunder_player,
			_thunk_player, _jingle_player, _murmur_player, _clatter_player,
			_call_player] + _distant_players:
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
	if _murmur_player != null and not _murmur_player.playing:
		_murmur_player.play()


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


func jingle() -> void:
	## Mission reward jingle (issue #154, free-roam feel): a bright
	## rising four-note arpeggio the moment a job pays out — the audio
	## half of the "job done" beat every free-roam loop leans on.
	if _jingle_player == null:
		return
	if not _jingle_player.playing:
		_jingle_player.play()


func _process(delta: float) -> void:
	if not _ambient_on:
		return
	_duck = move_toward(_duck, 1.0 if _wants_duck() else 0.0, delta / DUCK_RAMP_S)
	_ctx_cd -= delta
	if _ctx_cd <= 0.0:
		_ctx_cd = 0.2
		_update_context()
	_ambient_player.volume_db = AMBIENT_DB - _duck * DIALOGUE_DUCK_DB \
			+ _day_gain_db + _traffic_swell_db
	if _murmur_player != null:
		_murmur_player.volume_db = _murmur_target_db - _duck * DIALOGUE_DUCK_DB
	_distant_cd -= delta
	if _distant_cd > 0.0:
		return
	_distant_cd = _rng.randf_range(DISTANT_MIN_GAP, DISTANT_MAX_GAP) \
			* (1.0 + _night_f * 1.2)
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


func register_world(food: Node, traffic: Node) -> void:
	## Main hands over the live food stalls + traffic once, so the bed can
	## react to real positions without walking the scene tree (issue #165).
	_food = food
	_traffic = traffic
	_refresh_stalls()


func set_player(p: Node3D) -> void:
	_player = p


func set_day(t: float) -> void:
	## Day/night mix (issue #165): the street quiets through the evening —
	## beds drop, distant honks space out, the bazaar hushes to a murmur.
	var hours := fmod(t * 24.0 + 6.0, 24.0)
	_night_f = _night_factor(hours)
	_day_gain_db = -EVENING_DROP_DB * _night_f


func _night_factor(hours: float) -> float:
	## 0 = full day, 1 = deep night; smooth dusk and dawn shoulders.
	if hours >= 21.5 or hours < 4.0:
		return 1.0
	if hours >= 17.0:
		return (hours - 17.0) / 4.5
	if hours < 8.0:
		return 1.0 - (hours - 4.0) / 4.0
	return 0.0


func _update_context() -> void:
	## Every 0.2 s: distance drives the crowd murmur, chai-stall clatter,
	## vendor calls and reactive traffic honks (issue #165).
	if _player == null or not is_instance_valid(_player):
		return
	if _bazaar_center == Vector3.ZERO:
		_refresh_stalls()
	var pos: Vector3 = _player.global_position
	_traffic_swell_db = 0.0
	if _traffic != null and _traffic.has_method("near_positions"):
		var near: Array = _traffic.near_positions(pos, 24.0, 3)
		if not near.is_empty():
			var d_near := pos.distance_to(near[0])
			_traffic_swell_db = lerpf(TRAFFIC_SWELL_MAX_DB, 0.0,
					clampf((d_near - 4.0) / 18.0, 0.0, 1.0))
			_reactive_cd -= 0.2
			if _reactive_cd <= 0.0 and d_near < 18.0:
				_reactive_cd = _rng.randf_range(3.0, 7.0)
				_horn_at(near[_rng.randi_range(0, near.size() - 1)])
	var d_bazaar := pos.distance_to(_bazaar_center)
	var attn := 1.0 - clampf((d_bazaar - MURMUR_FULL_M)
			/ (MURMUR_ZERO_M - MURMUR_FULL_M), 0.0, 1.0)
	if attn <= 0.02:
		_murmur_target_db = -60.0
	else:
		var night_hush := lerpf(1.0, 0.22, _night_f)
		_murmur_target_db = MURMUR_DB \
				+ linear_to_db(maxf(attn * night_hush, 0.001))
	var d_stall := _nearest_distance(pos, _stall_positions)
	if d_stall < STALL_NEAR_M:
		_clatter_cd -= 0.2
		if _clatter_cd <= 0.0:
			_clatter_cd = _rng.randf_range(2.2, 6.5) * (1.0 + _night_f * 1.5)
			var c_gain := clampf(1.0 - (d_stall - 2.0) / (STALL_NEAR_M - 2.0), 0.0, 1.0)
			_clatter_player.volume_db = lerpf(CLATTER_MIN_DB, CLATTER_MAX_DB, c_gain) \
					- _night_f * 3.0 - _duck * DIALOGUE_DUCK_DB
			_clatter_player.pitch_scale = _rng.randf_range(0.92, 1.1)
			_clatter_player.play()
		_call_cd -= 0.2
		if _call_cd <= 0.0 and _night_f < 0.5 and d_stall < 12.0:
			_call_cd = _rng.randf_range(18.0, 40.0)
			_call_player.volume_db = lerpf(CALL_MIN_DB, CALL_MAX_DB,
					clampf(1.0 - d_stall / 12.0, 0.0, 1.0)) \
					- _duck * DIALOGUE_DUCK_DB
			_call_player.play()
	else:
		_clatter_cd = maxf(_clatter_cd, 1.0)
		_call_cd = maxf(_call_cd, 4.0)


func _refresh_stalls() -> void:
	if _food == null or not _food.has_method("stall_positions"):
		return
	_stall_positions = _food.stall_positions()
	if _stall_positions.is_empty():
		return
	var center := Vector3.ZERO
	for s in _stall_positions:
		center += s
	_bazaar_center = center / float(_stall_positions.size())


func _nearest_distance(pos: Vector3, points: Array[Vector3]) -> float:
	var best := 999999.0
	for pnt in points:
		best = minf(best, pos.distance_to(pnt))
	return best


func _horn_at(pos: Vector3) -> void:
	## A real auto honks from its actual street position: spatialised,
	## distance-attenuated, never louder than the player's own horn.
	for p in _spatial_horns:
		if p.playing:
			continue
		p.global_position = pos + Vector3(0.0, 0.9, 0.0)
		var d := _player.global_position.distance_to(pos)
		p.volume_db = lerpf(SPATIAL_HORN_MAX_DB, SPATIAL_HORN_MIN_DB,
				clampf(d / 20.0, 0.0, 1.0)) - _duck * DIALOGUE_DUCK_DB
		p.pitch_scale = _rng.randf_range(0.85, 1.05)
		p.play()
		return


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
		_measure("murmur", _murmur_player.stream, MURMUR_DB),
		_measure("clatter", _clatter_player.stream, CLATTER_MAX_DB),
		_measure("vendor_call", _call_player.stream, CALL_MAX_DB),
		_measure("spatial_horn", _spatial_horns[0].stream, SPATIAL_HORN_MAX_DB),
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


func _make_jingle() -> AudioStreamWAV:
	## Reward arpeggio (issue #154): rising C5-E5-G5-C6, ~half a
	## second, bright and short — the "job done" sting under the
	## MISSION COMPLETE toast.
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var note_len := 0.11
	var frames := int(MIX_RATE * (note_len * float(notes.size()) + 0.08))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var idx := clampi(int(t / note_len), 0, notes.size() - 1)
		var note_t := t - float(idx) * note_len
		phase += TAU * notes[idx] / MIX_RATE
		var env := pow(maxf(1.0 - note_t / note_len, 0.0), 1.6)
		var s := sin(phase) * 0.8 + sin(phase * 2.0) * 0.2
		var sample := int(clampf(s * env * 0.5, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


func _make_murmur() -> AudioStreamWAV:
	## Loopable bazaar crowd: speech-band noise with a conversational
	## flutter — three overlapping slow swells that read as chatter,
	## wordless and warm under the traffic bed. Crossfaded seamless loop.
	var loop_len := int(MIX_RATE * MURMUR_SECONDS)
	var xfade := int(MIX_RATE * XFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + xfade)
	var lp := 0.0
	var lp2 := 0.0
	for i in raw.size():
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.18    # ~1.3 kHz — top of the speech band
		lp2 += (lp - lp2) * 0.06  # ~420 Hz — vowel warmth
		var voicey := lp2 + (lp - lp2) * 0.5
		var t := float(i) / MIX_RATE
		var flutter := 0.55 \
				+ 0.22 * sin(TAU * t * 0.9 + 0.7) \
				+ 0.14 * sin(TAU * t * 1.7 + 2.9) \
				+ 0.09 * sin(TAU * t * 2.8 + 5.1)
		raw[i] = voicey * flutter
	var peak := 0.001
	for v in raw:
		peak = maxf(peak, absf(v))
	var gain := 0.26 / peak
	var bytes := PackedByteArray()
	bytes.resize(loop_len * 2)
	for i in loop_len:
		var v: float = raw[i]
		if i < xfade:
			var w := float(i) / xfade
			v = raw[i] * w + raw[i + loop_len] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * gain, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)


func _make_clatter() -> AudioStreamWAV:
	## One-shot chai-stall clatter: a glass set down on the cart — two
	## quick high pings with a tick of metal, gone in 140 ms.
	var frames := int(MIX_RATE * 0.14)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var s := 0.0
		if t < 0.05:
			phase += TAU * 2350.0 / MIX_RATE
			s = sin(phase) * pow(maxf(1.0 - t / 0.05, 0.0), 3.0)
		else:
			phase += TAU * 3100.0 / MIX_RATE
			s = sin(phase) * 0.6 * pow(maxf(1.0 - (t - 0.055) / 0.07, 0.0), 3.0)
		if t < 0.004:
			s += _rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.004) * 0.5
		var sample := int(clampf(s * 0.55, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


func _make_call() -> AudioStreamWAV:
	## One-shot street vendor call: a wordless sing-song line — pitch
	## rises, dips, then rises out, with light vibrato and a throaty
	## second harmonic so it reads as a voice, not a beep.
	var frames := int(MIX_RATE * 0.6)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var f := 300.0
		if t < 0.22:
			f = lerpf(300.0, 430.0, t / 0.22)
		elif t < 0.38:
			f = lerpf(430.0, 340.0, (t - 0.22) / 0.16)
		else:
			f = lerpf(340.0, 400.0, (t - 0.38) / 0.22)
		f *= 1.0 + sin(TAU * 5.5 * t) * 0.012
		phase += TAU * f / MIX_RATE
		var env: float = minf(t / 0.03, 1.0) * pow(maxf(1.0 - t / 0.6, 0.0), 1.4)
		var wave := sin(phase) * 0.75 + sin(phase * 2.0) * 0.25
		var sample := int(clampf(wave * env * 0.4, -1.0, 1.0) * 32767.0)
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
