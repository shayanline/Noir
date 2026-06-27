extends Node
## Native sound director. Looping beds (music, ambience, rain) crossfade, one-shots are
## pooled and can be ducked, footstep-style loops hold while an animation runs. Carries over
## every Inkfall sound. Nothing plays until start() so audio never leaks between screens.

const MUSIC := {
	"burning_silence": "res://audio/music/burning_silence.mp3",
	"piano_noir": "res://audio/music/piano_noir.wav",
	"sad_jazz": "res://audio/music/sad_jazz.wav",
}
const AMBIENCE := {
	"street": "res://audio/ambience/amb_street.mp3",
	"rooftop": "res://audio/ambience/amb_rooftop.mp3",
}
const RAIN := "res://audio/rain.mp3"
const SFX := {
	"gunshot": "res://audio/sfx/gunshot.mp3",
	"shell": "res://audio/sfx/shell.mp3",
	"hammer": "res://audio/sfx/hammer.mp3",
	"footstep": "res://audio/sfx/footstep.mp3",
	"lidopen": "res://audio/sfx/lidopen.mp3",
	"flint": "res://audio/sfx/flint.mp3",
	"neon": "res://audio/sfx/neon_crackle.mp3",
	"thunder": "res://audio/sfx/thunder.mp3",
	"whoosh": "res://audio/sfx/whoosh.mp3",
}

const SFX_VOICES := 6          # round-robin one-shot players
const SILENCE_DB := -60.0

var _muted := false
var _started := false

var _music: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _music_vol := 0.5
var _rain_vol := 0.16
var _amb_vol := 0.4

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _loops := {}               # name -> AudioStreamPlayer held while active


func _ready() -> void:
	_music = _make_loop_player()
	_rain = _make_loop_player()
	_amb = _make_loop_player()
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)


func _make_loop_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = SILENCE_DB
	add_child(p)
	return p


static func _linear_to_db(v: float) -> float:
	return SILENCE_DB if v <= 0.0001 else linear_to_db(v)


func _load_loop(path: String) -> AudioStream:
	var s := load(path)
	if s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s


func _fade(p: AudioStreamPlayer, target_linear: float, dur: float) -> void:
	if p == null:
		return
	var target_db := _linear_to_db(0.0 if _muted else target_linear)
	if dur <= 0.0:
		p.volume_db = target_db
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, dur)


# --- beds ---------------------------------------------------------------

func start() -> void:
	_started = true


func play_music(key: String, vol := 0.5) -> void:
	if not MUSIC.has(key):
		return
	_music_vol = vol
	_music.stream = _load_loop(MUSIC[key])
	_music.volume_db = SILENCE_DB
	_music.play()
	if _started:
		_fade(_music, vol, 1.2)


func enter_scene(ambience := "", indoor := false, ambience_vol := 0.4, rain_vol := 0.16) -> void:
	## crossfade ambience + rain for a new act, fade any ringing one-shots and held loops
	duck(0.5)
	stop_loops(0.45)
	_amb_vol = ambience_vol
	if ambience != "" and AMBIENCE.has(ambience):
		_amb.stream = _load_loop(AMBIENCE[ambience])
		_amb.play()
		_fade(_amb, ambience_vol, 0.6)
	else:
		_fade(_amb, 0.0, 0.5)
	_rain_vol = rain_vol
	if not indoor:
		if _rain.stream == null:
			_rain.stream = _load_loop(RAIN)
			_rain.play()
		_fade(_rain, rain_vol, 0.6)
	else:
		_fade(_rain, 0.0, 0.6)


# --- one-shots ----------------------------------------------------------

func play(key: String, vol_scale := 1.0, pitch := 1.0) -> void:
	if _muted or not _started or not SFX.has(key):
		return
	var p := _sfx_pool[_sfx_next % _sfx_pool.size()]
	_sfx_next += 1
	p.stream = load(SFX[key])
	p.pitch_scale = pitch
	p.volume_db = _linear_to_db(0.7 * vol_scale)
	p.play()


func duck(dur := 0.6) -> void:
	for p in _sfx_pool:
		if p.playing:
			_fade(p, 0.0, dur)


# loops tied to an animation (footsteps): held full while active, faded when it stops
func set_loop(key: String, active: bool) -> void:
	if not SFX.has(key):
		return
	if active:
		var p: AudioStreamPlayer = _loops.get(key)
		if p == null:
			p = _make_loop_player()
			_loops[key] = p
			p.stream = _load_loop(SFX[key])
			p.play()
		p.volume_db = _linear_to_db(0.0 if _muted else 0.6)
	elif _loops.has(key):
		_fade(_loops[key], 0.0, 0.4)


func stop_loops(dur := 0.45) -> void:
	for key in _loops:
		_fade(_loops[key], 0.0, dur)


# --- mute ---------------------------------------------------------------

func toggle_mute() -> bool:
	_muted = not _muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)
	return not _muted


func is_on() -> bool:
	return not _muted


# --- pause + reset ------------------------------------------------------

## freeze or thaw every player so the pause menu is a true pause of sound, not just a duck.
func set_suspended(s: bool) -> void:
	for p in [_music, _rain, _amb]:
		p.stream_paused = s
	for key in _loops:
		_loops[key].stream_paused = s
	for p in _sfx_pool:
		p.stream_paused = s


## stop everything and return to the unstarted state, so leaving a story leaves no sound ringing.
func reset() -> void:
	set_suspended(false)
	for p in [_music, _rain, _amb]:
		p.stop()
		p.stream = null
		p.volume_db = SILENCE_DB
	for key in _loops:
		_loops[key].stop()
	_loops.clear()
	for p in _sfx_pool:
		p.stop()
	_started = false


# --- named convenience shots (match Inkfall) ----------------------------

func gun() -> void: play("gunshot", 1.0, randf_range(0.97, 1.03))
func gun_cock() -> void: play("hammer")
func shell_clink() -> void: play("shell", randf_range(0.8, 1.1), randf_range(0.95, 1.05))
func thunder() -> void: play("thunder")
func neon_zap() -> void: play("neon")
func whoosh() -> void: play("whoosh")
func lid_open() -> void: play("lidopen")
func flint() -> void: play("flint")
