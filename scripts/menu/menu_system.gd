class_name MenuSystem
extends RefCounted

enum MenuState { MENU_IN, MENU_IDLE, SUBMENU, CONFIRM_EXIT, LOADING, ERROR }

const SIZE := Vector2(1920.0, 1080.0)
const MENU_X := 180.0
const ROW_HEIGHT := 56.0
const ROW_GAP := 18.0
const FIRST_ROW_Y := 600.0
const HIT_GROW := 24.0
const INPUT_LOCK := 0.2
const MOUSE_TAKEOVER_DELAY := 0.1
const KEY_REPEAT_DELAY := 0.35
const KEY_REPEAT_INTERVAL := 0.09
const COOP_HOVER_TIME := 0.3
const IDLE_CYCLE := 20.0
const AFK_THRESHOLD := 45.0

var state := MenuState.MENU_IN
var focus_index := 0
var previous_focus := -1
var idle_time := 0.0
var afk_time := 0.0
var afk_cooldown := 0.0
var afk_step := 0
var afk_step_timer := 0.0
var input_lock := 0.0
var menu_in_timer := 0.0
var loading_progress := 0.0
var loading_timer := 0.0
var loading_ready := false
var error_timer := 0.0
var error_shake := 0.0
var transition_fade := 0.0
var transition_active := false
var transition_timer := 0.0
var item_scales: Array[float] = []
var navigation_owner := "keyboard"
var mouse_still_time := 0.0
var key_repeat_timer := 0.0
var key_repeat_dir := 0
var coop_timer := 0.0
var coop_ready := false
var pin_cursor: ThreadCursor
var pan_cursor: ThreadCursor
var second_player_connected := false

func _init() -> void:
	pin_cursor = ThreadCursor.new()
	pan_cursor = ThreadCursor.new()
	pin_cursor.is_pin_contour = true
	pan_cursor.is_pin_contour = false

func reset() -> void:
	state = MenuState.MENU_IN
	focus_index = 0
	previous_focus = -1
	idle_time = 0.0
	afk_time = 0.0
	afk_cooldown = 0.0
	afk_step = 0
	menu_in_timer = 0.0
	loading_progress = 0.0
	loading_ready = false
	transition_active = false
	coop_timer = 0.0
	coop_ready = false

func item_ids(save: PinPanSave) -> Array[String]:
	var ids: Array[String] = ["PLAY"]
	if save.can_continue():
		ids.append("CONTINUE")
	ids.append_array(["SETTINGS", "EXIT"])
	return ids

func item_labels(save: PinPanSave) -> Array[String]:
	var labels: Array[String] = []
	for id in item_ids(save):
		match id:
			"PLAY": labels.append("ИГРАТЬ")
			"CONTINUE": labels.append("ПРОДОЛЖИТЬ")
			"SETTINGS": labels.append("НАСТРОЙКИ")
			"EXIT": labels.append("ВЫХОД")
	return labels

func row_rect(index: int, save: PinPanSave) -> Rect2:
	var count := item_ids(save).size()
	var hidden_slots := 5 - count
	var y := FIRST_ROW_Y + float(index + hidden_slots) * (ROW_HEIGHT + ROW_GAP)
	return Rect2(MENU_X - 22.0, y - ROW_HEIGHT * 0.5, 420.0, ROW_HEIGHT)

func row_anchor(index: int, save: PinPanSave) -> Vector2:
	var rect := row_rect(index, save)
	return Vector2(rect.position.x + 18.0, rect.get_center().y + 10.0)

func hit_test(point: Vector2, save: PinPanSave) -> int:
	for i in item_ids(save).size():
		if row_rect(i, save).grow(HIT_GROW).has_point(point):
			return i
	return -1

func process(delta: float, save: PinPanSave, settings: PinPanSettings, mouse: Vector2, mouse_moved: bool) -> void:
	input_lock = maxf(0.0, input_lock - delta)
	if state == MenuState.MENU_IN:
		menu_in_timer += delta
		if menu_in_timer >= 0.4:
			state = MenuState.MENU_IDLE
	elif state == MenuState.MENU_IDLE or state == MenuState.SUBMENU:
		idle_time += delta
		if mouse_moved:
			mouse_still_time = 0.0
			if navigation_owner != "mouse":
				mouse_still_time = MOUSE_TAKEOVER_DELAY
		else:
			mouse_still_time += delta
			if mouse_still_time >= MOUSE_TAKEOVER_DELAY:
				navigation_owner = "mouse"
		afk_time += delta
		afk_cooldown = maxf(0.0, afk_cooldown - delta)
		if afk_cooldown <= 0.0 and not settings.reduce_motion:
			_process_afk(delta)
		else:
			afk_step = 0
			afk_step_timer = 0.0
	elif state == MenuState.LOADING:
		loading_timer += delta
		loading_progress = minf(1.0, loading_progress + delta * 1.6)
		if loading_progress >= 0.85 and loading_timer >= 0.5:
			loading_ready = true
		if loading_timer >= 8.0 and not loading_ready:
			state = MenuState.ERROR
			error_timer = 2.0
			error_shake = 4.0
	elif state == MenuState.ERROR:
		error_timer -= delta
		error_shake = maxf(0.0, error_shake - delta * 8.0)
		if error_timer <= 0.0:
			state = MenuState.MENU_IDLE
	if transition_active:
		transition_timer += delta
		transition_fade = clampf(transition_timer / 0.24, 0.0, 1.0)
	var labels := item_labels(save)
	if item_scales.size() != labels.size():
		item_scales.resize(labels.size())
		for i in item_scales.size():
			item_scales[i] = 1.0
	for i in labels.size():
		var target_scale := 1.06 if i == focus_index and state != MenuState.LOADING else 1.0
		item_scales[i] = lerpf(item_scales[i], target_scale, minf(1.0, delta * 12.0))
	var snap := row_anchor(focus_index, save) if focus_index >= 0 else mouse
	pin_cursor.set_hover(focus_index >= 0)
	pin_cursor.set_target(mouse if navigation_owner == "mouse" else snap)
	pin_cursor.update(delta, snap if navigation_owner != "mouse" else Vector2.INF)
	if second_player_connected:
		pan_cursor.update(delta)
	else:
		pan_cursor.reset(pin_cursor.position + Vector2(30, -8))

