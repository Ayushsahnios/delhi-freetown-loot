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
# Monsoon soundscape (issue #227): the street bed dips under a downpour,
# and everything on the Ambient bus low-passes behind a shopfront.
const RAIN_AMBIENT_DUCK_DB := 5.0   # rain takes over, bed yields
const INDOOR_CUTOFF_HZ := 950.0     # muffled behind the shopfront
const OUTDOOR_CUTOFF_HZ := 20000.0  # wide open on the street
const MUFFLE_RAMP_HZ_S := 12000.0   # cutoff slew — ~1.6 s door-to-muffled
# Interaction foley (issue #187): feet, doors and paisa — quiet layers
# that sit UNDER the street bed, never on top of it.
const FOOTSTEP_WALK_DB := -25.0  # own feet: present, never the loudest thing
const FOOTSTEP_RUN_DB := -17.0   # sprint stride lands harder
const FOOTSTEP_STRIDE_MIN := 3.0 # metres per step at walk pace
const FOOTSTEP_STRIDE_MAX := 3.7 # sprint stretches the stride
const STEP_WALK_MPS := 6.5       # player.gd walk speed, mirrored for cadence
const STEP_RUN_MPS := 11.5       # player.gd run speed, mirrored for cadence
const DOOR_CHIME_DB := -15.0     # shop-door ding-dong on entry/exit beats
const PURCHASE_BLIP_DB := -16.0  # cash pip under the food toast
const CAR_HORN_DB := -6.0        # fuller twin-tone against the bed
const SCOOTER_HORN_DB := -8.0    # thin city meep, present not piercing
# Night palette (issue #214): dusk-to-dawn the street changes character —
# crickets own the quiet, a distant stray answers, and every bed thins
# a few dB more while the city sleeps.
const CRICKET_DB := -19.0         # pulsing high-chirp bed, on after dusk
const CRICKET_RAIN_DUCK_DB := 8.0 # the chorus hushes under a downpour
const CRICKET_SECONDS := 5.5
const DOG_BARK_MIN_DB := -26.0    # distant one-shot woof, late night only
const DOG_BARK_MAX_DB := -19.0
const DOG_BARK_MIN_GAP := 22.0    # a stray barks, then the street settles
const DOG_BARK_MAX_GAP := 65.0
const LATE_NIGHT_THIN_DB := 3.5   # beds drop again through the small hours
const LATE_HONK_WIDEN := 0.8      # extra distant-honk gap multiplier
const TEMPLE_BELL_MIN_DB := -20.0  # distant mandir bell, morning window only
const TEMPLE_BELL_MAX_DB := -14.0
const TEMPLE_BELL_MIN_GAP := 24.0  # a strike, then the lane settles (#267)
const TEMPLE_BELL_MAX_GAP := 70.0
const SHANKH_DB := -18.0           # one conch swell as the window opens
const AZAN_DB := -16.0             # one short evening call, under dialogue
const SACRED_UNIT_M := 10.0        # inverse-distance reach, sacred voices
const SACRED_MAX_M := 110.0        # gone well before the next district

