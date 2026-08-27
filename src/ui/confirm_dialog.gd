class_name ConfirmDialog
extends Node2D
## Диалог с двумя кнопками: подтверждение новой игры и выхода.

signal chosen(ok: bool)

const PANEL := Rect2(610, 350, 700, 380)
const YES_RECT := Rect2(690, 540, 270, 64)
const NO_RECT := Rect2(970, 540, 270, 64)

var title := ""
var subtitle := ""
var yes_label := "ДА"
var no_label := "НАЗАД"
var focus_yes := true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0, 0, 0, 0.55))
	draw_rect(PANEL, Color("121218fa"), true)
	draw_rect(PANEL, Color(PinPanPalette.FOCUS, 0.5), false, 2.0)
	draw_dashed_line(PANEL.position + Vector2(6, 6), PANEL.position + Vector2(PANEL.size.x - 6, 6), Color(PinPanPalette.WARM, 0.3), 1.5, 10.0)
	TextFX.centered(self, font, title, 960, 450, 34, PinPanPalette.UI, 1.5)
	if subtitle != "":
		TextFX.centered(self, font, subtitle, 960, 492, 16, PinPanPalette.MUTED, 1.0)
	_draw_button(YES_RECT, yes_label, focus_yes)
	_draw_button(NO_RECT, no_label, not focus_yes)


func _draw_button(rect: Rect2, label: String, focused: bool) -> void:
	if focused:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(PinPanPalette.FOCUS, 0.08)
		box.border_color = Color(PinPanPalette.FOCUS, 0.92)
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		draw_style_box(box, rect)
	else:
		draw_rect(rect, Color(PinPanPalette.MUTED, 0.10), true)
		draw_rect(rect, Color(PinPanPalette.MUTED, 0.45), false, 1.5)
	TextFX.centered(self, font_fallback(), label, rect.get_center().x, rect.get_center().y + 9, 23,
		PinPanPalette.UI if focused else PinPanPalette.MUTED, 1.4)


func font_fallback() -> Font:
	return ThemeDB.fallback_font


func handle_key(key: Key) -> void:
	match key:
		KEY_LEFT:
			focus_yes = true
		KEY_RIGHT:
			focus_yes = false
		KEY_ENTER, KEY_SPACE:
			PinPanCore.I.ui.play(PinPanUIAudio.Event.SELECT)
			chosen.emit(focus_yes)
		KEY_ESCAPE:
			chosen.emit(false)


func handle_joy_button(button: JoyButton) -> void:
	match button:
		JOY_BUTTON_DPAD_LEFT:
			focus_yes = true
		JOY_BUTTON_DPAD_RIGHT:
			focus_yes = false
		JOY_BUTTON_A:
			handle_key(KEY_ENTER)
		JOY_BUTTON_B:
			handle_key(KEY_ESCAPE)


func handle_click(p: Vector2) -> void:
	if YES_RECT.grow(6).has_point(p):
		focus_yes = true
		chosen.emit(true)
	elif NO_RECT.grow(6).has_point(p):
		focus_yes = false
		chosen.emit(false)


func handle_motion(p: Vector2) -> void:
	if YES_RECT.grow(6).has_point(p):
		focus_yes = true
	elif NO_RECT.grow(6).has_point(p):
		focus_yes = false
