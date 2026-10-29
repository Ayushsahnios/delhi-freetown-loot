extends Node
## Procedural in-vehicle radio — three named stations, zero assets (issue #186).
## Every station is rendered into a looping AudioStreamWAV once at setup().
## Notes are mixed circularly (tails wrap past the loop point), so each
## station loops seamlessly. Station switches cross-fade over two players.
##
## Stations:
##   1. DHOL POWER      — upbeat bhangra-energy synth (drums + pentatonic bass)
##   2. BANSURI & SITAR — mellow classical mood (flute lead, sitar, tanpura)
##   3. DHJ NEWS 24x7   — bustling news chatter loop with station-ID jingles

const MIX_RATE := 22050
const STATION_LABELS := [
	"FM 108.0 · DHOL POWER",
	"FM 92.6 · BANSURI & SITAR",
	"FM 78.9 · DHJ NEWS 24x7",
]
const CABIN_DB := -8.0  # head-unit level: present, never dominating (issue #94)
const FADE_S := 0.55    # station-switch cross-fade
const POWER_S := 0.35   # ignition on/off fade
const FADE_FLOOR_DB := -38.0
const ID_DB := -7.0     # station-ID one-shot on every preset switch (issue #209)

var _players: Array[AudioStreamPlayer] = []
var _loops: Array[AudioStreamWAV] = []
var _id_wavs: Array[AudioStreamWAV] = []       # per-station ID one-shots
var _id_player: AudioStreamPlayer
var _station := 0
var _active_idx := 0
var _active := false
var _fade: Tween
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	_loops = [
		_make_dhol_power(),
		_make_bansuri_sitar(),
		_make_dhj_news(),
	]
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.stream = _loops[0] if i == 0 else null
		p.volume_db = CABIN_DB if i == 0 else FADE_FLOOR_DB
		p.bus = "Radio"
		add_child(p)
		_players.append(p)
	# Synced station IDs (issue #209): each preset gets its own call-sign
	# one-shot, played over the cross-fade the moment you land on it.
	_id_wavs = [_make_id_dhol(), _make_id_bansuri(), _make_id_dhj()]
	_id_player = AudioStreamPlayer.new()
	_id_player.bus = "Radio"
	add_child(_id_player)


func set_active(on: bool) -> void:
	## Ignition switch: the head unit fades in/out and remembers its station.
	_active = on
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var p := _players[_active_idx]
	if on:
		if not p.playing:
			p.volume_db = FADE_FLOOR_DB
			p.play()
			_fade = create_tween()
			_fade.tween_property(p, "volume_db", CABIN_DB, POWER_S)
		else:
			p.volume_db = CABIN_DB
	else:
		_fade = create_tween()
		_fade.tween_property(p, "volume_db", FADE_FLOOR_DB, POWER_S)
		_fade.tween_callback(p.stop)


func cycle_station() -> String:
	## Next preset with a smooth cross-fade; returns the HUD label.
	## The new station announces itself with its ID one-shot (issue #209).
	_station = (_station + 1) % STATION_LABELS.size()
	_switch_stream(_loops[_station])
	if _id_player != null and not _id_wavs.is_empty():
		_id_player.stream = _id_wavs[_station]
		_id_player.volume_db = ID_DB
		_id_player.play()
	return STATION_LABELS[_station]


func label() -> String:
	return STATION_LABELS[_station]


func loudness_profile() -> Array:
	## Loudest station's level for the scripted loudness check,
	## measured on the synthesized loop with CABIN_DB applied, plus the
	## station-ID one-shots at ID_DB (issue #209).
	if _players.is_empty():
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
	var out := [loudest]
	for id_name in ["radio_id_dhol", "radio_id_bansuri", "radio_id_dhj"]:
		out.append(_measure_id(id_name, _id_wavs[out.size() - 1], ID_DB))
	return out


func _measure_id(name: String, wav: AudioStreamWAV, channel_db: float) -> Dictionary:
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
	## A/B cross-fade: the new station fades in while the old melts away.
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var into := _players[1 - _active_idx]
	var out := _players[_active_idx]
	into.stream = stream
	_active_idx = 1 - _active_idx
	if not _active:
		into.volume_db = CABIN_DB
		out.stop()
		return
	into.volume_db = FADE_FLOOR_DB
	if not into.playing:
		into.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(into, "volume_db", CABIN_DB, FADE_S)
	_fade.tween_property(out, "volume_db", FADE_FLOOR_DB, FADE_S)
	_fade.chain().tween_callback(out.stop)


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