# Engine voice pack (issue #213): every drivable kind gets its own hum.
const ENGINE_IDLE_DB := -17.0   # idling at a standstill, under every horn
const ENGINE_FULL_DB := -11.0   # flat out on the open stretch
const ENGINE_REV_BUMP := 0.16   # pitch overshoot while flooring it
const ENGINE_PITCH := {         # per kind: idle -> flat-out pitch_scale
	# Issue #269: the heavy three idle deep and never wind far — the
	# tanker is the lowest voice on the street.
	"tanker": [0.5, 0.95],
	"truck": [0.55, 1.0],
	"tempo": [0.72, 1.3],
	"van": [0.82, 1.5],
	"car": [0.95, 1.75],
	"auto": [1.05, 1.95],
	"scooter": [1.4, 2.65],
}
const BRAKE_SQUEAL_DB := -18.0  # one-shot pad pinch, under the engine hum
const BRAKE_SQUEAL_MIN_RATIO := 0.45  # only bites when braking from speed
const INDICATOR_DB := -20.0     # tick-tock while leaned into a hard turn
const INDICATOR_STEER := 0.5    # steering held at least this hard...
const INDICATOR_RATIO := 0.4    # ...at this much of top speed

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
var _clack_player: AudioStreamPlayer
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
var _step_players: Array[AudioStreamPlayer] = []
var _chime_player: AudioStreamPlayer
var _blip_player: AudioStreamPlayer
var _horn_voices := {}          # vehicle kind -> AudioStreamWAV (issue #187)
var _step_voices := {}          # surface -> AudioStreamWAV (issue #187)
var _engine_player: AudioStreamPlayer   # hum loop (issue #213)
var _squeal_player: AudioStreamPlayer   # brake one-shot (issue #213)
var _indicator_player: AudioStreamPlayer  # tick-tock loop (issue #213)
var _engine_kind := "auto"
var _engine_ratio := 0.0
var _rev_bump := 0.0
var _squeal_cd := 0.0
var _step_dist := 0.0
var _step_alt := 0
var _rain_level := 0.0
var _indoors := false
var _muffle: AudioEffectLowPassFilter = null
var _wetness := 0.0   # road wetness — squelch follows this, not the rain
var _cricket_player: AudioStreamPlayer
var _bark_player: AudioStreamPlayer
var _bark_cd := 45.0
var _cricket_f := 0.0   # chirp bed gate: in after dusk, out before dawn
var _late_f := 0.0      # deep-night gate: barks + the extra bed thinning
var _temple_player: AudioStreamPlayer3D  # mandir lane anchor (issue #267)
var _mosque_player: AudioStreamPlayer3D  # mosque block anchor (issue #267)
var _bell_wav: AudioStreamWAV
var _shankh_wav: AudioStreamWAV
var _azan_wav: AudioStreamWAV
var _bell_cd := 16.0
var _day_hours := 12.0   # hour hand for the sacred windows (issue #267)
var _shankh_done := false  # one conch swell per morning window
var _azan_done := false    # one evening call phrase per day
var _prev_day_frac := 0.0  # wrap detector: a day_t drop is midnight


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
	_clack_player = AudioStreamPlayer.new()
	_clack_player.stream = _make_board_clack()
	add_child(_clack_player)
	_call_player = AudioStreamPlayer.new()
	_call_player.stream = _make_call()
	add_child(_call_player)
	# Night palette (issue #214): the cricket bed loops silent until dusk;
	# dog barks are one-shots gated by the late-night window.
	_cricket_player = AudioStreamPlayer.new()
	_cricket_player.stream = _make_crickets()
	_cricket_player.volume_db = -60.0
	add_child(_cricket_player)
	_bark_player = AudioStreamPlayer.new()
	_bark_player.stream = _make_dog_bark()
	add_child(_bark_player)
	# Engine voice pack (issue #213): one hum loop pitched per vehicle
	# kind at play time, a brake-squeal one-shot and the indicator
	# tick-tock — the fleet's own voice, silent until a drive starts.
	_engine_player = AudioStreamPlayer.new()
	_engine_player.stream = _make_engine_voice()
	_engine_player.volume_db = -60.0
	add_child(_engine_player)
	_squeal_player = AudioStreamPlayer.new()
	_squeal_player.stream = _make_brake_squeal()
	add_child(_squeal_player)
	_indicator_player = AudioStreamPlayer.new()
	_indicator_player.stream = _make_indicator()
	add_child(_indicator_player)
	# Interaction foley (issue #187): footsteps by surface and speed,
	# shop-door chime, purchase pip, and one horn voice per vehicle kind.
	for surface in ["pave", "dirt", "wet"]:
		_step_voices[surface] = _make_footstep(surface)
		var step := AudioStreamPlayer.new()
		step.stream = _step_voices[surface]
		add_child(step)
		_step_players.append(step)
	_chime_player = AudioStreamPlayer.new()
	_chime_player.stream = _make_door_chime()
	add_child(_chime_player)
	_blip_player = AudioStreamPlayer.new()
	_blip_player.stream = _make_purchase_blip()
	add_child(_blip_player)
	_horn_voices["auto"] = horn  # the e-rickshaw two-tone stays the lead
	_horn_voices["car"] = _make_car_horn()
	_horn_voices["van"] = _horn_voices["car"]  # van shares the car voice,
	# pitched down at play time so it reads heavier.
	_horn_voices["scooter"] = _make_scooter_horn()
	# Issue #269: the heavy three speak from the existing packs — the
	# tempo takes the rickshaw two-tone a step down, the truck and
	# tanker blast the car horn from the basement, played slow.
	_horn_voices["tempo"] = _horn_voices["auto"]
	_horn_voices["truck"] = _horn_voices["car"]
	_horn_voices["tanker"] = _horn_voices["car"]
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
	# Sacred soundscape (issue #267): distance-attenuated one-shots on
	# the same street bus — the mandir bell and shankh share the
	# temple-gate anchor, the evening call sits on the mosque side.
	_temple_player = AudioStreamPlayer3D.new()
	_temple_player.stream = _make_temple_bell()
	_bell_wav = _temple_player.stream
	_shankh_wav = _make_shankh()
	_mosque_player = AudioStreamPlayer3D.new()
	_mosque_player.stream = _make_azan_call()
	_azan_wav = _mosque_player.stream
	for sacred in [_temple_player, _mosque_player]:
		sacred.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		sacred.unit_size = SACRED_UNIT_M
		sacred.max_distance = SACRED_MAX_M
		sacred.bus = "Ambient"
		spatial_root.add_child(sacred)
	# Street honks belong on the street bus so the settings slider and
	# the interior muffle (issue #227) hear them too.
	for sp in _spatial_horns:
		sp.bus = "Ambient"
	# Settings sliders scale the Ambient bus, never these players directly.
	for p in [_horn_player, _ambient_player, _rain_player, _thunder_player,
			_thunk_player, _jingle_player, _murmur_player, _clatter_player,
		_clack_player,
			_call_player, _chime_player, _blip_player, _cricket_player,
			_bark_player, _engine_player, _squeal_player,
			_indicator_player] + _distant_players \
			+ _step_players:
		p.bus = "Ambient"
	_prepare_muffle()


func horn(kind := "auto") -> void:
	## One voice per vehicle kind (issue #187): the e-rickshaw's buzzy
	## two-tone, a fuller car/van blast, a thin scooter meep. On foot the
	## lead voice plays — a street-side hand on the horn button.
	if _horn_player == null:
		return
	_horn_player.stream = _horn_voices.get(kind, _horn_voices["auto"])
	_horn_player.pitch_scale = 0.72 if kind == "tanker" \
			else 0.78 if kind == "truck" \
			else 0.9 if kind == "tempo" \
			else 0.85 if kind == "van" \
			else _rng.randf_range(0.96, 1.04)
	_horn_player.play()


func engine_start(kind := "auto") -> void:
	## Engine voice pack (issue #213): the hum starts with the take-a-
	## vehicle beat — idling at a standstill in this kind's register,
	## then pitch and level ride the speedometer every frame after.
	if _engine_player == null:
		return
	_engine_kind = kind
	_engine_ratio = 0.0
	_rev_bump = 0.0
	_squeal_cd = 0.0
	_engine_player.pitch_scale = float(ENGINE_PITCH.get(kind,
			ENGINE_PITCH["auto"])[0])
	_engine_player.volume_db = ENGINE_IDLE_DB
	_engine_player.play()