func _process_afk(delta: float) -> void:
	if afk_time < AFK_THRESHOLD:
		afk_step = 0
		return
	if afk_step == 0:
		afk_step = 1
		afk_step_timer = 0.0
	afk_step_timer += delta
	if afk_step == 1 and afk_step_timer >= 0.0:
		pass
	if afk_step == 1 and afk_step_timer >= 0.0:
		var interval := 1.2
		var step_index := int((afk_time - AFK_THRESHOLD) / interval)
		if step_index > afk_step - 1:
			afk_step = min(4, step_index + 1)
		if afk_step >= 3 and afk_step_timer >= 0.6:
			afk_cooldown = AFK_THRESHOLD
			afk_time = 0.0
			afk_step = 0

func idle_phase() -> Dictionary:
	var t := fmod(idle_time, IDLE_CYCLE)
	var pin_brightness := 1.0
	var pan_brightness := 1.0
	var pan_tilt := 2.0
	var thread_tension := 0.0
	var thread_sag := 42.0
	if t < 7.0:
		pin_brightness = lerpf(0.92, 1.0, (sin(t / 7.0 * TAU) + 1.0) * 0.5)
		pan_brightness = lerpf(0.92, 1.0, (sin(t / 7.0 * TAU + PI) + 1.0) * 0.5)
	elif t < 14.0:
		var phase := clampf((t - 7.0) / 7.0, 0.0, 1.0)
		if phase < 0.128:
			pan_tilt = lerpf(2.0, 6.0, phase / 0.128)
		elif phase > 0.428:
			pan_tilt = lerpf(6.0, 2.0, (phase - 0.428) / 0.572)
		else:
			pan_tilt = 6.0
	elif t < 20.0:
		var phase := clampf((t - 14.0) / 6.0, 0.0, 1.0)
		if phase < 0.333:
			thread_tension = lerpf(0.0, 0.35, phase / 0.333)
			pin_brightness = lerpf(1.0, 0.96, phase / 0.333)
			pan_brightness = pin_brightness
		else:
			thread_tension = lerpf(0.35, 0.0, (phase - 0.333) / 0.667)
	return {
		"pin_brightness": pin_brightness,
		"pan_brightness": pan_brightness,
		"pan_tilt": pan_tilt,
		"thread_tension": thread_tension,
		"thread_sag": thread_sag,
		"afk_jerk": afk_step,
	}

func pin_menu_pos() -> Vector2:
	return Vector2(1320.0, 530.0)

func pan_menu_pos(idle: Dictionary) -> Vector2:
	var base := Vector2(1510.0, 490.0)
	var tilt: float = idle.get("pan_tilt", 2.0)
	return base + Vector2(sin(deg_to_rad(tilt)) * 8.0, cos(deg_to_rad(tilt)) * 4.0)

func camera_offset(cursor: Vector2) -> Vector2:
	var center := Vector2(960.0, 540.0)
	var delta := cursor - center
	return Vector2(clampf(delta.x * 0.012, -12.0, 12.0), clampf(delta.y * 0.008, -8.0, 8.0))

func register_input() -> void:
	afk_time = 0.0
	afk_step = 0
	afk_cooldown = 0.0

func navigate(direction: int, save: PinPanSave) -> bool:
	if input_lock > 0.0 or state == MenuState.LOADING:
		return false
	var count := item_ids(save).size()
	if count == 0:
		return false
	register_input()
	navigation_owner = "keyboard"
	focus_index = posmod(focus_index + direction, count)
	input_lock = INPUT_LOCK
	return true

func set_focus(index: int, save: PinPanSave) -> bool:
	if input_lock > 0.0 or state == MenuState.LOADING:
		return false
	var count := item_ids(save).size()
	if index < 0 or index >= count:
		return false
	if index != focus_index:
		previous_focus = focus_index
		focus_index = index
		register_input()
	return true

func begin_loading() -> void:
	state = MenuState.LOADING
	loading_progress = 0.0
	loading_timer = 0.0
	loading_ready = false
	input_lock = INPUT_LOCK

func begin_transition() -> void:
	transition_active = true
	transition_timer = 0.0
	transition_fade = 0.0

func consume_focus_changed() -> bool:
	var changed := previous_focus != focus_index and previous_focus >= 0
	previous_focus = focus_index
	return changed