func _make_bansuri_sitar() -> AudioStreamWAV:
	## Mellow classical mood: bansuri flute lead over sitar answer phrases
	## and a tanpura drone (D-major Bhupali: D E F# A B).
	var bpm := 76.0
	var eighth_s := 60.0 / bpm / 2.0
	var eighth := _eighth_samples(bpm)
	var loop_len := eighth * 64  # 8 bars — the raga needs room to breathe
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	var flute := [
		[293.66, 0.0, 369.99, 0.0, 440.0, 0.0, 493.88, 440.0],
		[369.99, 0.0, 293.66, 0.0, 329.63, 0.0, 0.0, 0.0],
		[440.0, 0.0, 493.88, 0.0, 587.33, 0.0, 493.88, 440.0],
		[369.99, 0.0, 329.63, 0.0, 293.66, 0.0, 0.0, 0.0],
		[293.66, 0.0, 329.63, 0.0, 369.99, 0.0, 440.0, 0.0],
		[493.88, 0.0, 440.0, 0.0, 369.99, 0.0, 329.63, 0.0],
		[369.99, 0.0, 440.0, 0.0, 493.88, 0.0, 587.33, 0.0],
		[440.0, 0.0, 369.99, 0.0, 293.66, 0.0, 0.0, 0.0],
	]
	var sitar := [
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 146.83, 0.0, 0.0, 0.0, 164.81, 0.0],
		[0.0, 0.0, 0.0, 0.0, 185.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 164.81, 0.0, 146.83, 0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0, 0.0, 146.83, 0.0, 0.0, 0.0],
		[220.0, 0.0, 0.0, 0.0, 185.0, 0.0, 0.0, 0.0],
		[0.0, 0.0, 164.81, 0.0, 0.0, 0.0, 220.0, 0.0],
		[0.0, 0.0, 185.0, 0.0, 146.83, 0.0, 0.0, 0.0],
	]
	for bar in 8:
		# Tanpura drone: Sa at the bar head, low Pa mid-bar on odd bars.
		_drone(buf, bar * 8 * eighth, loop_len, 146.83, eighth_s * 10.0, 0.16)
		if bar % 2 == 1:
			_drone(buf, (bar * 8 + 4) * eighth, loop_len, 110.0, eighth_s * 10.0, 0.14)
		for e in 8:
			var at := (bar * 8 + e) * eighth
			var fnote: float = flute[bar][e]
			if fnote > 0.0:
				var hold := 2.0 if e % 2 == 0 else 1.2
				_flute(buf, at, loop_len, fnote, eighth_s * hold, 0.2)
			var snote: float = sitar[bar][e]
			if snote > 0.0:
				_sitar(buf, at, loop_len, snote, eighth_s * 3.0, 0.3)
	return _finish(buf)


func _make_dhj_news() -> AudioStreamWAV:
	## Bustling news-talk loop: two anchors chatter over a soft street bed,
	## with station-ID jingles bookending the segment.
	var bpm := 112.0
	var eighth := _eighth_samples(bpm)
	var loop_len := eighth * 64  # 8 bars
	var buf := PackedFloat32Array()
	buf.resize(loop_len)
	# Chatter plan: [bar, eighth, anchor (0 = deep, 1 = bright), syllables].
	var script := [
		[0, 3, 0, 5], [1, 0, 0, 6], [1, 5, 1, 4],
		[2, 2, 0, 5], [3, 0, 1, 6], [3, 5, 0, 5],
		[4, 3, 1, 5], [5, 0, 1, 6], [5, 5, 0, 4],
		[6, 2, 1, 5], [7, 0, 0, 6], [7, 4, 1, 6],
	]
	for cue in script:
		var at: int = (int(cue[0]) * 8 + int(cue[1])) * eighth
		var f0 := 128.0 if cue[2] == 0 else 210.0
		_chatter_phrase(buf, at, loop_len, f0, int(cue[3]), 0.34)
	for bar in 8:
		for e in 8:
			var at := (bar * 8 + e) * eighth
			if e == 0 or e == 4:
				_kick(buf, at, loop_len, 0.3)
			_hat(buf, at, loop_len, 0.05 if e % 2 == 0 else 0.035)
	# Station IDs: full jingle at the top of the loop, beeps mid-loop.
	_station_id(buf, 0, loop_len)
	_station_beeps(buf, (4 * 8 + 4) * eighth, loop_len)
	return _finish(buf)


func _make_id_dhol() -> AudioStreamWAV:
	## DHOL POWER ID (~1.1 s): a dhol hit pair into a rising tumbi twang —
	## the preset says its name the moment you land on it.
	var frames := int(MIX_RATE * 1.1)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	_kick(buf, int(0.05 * MIX_RATE), frames, 0.8)
	_snare(buf, int(0.2 * MIX_RATE), frames, 0.6)
	_pluck(buf, int(0.3 * MIX_RATE), frames, 293.66, 0.3, 0.5)
	_pluck(buf, int(0.48 * MIX_RATE), frames, 440.0, 0.5, 0.5)
	_hat(buf, int(0.3 * MIX_RATE), frames, 0.1)
	return _finish_oneshot(buf)


