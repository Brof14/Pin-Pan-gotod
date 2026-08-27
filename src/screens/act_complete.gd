class_name ActCompleteScreen
extends Node2D
## Финальный слайд Акта I: герои, сводка и приглашение вернуться в меню.

signal done

var _time := 0.0


func play() -> void:
	visible = true
	set_process(true)
	_time = 0.0


func stop() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var settings := PinPanCore.I.settings
	var colors := PinPanPalette.role_pair(settings.color_preset)
	draw_rect(Rect2(-400, -400, 2720, 1880), PinPanPalette.VOID, true)
	for i in range(28):
		var x := fposmod(float(i * 157), 2050.0) - 80.0
		var y := 80.0 + float(i % 6) * 110.0
		draw_line(Vector2(x, y), Vector2(x + sin(_time + i) * 25.0, 940), Color(PinPanPalette.WOOL, 0.45), 32.0)
	draw_rect(Rect2(-400, -400, 2720, 1880), Color(PinPanPalette.VOID, 0.55), true)
	Actors.thread(self, Vector2(820, 570), Vector2(1100, 520), 0.26, PinPanPalette.WARM)
	Actors.character(self, Vector2(820, 570), true, 1.18, 0.0, colors, settings.symbols, settings.high_contrast)
	Actors.character(self, Vector2(1100, 520), false, 1.12, 5.0, colors, settings.symbols, settings.high_contrast)
	TextFX.spaced(self, ThemeDB.fallback_font, "КОНЕЦ ПЕРВОГО АКТА", Vector2(585, 330), 54, PinPanPalette.UI, 2.4)
	TextFX.spaced(self, ThemeDB.fallback_font, "ВЫ НАУЧИЛИСЬ ДЕРЖАТЬСЯ ДРУГ ЗА ДРУГА — И УШЛИ ОТ ПОГОНИ.", Vector2(420, 420), 20, PinPanPalette.FOCUS, 0.55)
	var nodes := PinPanCore.I.save.memory_nodes
	TextFX.spaced(self, ThemeDB.fallback_font, "УЗЛОВ ПАМЯТИ НАЙДЕНО: " + str(nodes) + " ИЗ 8", Vector2(420, 455), 18, PinPanPalette.UI, 0.6)
	TextFX.spaced(self, ThemeDB.fallback_font, "ДАЛЬШЕ — ШЁЛКОВЫЕ ПИКИ. ОНИ ЖДУТ СЛЕДУЮЩЕГО ЭТАПА.", Vector2(545, 500), 16, Color(PinPanPalette.MUTED, 0.9), 0.8)
	if _time > 1.2:
		TextFX.centered(self, ThemeDB.fallback_font, "ENTER / SPACE — В ГЛАВНОЕ МЕНЮ", 960, 780, 19, Color(PinPanPalette.UI, 0.85), 1.5)
