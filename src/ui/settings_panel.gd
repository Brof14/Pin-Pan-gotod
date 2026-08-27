class_name SettingsPanel
extends Node2D
## Панель настроек: используется и в меню, и в паузе.
## Все изменения применяются мгновенно (шины аудио, физика нити) и сохраняются.

signal closed

const PANEL := Rect2(350, 96, 1220, 884)
const ROW_X := 448.0
const ROW_W := 1040.0
const ROW_Y0 := 300.0
const ROW_STEP := 52.0
const SLIDER_X := 920.0
const SLIDER_W := 380.0

var focus := 0
var dragging := -1
var _slider_sound_value := -1

var _rows: Array[String] = [
	"ОБЩАЯ ГРОМКОСТЬ", "МУЗЫКА", "ЭФФЕКТЫ", "АТМОСФЕРА", "НАТЯЖЕНИЕ НИТИ",
	"ЯРКОСТЬ", "ТРЯСКА ЭКРАНА", "ПАЛИТРА", "СИМВОЛЫ РОЛЕЙ",
	"УМЕНЬШИТЬ ДВИЖЕНИЕ", "МЯГКАЯ ВСПЫШКА", "ВЫСОКИЙ КОНТРАСТ", "НАЗАД",
]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var settings := PinPanCore.I.settings
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0, 0, 0, 0.62))
	draw_rect(PANEL, Color("121218f2"), true)
	_stitched_border(PANEL)
	TextFX.spaced(self, font, "НАСТРОЙКИ", Vector2(ROW_X, 196), 40, PinPanPalette.UI, 4.0)
	TextFX.spaced(self, font, "ИЗМЕНЕНИЯ ПРИМЕНЯЮТСЯ СРАЗУ", Vector2(ROW_X, 228), 13, PinPanPalette.MUTED, 2.0)
	for i in _rows.size():
		_draw_row(i, font, settings)
	TextFX.spaced(self, font, "↑↓ — ВЫБОР    ←→ — ИЗМЕНИТЬ    ESC — НАЗАД",
		Vector2(ROW_X, PANEL.end.y - 28), 13, Color(PinPanPalette.MUTED, 0.75), 1.5)


func _draw_row(i: int, font: Font, settings: PinPanSettings) -> void:
	var y := ROW_Y0 + i * ROW_STEP
	var focused := i == focus
	if focused:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(PinPanPalette.FOCUS, 0.06)
		box.border_color = Color(PinPanPalette.FOCUS, 0.9)
		box.set_border_width_all(2)
		box.set_corner_radius_all(7)
		draw_style_box(box, Rect2(ROW_X - 34, y - 36, ROW_W + 68, 48))
	var color := PinPanPalette.UI if focused else PinPanPalette.MUTED
	TextFX.spaced(self, font, _rows[i], Vector2(ROW_X, y), 21, color, 1.2)
	if i < 7:
		var value := _slider_value(i, settings)
		var max_value := 150.0 if i == 5 else 100.0
		var fill := SLIDER_W * float(value) / max_value
		draw_rect(Rect2(SLIDER_X, y - 20, SLIDER_W, 8), Color(PinPanPalette.MUTED, 0.3), true)
		draw_rect(Rect2(SLIDER_X, y - 20, fill, 8), PinPanPalette.FOCUS, true)
		draw_circle(Vector2(SLIDER_X + fill, y - 16), 9 if focused else 7, PinPanPalette.FOCUS)
		TextFX.spaced(self, font, str(value), Vector2(1310, y), 20, color)
	elif i == 7:
		TextFX.spaced(self, font, _preset_label(settings.color_preset), Vector2(1090, y), 21, PinPanPalette.FOCUS, 1.5)
	else:
			var on: bool = [false, false, false, false, false, false, false, false,
			settings.symbols, settings.reduce_motion, settings.reduced_flash, settings.high_contrast][i]
		draw_rect(Rect2(1090, y - 20, 54, 24), Color(PinPanPalette.FOCUS, 0.12 if on else 0.05), true)
		draw_rect(Rect2(1090, y - 20, 54, 24), Color(PinPanPalette.FOCUS, 0.8), false, 1.5)
		if on:
			draw_circle(Vector2(1090 + 40, y - 8), 7, PinPanPalette.FOCUS)
		else:
			draw_circle(Vector2(1090 + 14, y - 8), 7, Color(PinPanPalette.MUTED, 0.7))
		TextFX.spaced(self, font, "ВКЛ" if on else "ВЫКЛ", Vector2(1164, y), 20, color)


func _slider_value(i: int, settings: PinPanSettings) -> int:
	match i:
		0: return settings.master
		1: return settings.music
		2: return settings.sfx
		3: return settings.ambience
		4: return settings.thread_tension
		5: return settings.brightness
		6: return settings.screen_shake
	return 0


