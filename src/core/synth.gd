class_name Synth
extends RefCounted
## Процедурный синтез звуков: ни одного аудиофайла в проекте, всё строится на старте.
## 22050 Гц моно — этого достаточно с запасом для UI-щелчков и тёплых тонов.

const RATE := 22050


## Тон с глиссандо, гармониками, короткой атакой и экспоненциальным затуханием.
## noise — доля шума в сигнале (щелчки), harmonic — вес второй/третьей гармоники.
static func tone(freq0: float, freq1: float, dur: float, gain: float, attack := 0.006, noise := 0.0, harmonic := 0.3) -> AudioStreamWAV:
	var samples := maxi(1, int(dur * RATE))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(RATE)
		var k := float(i) / float(samples)
		phase += TAU * lerpf(freq0, freq1, k) / float(RATE)
		var env := minf(t / maxf(attack, 0.001), 1.0) * pow(1.0 - k, 1.6)
		var shaper := sin(phase) + harmonic * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)
		if noise > 0.0:
			shaper += (randf() * 2.0 - 1.0) * noise
		data.encode_s16(i * 2, int(clampf(shaper * env * gain, -1.0, 1.0) * 32767.0))
	return _wrap(data)


## Шумовой всплеск с однополюсным фильтром — шорохи, свисты, разрезы.
static func noise(dur: float, gain: float, cutoff := 0.12, attack := 0.01) -> AudioStreamWAV:
	var samples := maxi(1, int(dur * RATE))
	var data := PackedByteArray()
	data.resize(samples * 2)
	var y := 0.0
	for i in range(samples):
		var t := float(i) / float(RATE)
		var k := float(i) / float(samples)
		y += cutoff * ((randf() * 2.0 - 1.0) - y)
		var env := minf(t / maxf(attack, 0.001), 1.0) * pow(1.0 - k, 1.2)
		data.encode_s16(i * 2, int(clampf(y * env * gain * 2.4, -1.0, 1.0) * 32767.0))
	return _wrap(data)


## Тёплая тишина мастерской: минорное трезвучие с медленным дыханием + воздух.
## Петля замыкается кроссфейдом хвоста в голову — без щелчка на стыке.
static func pad_loop(seconds := 10.0) -> AudioStreamWAV:
	var samples := int(seconds * RATE)
	var chord := [[110.0, 0.045, 0.0], [130.81, 0.030, 2.1], [164.81, 0.024, 4.2]]
	var data := PackedByteArray()
	data.resize(samples * 2)
	var noise_y := 0.0
	var head := PackedFloat32Array()
	head.resize(int(RATE))
	for i in range(samples):
		var t := float(i) / float(RATE)
		var value := 0.0
		for voice in chord:
			var lfo := 0.78 + 0.22 * sin(TAU * t / seconds + float(voice[2]))
			value += sin(TAU * float(voice[0]) * t) * float(voice[1]) * lfo
		noise_y += 0.045 * ((randf() * 2.0 - 1.0) - noise_y)
		value += noise_y * 0.55
		if i < int(RATE):
			head[i] = value
		if i > samples - int(RATE):
			var k := float(samples - i) / float(RATE)
			value = lerpf(head[i - (samples - int(RATE))], value, k)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := _wrap(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream


## Ветер: отфильтрованный шум с медленными порывами. Используется в Прологе и Пиках.
static func wind_loop(seconds := 6.0) -> AudioStreamWAV:
	var samples := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var y := 0.0
	var y2 := 0.0
	var head := PackedFloat32Array()
	head.resize(int(RATE))
	for i in range(samples):
		var t := float(i) / float(RATE)
		y += 0.06 * ((randf() * 2.0 - 1.0) - y)
		y2 += 0.012 * (y - y2)
		var gust := 0.65 + 0.35 * sin(TAU * t / seconds) * sin(TAU * t / (seconds * 0.37) + 1.3)
		var value := y2 * 2.6 * gust
		if i < int(RATE):
			head[i] = value
		if i > samples - int(RATE):
			var k := float(samples - i) / float(RATE)
			value = lerpf(head[i - (samples - int(RATE))], value, k)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := _wrap(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	return stream


static func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
