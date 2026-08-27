class_name MenuScreen
extends Node2D
## Главное меню PIN&PAN. Слева — заголовок и пункты, справа — герои на лоскуте.
## Ввод: мышь (пружинный курсор), клавиатура, геймпад. При двух геймпадах —
## два курсора, ИГРАТЬ активируется совместным hover 300 мс.

signal play_requested
signal continue_requested
signal quit_requested

const SIZE := Vector2(1920, 1080)

var _system := MenuSystem.new()
var _cursor: NeedleCursor
var _pad_cursor: NeedleCursor
var _joint_hover := 0.0
var _settings_panel: SettingsPanel
var _dialog: ConfirmDialog
var _dialog_kind := ""
var _mouse_age := 10.0
var _pending := ""
var _time := 0.0
var _parallax := Vector2.ZERO
var _backdrop: MenuBackdrop
var _hero: MenuHero
var _cursor_view: CursorView


func _ready() -> void:
	_backdrop = MenuBackdrop.new()
	_backdrop.show_behind_parent = true
	add_child(_backdrop)
	_hero = MenuHero.new()
	_hero.show_behind_parent = true
	_hero.setup(_system)
	add_child(_hero)
	_cursor = NeedleCursor.new()
	var mouse_pos := get_viewport().get_mouse_position()
	_cursor.reset(mouse_pos if mouse_pos != Vector2.ZERO else Vector2(960, 540))
	_cursor.role_symbol = "pin" if PinPanCore.I.settings.symbols else ""
	_cursor_view = CursorView.new()
	add_child(_cursor_view)


func _process(delta: float) -> void:
	_time += delta
	_mouse_age += delta
	var settings := PinPanCore.I.settings
	_system.process(delta, PinPanCore.I.save, settings)
	_update_cursors(delta)
	_update_focus_from_mouse()
	_update_joint_hover(delta)
	_update_parallax(delta)
	if _system.consume_focus_changed():
		# голоса по очереди: чётные пункты — Pin, нечётные — Pan
		if _system.focus_index % 2 == 0:
			PinPanCore.I.ui.play(PinPanUIAudio.Event.PIN_FOCUS)
		else:
			PinPanCore.I.ui.play(PinPanUIAudio.Event.PAN_FOCUS)
	if _system.state == MenuSystem.MenuState.LOADING and _system.loading_ready and _pending != "":
		var kind := _pending
		_pending = ""
		if kind == "new":
			play_requested.emit()
		else:
			continue_requested.emit()
	queue_redraw()


