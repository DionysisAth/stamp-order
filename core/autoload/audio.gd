extends Node
## Layered, slightly pitch-varied sounds. Placeholder sounds are synthesised at
## startup so the MVP ships without audio assets; swap in recorded samples by
## pointing the streams at files in res://audio/.

const MIX_RATE := 22050
const VOICES := 6

var _thumps: Array[AudioStreamWAV] = []
var _click: AudioStreamWAV
var _undo: AudioStreamWAV
var _win: AudioStreamWAV
var _error: AudioStreamWAV
var _rotate: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for f in [118.0, 132.0, 146.0, 160.0]:
		_thumps.append(_synth(0.22, _thump_fn(f)))
	_click = _synth(0.05, func(t: float) -> float: return sin(TAU * 1500.0 * t) * exp(-t * 110.0) * 0.35)
	_rotate = _synth(0.09, func(t: float) -> float: return sin(TAU * (700.0 + 900.0 * t) * t) * exp(-t * 40.0) * 0.25)
	_undo = _synth(0.14, func(t: float) -> float: return sin(TAU * (520.0 - 1200.0 * t) * t) * exp(-t * 22.0) * 0.3)
	_error = _synth(0.3, func(t: float) -> float:
		var f := 220.0 if t < 0.13 else 175.0
		return sin(TAU * f * t) * exp(-fmod(t, 0.15) * 14.0) * 0.3)
	_win = _synth(1.1, _chime_fn())
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play_press() -> void:
	_play(_thumps.pick_random(), 0.05)


func play_click() -> void:
	_play(_click, 0.03)


func play_rotate() -> void:
	_play(_rotate, 0.04)


func play_undo() -> void:
	_play(_undo, 0.03)


func play_error() -> void:
	_play(_error, 0.0)


func play_win() -> void:
	_play(_win, 0.0)


func _play(stream: AudioStream, pitch_variation: float) -> void:
	if not bool(Save.get_setting("sound")):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


func _thump_fn(freq: float) -> Callable:
	var noise := RandomNumberGenerator.new()
	noise.seed = int(freq)
	return func(t: float) -> float:
		var body := sin(TAU * freq * t * (1.0 - t * 1.6)) * exp(-t * 26.0)
		var slap := noise.randf_range(-1.0, 1.0) * exp(-t * 90.0)
		return body * 0.75 + slap * 0.3


func _chime_fn() -> Callable:
	var notes := [[0.0, 523.25], [0.12, 659.25], [0.24, 783.99], [0.38, 1046.5]]
	return func(t: float) -> float:
		var v := 0.0
		for n in notes:
			var dt: float = t - n[0]
			if dt >= 0.0:
				v += (sin(TAU * n[1] * dt) + 0.3 * sin(TAU * n[1] * 2.0 * dt)) * exp(-dt * 5.0)
		return v * 0.18


func _synth(seconds: float, fn: Callable) -> AudioStreamWAV:
	var frames := int(seconds * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / MIX_RATE
		var fade := minf(1.0, float(frames - i) / (MIX_RATE * 0.01))
		var v: float = clampf(fn.call(t) * fade, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