func engine_stop() -> void:
	## Key out: hum and indicator relay fall silent together.
	if _engine_player != null:
		_engine_player.stop()
	if _indicator_player != null:
		_indicator_player.stop()


func engine_drive(telemetry: Dictionary, delta: float) -> void:
	## Per-frame heartbeat from the driven vehicle (issue #213): hum
	## pitch tracks the speed ratio in this kind's register — scooter
	## buzzing well above the van — with a soft rev bump while the
	## throttle is held. Braking from speed pinches one squeal; steering
	## hard at speed starts the indicator tick-tock, mirroring the
	## cornering-lean system (issue #154) — fully automatic.
	if _engine_player == null or not _engine_player.playing:
		return
	var ratio: float = clampf(float(telemetry.get("ratio", 0.0)), 0.0, 1.0)
	var accel: float = float(telemetry.get("accel", 0.0))
	var steer: float = absf(float(telemetry.get("steer", 0.0)))
	var braking: bool = bool(telemetry.get("braking", false))
	var range: Array = ENGINE_PITCH.get(_engine_kind, ENGINE_PITCH["auto"])
	var k := clampf(10.0 * delta, 0.0, 1.0)
	_engine_ratio = lerpf(_engine_ratio, ratio, k)
	# Rev bump: flooring it overshoots the pitch, easing off as speed builds.
	_rev_bump = lerpf(_rev_bump,
			ENGINE_REV_BUMP * maxf(accel, 0.0) * (1.0 - _engine_ratio * 0.7),
			clampf(5.0 * delta, 0.0, 1.0))
	_engine_player.pitch_scale = lerpf(float(range[0]), float(range[1]),
			_engine_ratio) + _rev_bump
	_engine_player.volume_db = lerpf(ENGINE_IDLE_DB, ENGINE_FULL_DB,
			_engine_ratio) - _duck * DIALOGUE_DUCK_DB
	# Brake squeal: one pinch per braking event from real speed.
	_squeal_cd = maxf(_squeal_cd - delta, 0.0)
	if braking and ratio > BRAKE_SQUEAL_MIN_RATIO and _squeal_cd <= 0.0 \
			and not _squeal_player.playing:
		_squeal_cd = 1.8
		_squeal_player.volume_db = BRAKE_SQUEAL_DB - _duck * DIALOGUE_DUCK_DB
		_squeal_player.pitch_scale = _rng.randf_range(0.92, 1.08)
		_squeal_player.play()
	# Indicator tick-tock: hard lock at open-road speed — the same state
	# that rolls the chassis in auto.gd — releasing the wheel settles it.
	if steer > INDICATOR_STEER and _engine_ratio > INDICATOR_RATIO:
		if not _indicator_player.playing:
			_indicator_player.volume_db = INDICATOR_DB \
					- _duck * DIALOGUE_DUCK_DB
			_indicator_player.play()
	elif _indicator_player.playing and (steer < 0.35 or _engine_ratio < 0.3):
		_indicator_player.stop()


func start_ambient() -> void:
	if _ambient_player != null and not _ambient_on:
		_ambient_on = true
		_ambient_player.play()
	if _rain_player != null and not _rain_player.playing:
		_rain_player.play()
	if _murmur_player != null and not _murmur_player.playing:
		_murmur_player.play()
	if _cricket_player != null and not _cricket_player.playing:
		_cricket_player.play()


func set_rain(level: float) -> void:
	## Rain bed volume follows the weather intensity (silent when dry).
	var l := clampf(level, 0.0, 1.0)
	_rain_level = l
	if _rain_player != null:
		_rain_player.volume_db = -60.0 if l <= 0.03 else lerpf(-34.0, RAIN_TOP_DB, l)


func set_indoors(inside: bool) -> void:
	## Interior muffle (issue #227): the doorway check in interiors.gd
	## flips this — the whole street bed goes behind the shopfront.
	_indoors = inside


func set_wetness(w: float) -> void:
	## Road wetness from the weather system (issue #205): the squelch
	## voice follows the pavement, not the shower — streets stay soggy
	## for a while after the rain has passed.
	_wetness = clampf(w, 0.0, 1.0)


func thunder() -> void:
	if _thunder_player == null:
		return
	_thunder_player.pitch_scale = _rng.randf_range(0.8, 1.15)
	_thunder_player.volume_db = _rng.randf_range(THUNDER_MIN_DB, THUNDER_MAX_DB)
	_thunder_player.play()


func board_clack(db := -15.0) -> void:
	## Split-flap departure-board clack (issue #184) — one row flip;
	## db is the caller's distance attenuation (railway.gd).
	if _clack_player == null:
		return
	_clack_player.pitch_scale = _rng.randf_range(0.92, 1.08)
	_clack_player.volume_db = db
	_clack_player.play()


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

func door_chime() -> void:
	## Shop-door ding-dong (issue #187): every entry/exit beat rings it
	## — vehicle doors and metro gates today, walk-in interiors when
	## they land. Skipped if one is already ringing, so it never stacks.
	if _chime_player == null or _chime_player.playing:
		return
	_chime_player.volume_db = DOOR_CHIME_DB - _duck * DIALOGUE_DUCK_DB
	_chime_player.play()

func purchase_blip() -> void:
	## Cash pip (issue #187): the beat the moment paisa leaves the
	## wallet for street food — two quick register notes under the toast.
	if _blip_player == null or _blip_player.playing:
		return
	_blip_player.volume_db = PURCHASE_BLIP_DB - _duck * DIALOGUE_DUCK_DB
	_blip_player.play()