func _update_cursors(delta: float) -> void:
	_cursor.target = get_viewport().get_mouse_position()
	_cursor.hovered = _hovered_at(_cursor.position)
	_cursor.process(delta)
	# Co-op: второй курсор появляется, когда подключено два геймпада.
	var pads := Input.get_connected_joypads()
	if pads.size() >= 2 and _pad_cursor == null:
		_pad_cursor = NeedleCursor.new()
		_pad_cursor.reset(Vector2(1200, 540))
		_pad_cursor.role_symbol = "pan" if PinPanCore.I.settings.symbols else ""
	elif pads.size() < 2:
		_pad_cursor = null
	if _pad_cursor != null:
		var axis := Vector2(
			Input.get_joy_axis(pads[1], JOY_AXIS_LEFT_X) + Input.get_joy_axis(pads[1], JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(pads[1], JOY_AXIS_LEFT_Y) + Input.get_joy_axis(pads[1], JOY_AXIS_RIGHT_Y))
		if axis.length() > 0.25:
			_pad_cursor.target += axis.limit_length(1.0) * 1500.0 * delta
			_pad_cursor.target = _pad_cursor.target.clamp(Vector2.ZERO, SIZE)
		_pad_cursor.hovered = _hovered_at(_pad_cursor.position)
		_pad_cursor.process(delta)
	_cursor_view.cursors = [_cursor]
	if _pad_cursor != null:
		_cursor_view.cursors.append(_pad_cursor)


func _hovered_at(p: Vector2) -> bool:
	if _system.state == MenuSystem.MenuState.LOADING:
		return false
	return _system.hit_test(p, PinPanCore.I.save) >= 0


## Мышь отбирает фокус только если она двигалась в последние 100 мс.
func _update_focus_from_mouse() -> void:
	if _settings_panel != null or _dialog != null:
		return
	if _system.state == MenuSystem.MenuState.LOADING:
		return
	if _mouse_age < 0.1:
		var idx := _system.hit_test(_cursor.position, PinPanCore.I.save)
		if idx >= 0:
			_system.set_focus(idx, PinPanCore.I.save)


## ИГРАТЬ в co-op требует совместного hover обоих курсоров 300 мс.
func _update_joint_hover(delta: float) -> void:
	if _pad_cursor == null or _system.state != MenuSystem.MenuState.MENU_IDLE or _pending != "":
		_joint_hover = 0.0
		return
	var play_rect := _system.rows(PinPanCore.I.save)[0]["rect"] as Rect2
	var both := play_rect.grow(MenuSystem.HOVER_PAD).has_point(_cursor.position) \
		and play_rect.grow(MenuSystem.HOVER_PAD).has_point(_pad_cursor.position)
	if both:
		_joint_hover += delta
		if _joint_hover >= 0.3:
			_joint_hover = 0.0
			_activate("PLAY")
	else:
		_joint_hover = maxf(0.0, _joint_hover - delta * 2.0)


func _update_parallax(delta: float) -> void:
	var settings := PinPanCore.I.settings
	var target := Vector2.ZERO
	if not settings.reduce_motion:
		var n := (_cursor.position / SIZE - Vector2(0.5, 0.5)) * 2.0
		target = Vector2(-n.x * 9.0, -n.y * 6.0)
	_parallax = _parallax.lerp(target, minf(1.0, delta * 4.0))
	_backdrop.set_parallax(_parallax)


func _process_joy_motion(_device: int, axis: int, value: float) -> void:
	if _settings_panel == null and _dialog == null and _pad_cursor == null:
		# один геймпад управляет главным курсором
		if axis == JOY_AXIS_LEFT_X and absf(value) > 0.25:
			_cursor.target.x = clampf(_cursor.target.x + value * 14.0, 0.0, SIZE.x)
		elif axis == JOY_AXIS_LEFT_Y and absf(value) > 0.25:
			_cursor.target.y = clampf(_cursor.target.y + value * 14.0, 0.0, SIZE.y)


# --- Ввод (вызывается из Main) ---

func handle_mouse_motion() -> void:
	_mouse_age = 0.0
	if _dialog != null:
		_dialog.handle_motion(get_viewport().get_mouse_position())
	if _settings_panel != null:
		_settings_panel.handle_drag(get_viewport().get_mouse_position())


func handle_mouse_release() -> void:
	if _settings_panel != null:
		_settings_panel.handle_release()


func handle_click(p: Vector2) -> void:
	_system.register_input()
	if _settings_panel != null:
		_settings_panel.handle_click(p)
		return
	if _dialog != null:
		_dialog.handle_click(p)
		return
	if _system.state == MenuSystem.MenuState.LOADING:
		return
	var idx := _system.hit_test(p, PinPanCore.I.save)
	if idx >= 0:
		_system.set_focus(idx, PinPanCore.I.save)
		_activate(_system.item_id(idx, PinPanCore.I.save))


func handle_key(key: Key) -> void:
	_system.register_input()
	if _settings_panel != null:
		_settings_panel.handle_key(key)
		return
	if _dialog != null:
		if key == KEY_ESCAPE:
			_close_dialog()
		else:
			_dialog.handle_key(key)
		return
	if _system.state == MenuSystem.MenuState.LOADING:
		return
	match key:
		KEY_DOWN, KEY_S:
			if _system.navigate(1, PinPanCore.I.save):
				PinPanCore.I.ui.play(PinPanUIAudio.Event.HOVER)
		KEY_UP, KEY_W:
			if _system.navigate(-1, PinPanCore.I.save):
				PinPanCore.I.ui.play(PinPanUIAudio.Event.HOVER)
		KEY_ENTER, KEY_SPACE:
			_activate(_system.item_id(_system.focus_index, PinPanCore.I.save))
		KEY_ESCAPE:
			_open_dialog("EXIT")


func handle_joy_button(button: JoyButton, device: int) -> void:
	_system.register_input()
	if _settings_panel != null:
		_settings_panel.handle_joy_button(button)
		return
	if _dialog != null:
		_dialog.handle_joy_button(button)
		return
	if _system.state == MenuSystem.MenuState.LOADING:
		return
	if device == 0:
		match button:
			JOY_BUTTON_DPAD_DOWN:
				if _system.navigate(1, PinPanCore.I.save):
					PinPanCore.I.ui.play(PinPanUIAudio.Event.HOVER)
			JOY_BUTTON_DPAD_UP:
				if _system.navigate(-1, PinPanCore.I.save):
					PinPanCore.I.ui.play(PinPanUIAudio.Event.HOVER)
			JOY_BUTTON_A:
				_activate(_system.item_id(_system.focus_index, PinPanCore.I.save))
			JOY_BUTTON_B:
				_open_dialog("EXIT")


# --- Действия ---

## Вызывается из main.gd при каждом возвращении в меню.
func reset() -> void:
	_pending = ""
	_system.reset()
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
		_dialog_kind = ""


func _activate(id: String) -> void:
	if id == "":
		return
	match id:
		"PLAY":
			if PinPanCore.I.save.can_continue():
				_open_dialog("PLAY")
			else:
				_begin_loading("new")
		"CONTINUE":
			_begin_loading("continue")
		"SETTINGS":
			_open_settings()
		"EXIT":
			_open_dialog("EXIT")


func _begin_loading(kind: String) -> void:
	_pending = kind
	_system.begin_loading()
	PinPanCore.I.ui.play(PinPanUIAudio.Event.SELECT)
	_cursor.trigger_select()
	if _pad_cursor != null:
		_pad_cursor.trigger_select()


func _open_settings() -> void:
	if _settings_panel != null:
		return
	PinPanCore.I.ui.play(PinPanUIAudio.Event.OPEN)
	_settings_panel = SettingsPanel.new()
	_settings_panel.closed.connect(_close_settings)
	add_child(_settings_panel)


func _close_settings() -> void:
	if _settings_panel == null:
		return
	_settings_panel.queue_free()
	_settings_panel = null


func _open_dialog(kind: String) -> void:
	if _dialog != null:
		return
	_dialog_kind = kind
	PinPanCore.I.ui.play(PinPanUIAudio.Event.OPEN)
	_dialog = ConfirmDialog.new()
	if kind == "PLAY":
		_dialog.title = "НАЧАТЬ НОВУЮ ИГРУ?"
		_dialog.subtitle = "ТЕКУЩЕЕ СОХРАНЕНИЕ ОСТАНЕТСЯ"
		_dialog.yes_label = "ИГРАТЬ"
		_dialog.no_label = "НАЗАД"
	else:
		_dialog.title = "ВЫЙТИ ИЗ ИГРЫ?"
		_dialog.subtitle = "НИТЬ БУДЕТ ЖДАТЬ ВАШЕГО ВОЗВРАЩЕНИЯ"
		_dialog.yes_label = "ВЫЙТИ"
		_dialog.no_label = "НАЗАД"
	_dialog.chosen.connect(_on_dialog_chosen)
	add_child(_dialog)


func _close_dialog() -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
	_dialog_kind = ""
	PinPanCore.I.ui.play(PinPanUIAudio.Event.BACK)


func _on_dialog_chosen(ok: bool) -> void:
	var kind := _dialog_kind
	_dialog.queue_free()
	_dialog = null
	_dialog_kind = ""
	if not ok:
		return
	if kind == "PLAY":
		_begin_loading("new")
	elif kind == "EXIT":
		quit_requested.emit()


# --- Отрисовка ---

func _draw() -> void:
	_draw_logo()
	_draw_menu_items()
	_draw_footer()
	if _system.state == MenuSystem.MenuState.LOADING:
		_draw_loading()
	elif _system.state == MenuSystem.MenuState.ERROR:
		TextFX.centered(self, ThemeDB.fallback_font, "НЕ УДАЛОСЬ ЗАГРУЗИТЬ", 960, 520, 28, PinPanPalette.DANGER, 1.5)
	var settings := PinPanCore.I.settings
	if settings.brightness != 100:
		var b := settings.brightness_tint()
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(b.r, b.g, b.b, settings.brightness_alpha()), true)


