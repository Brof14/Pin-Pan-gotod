class_name MenuSystem
extends RefCounted
## Логика главного меню. Состояния: MENU_IDLE → FOCUS → ACTIVATE → LOADING (→ ERROR).
## Idle-цикл 20 сек: 0–7 противофазное свечение, 7–14 Pan наклоняется, 14–20 нить дышит.
## После 45 сек бездействия Pan трижды дёргает нить; на третьем оба поворачиваются на 12°.

enum MenuState { MENU_IDLE, FOCUS, ACTIVATE, LOADING, ERROR }

const ROW_X := 190.0
const ROW_W := 560.0
const ROW_H := 64.0
const ROW_STEP := 82.0
const ROW_Y := 566.0
const HOVER_PAD := 24.0 # зона hover растёт на 24 px с каждой стороны
const LOAD_TIME := 0.85
const LOAD_WATCHDOG := 8.0

var state := MenuState.MENU_IDLE
var focus_index := 0
var item_scales: Array[float] = [1.0, 1.0, 1.0, 1.0]
var item_focus_anim: Array[float] = [0.0, 0.0, 0.0, 0.0]
var loading_progress := 0.0
var loading_ready := false
var error_shake := 0.0
var afk := 0.0
var idle_clock := 0.0

var _loading_time := 0.0
var _focus_changed := false


## Строки меню: PLAY / CONTINUE / SETTINGS / EXIT. Без сохранения ПРОДОЛЖИТЬ
## не рисуется, но его пустая строка 44 px остаётся — макет не схлопывается.
func rows(save: PinPanSave) -> Array[Dictionary]:
	var ids: Array[String] = ["PLAY", "CONTINUE", "SETTINGS", "EXIT"]
	var out: Array[Dictionary] = []
	for i in ids.size():
		var enabled := ids[i] != "CONTINUE" or save.can_continue()
		var h := ROW_H if enabled else 44.0
		out.append({
			"id": ids[i],
			"rect": Rect2(ROW_X, ROW_Y + i * ROW_STEP, ROW_W, h),
			"enabled": enabled,
		})
	return out


func item_id(index: int, save: PinPanSave) -> String:
	var r := rows(save)
	if index < 0 or index >= r.size():
		return ""
	return r[index]["id"]


func hit_test(p: Vector2, save: PinPanSave) -> int:
	var r := rows(save)
	for i in r.size():
		if not r[i]["enabled"]:
			continue
		var rect: Rect2 = r[i]["rect"]
		if rect.grow(HOVER_PAD).has_point(p):
			return i
	return -1


func set_focus(index: int, save: PinPanSave) -> bool:
	var r := rows(save)
	if index < 0 or index >= r.size() or not r[index]["enabled"]:
		return false
	if index != focus_index:
		focus_index = index
		_focus_changed = true
	afk = 0.0
	return true


func navigate(direction: int, save: PinPanSave) -> bool:
	var r := rows(save)
	var idx := focus_index
	for step in r.size():
		idx = posmod(idx + direction, r.size())
		if r[idx]["enabled"]:
			return set_focus(idx, save)
	return false


func process(delta: float, save: PinPanSave, _settings: PinPanSettings) -> void:
	idle_clock += delta
	afk += delta
	for i in 4:
		var active := i == focus_index and state != MenuState.LOADING
		item_scales[i] = lerpf(item_scales[i], 1.03 if active else 1.0, minf(1.0, delta / 0.12))
		item_focus_anim[i] = move_toward(item_focus_anim[i], 1.0 if active else 0.0, delta / 0.18)
	error_shake = maxf(0.0, error_shake - delta * 8.0)
	if state == MenuState.LOADING:
		_loading_time += delta
		loading_progress = minf(1.0, _loading_time / LOAD_TIME)
		if loading_progress >= 1.0:
			loading_ready = true
		if _loading_time > LOAD_WATCHDOG:
			state = MenuState.ERROR
			error_shake = 4.0


func consume_focus_changed() -> bool:
	if _focus_changed:
		_focus_changed = false
		return true
	return false


## Возврат в меню после игры/загрузки: вернуть состояние и фокус.
func reset() -> void:
	state = MenuState.MENU_IDLE
	focus_index = 0
	loading_progress = 0.0
	loading_ready = false
	_loading_time = 0.0
	error_shake = 0.0
	for i in 4:
		item_scales[i] = 1.0
		item_focus_anim[i] = 0.0


func begin_loading() -> void:
	state = MenuState.LOADING
	loading_progress = 0.0
	loading_ready = false
	_loading_time = 0.0


func register_input() -> void:
	afk = 0.0


## Параметры idle-сцены для отрисовки героев.
func idle_phase() -> Dictionary:
	var t := fmod(idle_clock, 20.0)
	var pulse := sin(idle_clock * TAU / 7.0) * 0.08
	var pan_tilt := 0.0
	if t >= 7.0 and t < 14.0:
		var lt := t - 7.0
		if lt < 0.9:
			pan_tilt = 6.0 * smoothstep(0.0, 0.9, lt)
		elif lt < 1.2:
			pan_tilt = 6.0
		else:
			pan_tilt = 6.0 * (1.0 - smoothstep(1.2, 2.1, lt))
	var tension := 0.0
	if t >= 14.0:
		tension = 0.35 * sin((t - 14.0) / 6.0 * PI)
	var tug := 0
	var tug_t := 0.0
	var spin := 0.0
	if afk > 45.0:
		var at := fmod(afk - 45.0, 6.4)
		if at < 3.6:
			tug = int(at / 1.2) + 1
			var lt2 := fmod(at, 1.2)
			tug_t = sin(minf(lt2 / 0.5, 1.0) * PI) if lt2 < 0.5 else 0.0
		elif at < 5.2:
			spin = 12.0 * sin((at - 3.6) / 1.6 * PI)
	return {
		"pin_brightness": 1.0 + pulse,
		"pan_brightness": 1.0 - pulse,
		"pan_tilt": pan_tilt,
		"thread_tension": tension,
		"tug": tug,
		"tug_t": tug_t,
		"spin": spin,
	}