func _process(delta: float) -> void:
	if not _ambient_on:
		return
	_duck = move_toward(_duck, 1.0 if _wants_duck() else 0.0, delta / DUCK_RAMP_S)
	_ctx_cd -= delta
	if _ctx_cd <= 0.0:
		_ctx_cd = 0.2
		_update_context()
	_tick_footsteps(delta)
	_ambient_player.volume_db = AMBIENT_DB - _duck * DIALOGUE_DUCK_DB \
			+ _day_gain_db + _traffic_swell_db \
			- _rain_level * RAIN_AMBIENT_DUCK_DB
	if _muffle != null:
		var target_hz := INDOOR_CUTOFF_HZ if _indoors else OUTDOOR_CUTOFF_HZ
		_muffle.cutoff_hz = move_toward(_muffle.cutoff_hz, target_hz,
				delta * MUFFLE_RAMP_HZ_S)
	if _murmur_player != null:
		_murmur_player.volume_db = _murmur_target_db - _duck * DIALOGUE_DUCK_DB \
				- LATE_NIGHT_THIN_DB * _late_f
	if _cricket_player != null:
		# Crickets fade with their window and hush under rain (issue #214);
		# the Ambient-bus muffle keeps them outside when a door closes.
		_cricket_player.volume_db = CRICKET_DB \
				+ linear_to_db(maxf(_cricket_f, 0.001)) \
				- _rain_level * CRICKET_RAIN_DUCK_DB \
				- _duck * DIALOGUE_DUCK_DB
	_bell_cd -= delta
	if _bell_cd <= 0.0:
		_bell_cd = _rng.randf_range(TEMPLE_BELL_MIN_GAP, TEMPLE_BELL_MAX_GAP)
		# The mandir bell rings sparse through the 06:00-08:00 window
		# (issue #267), sharing the shankh's temple-gate anchor.
		if _day_hours >= 6.0 and _day_hours < 8.0 \
				and _temple_player != null and not _temple_player.playing:
			_temple_player.stream = _bell_wav
			_temple_player.volume_db = _rng.randf_range(
					TEMPLE_BELL_MIN_DB, TEMPLE_BELL_MAX_DB) \
					- _duck * DIALOGUE_DUCK_DB
			_temple_player.pitch_scale = _rng.randf_range(0.94, 1.06)
			_temple_player.play()
	_bark_cd -= delta
	if _bark_cd <= 0.0:
		_bark_cd = _rng.randf_range(DOG_BARK_MIN_GAP, DOG_BARK_MAX_GAP)
		# A distant stray answers the quiet — late-night window only.
		if _late_f > 0.5 and _bark_player != null and not _bark_player.playing:
			_bark_player.volume_db = _rng.randf_range(DOG_BARK_MIN_DB, DOG_BARK_MAX_DB) \
					- _duck * DIALOGUE_DUCK_DB
			_bark_player.pitch_scale = _rng.randf_range(0.88, 1.12)
			_bark_player.play()
	_distant_cd -= delta
	if _distant_cd > 0.0:
		return
	_distant_cd = _rng.randf_range(DISTANT_MIN_GAP, DISTANT_MAX_GAP) \
			* (1.0 + _night_f * 1.2 + _late_f * LATE_HONK_WIDEN)
	for p in _distant_players:
		if p.playing:
			continue
		p.volume_db = _rng.randf_range(DISTANT_MIN_DB, DISTANT_MAX_DB) \
				- _duck * DIALOGUE_DUCK_DB
		p.pitch_scale = _rng.randf_range(0.55, 0.85)
		# Phantom traffic takes turns on the voices (issue #187): mostly
		# the e-rickshaw fleet, sometimes a car or a scooter, and now a
		# far-off heavy-truck groan (issue #269) pitched into the floor.
		var roll := _rng.randf()
		if roll > 0.92:
			p.stream = _horn_voices["truck"]
			p.pitch_scale = _rng.randf_range(0.4, 0.55)
		elif roll > 0.85:
			p.stream = _horn_voices["car"]
		elif roll > 0.75:
			p.stream = _horn_voices["scooter"]
		else:
			p.stream = _horn_voices["auto"]
		p.play()
		break


func _prepare_muffle() -> void:
	## Interior muffle (issue #227): one low-pass filter on the Ambient
	## bus, cutoff parked wide open outdoors. The bus (not the players)
	## carries the effect so beds, rain, horns and foley all muffle
	## together the moment the player steps through a shop door.
	var idx := AudioServer.get_bus_index("Ambient")
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Ambient")
		AudioServer.set_bus_send(idx, "Master")
	for e in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, e) is AudioEffectLowPassFilter:
			_muffle = AudioServer.get_bus_effect(idx, e)
			return
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = OUTDOOR_CUTOFF_HZ
	_muffle.resonance = 0.4
	AudioServer.add_bus_effect(idx, _muffle)

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
	## Night palette (issue #214) rides the same clock, which is
	## sun-aligned since issue #185: day_t 0 = midnight, 0.5 = noon (the
	## old +6 h offset is gone — it had the beds quieting six hours early).
	var hours := fmod(t * 24.0, 24.0)
	_night_f = _night_factor(hours)
	_cricket_f = _night_window(hours, 19.5, 21.25, 4.75, 6.25)
	_late_f = _night_window(hours, 21.5, 23.0, 4.5, 6.5)
	_day_gain_db = -EVENING_DROP_DB * _night_f - LATE_NIGHT_THIN_DB * _late_f
	# Sacred soundscape (issue #267): the hour hand drives the windows;
	# a day_t drop is midnight, so the once-per-day flags reset with the
	# city's clock, not the player's session.
	_day_hours = hours
	if t < _prev_day_frac:
		_shankh_done = false
		_azan_done = false
	_prev_day_frac = t
	if not _shankh_done and hours >= 6.1 and hours < 6.9 \
			and _temple_player != null and not _temple_player.playing:
		_shankh_done = true
		_temple_player.stream = _shankh_wav
		_temple_player.volume_db = SHANKH_DB - _duck * DIALOGUE_DUCK_DB
		_temple_player.play()
	if not _azan_done and hours >= 17.5 and hours < 18.5 \
			and _mosque_player != null and not _mosque_player.playing:
		_azan_done = true
		_mosque_player.stream = _azan_wav
		_mosque_player.volume_db = AZAN_DB - _duck * DIALOGUE_DUCK_DB
		_mosque_player.play()