## Заголовок рисуется «стежками»: векторные буквы, между PIN и PAN — нить с узлом.
func _draw_logo() -> void:
	var glyphs := {
		"P": [[[0, 56], [0, 0], [16, 0], [24, 7], [24, 23], [16, 30], [0, 30]]],
		"I": [[[6, 0], [20, 0]], [[13, 0], [13, 56]], [[6, 56], [20, 56]]],
		"N": [[[0, 56], [0, 0], [26, 56], [26, 0]]],
		"A": [[[0, 56], [13, 0], [26, 56]], [[5, 36], [21, 36]]],
	}
	var origin := Vector2(172, 148)
	var s := 1.32
	var order := ["P", "I", "N", "&", "P", "A", "N"]
	var pen := origin
	var pin_end := Vector2.ZERO
	var pan_start := Vector2.ZERO
	for gi in order.size():
		var g: String = order[gi]
		if g == "&":
			pin_end = pen + Vector2(2, 26 * s)
			pen.x += 44.0 * s
			pan_start = pen + Vector2(-4, 26 * s)
			continue
		var wobble := sin(float(gi) * 2.3) * 1.6
		for seg in glyphs[g]:
			var pts := PackedVector2Array()
			for raw in seg:
				pts.append(pen + Vector2(float(raw[0]) * s, float(raw[1]) * s + wobble))
			draw_polyline(pts, Color(PinPanPalette.UI, 0.95), 3.0, true)
			for k in range(pts.size() - 1):
				draw_dashed_line(pts[k], pts[k + 1], Color(PinPanPalette.WARM, 0.8), 1.7, 9.0)
		pen.x += 30.0 * s
	# нить между половинами имени: провисает, с узелком
	var sag := Vector2(0, 34)
	var mid := (pin_end + pan_start) * 0.5 + sag
	var pts := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		pts.append(pin_end.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(pan_start, (t - 0.5) * 2.0))
	draw_polyline(pts, Color(PinPanPalette.WARM, 0.85), 2.0, true)
	draw_circle(mid, 3.5, Color(PinPanPalette.WARM, 0.95))
	draw_arc(mid + Vector2(5, -4), 5.0, 0, TAU, 10, Color(PinPanPalette.WARM, 0.6), 1.5)
	TextFX.spaced(self, ThemeDB.fallback_font, "ИСТОРИЯ ОДНОЙ НИТИ", Vector2(178, 320), 15, Color(PinPanPalette.MUTED, 0.9), 5.0)


