extends Node
## Efeitos sonoros sintetizados em tempo de execução (placeholder até a trilha final):
## "card" (estalo de carta), "chip" (ficha de cassino), "combo" (arpejo), "win" / "lose",
## e um drone atmosférico grave como fundo musical.

const RATE := 22050

var _streams := {}
var _players: Array = []
var _music: AudioStreamPlayer


func _ready() -> void:
	_streams["card"] = _noise_burst(0.06, 0.5)
	_streams["chip"] = _tones([1760.0, 2637.0], 0.05, 0.35)
	_streams["tick"] = _tones([1320.0], 0.03, 0.25)
	_streams["combo"] = _tones([523.25, 659.25, 783.99, 1046.5], 0.08, 0.35)
	_streams["win"] = _tones([392.0, 523.25, 659.25, 783.99, 1046.5], 0.11, 0.35)
	_streams["lose"] = _tones([329.63, 293.66, 246.94, 196.0], 0.16, 0.3)
	_streams["boost"] = _tones([392.0, 523.25, 783.99], 0.06, 0.35)
	_streams["flip"] = _noise_burst(0.05, 0.4)
	_streams["jackpot"] = _tones([523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0], 0.07, 0.35)
	_streams["buy"] = _tones([987.77, 1318.5], 0.07, 0.3)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _drone()
	_music.volume_db = -14.0
	add_child(_music)
	if DisplayServer.get_name() != "headless":
		_music.play()


func play(name: String, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.play()
			return


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _noise_burst(duration: float, gain: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in range(n):
		var env := pow(1.0 - float(i) / n, 3.0)
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.35)
		s[i] = prev * env * gain
	return _wav(s)


func _tones(freqs: Array, step: float, gain: float) -> AudioStreamWAV:
	var per := int(step * RATE)
	var tail := int(0.12 * RATE)
	var s := PackedFloat32Array()
	s.resize(per * freqs.size() + tail)
	for k in range(freqs.size()):
		var f: float = freqs[k]
		var length := per + tail
		for i in range(length):
			var idx := k * per + i
			if idx >= s.size():
				break
			var env := exp(-6.0 * float(i) / length)
			s[idx] += sin(TAU * f * i / RATE) * env * gain * 0.6 + sin(TAU * f * 2.0 * i / RATE) * env * gain * 0.15
	return _wav(s)


func _drone() -> AudioStreamWAV:
	var seconds := 8.0
	var n := int(seconds * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * t / seconds)
		s[i] = (sin(TAU * 55.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.1 * lfo + sin(TAU * 110.25 * t) * 0.05 * (1.0 - lfo))
	return _wav(s, true)