func _set_slider(i: int, value: int) -> void:
	var settings := PinPanCore.I.settings
	value = clampi(value, 50 if i == 5 else 0, 150 if i == 5 else 100)
	match i:
		0: settings.master = value
		1: settings.music = value
		2: settings.sfx = value
		3: settings.ambience = value
		4: settings.thread_tension = value
		5: settings.brightness = value
		6: settings.screen_shake = value
	if value != _slider_sound_value:
		PinPanCore.I.ui.play(PinPanUIAudio.Event.SLIDER)
		_slider_sound_value = value
	PinPanCore.I.save_settings()


func _activate(i: int) -> void:
	var settings := PinPanCore.I.settings
	match i:
		7:
			var idx := PinPanSettings.PRESET_NAMES.find(settings.color_preset)
			settings.color_preset = PinPanSettings.PRESET_NAMES[posmod(idx + 1, PinPanSettings.PRESET_NAMES.size())]
			PinPanCore.I.ui.play(PinPanUIAudio.Event.TOGGLE)
		8:
			settings.symbols = not settings.symbols
			PinPanCore.I.ui.play(PinPanUIAudio.Event.TOGGLE)
		9:
			settings.reduce_motion = not settings.reduce_motion
			PinPanCore.I.ui.play(PinPanUIAudio.Event.TOGGLE)
		10:
			settings.reduced_flash = not settings.reduced_flash
			PinPanCore.I.ui.play(PinPanUIAudio.Event.TOGGLE)
		11:
			settings.high_contrast = not settings.high_contrast
			PinPanCore.I.ui.play(PinPanUIAudio.Event.TOGGLE)
		12:
			PinPanCore.I.ui.play(PinPanUIAudio.Event.BACK)
			closed.emit()
			return
	PinPanCore.I.save_settings()


func handle_key(key: Key) -> void:
	match key:
		KEY_DOWN, KEY_S:
			focus = posmod(focus + 1, _rows.size())
		KEY_UP, KEY_W:
			focus = posmod(focus - 1, _rows.size())
		KEY_LEFT:
			_adjust(-1)
		KEY_RIGHT:
			_adjust(1)
		KEY_ENTER, KEY_SPACE:
			_activate(focus)
		KEY_ESCAPE:
			closed.emit()


func handle_joy_button(button: JoyButton) -> void:
	match button:
		JOY_BUTTON_DPAD_DOWN:
			handle_key(KEY_DOWN)
		JOY_BUTTON_DPAD_UP:
			handle_key(KEY_UP)
		JOY_BUTTON_DPAD_LEFT:
			handle_key(KEY_LEFT)
		JOY_BUTTON_DPAD_RIGHT:
			handle_key(KEY_RIGHT)
		JOY_BUTTON_A:
			handle_key(KEY_ENTER)
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			handle_key(KEY_ESCAPE)


func handle_click(p: Vector2) -> void:
	var row := _hit(p)
	if row < 0:
		return
	focus = row
	if row < 7:
		_set_slider(row, _slider_at(p, row))
		dragging = row
	else:
		_activate(row)


func handle_drag(p: Vector2) -> void:
	if dragging >= 0 and dragging < 7:
		_set_slider(dragging, _slider_at(p, dragging))


func handle_release() -> void:
	dragging = -1


func _adjust(direction: int) -> void:
	if focus < 7:
		_set_slider(focus, _slider_value(focus, PinPanCore.I.settings) + direction * 5)
	else:
		_activate(focus)


func _slider_at(p: Vector2, row: int) -> int:
	var max_value := 150.0 if row == 5 else 100.0
	return int(roundf(clampf((p.x - SLIDER_X) / SLIDER_W, 0.0, 1.0) * max_value))


func _hit(p: Vector2) -> int:
	for i in _rows.size():
		if Rect2(ROW_X - 34, ROW_Y0 + i * ROW_STEP - 36, ROW_W + 68, 48).has_point(p):
			return i
	return -1


func _preset_label(preset: String) -> String:
	match preset:
		"BASE": return "БАЗОВАЯ"
		"PROTANOPIA": return "ПРОТАНОПИЯ"
		"DEUTERANOPIA": return "ДЕЙТЕРАНОПИЯ"
		"TRITANOPIA": return "ТРИТАНОПИЯ"
	return preset


func _stitched_border(rect: Rect2) -> void:
	draw_rect(rect, Color(PinPanPalette.FOCUS, 0.35), false, 2.0)
	draw_dashed_line(rect.position + Vector2(4, 4), rect.position + Vector2(rect.size.x - 4, 4), Color(PinPanPalette.WARM, 0.3), 1.5, 10.0)
	draw_dashed_line(rect.position + Vector2(4, rect.size.y - 4), rect.position + Vector2(rect.size.x - 4, rect.size.y - 4), Color(PinPanPalette.WARM, 0.3), 1.5, 10.0)
