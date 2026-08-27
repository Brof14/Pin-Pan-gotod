class_name IntroScreen
extends Node2D
## Немое 14-секундное интро: нить ткётся, рука тянет, вспышка, падение, имя.
## Ни строки диалога. Пропуск с 3-й секунды.

signal done

var _time := 0.0
var _active := true


func play() -> void:
	_active = true
	_time = 0.0
	visible = true
	set_process(true)


func stop() -> void:
	_active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	if _time >= 14.0:
		done.emit()
	queue_redraw()


func can_skip() -> bool:
	return _time >= 3.0


func skip() -> void:
	if can_skip():
		done.emit()


func _draw() -> void:
	var t := _time
	var reduce_flash := PinPanCore.I.settings.reduced_flash
	draw_rect(Rect2(-400, -400, 2720, 1880), PinPanPalette.VOID, true)
	# дальняя основа станка
	for i in range(16):
		var x := 170.0 + float(i) * 116.0
		var sway := sin(t * 0.7 + float(i) * 0.61) * 13.0
		draw_line(Vector2(x + sway, -40), Vector2(x - 130.0 + sway, 870), Color(PinPanPalette.LOOM, 0.18), 7.0)
	var weave := clampf(t / 3.0, 0.0, 1.0)
	var pin_intro := Vector2(770, 500).lerp(Vector2(730, 520), weave)
	var pan_intro := Vector2(1150, 500).lerp(Vector2(1190, 485), weave)
	var colors := PinPanPalette.role_pair(PinPanCore.I.settings.color_preset)
	if t < 9.4:
		Actors.thread(self, pin_intro, pan_intro, 0.10 + weave * 0.52, PinPanPalette.WARM)
		Actors.character(self, pin_intro, true, 0.72 + weave * 0.20, -2.0, colors, false, false)
		Actors.character(self, pan_intro, false, 0.72 + weave * 0.20, 3.0, colors, false, false)
		if t > 3.1:
			var hand_in := ease(clampf((t - 3.1) / 2.8, 0.0, 1.0), -2.0)
			var palm := Vector2(1510, -120).lerp(Vector2(1190, 285), hand_in)
			draw_circle(palm, 96, Color("524552"))
			for finger in range(5):
				var base := palm + Vector2(-52 + finger * 26, 40)
				draw_line(base, base + Vector2(-104 + finger * 25, 184), Color("6d5968"), 28.0)
	else:
		var fall := clampf((t - 9.4) / 4.6, 0.0, 1.0)
		var center := Vector2(960, 410).lerp(Vector2(960, 680), ease(fall, 1.6))
		var separation := lerpf(230.0, 370.0, fall)
		var a := center + Vector2(-separation * 0.5, -20)
		var b := center + Vector2(separation * 0.5, 25)
		for i in range(12):
			var y := fposmod(float(i * 91) + t * 130.0, 1180.0) - 50.0
			draw_line(Vector2(110 + i * 142, y), Vector2(250 + i * 142, y + 108), Color(PinPanPalette.FABRIC, 0.32), 13.0)
		Actors.thread(self, a, b, 0.28, PinPanPalette.WARM)
		Actors.character(self, a, true, 0.88, -8.0, colors, false, false)
		Actors.character(self, b, false, 0.88, 8.0, colors, false, false)
		if t > 12.1:
			var title_alpha := clampf((t - 12.1) / 1.2, 0.0, 1.0)
			TextFX.spaced(self, ThemeDB.fallback_font, "PIN&PAN", Vector2(708, 280), 62, Color(PinPanPalette.UI, title_alpha), 3.0)
	if t > 9.15 and t < 9.65 and not reduce_flash:
		draw_rect(Rect2(-400, -400, 2720, 1880), Color(1.0, 0.98, 0.93, sin((t - 9.15) / 0.5 * PI) * 0.82), true)
	if can_skip():
		TextFX.spaced(self, ThemeDB.fallback_font, "SPACE — ПРОПУСТИТЬ", Vector2(1565, 1000), 14, Color(PinPanPalette.MUTED, 0.55), 1.0)