func _label_for(id: String) -> String:
	match id:
		"PLAY": return "ИГРАТЬ"
		"CONTINUE": return "ПРОДОЛЖИТЬ"
		"SETTINGS": return "НАСТРОЙКИ"
		"EXIT": return "ВЫХОД"
	return id


func _draw_menu_items() -> void:
	var font := ThemeDB.fallback_font
	var r := _system.rows(PinPanCore.I.save)
	var blocked := _dialog != null or _settings_panel != null
	for i in r.size():
		var row: Dictionary = r[i]
		if not row["enabled"]:
			continue
		var rect: Rect2 = row["rect"]
		var focused: bool = i == _system.focus_index and _system.state != MenuSystem.MenuState.LOADING and not blocked
		var scale: float = _system.item_scales[i]
		var anim: float = _system.item_focus_anim[i]
		var center := rect.get_center()
		draw_set_transform(center, 0.0, Vector2(scale, scale))
		if focused:
			var ring := rect.grow(10)
			draw_rect(ring, Color(PinPanPalette.FOCUS, 0.05), true)
			draw_rect(ring, Color(PinPanPalette.FOCUS, 0.9), false, 2.0)
			draw_dashed_line(ring.position, ring.position + Vector2(ring.size.x, 0), Color(PinPanPalette.WARM, 0.65), 1.6, 9.0)
		var label := _label_for(row["id"])
		if focused:
			TextFX.spaced(self, font, label, rect.position + Vector2(28, rect.size.y * 0.5 + 13), 33, Color(PinPanPalette.FOCUS, 0.22), 2.4)
		TextFX.spaced(self, font, label, rect.position + Vector2(28, rect.size.y * 0.5 + 12), 33,
			PinPanPalette.UI if focused else Color(PinPanPalette.MUTED, 0.85), 2.4)
		if anim > 0.01:
			# петля нитки слева + растущая подшивка под пунктом
			draw_arc(rect.position + Vector2(13, rect.size.y * 0.5), 7.0, 0, TAU, 12, Color(PinPanPalette.WARM, anim), 2.0)
			var w := TextFX.width(font, label, 33, 2.4)
			var y := rect.position.y + rect.size.y * 0.5 + 24
			draw_dashed_line(Vector2(rect.position.x + 28, y), Vector2(rect.position.x + 28 + w * anim, y),
				Color(PinPanPalette.WARM, 0.55 * anim), 2.0, 8.0)
		# co-op: круговой индикатор совместного hover на ИГРАТЬ
		if i == 0 and _joint_hover > 0.01:
			draw_arc(center + Vector2(330, 0), 14.0, -PI / 2, -PI / 2 + TAU * (_joint_hover / 0.3), 20, PinPanPalette.FOCUS, 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_footer() -> void:
	var font := ThemeDB.fallback_font
	var hint := "↑ ↓ — ВЫБОР      ENTER — ОК      ESC — ВЫХОД"
	if not Input.get_connected_joypads().is_empty():
		hint += "      D-PAD — ВЫБОР      Ⓐ — ОК"
	TextFX.spaced(self, font, hint, Vector2(190, 1032), 13, Color(PinPanPalette.MUTED, 0.55), 1.5)


func _draw_loading() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(PinPanPalette.VOID, 0.78), true)
	TextFX.centered(self, font, "НИТЬ ВЕДЁТ ВПЕРЁД", 960, 516, 28, PinPanPalette.UI, 2.5)
	var a := Vector2(760, 562)
	var b := Vector2(1160, 562)
	draw_line(a, b, Color(PinPanPalette.MUTED, 0.3), 3.0)
	var p := _system.loading_progress
	if p > 0.0:
		var tip := a.lerp(b, p)
		draw_dashed_line(a, tip, Color(PinPanPalette.WARM, 0.9), 3.0, 9.0)
		draw_circle(tip, 5.0, PinPanPalette.WARM)
		draw_circle(tip, 10.0, Color(PinPanPalette.WARM, 0.25))
	TextFX.centered(self, font, _loading_caption(), 960, 610, 15, Color(PinPanPalette.MUTED, 0.85), 2.0)


func _loading_caption() -> String:
	if _pending == "continue":
		return "ВОЗВРАЩЕНИЕ К СЕРЕДИНЕ ИСТОРИИ"
	return "ПРОБУЖДЕНИЕ В МАСТЕРСКОЙ"
