class_name PinPanSfx
extends RefCounted
## Игровые звуки Пролога и Акта I. Роли звучат по-разному:
## Pin — низкое дерево, Pan — воздух и струна.

var _players: Array[AudioStreamPlayer] = []
var _streams := {}
var _tension_cache := {}


func setup(parent: Node) -> void:
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		parent.add_child(p)
		_players.append(p)
	_streams["jump_pin"] = Synth.tone(185.0, 140.0, 0.09, 0.10, 0.002, 0.06, 0.5)
	_streams["jump_pan"] = Synth.tone(255.0, 330.0, 0.08, 0.09, 0.002, 0.04, 0.3)
	_streams["bind"] = Synth.tone(155.0, 150.0, 0.22, 0.14, 0.010, 0.02, 0.55)
	_streams["anchor_release"] = Synth.tone(205.0, 260.0, 0.12, 0.09, 0.004, 0.03, 0.3)
	_streams["cut"] = Synth.noise(0.10, 0.13, 0.5, 0.002)
	_streams["ignite"] = Synth.tone(560.0, 740.0, 0.24, 0.14, 0.005, 0.10, 0.3)
	_streams["door"] = Synth.tone(220.0, 220.0, 0.45, 0.10, 0.02, 0.01, 0.8)
	_streams["memory"] = Synth.tone(520.0, 660.0, 0.32, 0.10, 0.012, 0.0, 0.25)
	_streams["fabric_snap"] = Synth.tone(95.0, 60.0, 0.24, 0.15, 0.005, 0.22, 0.6)
	_streams["danger"] = Synth.tone(70.0, 54.0, 0.26, 0.13, 0.008, 0.05, 0.6)
	_streams["checkpoint"] = Synth.tone(330.0, 300.0, 0.18, 0.08, 0.008, 0.02, 0.3)
	_streams["heartbeat"] = Synth.tone(52.0, 40.0, 0.12, 0.20, 0.010, 0.0, 0.6)
	_streams["land"] = Synth.tone(60.0, 36.0, 0.30, 0.16, 0.004, 0.16, 0.6)
	_streams["whoosh"] = Synth.noise(1.8, 0.11, 0.05, 0.8)
	_streams["flash"] = Synth.noise(0.5, 0.06, 0.10, 0.05)
	_streams["gust"] = Synth.noise(1.2, 0.07, 0.08, 0.4)
	for step in range(8):
		var freq := lerpf(120.0, 900.0, step / 7.0)
		_tension_cache[step] = Synth.tone(freq, freq * 1.06, 0.16, 0.05, 0.01, 0.0, 0.1)


func play(name: String) -> void:
	var stream: AudioStreamWAV = _streams.get(name)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


## Звук натяжения нити: высота растёт вместе с tension (0..1) — нить «поёт».
func play_tension(tension: float) -> void:
	var step := clampi(int(tension * 8.0), 0, 7)
	var stream: AudioStreamWAV = _tension_cache[step]
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