func _night_window(hours: float, dusk_start: float, dusk_end: float,
		dawn_start: float, dawn_end: float) -> float:
	## Night palette gate (issue #214): 0 by day, 1 through the wrapped
	## night span [dusk_end, dawn_start), linear shoulders on the way in
	## from dusk_start and out again to dawn_end.
	if hours >= dusk_end or hours < dawn_start:
		return 1.0
	if hours >= dusk_start:
		return (hours - dusk_start) / (dusk_end - dusk_start)
	if hours < dawn_end:
		return 1.0 - (hours - dawn_start) / (dawn_end - dawn_start)
	return 0.0


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
	if _traffic != null and _traffic.has_method("near_horns"):
		var near: Array = _traffic.near_horns(pos, 24.0, 3)
		if not near.is_empty():
			var d_near := pos.distance_to(near[0]["pos"])
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


func _horn_at(hit: Dictionary) -> void:
	## A real vehicle honks from its street position in its own voice
	## (issue #187): e-rickshaw buzz, car blast or scooter meep —
	## spatialised, distance-attenuated, never louder than the player's
	## own horn.
	for p in _spatial_horns:
		if p.playing:
			continue
		p.global_position = hit["pos"] + Vector3(0.0, 0.9, 0.0)
		var d := _player.global_position.distance_to(hit["pos"])
		p.volume_db = lerpf(SPATIAL_HORN_MAX_DB, SPATIAL_HORN_MIN_DB,
				clampf(d / 20.0, 0.0, 1.0)) - _duck * DIALOGUE_DUCK_DB
		p.stream = _horn_voices.get(String(hit["kind"]), _horn_voices["auto"])
		p.pitch_scale = _rng.randf_range(0.85, 1.05)
		p.play()
		return

func _tick_footsteps(delta: float) -> void:
	## The player's own feet (issue #187): stride cadence follows ground
	## speed, one voice per surface — paved lane, dirt verge, monsoon
	## wet — loudness stepping up from walk to sprint. Only while the
	## legend is visibly on foot (hidden means driving or riding).
	if _player == null or not is_instance_valid(_player) or not _player.visible:
		_step_dist = 0.0
		return
	var vel: Vector3 = _player.velocity
	var spd := Vector2(vel.x, vel.z).length()
	if spd < 0.8 or absf(vel.y) > 3.0:
		_step_dist = 0.0
		return
	_step_dist += spd * delta
	var f := clampf((spd - STEP_WALK_MPS) / (STEP_RUN_MPS - STEP_WALK_MPS), 0.0, 1.0)
	if _step_dist < lerpf(FOOTSTEP_STRIDE_MIN, FOOTSTEP_STRIDE_MAX, f):
		return
	_step_dist = 0.0
	var surface := "dirt"
	if _traffic != null and _traffic.has_method("on_road") \
				and _traffic.on_road(_player.global_position, 1.2):
		surface = "wet" if _wetness > 0.2 else "pave"
	var p := _step_players[_step_alt % _step_players.size()]
	_step_alt += 1
	p.stream = _step_voices[surface]
	p.volume_db = lerpf(FOOTSTEP_WALK_DB, FOOTSTEP_RUN_DB, f) \
			- _duck * DIALOGUE_DUCK_DB
	p.pitch_scale = _rng.randf_range(0.93, 1.07)
	p.play()