func _make_id_bansuri() -> AudioStreamWAV:
	## BANSURI & SITAR ID (~1.4 s): a soft tanpura touch under a rising
	## two-note flute figure.
	var frames := int(MIX_RATE * 1.4)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	_drone(buf, int(0.02 * MIX_RATE), frames, 220.0, 1.2, 0.4)
	_flute(buf, int(0.1 * MIX_RATE), frames, 440.0, 0.5, 0.4)
	_flute(buf, int(0.55 * MIX_RATE), frames, 587.33, 0.7, 0.4)
	return _finish_oneshot(buf)


func _make_id_dhj() -> AudioStreamWAV:
	## DHJ NEWS ID (~1.2 s): urgent beeps straight into anchor chatter.
	var frames := int(MIX_RATE * 1.2)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	_beep(buf, int(0.04 * MIX_RATE), frames, 1180.0, 0.09, 0.3)
	_beep(buf, int(0.18 * MIX_RATE), frames, 1180.0, 0.09, 0.3)
	_beep(buf, int(0.32 * MIX_RATE), frames, 1560.0, 0.16, 0.3)
	_chatter_phrase(buf, int(0.6 * MIX_RATE), frames, 130.0, 3, 0.3)
	return _finish_oneshot(buf)


func _finish_oneshot(buf: PackedFloat32Array) -> AudioStreamWAV:
	## Same mixdown as the loops, no loop points — IDs play once.
	var wav := _finish(buf)
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav


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


func _flute(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
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


func _sitar(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
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


func _drone(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
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


func _beep(buf: PackedFloat32Array, at: int, loop_len: int, freq: float, dur: float, gain: float) -> void:
	## Clean sine blip for the station-ID call sign.
	var frames := int(MIX_RATE * dur)
	var p := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		p += TAU * freq / MIX_RATE
		var env := minf(t / 0.004, 1.0) * (1.0 - float(i) / frames)
		_add(buf, at + i, loop_len, sin(p) * env * gain)


func _syllable(buf: PackedFloat32Array, at: int, loop_len: int, f0: float, gain: float) -> void:
	## One babble syllable: pitch-wobbling buzzy vowel with a consonant tick.
	var dur := _rng.randf_range(0.07, 0.18)
	var frames := int(dur * MIX_RATE)
	var tick_frames := int(0.012 * MIX_RATE)
	var phase := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var wobble := 1.0 + 0.06 * sin(TAU * 3.0 * t)
		phase += TAU * f0 * wobble / MIX_RATE
		lp1 += (signf(sin(phase)) - lp1) * 0.25
		lp2 += (lp1 - lp2) * 0.06
		var env := minf(t / 0.012, 1.0) * exp(-t * 18.0)
		var v := (lp1 * 0.55 + lp2 * 0.45) * env
		if i < tick_frames:
			v += _rng.randf_range(-1.0, 1.0) * 0.25 * (1.0 - float(i) / tick_frames)
		_add(buf, at + i, loop_len, v * gain)


func _chatter_phrase(buf: PackedFloat32Array, at: int, loop_len: int, f0: float, count: int, gain: float) -> void:
	## A run of syllables with natural gaps — one anchor's sentence.
	var cursor := at
	for s in count:
		_syllable(buf, cursor, loop_len, f0 * _rng.randf_range(0.9, 1.15), gain)
		cursor += int(MIX_RATE * _rng.randf_range(0.10, 0.22))


func _station_id(buf: PackedFloat32Array, at: int, loop_len: int) -> void:
	## Full station ID: three-note jingle sting, then call-sign beeps.
	var notes := [880.0, 1108.73, 1318.51]
	for j in 3:
		_pluck(buf, at + j * int(0.09 * MIX_RATE), loop_len, notes[j], 0.5, 0.3)
	_beep(buf, at + int(0.45 * MIX_RATE), loop_len, 1180.0, 0.09, 0.22)
	_beep(buf, at + int(0.62 * MIX_RATE), loop_len, 1180.0, 0.09, 0.22)
	_beep(buf, at + int(0.79 * MIX_RATE), loop_len, 1560.0, 0.14, 0.22)


func _station_beeps(buf: PackedFloat32Array, at: int, loop_len: int) -> void:
	## Short top-of-hour style ID: two quick blips and a long one.
	_beep(buf, at, loop_len, 1180.0, 0.08, 0.18)
	_beep(buf, at + int(0.14 * MIX_RATE), loop_len, 1180.0, 0.08, 0.18)
	_beep(buf, at + int(0.28 * MIX_RATE), loop_len, 1560.0, 0.16, 0.18)


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
