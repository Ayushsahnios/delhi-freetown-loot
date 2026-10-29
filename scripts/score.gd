extends Node
## Score suite (issue #209) — the game's musical identity, procedural and
## zero-asset like every other voice: a sitar-flavored theme under the
## character-select screen, and mission complete/fail jingles that vary
## the classic reward arpeggio (bright sitar rise vs a falling minor
## figure). Synth idioms are the same compact circular-mixdown siblings
## the radio and chase stems use — loops wrap seamlessly, one-shots don't.

const MIX_RATE := 22050
const TITLE_DB := -8.0    # title bed: level with the radio/cabin bed
const JINGLE_DB := -5.0   # one-shots cut through for a beat (chase sting level)
const FAIL_DB := -6.0     # the fail figure sits just under the success one
const FADE_S := 0.5
const FADE_FLOOR_DB := -38.0

var _title_player: AudioStreamPlayer
var _jingle_player: AudioStreamPlayer
var _title_wav: AudioStreamWAV
var _success_wav: AudioStreamWAV
var _fail_wav: AudioStreamWAV
var _fade: Tween
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_title_wav = _make_title_theme()
	_success_wav = _make_success_jingle()
	_fail_wav = _make_fail_jingle()
	_title_player = AudioStreamPlayer.new()
	_title_player.stream = _title_wav
	_title_player.volume_db = FADE_FLOOR_DB
	_title_player.bus = "Radio"
	add_child(_title_player)
	_jingle_player = AudioStreamPlayer.new()
	_jingle_player.bus = "Radio"
	add_child(_jingle_player)


func play_title() -> void:
	## Character select is up: the theme fades in under the legend cards.
	if _title_player == null:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not _title_player.playing:
		_title_player.volume_db = FADE_FLOOR_DB
		_title_player.play()
	_fade = create_tween()
	_fade.tween_property(_title_player, "volume_db", TITLE_DB, FADE_S)


func stop_title() -> void:
	## A legend is picked: the theme melts away as the street takes over.
	if _title_player == null or not _title_player.playing:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_title_player, "volume_db", FADE_FLOOR_DB, FADE_S)
	_fade.tween_callback(_title_player.stop)


func mission_result(success: bool) -> void:
	## Mission complete: bright sitar variation of the reward arpeggio.
	## Mission failed: the same idea falls minor and lands on a thud.
	if _jingle_player == null:
		return
	_jingle_player.stream = _success_wav if success else _fail_wav
	_jingle_player.volume_db = JINGLE_DB if success else FAIL_DB
	_jingle_player.play()


func loudness_profile() -> Array:
	## Score channels for the scripted loudness check (issue #94).
	if _title_player == null:
		return []
	return [
		_measure("score_title", _title_wav, TITLE_DB),
		_measure("score_success", _success_wav, JINGLE_DB),
		_measure("score_fail", _fail_wav, FAIL_DB),
	]


# ---------------------------------------------------------------- synthesis

func _make_title_theme() -> AudioStreamWAV:
	## 8 bars at 76 BPM: tanpura Sa/Pa drone, a bhupali-pentatonic sitar
	## call (bars 1-4) answered by a soft bansuri echo (bars 5-8), light
	## tabla-ish pulse underneath. D major pentatonic throughout.
	var bpm := 76.0
	var eighth := _eighth_samples(bpm)
	var eighth_s := 60.0 / bpm / 2.0
	var loop_len := eighth * 64  # 8 bars
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	# Call: sitar phrase, bars 1-4 (slot = eighth index, note, length).
	var lead := [
		[0, 293.66, 2.0], [2, 369.99, 1.0], [3, 440.0, 2.0], [5, 493.88, 1.0],
		[6, 440.0, 2.0], [8, 369.99, 2.0], [10, 329.63, 1.0], [11, 293.66, 3.0],
		[16, 440.0, 2.0], [18, 493.88, 1.0], [19, 587.33, 2.0], [21, 493.88, 1.0],
		[22, 440.0, 2.0], [24, 369.99, 2.0], [26, 329.63, 1.0], [27, 369.99, 3.0],
	]
	# Answer: bansuri echo, bars 5-8 — same contour, softer, longer tails.
	var answer := [
		[32, 587.33, 2.0], [34, 493.88, 1.0], [35, 440.0, 2.0], [37, 369.99, 1.0],
		[38, 329.63, 2.0], [40, 293.66, 3.0],
		[44, 440.0, 2.0], [46, 493.88, 1.0], [47, 440.0, 2.0], [49, 369.99, 1.0],
		[50, 329.63, 2.0], [52, 293.66, 4.0],
	]
	for bar in 8:
		var at := bar * 8 * eighth
		# Drone strings alternate Sa / Pa, re-struck every bar.
		_drone(buf, at, loop_len, 146.83 if bar % 2 == 0 else 110.0, 6.0, 0.5)
		_kick(buf, at, loop_len, 0.3)
		for e in 8:
			var tick := at + e * eighth
			_hat(buf, tick, loop_len, 0.035 if e % 2 == 0 else 0.025)
	for n in lead:
		_sitar(buf, int(n[0]) * eighth, loop_len, n[1], eighth_s * 1.8 * n[2] * 0.55, 0.4)
	for n in answer:
		_flute(buf, int(n[0]) * eighth, loop_len, n[1], eighth_s * 2.2 * n[2] * 0.55, 0.3)
	return _finish(buf)


