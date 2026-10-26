extends Node
## Procedural in-vehicle radio — three synthesized station loops, zero assets.
## Every station is rendered into a looping AudioStreamWAV once at setup().
## Notes are mixed circularly (tails wrap past the loop point), so each
## station loops seamlessly with no crossfade seams.

const MIX_RATE := 22050
const STATION_LABELS := [
	"FM 108.0 · DHOL POWER",
	"FM 92.6 · TUMBI GROOVE",
	"FM 78.9 · MONSOON LOUNGE",
]
const CABIN_DB := -8.0  # head-unit level: present, never dominating (issue #94)

var _player: AudioStreamPlayer
var _loops: Array[AudioStreamWAV] = []
var _station := 0
var _active := false
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_loops = [
		_make_dhol_power(),
		_make_tumbi_groove(),
		_make_monsoon_lounge(),
	]
	_player = AudioStreamPlayer.new()
	_player.stream = _loops[0]
	_player.volume_db = CABIN_DB
	_player.bus = "Radio"
	add_child(_player)


func set_active(on: bool) -> void:
	## Ignition switch: the head unit resumes the last station when on.
	_active = on
	if on:
		_player.stream = _loops[_station]
		if not _player.playing:
			_player.play()
	elif _player.playing:
		_player.stop()


func cycle_station() -> String:
	## Next preset; returns the HUD label of the new station.
	_station = (_station + 1) % STATION_LABELS.size()
	_player.stream = _loops[_station]
	if _active and not _player.playing:
		_player.play()
	return STATION_LABELS[_station]


func label() -> String:
	return STATION_LABELS[_station]


func loudness_profile() -> Array:
	## Loudest station's level for the scripted loudness check,
	## measured on the synthesized loop with CABIN_DB applied.
	if _player == null:
		return []
	var loudest := {"name": "radio", "peak_db": -99.0, "rms_db": -99.0}
	for wav in _loops:
		var data: PackedByteArray = wav.data
		var frames := data.size() / 2
		var peak := 0.0
		var sum_sq := 0.0
		for i in frames:
			var v := float(data.decode_s16(i * 2)) / 32768.0
			peak = maxf(peak, absf(v))
			sum_sq += v * v
		var rms := sqrt(sum_sq / maxf(frames, 1.0))
		loudest["peak_db"] = maxf(float(loudest["peak_db"]),
				20.0 * log(maxf(peak, 1e-6)) / log(10.0) + CABIN_DB)
		loudest["rms_db"] = maxf(float(loudest["rms_db"]),
				20.0 * log(maxf(rms, 1e-6)) / log(10.0) + CABIN_DB)
	return [loudest]


# ---------------------------------------------------------------- stations

func _make_dhol_power() -> AudioStreamWAV:
	## Bhangra-tempo dhol groove: driving chaal kick/snare, pentatonic bass.
	var bpm := 140.0
	var eighth_s := 60.0 / bpm / 2.0
	var eighth := _eighth_samples(bpm)
	var loop_len := eighth * 32  # 4 bars of 8 eighths
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var riff := [82.41, 82.41, 98.0, 110.0, 82.41, 123.47, 110.0, 98.0]
	for bar in 4:
		var fill := bar == 3
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 3 or e == 4:
				_kick(buf, at, loop_len, 0.9)
			if e == 1 or e == 2 or e >= 5:
				_snare(buf, at, loop_len, 0.7 if fill and e >= 6 else 0.5)
			if fill and e >= 6:
				_snare(buf, at + eighth / 2, loop_len, 0.4)  # 16th-note roll
			_hat(buf, at, loop_len, 0.14 if e % 2 == 0 else 0.09)
			_bass(buf, at, loop_len, riff[e], eighth_s * 0.85, 0.5)
	return _finish(buf)


