class_name PinPanUIAudio
extends RefCounted
## UI-звуки меню. Голоса Pin и Pan различимы: у Pin деревянный щелчок, у Pan — глиссандо.
## На каждое событие фон меню приглушается (duck), релиз 300 мс — делает Core.duck().

enum Event { HOVER, PIN_FOCUS, PAN_FOCUS, SELECT, OPEN, BACK, ERROR, TOGGLE, SLIDER }

var _players: Array[AudioStreamPlayer] = []
var _streams := {}


func setup(parent: Node, duck_callback: Callable) -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		parent.add_child(p)
		_players.append(p)
	_streams[Event.HOVER] = Synth.tone(660.0, 640.0, 0.07, 0.045, 0.004, 0.02, 0.15)
	_streams[Event.PIN_FOCUS] = Synth.tone(190.0, 165.0, 0.06, 0.10, 0.002, 0.10, 0.4)
	_streams[Event.PAN_FOCUS] = Synth.tone(520.0, 780.0, 0.18, 0.055, 0.012, 0.0, 0.08)
	_streams[Event.SELECT] = Synth.tone(320.0, 235.0, 0.16, 0.12, 0.003, 0.05, 0.35)
	_streams[Event.OPEN] = Synth.noise(0.16, 0.06, 0.30)
	_streams[Event.BACK] = Synth.noise(0.13, 0.05, 0.22)
	_streams[Event.ERROR] = Synth.tone(120.0, 82.0, 0.22, 0.11, 0.010, 0.03, 0.5)
	_streams[Event.TOGGLE] = Synth.tone(440.0, 430.0, 0.05, 0.05, 0.002, 0.03, 0.2)
	_streams[Event.SLIDER] = Synth.tone(520.0, 505.0, 0.035, 0.035, 0.002, 0.04, 0.15)
	_duck_callback = duck_callback


var _duck_callback := Callable()


func play(event: int) -> void:
	if _duck_callback.is_valid():
		_duck_callback.call()
	var stream: AudioStreamWAV = _streams.get(event)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()