func loudness_profile() -> Array:
	## Worst-case per-channel levels for the scripted loudness check:
	## {name, peak_db, rms_db} measured on the synthesized buffers with
	## the channel's loudest volume_db applied (rain at full downpour,
	## thunder at THUNDER_MAX_DB, distant honks at DISTANT_MAX_DB).
	if _ambient_player == null:
		return []
	return [
		_measure("horn", _horn_voices["auto"], HORN_DB),
		_measure("horn_car", _horn_voices["car"], CAR_HORN_DB),
		_measure("horn_scooter", _horn_voices["scooter"], SCOOTER_HORN_DB),
		_measure("thunder", _thunder_player.stream, THUNDER_MAX_DB),
		_measure("thunk", _thunk_player.stream, THUNK_MAX_DB),
		_measure("ambient", _ambient_player.stream, AMBIENT_DB),
		_measure("rain", _rain_player.stream, RAIN_TOP_DB),
		_measure("distant_horn", _distant_players[0].stream, DISTANT_MAX_DB),
		_measure("murmur", _murmur_player.stream, MURMUR_DB),
		_measure("clatter", _clatter_player.stream, CLATTER_MAX_DB),
		_measure("board_clack", _clack_player.stream, -11.0),
		_measure("vendor_call", _call_player.stream, CALL_MAX_DB),
		_measure("spatial_horn", _spatial_horns[0].stream, SPATIAL_HORN_MAX_DB),
		_measure("footstep_pave", _step_voices["pave"], FOOTSTEP_RUN_DB),
		_measure("footstep_dirt", _step_voices["dirt"], FOOTSTEP_RUN_DB),
		_measure("footstep_wet", _step_voices["wet"], FOOTSTEP_RUN_DB),
		_measure("door_chime", _chime_player.stream, DOOR_CHIME_DB),
		_measure("purchase_blip", _blip_player.stream, PURCHASE_BLIP_DB),
		_measure("crickets", _cricket_player.stream, CRICKET_DB),
		_measure("dog_bark", _bark_player.stream, DOG_BARK_MAX_DB),
		_measure("temple_bell", _bell_wav, TEMPLE_BELL_MAX_DB),
		_measure("shankh", _shankh_wav, SHANKH_DB),
		_measure("azan_call", _azan_wav, AZAN_DB),
		_measure("engine", _engine_player.stream, ENGINE_FULL_DB),
		_measure("brake_squeal", _squeal_player.stream, BRAKE_SQUEAL_DB),
		_measure("indicator", _indicator_player.stream, INDICATOR_DB),
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

func _make_footstep(surface) -> AudioStreamWAV:
	## One stride of the player's own feet (issue #187), one texture per
	## surface: a sharp paved slap, a soft dirt scuff, a monsoon squelch
	## — each gone in ~160 ms so a fast cadence never stacks into buzz.
	var dur := 0.16 if String(surface) == "wet" else 0.11
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var n := _rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match String(surface):
			"pave":
				# Hard slap: bright click over a low body thump.
				lp += (n - lp) * 0.55
				phase += TAU * 95.0 / MIX_RATE
				s = lp * 0.8 + sin(phase) * 0.5
			"dirt":
					# Soft scuff: darker shuffle, no click.
				lp += (n - lp) * 0.16
				lp2 += (lp - lp2) * 0.5
				s = lp2 * 1.1
			"wet":
				# Squelch: splashy hiss over a downward heel chirp.
				lp += (n - lp) * 0.38
				phase += TAU * lerpf(240.0, 90.0, t / dur) / MIX_RATE
				s = lp * 0.7 + sin(phase) * 0.4
		var env: float = minf(t / 0.008, 1.0) * pow(maxf(1.0 - t / dur, 0.0), 1.8)
		var sample := int(clampf(s * env * 0.5, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_door_chime() -> AudioStreamWAV:
	## Shop-door ding-dong (issue #187): the two-note electronic bell over
	## every shop door in the city — E5 drops to C5, each note struck fast
	## and ringing out, done in half a second.
	var frames := int(MIX_RATE * 0.52)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var f := 659.25 if t < 0.24 else 523.25
		var note_t := t if t < 0.24 else t - 0.24
		phase += TAU * f / MIX_RATE
		var env: float = minf(note_t / 0.006, 1.0) * pow(maxf(1.0 - note_t / 0.26, 0.0), 2.0)
		var wave := sin(phase) * 0.75 + sin(phase * 2.0) * 0.18 + sin(phase * 3.0) * 0.07
		var sample := int(clampf(wave * env * 0.42, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_purchase_blip() -> AudioStreamWAV:
	## Cash pip (issue #187): two quick register notes — paisa left the
	## wallet, HP on the way. A quarter second, gone before the toast.
	var frames := int(MIX_RATE * 0.28)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var f := 1318.5 if t < 0.09 else 987.77
		var note_t := t if t < 0.09 else t - 0.09
		phase += TAU * f / MIX_RATE
		var env: float = minf(note_t / 0.004, 1.0) * pow(maxf(1.0 - note_t / 0.18, 0.0), 2.2)
		var wave := sin(phase) * 0.8 + sin(phase * 2.0) * 0.2
		var sample := int(clampf(wave * env * 0.4, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_car_horn() -> AudioStreamWAV:
	## Car/van blast (issue #187): a fuller twin tone than the e-rickshaw
	## buzz — 415+494 Hz paired sines with a second-harmonic edge, the
	## round "paarp" of a proper car horn.
	var frames := int(MIX_RATE * 0.45)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var pa := 0.0
	var pb := 0.0
	for i in frames:
		pa += TAU * 415.3 / MIX_RATE
		pb += TAU * 493.9 / MIX_RATE
		var wave := sin(pa) * 0.45 + sin(pb) * 0.45 + sin(pa * 2.0) * 0.1
		var env := 1.0
		var attack: float = MIX_RATE * 0.012
		var release: float = MIX_RATE * 0.06
		if i < attack:
			env = i / attack
		elif i > frames - release:
			env = (frames - i) / release
		var sample := int(clampf(wave * env * 0.5, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_scooter_horn() -> AudioStreamWAV:
	## Scooter meep (issue #187): one thin bright ~940 Hz tone, short and
	## polite — the two-wheeler's chirp against the big horns.
	var frames := int(MIX_RATE * 0.22)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		phase += TAU * 940.0 / MIX_RATE
		var wave := signf(sin(phase)) * 0.22 + sin(phase) * 0.6
		var env := 1.0
		var attack: float = MIX_RATE * 0.006
		var release: float = MIX_RATE * 0.05
		if i < attack:
			env = i / attack
		elif i > frames - release:
			env = (frames - i) / release
		var sample := int(clampf(wave * env * 0.4, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

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


func _make_board_clack() -> AudioStreamWAV:
	## Split-flap row flip (issue #184): sharp 860 Hz sin^4 knock with
	## a low sub-thud and a 3 ms noise transient — mechanical board
	## clatter, gone in 80 ms.
	var frames := int(MIX_RATE * 0.08)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	var sub := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		phase += TAU * 860.0 / MIX_RATE
		sub += TAU * 190.0 / MIX_RATE
		var s := pow(absf(sin(phase)), 4.0) 				* pow(maxf(1.0 - t / 0.08, 0.0), 2.2)
		s += sin(sub) * 0.35 * pow(maxf(1.0 - t / 0.05, 0.0), 3.0)
		if t < 0.003:
			s += _rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.003) * 0.5
		var sample := int(clampf(s * 0.6, -1.0, 1.0) * 32767.0)
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


func _make_crickets() -> AudioStreamWAV:
	## Loopable night cricket bed (issue #214): two stridulating voices —
	## pulsed ~4.1/4.5 kHz sine trills, three pulses per chirp on slightly
	## different periods, so the chorus breathes and never machine-guns.
	## Head crossfades with tail material for a seamless loop.
	var loop_len := int(MIX_RATE * CRICKET_SECONDS)
	var xfade := int(MIX_RATE * XFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + xfade)
	var periods := [0.58, 0.83]
	var carriers := [4120.0, 4540.0]
	var offsets := [0.11, 0.37]
	for i in raw.size():
		var t := float(i) / MIX_RATE
		var s := 0.0
		for voice in 2:
			var chirp_t := fmod(t + offsets[voice], periods[voice])
			var pulse := 0.0
			for p in 3:
				var pt := chirp_t - float(p) * 0.032
				if pt >= 0.0 and pt < 0.021:
					pulse = maxf(pulse, pow(sin(PI * pt / 0.021), 2.0))
			s += sin(TAU * carriers[voice] * t) * pulse
		raw[i] = s
	var peak := 0.001
	for v in raw:
		peak = maxf(peak, absf(v))
	var gain := 0.22 / peak
	var bytes := PackedByteArray()
	bytes.resize(loop_len * 2)
	for i in loop_len:
		var v: float = raw[i]
		if i < xfade:
			var w := float(i) / xfade
			v = raw[i] * w + raw[i + loop_len] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * gain, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)

func _make_dog_bark() -> AudioStreamWAV:
	## One-shot distant dog bark (issue #214): two muffled descending
	## woofs — sawtooth body with noise grit, then one-pole low-passed so
	## it reads as a stray down the block, not a dog in the room.
	var frames := int(MIX_RATE * 0.78)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var lp := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for b in 2:
			var bt := t - (0.05 if b == 0 else 0.34)
			var loud := 1.0 if b == 0 else 0.6
			if bt >= 0.0 and bt < 0.16:
				# Descending woof, 330 -> 190 Hz — phase integrated by hand.
				var k := (330.0 - 190.0) / 0.16
				var ph := TAU * (330.0 * bt - k * bt * bt * 0.5)
				var env := minf(bt / 0.009, 1.0) \
						* pow(maxf(1.0 - bt / 0.16, 0.0), 1.7)
				s += (signf(sin(ph)) * 0.7 + sin(ph) * 0.3 \
						+ _rng.randf_range(-1.0, 1.0) * 0.18) * env * loud
		lp += (s - lp) * 0.14
		var sample := int(clampf(lp * 0.5, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_temple_bell() -> AudioStreamWAV:
	## Single temple-bell strike (issue #267): classic inharmonic bell
	## partials — hum, prime, tierce, quint, nominal — each ringing out
	## at its own rate over a bright strike transient, so the small brass
	## bell on the mandir gate reads from a lane away.
	var dur := 3.0
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	# Partial table: frequency ratio, amplitude, decay seconds.
	var partials := [
		[0.5, 0.30, 2.8], [1.0, 0.45, 2.3], [1.2, 0.22, 1.7],
		[1.5, 0.20, 1.35], [2.0, 0.12, 1.0], [2.76, 0.07, 0.55],
	]
	var f0 := 329.63
	var phases := []
	phases.resize(partials.size())
	for i in phases.size():
		phases[i] = _rng.randf() * TAU
	var strike := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for p in partials.size():
			var ratio := float(partials[p][0])
			var amp := float(partials[p][1])
			var dec := float(partials[p][2])
			phases[p] += TAU * f0 * ratio / MIX_RATE
			s += sin(phases[p]) * amp * pow(maxf(1.0 - t / dec, 0.0), 1.9)
		# Strike transient: one-pole lowpassed noise in the first 30 ms.
		strike += (_rng.randf_range(-1.0, 1.0) - strike) * 0.55
		if t < 0.03:
			s += strike * 0.22 * (1.0 - t / 0.03)
		var sample := int(clampf(s * 0.55, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_shankh() -> AudioStreamWAV:
	## Conch-shell swell (issue #267): the morning shankh that opens the
	## temple window — a soft, breathy B-flat with a slow swell, a gentle
	## vibrato, and a droop as the breath runs out.
	var dur := 3.4
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	var breath := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		# Pitch: steady Bb3, vibrato fading in, drooping over the tail.
		var droop := lerpf(1.0, 0.93,
				clampf((t - (dur - 0.45)) / 0.45, 0.0, 1.0))
		var f := 233.08 * droop \
				* (1.0 + 0.006 * minf(t / 1.2, 1.0) * sin(TAU * 4.7 * t))
		phase += TAU * f / MIX_RATE
		var env := pow(minf(t / 0.7, 1.0), 2.0) \
				* pow(maxf(1.0 - t / dur, 0.0), 1.4)
		var wave := sin(phase) + sin(phase * 2.0) * 0.5 \
				+ sin(phase * 3.0) * 0.18
		breath += (_rng.randf_range(-1.0, 1.0) - breath) * 0.16
		wave += breath * 0.14
		var sample := int(clampf(wave * env * 0.42, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_azan_call() -> AudioStreamWAV:
	## Evening call phrase (issue #267): a short, respectful, fully
	## synthesized melodic line — a soft reed-like tone gliding between
	## five notes, rising to a held peak and settling home. Pure
	## abstraction: no recited text, no samples; distance-attenuated at
	## the mosque anchor and ducked under dialogue.
	var notes := [
		[0.00, 293.66], [1.30, 349.23], [2.90, 440.00],
		[4.50, 392.00], [6.00, 349.23], [7.30, 293.66],
	]
	var dur := 8.8
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		# Frequency curve: hold each note, glide 0.22 s into the next.
		var f := 293.66
		for n in notes.size():
			var start := float(notes[n][0])
			var freq := float(notes[n][1])
			if t < start:
				break
			var glide := clampf((t - start) / 0.22, 0.0, 1.0)
			f = freq if glide >= 1.0 or n == 0 \
					else lerpf(float(notes[n - 1][1]), freq, glide)
		# Vibrato fades in with the phrase and stays gentle.
		f *= 1.0 + 0.007 * minf(t / 0.9, 1.0) * sin(TAU * 5.4 * t)
		phase += TAU * f / MIX_RATE
		var wave := sin(phase) + sin(phase * 2.0) * 0.28 \
				+ sin(phase * 3.0) * 0.10
		var env := minf(t / 0.35, 1.0) * pow(maxf(1.0 - t / dur, 0.0), 1.6)
		var sample := int(clampf(wave * env * 0.34, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func set_sacred_anchors(mandir: Vector3, mosque: Vector3) -> void:
	## World anchors for the sacred voices (issue #267): the temple-gate
	## cluster on the mandir lane, and the mosque side of the same block.
	## Players default to the world origin until main.gd hands over the
	## real corners, so the mix is safe even before the map exists.
	if _temple_player != null:
		_temple_player.global_position = mandir
	if _mosque_player != null:
		_mosque_player.global_position = mosque

func _make_engine_voice() -> AudioStreamWAV:
	## Loopable engine hum (issue #213): a 55 Hz crank voice — sawtooth
	## body, firing-pulse throb at twice the crank, a breath of
	## combustion grit — loop-perfect over 2 s (integer cycles) with a
	## crossfaded tail for the noise. Pitched per kind at play time, so
	## the scooter buzzes high and the van drones low off one buffer.
	var loop_len := int(MIX_RATE * 2.0)
	var xfade := int(MIX_RATE * XFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(loop_len + xfade)
	var ph := 0.0
	var lp := 0.0
	for i in raw.size():
		ph += TAU * 55.0 / MIX_RATE
		var crank := 2.0 * fmod(ph / TAU, 1.0) - 1.0
		var throb := 0.68 + 0.32 * sin(2.0 * ph + 0.6)
		var n := _rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.22
		var grit := (n - lp) * 0.6  # highs left after the one-pole
		raw[i] = tanh((crank * 0.8 + sin(ph * 3.0) * 0.18
				+ grit * 0.22 * throb) * throb * 1.6)
	var peak := 0.001
	for v in raw:
		peak = maxf(peak, absf(v))
	var gain := 0.30 / peak
	var bytes := PackedByteArray()
	bytes.resize(loop_len * 2)
	for i in loop_len:
		var v: float = raw[i]
		if i < xfade:
			var w := float(i) / xfade
			v = raw[i] * w + raw[i + loop_len] * (1.0 - w)
		bytes.encode_s16(i * 2, int(clampf(v * gain, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)

func _make_brake_squeal() -> AudioStreamWAV:
	## One-shot brake pinch (issue #213): the pads bite from speed — a
	## 2.6-to-1.8 kHz slide with friction hiss, gone in 350 ms and
	## pinned under the engine hum in the mix.
	var dur := 0.35
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	for i in frames:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(2600.0, 1800.0, t / dur) / MIX_RATE
		var env := minf(t / 0.02, 1.0) * pow(maxf(1.0 - t / dur, 0.0), 1.8)
		var squeal := sin(phase) * 0.8 + sin(phase * 2.01) * 0.2
		squeal += _rng.randf_range(-1.0, 1.0) * 0.25
		var sample := int(clampf(squeal * env * 0.30, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)

func _make_indicator() -> AudioStreamWAV:
	## Loopable indicator relay (issue #213): tick...tock at ~86 bpm —
	## a bright click answered half a beat later by a duller one, the
	## dashboard habit of hard cornering at speed. Bursts stay clear of
	## the loop seam, so no crossfade is needed.
	var period := 0.7
	var frames := int(MIX_RATE * period)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for k in 2:
			var bt := t - (0.02 if k == 0 else 0.02 + period * 0.5)
			var f := 2350.0 if k == 0 else 1750.0
			if bt >= 0.0 and bt < 0.045:
				s += sin(TAU * f * bt) * pow(maxf(1.0 - bt / 0.045, 0.0), 2.4)
		var sample := int(clampf(s * 0.45, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, true)

static func make_siren() -> AudioStreamWAV:
	## Ambulance two-tone loop (issue #215): 0.42 s at 700 Hz then
	## 0.42 s at 935 Hz — the street siren — rounder than the rickshaw
	## horn and pinned under it (peak 0.38 vs 0.45-0.50). Loops for the
	## whole run; the ambulance node plays it spatially at SIREN_DB.
	var half := int(MIX_RATE * 0.42)
	var bytes := PackedByteArray()
	bytes.resize(half * 4)
	var phase := 0.0
	for i in half * 2:
		phase += TAU * (700.0 if i < half else 935.0) / MIX_RATE
		# Sine body with a thin square edge: a siren speaker, not a buzz.
		var wave := sin(phase) * 0.6 + signf(sin(phase)) * 0.18
		var half_i: int = i % half
		var env := 1.0
		var attack: float = MIX_RATE * 0.01
		var release: float = MIX_RATE * 0.03
		if half_i < attack:
			env = half_i / attack
		elif half_i > half - release:
			env = (half - half_i) / release
		var sample := int(clampf(wave * env * 0.38, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, true)


static func make_relay_click() -> AudioStreamWAV:
	## Hazard-relay click (issue #216): a single 45 ms snap at 2.1 kHz
	## with a fast decay — the soft tick under every hazard flash of a
	## kerbside breakdown. One-shot; the breakdown node replays it on
	## each rising blink, so there is no loop seam at any flash rate.
	var dur := 0.045
	var frames := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := pow(maxf(1.0 - t / dur, 0.0), 2.6)
		var s := sin(TAU * 2100.0 * t) * 0.85
		s += sin(TAU * 3400.0 * t) * 0.15
		var sample := int(clampf(s * env * 0.22, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes, false)


static func _wav(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
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