func _make_tumbi_groove() -> AudioStreamWAV:
	## Plucked-string melody over a light Em–C–G–D backing.
	var bpm := 118.0
	var eighth_s := 60.0 / bpm / 2.0
	var eighth := _eighth_samples(bpm)
	var loop_len := eighth * 32
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var roots := [82.41, 130.81, 98.0, 146.83]
	var melody := [
		[329.63, 0.0, 392.0, 0.0, 440.0, 0.0, 493.88, 0.0],
		[440.0, 0.0, 392.0, 0.0, 329.63, 0.0, 293.66, 0.0],
		[329.63, 0.0, 392.0, 0.0, 493.88, 0.0, 587.33, 0.0],
		[659.26, 0.0, 587.33, 0.0, 493.88, 0.0, 440.0, 0.0],
	]
	for bar in 4:
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 4:
				_kick(buf, at, loop_len, 0.7)
			if e == 2 or e == 6:
				_snare(buf, at, loop_len, 0.35)
			if e % 2 == 1:
				_hat(buf, at, loop_len, 0.07)
			var note: float = melody[bar][e]
			if note > 0.0:
				_pluck(buf, at, loop_len, note, 0.22, 0.42)
			if e == 0:
				_bass(buf, at, loop_len, roots[bar], eighth_s * 5.0, 0.42)
	return _finish(buf)


func _make_monsoon_lounge() -> AudioStreamWAV:
	## Slow detuned pads with a soft beat for rainy-night cruising.
	var bpm := 92.0
	var eighth_s := 60.0 / bpm / 2.0
	var eighth := _eighth_samples(bpm)
	var loop_len := eighth * 32
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var chords := [
		[164.81, 196.0, 246.94],
		[130.81, 164.81, 196.0],
		[196.0, 246.94, 293.66],
		[146.83, 185.0, 220.0],
	]
	var plucks := [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 493.88, 0.0, 0.0, 440.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0, 392.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 440.0, 0.0, 0.0, 0.0, 329.63, 0.0],
	]
	for bar in 4:
		_pad(buf, bar * 8 * eighth, loop_len, chords[bar], eighth_s * 8.0, 0.16)
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 4:
				_kick(buf, at, loop_len, 0.5)
			if e == 2 or e == 6:
				_snare(buf, at, loop_len, 0.2)
			if e == 3 or e == 7:
				_hat(buf, at, loop_len, 0.05)
			var note: float = plucks[bar][e]
			if note > 0.0:
				_pluck(buf, at, loop_len, note, 0.35, 0.3)
	return _finish(buf)


# ---------------------------------------------------------------- synthesis

func _eighth_samples(bpm: float) -> int:
	return int(round(60.0 / bpm / 2.0 * MIX_RATE))


func _add(buf: PackedFloat32Array, i: int, loop_len: int, v: float) -> void:
	## Circular mixdown: anything written past the loop end wraps to the
	## head, which is what makes the rendered loop seamless.
	buf[i % loop_len] += v


func _kick(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	## Dhol-style open bass drum: sine with a fast pitch dive.
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
	## Dhina: noise snap over a short 190 Hz body.
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
		_add(buf, at + i, loop_len, (n * 0.6 + lp * 0.4 + sin(TAU * 190.0 * t) * 0.3) * env * gain)


func _hat(buf: PackedFloat32Array, at: int, loop_len: int, gain: float) -> void:
	var frames := int(MIX_RATE * 0.035)
	var tail := 150
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 90.0)
		if i > frames - tail:
			env *= float(frames - i) / tail
		_add(buf, at + i, loop_len, _rng.randf_range(-1.0, 1.0) * env * gain)


func _bass(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
	## Square-through-lowpass bass with a plucky envelope.
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


func _pluck(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
	## Tumbi-style pluck: fundamental plus a slightly detuned octave.
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


func _pad(buf: PackedFloat32Array, at: int, loop_len: int, freqs: Array, dur: float, gain: float) -> void:
	## Detuned sine chord bed, raised-cosine window over the whole bar.
	var frames := int(MIX_RATE * dur)
	var attack := int(MIX_RATE * 0.5)
	var release := int(MIX_RATE * 0.6)
	var n := freqs.size()
	var p_up := PackedFloat32Array()
	p_up.resize(n)
	var p_dn := PackedFloat32Array()
	p_dn.resize(n)
	for i in frames:
		var env := 1.0
		if i < attack:
			env = 0.5 - 0.5 * cos(TAU * float(i) / float(2 * attack))
		elif i > frames - release:
			env = 0.5 - 0.5 * cos(TAU * float(frames - i) / float(2 * release))
		var v := 0.0
		for j in n:
			var f := float(freqs[j])
			p_up[j] += TAU * f * 1.003 / MIX_RATE
			p_dn[j] += TAU * f * 0.997 / MIX_RATE
			v += sin(p_up[j]) + sin(p_dn[j])
		_add(buf, at + i, loop_len, v * env * gain / float(n))


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
