class_name PauseOverlay
extends Node2D
## Пауза поверх Пролога или Акта I. Умеет сообщать об отсоединении геймпада.

signal resume_requested
signal settings_requested
signal menu_requested

const ROWS := ["ПРОДОЛЖИТЬ", "НАСТРОЙКИ", "В ГЛАВНОЕ МЕНЮ"]
const PANEL := Rect2(620, 295, 680, 500)

var focus := 0
var device_lost := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0, 0, 0, 0.58))
	draw_rect(PANEL, Color("121218f6"), true)
	draw_rect(PANEL, Color(PinPanPalette.FOCUS, 0.48), false, 2.0)
	TextFX.centered(self, font, "ПАУЗА", 960, 385, 42, PinPanPalette.UI, 3.0)
	if device_lost:
		# Пиктограмма отсоединённого устройства + подсказка
		var cx := 960.0
		draw_arc(Vector2(cx, 452), 16.0, 0.0, TAU, 16, Color(PinPanPalette.DANGER, 0.9), 2.5)
		draw_line(Vector2(cx - 8, 446), Vector2(cx + 8, 458), Color(PinPanPalette.DANGER, 0.9), 2.5)
		TextFX.centered(self, font, "ГЕЙМПАД ОТСОЕДИНЁН", cx, 500, 20, Color(PinPanPalette.DANGER, 0.95), 1.5)
		TextFX.centered(self, font, "ПОДКЛЮЧИТЕ УСТРОЙСТВО ИЛИ ИГРАЙТЕ С КЛАВИАТУРЫ", cx, 528, 14, PinPanPalette.MUTED, 1.0)
	for i in ROWS.size():
		_draw_button(Rect2(690, 560 + i * 68, 540, 56), ROWS[i], i == focus)
	TextFX.centered(self, font, "ESC — ПРОДОЛЖИТЬ", 960, PANEL.end.y - 22, 13, Color(PinPanPalette.MUTED, 0.75), 1.5)


func _draw_button(rect: Rect2, label: String, focused: bool) -> void:
	if focused:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(PinPanPalette.FOCUS, 0.07)
		box.border_color = Color(PinPanPalette.FOCUS, 0.92)
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		draw_style_box(box, rect)
	else:
		draw_rect(rect, Color(PinPanPalette.MUTED, 0.08), true)
		draw_rect(rect, Color(PinPanPalette.MUTED, 0.4), false, 1.5)
	TextFX.centered(self, font_fallback(), label, rect.get_center().x, rect.get_center().y + 8, 22,
		PinPanPalette.UI if focused else PinPanPalette.MUTED, 1.4)


func font_fallback() -> Font:
	return ThemeDB.fallback_font


func handle_key(key: Key) -> void:
	match key:
		KEY_DOWN, KEY_S:
			focus = posmod(focus + 1, ROWS.size())
		KEY_UP, KEY_W:
			focus = posmod(focus - 1, ROWS.size())
		KEY_ENTER, KEY_SPACE:
			_activate(focus)
		KEY_ESCAPE:
			resume_requested.emit()


func handle_joy_button(button: JoyButton) -> void:
	match button:
		JOY_BUTTON_DPAD_DOWN:
			handle_key(KEY_DOWN)
		JOY_BUTTON_DPAD_UP:
			handle_key(KEY_UP)
		JOY_BUTTON_A:
			_activate(focus)
		JOY_BUTTON_B, JOY_BUTTON_START:
			resume_requested.emit()


func handle_click(p: Vector2) -> void:
	for i in ROWS.size():
		if Rect2(690, 560 + i * 68, 540, 56).has_point(p):
			focus = i
			_activate(i)
			return


func handle_motion(p: Vector2) -> void:
	for i in ROWS.size():
		if Rect2(690, 560 + i * 68, 540, 56).has_point(p):
			focus = i


func _activate(i: int) -> void:
	match i:
		0:
			resume_requested.emit()
		1:
			settings_requested.emit()
		2:
			menu_requested.emit()
