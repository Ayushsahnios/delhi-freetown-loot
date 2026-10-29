extends Node
## Wanted-level chase stems (issue #226) — procedural music that escalates
## with the stars: a calm groove at 1 star, a tense pulse at 2, a driving
## chase rhythm at 3+. A distinct sting lands when BUSTED and a short
## resolve plays when the heat clears. Every loop is rendered once at
## setup() with the same circular-mixdown engine the radio stations use
## — zero assets.

const MIX_RATE := 22050
const CHASE_DB := -7.0        # stems sit under the horn, over the beds
const STING_DB := -5.0        # one-shots cut through for a beat
const FADE_S := 0.4           # escalation cross-fade
const FADE_FLOOR_DB := -38.0

var _players: Array[AudioStreamPlayer] = []  # A/B cross-fade pair
var _stems: Array[AudioStreamWAV] = []       # tier 1/2/3 loops
var _sting_player: AudioStreamPlayer
var _busted_wav: AudioStreamWAV
var _cleared_wav: AudioStreamWAV
var _active_idx := 0
var _tier := 0
var _fade: Tween
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_stems = [_make_calm_groove(), _make_tense_pulse(), _make_chase_drive()]
	_busted_wav = _make_busted_sting()
	_cleared_wav = _make_cleared_sting()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.stream = null
		p.volume_db = FADE_FLOOR_DB
		p.bus = "Radio"
		add_child(p)
		_players.append(p)
	_sting_player = AudioStreamPlayer.new()
	_sting_player.bus = "Radio"
	add_child(_sting_player)


func set_stars(s: int) -> void:
	## Tier follows the wanted stars: 1 = calm, 2 = tense, 3+ = drive;
	## 0 fades the stems away (the cleared() resolve is a separate call).
	var tier := clampi(s, 0, 3)
	if tier == _tier:
		return
	_tier = tier
	if tier == 0:
		var p := _players[_active_idx]
		if _fade != null and _fade.is_valid():
			_fade.kill()
		if not p.playing:
			return
		_fade = create_tween()
		_fade.tween_property(p, "volume_db", FADE_FLOOR_DB, FADE_S)
		_fade.tween_callback(p.stop)
		return
	_switch_stream(_stems[tier - 1])


func busted() -> void:
	## The arrest sting: two deep thuds under a falling bass figure —
	## the ride is over, the thana awaits.
	if _sting_player == null:
		return
	_sting_player.stream = _busted_wav
	_sting_player.volume_db = STING_DB
	_sting_player.play()


func cleared() -> void:
	## Heat-clear resolve: a rising pluck pair — clean again.
	if _sting_player == null or _sting_player.playing:
		return
	_sting_player.stream = _cleared_wav
	_sting_player.volume_db = STING_DB - 2.0
	_sting_player.play()