func _make_success_jingle() -> AudioStreamWAV:
	## Mission complete (~1.0 s): the issue-#154 reward arpeggio
	## C5-E5-G5-C6 re-voiced for sitar over a low Sa drone pluck.
	var frames := int(MIX_RATE * 1.0)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	_drone(buf, int(0.02 * MIX_RATE), frames, 146.83, 0.8, 0.4)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for n in notes.size():
		_sitar(buf, int((0.06 + 0.11 * n) * MIX_RATE), frames,
				notes[n], 0.3, 0.55)
	_hat(buf, int(0.5 * MIX_RATE), frames, 0.1)
	return _finish_oneshot(buf)


func _make_fail_jingle() -> AudioStreamWAV:
	## Mission failed (~1.1 s): the same arpeggio idea inverted and
	## minored — E4-C4-A3-F#3 falling plucks over a low thud.
	var frames := int(MIX_RATE * 1.1)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var notes := [329.63, 261.63, 220.0, 185.0]
	_kick(buf, 0, frames, 0.7)
	for n in notes.size():
		_pluck(buf, int((0.1 + 0.16 * n) * MIX_RATE), frames,
				notes[n], 0.34, 0.5)
	return _finish_oneshot(buf)


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


# ---------------------------------------------------------------- voices
# Compact siblings of the radio/chase voices (same conventions there).

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


func _hat(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	var frames := int(MIX_RATE * 0.035)
	var tail := 150
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 90.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, _rng.randf_range(-1.0, 1.0) * env * gain)


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


func _sitar(buf: PackedFloat32Array, at: int, loop_len: int,
		freq: float, dur: float, gain: float) -> void:
	## Sitar-style pluck: sawtooth through a closing lowpass (jawari buzz).
	var frames := int(MIX_RATE * dur)
	var tail := 400
	var p := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		p = fposmod(p + freq / MIX_RATE, 1.0)
		var cutoff := lerpf(0.55, 0.06, minf(t / 0.25, 1.0))
		lp1 += (2.0 * p - 1.0 - lp1) * cutoff
		lp2 += (lp1 - lp2) * cutoff
		var env := minf(t / 0.003, 1.0) * exp(-t * 3.2)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, (lp1 * 0.5 + lp2 * 0.6) * env * gain)


func _flute(buf: PackedFloat32Array, at: int, loop_len: int,
		freq: float, dur: float, gain: float) -> void:
	## Bansuri-style flute: sine core with delayed vibrato and breath noise.
	var frames := int(MIX_RATE * dur)
	var tail := 300
	var p := 0.0
	var breath := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var depth := minf(t / 0.25, 1.0) * 0.006
		p += TAU * freq * (1.0 + sin(TAU * 5.3 * t) * depth) / MIX_RATE
		var n := _rng.randf_range(-1.0, 1.0)
		breath += (n - breath) * 0.04
		var env := minf(t / 0.05, 1.0) * exp(-t * 1.2)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len,
				(sin(p) * 0.8 + sin(2.0 * p) * 0.12 + breath * 0.18) * env * gain)


func _drone(buf: PackedFloat32Array, at: int, loop_len: int,
		freq: float, dur: float, gain: float) -> void:
	## Tanpura-style drone string: bright pluck melting into a pure tone.
	var frames := int(MIX_RATE * dur)
	var tail := 500
	var p := 0.0
	var lp := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		p = fposmod(p + freq / MIX_RATE, 1.0)
		var cutoff := lerpf(0.4, 0.03, minf(t / 1.2, 1.0))
		lp += (2.0 * p - 1.0 - lp) * cutoff
		var env := minf(t / 0.01, 1.0) * exp(-t * 0.9)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, lp * env * gain)


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
	## Same mixdown, no loop points — jingles play through once.
	var wav := _finish(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav
