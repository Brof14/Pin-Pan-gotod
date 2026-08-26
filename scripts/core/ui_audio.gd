class_name PinPanUIAudio
extends RefCounted

enum Event { HOVER, PIN_FOCUS, PAN_FOCUS, SELECT, OPEN, BACK, ERROR, AFK }

var _player: AudioStreamPlayer
var _settings: PinPanSettings
var _last_hover_time := -1.0

func setup(player: AudioStreamPlayer, settings: PinPanSettings) -> void:
	_player = player
	_settings = settings

func play(event: Event, time: float = 0.0) -> void:
	if _player == null or _settings == null:
		return
	var volume := float(_settings.master) / 100.0 * float(_settings.sfx) / 100.0
	if volume <= 0.001:
		return
	if event == Event.HOVER:
		if time - _last_hover_time < 0.08:
			return
		_last_hover_time = time
	match event:
		Event.HOVER: _tone(420.0, 0.15, 0.06, volume, -24.0)
		Event.PIN_FOCUS: _tone(180.0, 0.06, 0.08, volume, -26.0)
		Event.PAN_FOCUS: _gliss(280.0, 520.0, 0.18, 0.07, volume, -26.0)
		Event.SELECT: _tone(320.0, 0.23, 0.14, volume, -18.0)
		Event.OPEN: _noise_burst(0.40, 0.10, volume, -22.0)
		Event.BACK: _noise_burst(0.18, 0.08, volume, -24.0)
		Event.ERROR: _tone(95.0, 0.22, 0.12, volume, -20.0)
		Event.AFK: _gliss(240.0, 360.0, 0.60, 0.06, volume, -26.0)

func _tone(freq: float, duration: float, gain: float, volume: float, db_offset: float) -> void:
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var env := 1.0 - float(i) / float(samples)
		env *= env
		var value := int(sin(TAU * freq * float(i) / float(rate)) * 32767.0 * gain * env)
		data.encode_s16(i * 2, value)
	_emit(data, rate, volume, db_offset)

func _gliss(freq_a: float, freq_b: float, duration: float, gain: float, volume: float, db_offset: float) -> void:
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := lerpf(freq_a, freq_b, t)
		var env := 1.0 - t
		var value := int(sin(TAU * freq * float(i) / float(rate)) * 32767.0 * gain * env)
		data.encode_s16(i * 2, value)
	_emit(data, rate, volume, db_offset)

func _noise_burst(duration: float, gain: float, volume: float, db_offset: float) -> void:
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	for i in range(samples):
		var env := 1.0 - float(i) / float(samples)
		var value := int(rng.randf_range(-1.0, 1.0) * 32767.0 * gain * env * 0.35)
		data.encode_s16(i * 2, value)
	_emit(data, rate, volume, db_offset)

func _emit(data: PackedByteArray, rate: int, volume: float, db_offset: float) -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	_player.stream = stream
	_player.volume_db = linear_to_db(maxf(0.001, volume)) + db_offset
	_player.play()