func loudness_profile() -> Array:
	## Stem + sting levels for the scripted loudness check, measured on
	## the rendered buffers with their loudest volume_db applied.
	if _players.is_empty():
		return []
	return [
		_measure("chase_calm", _stems[0], CHASE_DB),
		_measure("chase_pulse", _stems[1], CHASE_DB),
		_measure("chase_drive", _stems[2], CHASE_DB),
		_measure("chase_busted", _busted_wav, STING_DB),
		_measure("chase_cleared", _cleared_wav, STING_DB),
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


# ---------------------------------------------------------------- playback

func _switch_stream(stream: AudioStreamWAV) -> void:
	## A/B cross-fade, same trick as the radio: new stem in, old out.
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var into := _players[1 - _active_idx]
	var out := _players[_active_idx]
	into.stream = stream
	_active_idx = 1 - _active_idx
	into.volume_db = FADE_FLOOR_DB
	if not into.playing:
		into.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(into, "volume_db", CHASE_DB, FADE_S)
	_fade.tween_property(out, "volume_db", FADE_FLOOR_DB, FADE_S)
	_fade.chain().tween_callback(out.stop)


# ---------------------------------------------------------------- stems

func _make_calm_groove() -> AudioStreamWAV:
	## One star, watched but unhurried: 96 BPM round bass walking
	## root-fifth, soft kick on the bar head, hats ticking underneath.
	var bpm := 96.0
	var eighth := _eighth_samples(bpm)
	var eighth_s := 60.0 / bpm / 2.0
	var loop_len := eighth * 32  # 4 bars
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var bassline := [73.42, 0.0, 0.0, 73.42, 0.0, 87.31, 0.0, 0.0,
			98.0, 0.0, 0.0, 98.0, 0.0, 87.31, 0.0, 0.0,
			110.0, 0.0, 0.0, 110.0, 0.0, 98.0, 0.0, 0.0,
			87.31, 0.0, 73.42, 0.0, 73.42, 0.0, 0.0, 0.0]
	for bar in 4:
		for e in 8:
			var at := (bar * 8 + e) * eighth
			var idx := (bar * 8 + e) % bassline.size()
			if e == 0:
				_kick(buf, at, loop_len, 0.55)
			if e == 4 and bar % 2 == 1:
				_kick(buf, at, loop_len, 0.4)
			_hat(buf, at, loop_len, 0.08 if e % 2 == 0 else 0.05)
			var f := float(bassline[idx])
			if f > 0.0:
				_bass(buf, at, loop_len, f, eighth_s * 1.7, 0.42)
	return _finish(buf)


func _make_tense_pulse() -> AudioStreamWAV:
	## Two stars: 118 BPM — a pumping one-note eighth bass, snare on
	## 2 and 4, a tight 16th tick and off-beat stabs winding it up.
	var bpm := 118.0
	var eighth := _eighth_samples(bpm)
	var eighth_s := 60.0 / bpm / 2.0
	var loop_len := eighth * 32  # 4 bars
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var root := 58.27  # Bb2 — flat-side menace
	for bar in 4:
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 3 or e == 5:
				_kick(buf, at, loop_len, 0.7)
			if e == 2 or e == 6:
				_snare(buf, at, loop_len, 0.55)
			_hat(buf, at, loop_len, 0.1)
			_hat(buf, at + eighth / 2, loop_len, 0.06)
			# Pumping bass: every eighth, accent the bar head.
			_bass(buf, at, loop_len, root, eighth_s * 0.8,
					0.5 if e == 0 else 0.34)
			# Off-beat stab every other bar answers the pump.
			if e == 7 and bar % 2 == 1:
				_pluck(buf, at, loop_len, root * 4.0, eighth_s * 1.4, 0.3)
	return _finish(buf)


func _make_chase_drive() -> AudioStreamWAV:
	## Three stars and up: 148 BPM dhol-style chaal at full gallop —
	## driving pentatonic bass riff, snare rolls, a top alarm motif.
	var bpm := 148.0
	var eighth := _eighth_samples(bpm)
	var eighth_s := 60.0 / bpm / 2.0
	var loop_len := eighth * 32  # 4 bars
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var riff := [73.42, 73.42, 82.41, 87.31, 73.42, 98.0, 87.31, 82.41]
	for bar in 4:
		var fill := bar == 3
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 3 or e == 4 or e == 6:
				_kick(buf, at, loop_len, 0.85)
			if e == 1 or e == 2 or e >= 5:
				_snare(buf, at, loop_len, 0.7 if fill and e >= 6 else 0.5)
			if fill and e >= 6:
				_snare(buf, at + eighth / 2, loop_len, 0.4)
			_hat(buf, at, loop_len, 0.13 if e % 2 == 0 else 0.09)
			_hat(buf, at + eighth / 2, loop_len, 0.05)
			_bass(buf, at, loop_len, riff[e], eighth_s * 0.85, 0.5)
			# Alarm motif rides the top of the bar on the drive tier.
			if e == 0 or e == 4:
				_pluck(buf, at, loop_len, 587.33 if e == 0 else 493.88,
						eighth_s * 1.5, 0.24)
	return _finish(buf)


func _make_busted_sting() -> AudioStreamWAV:
	## The arrest sting (one-shot, ~1.3 s): two deep thuds under a
	## falling three-note bass figure — no loop.
	var frames := int(MIX_RATE * 1.3)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var falls := [146.83, 116.54, 87.31]  # D3, Bb2, F2
	for n in 3:
		_bass(buf, int((0.08 + 0.22 * n) * MIX_RATE), frames, falls[n], 0.5, 0.6)
	_kick(buf, 0, frames, 1.0)
	_kick(buf, int(0.16 * MIX_RATE), frames, 0.9)
	_snare(buf, int(0.16 * MIX_RATE), frames, 0.5)
	return _finish_oneshot(buf)


func _make_cleared_sting() -> AudioStreamWAV:
	## Heat-clear resolve (one-shot, ~0.9 s): a rising pluck pair into
	## a soft settling tone — clean again.
	var frames := int(MIX_RATE * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	_pluck(buf, int(0.05 * MIX_RATE), frames, 293.66, 0.4, 0.5)
	_pluck(buf, int(0.22 * MIX_RATE), frames, 440.0, 0.6, 0.5)
	_hat(buf, int(0.22 * MIX_RATE), frames, 0.08)
	return _finish_oneshot(buf)


# ---------------------------------------------------------------- synthesis
# Compact siblings of the radio.gd voices: circular mixdown makes every
# rendered loop seamless; one-shots skip the wrap.

func _eighth_samples(bpm: float) -> int:
	return int(round(60.0 / bpm / 2.0 * MIX_RATE))


func _add(buf: PackedFloat32Array, i: int, loop_len: int, v: float) -> void:
	buf[i % loop_len] += v


func _kick(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	var frames := int(MIX_RATE * 0.2)
	var tail := 400
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var f := lerpf(130.0, 48.0, minf(t / 0.05, 1.0))
		phase += TAU * f / MIX_RATE
		var env := exp(-t * 22.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, sin(phase) * env * gain)


func _snare(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	var frames := int(MIX_RATE * 0.09)
	var tail := 300
	var lp := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.35
		var env := exp(-t * 42.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len,
				(n * 0.6 + lp * 0.4 + sin(TAU * 190.0 * t) * 0.3) * env * gain)


func _hat(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	var frames := int(MIX_RATE * 0.035)
	var tail := 150
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 90.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, _rng.randf_range(-1.0, 1.0) * env * gain)


func _bass(buf: PackedFloat32Array, at: int, loop_len: int,
		freq: float, dur: float, gain: float) -> void:
	var frames := int(MIX_RATE * dur)
	var tail := 400
	var phase := 0.0
	var lp := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		phase += TAU * freq / MIX_RATE
		var raw := signf(sin(phase)) * 0.5 + sin(phase) * 0.5
		lp += (raw - lp) * 0.09
		var env := minf(t / 0.005, 1.0) * exp(-t * 5.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, lp * env * gain)


func _pluck(buf: PackedFloat32Array, at: int, loop_len: int,
		freq: float, dur: float, gain: float) -> void:
	var frames := int(MIX_RATE * dur)
	var tail := 400
	var p1 := 0.0
	var p2 := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		p1 += TAU * freq / MIX_RATE
		p2 += TAU * freq * 2.003 / MIX_RATE
		var env := minf(t / 0.004, 1.0) * exp(-t * 9.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, (sin(p1) * 0.62 + sin(p2) * 0.3) * env * gain)


func _finish(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.72 / peak
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buf.size()
	return wav


func _finish_oneshot(buf: PackedFloat32Array) -> AudioStreamWAV:
	## Same mixdown, no loop points — stings play through once.
	var wav := _finish(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav
