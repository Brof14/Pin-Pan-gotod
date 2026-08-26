extends Node2D

const SIZE := Vector2(1920.0, 1080.0)
const VOID := Color("0a0a0e")
const DEEP := Color("15151d")
const LOOM := Color("292832")
const FABRIC := Color("37333e")
const LINEN := Color("90785c")
const LINEN_LIGHT := Color("d2b98c")
const WOOL := Color("384354")
const WOOL_LIGHT := Color("68758c")
const WARM := Color("e3c69a")
const UI := Color("e8e4da")
const MUTED := Color("8a8790")
const FOCUS := Color("f4d7a1")
const PIN := Color("d95555")
const PIN_DEEP := Color("7d252f")
const PIN_GLOW := Color("ff8a72")
const PAN := Color("5e8fd8")
const PAN_DEEP := Color("263f78")
const PAN_GLOW := Color("90c8ff")
const DANGER := Color("bf6571")
const ACT_ONE_LAST_ROOM := 6

enum AppState { INTRO, MENU, SETTINGS, LOADING, PROLOGUE, GAME, PAUSE, ACT_COMPLETE, EXIT_CONFIRM, CREDITS }
enum PrologueState { WAKE, MOVE, HAND, BREAK, FALL, LAND }
enum World { FIELDS, FOREST, PEAKS, ECHO, WASTES, HEART }

var app_state := AppState.INTRO
var settings_return := AppState.MENU
var prologue_state := PrologueState.WAKE
var world := World.FIELDS
var room := 0
var room_title := ""
var room_subtitle := ""
var font: Font
var time := 0.0
var state_time := 0.0
var room_time := 0.0
var fade := 1.0
var loading := 0.0
var menu_focus := 0
var settings_focus := 0
var pause_focus := 0
var mouse := Vector2(960.0, 540.0)
var cursor_trail: Array[Vector2] = []
var mouse_moved := false
var particles: Array[Dictionary] = []
var game_started := false
var act_complete := false
var checkpoint_room := 0
var memory_nodes := 0
var memories: Array[int] = []
var ending := ""
var settings := {"master": 80, "music": 80, "sfx": 80, "thread": 65, "symbols": false, "motion": false, "contrast": false}

var pin_pos := Vector2(260.0, 740.0)
var pan_pos := Vector2(410.0, 740.0)
var pin_vel := Vector2.ZERO
var pan_vel := Vector2.ZERO
var pin_grounded := false
var pan_grounded := false
var pin_jump := false
var pan_jump := false
var tension := 0.0
var input_lock := 0.0
var pin_awake := 0.0
var pan_awake := 0.0
var letterbox := 0.0
var prologue_elapsed := 0.0
var hand_progress := 0.0
var bind_active := false
var anchor_point := Vector2.ZERO
var bridge_active := false
var door_open := false
var room_message := ""
var room_message_time := 0.0
var enemies: Array[Dictionary] = []
var traps: Array[Rect2] = []
var chase_pressure := 0.0
var ignite_ready := false
var paused_from_game := false
var paused_state_time := 0.0

var platforms: Array[Rect2] = []
var pads: Array[Rect2] = []
var gate := Rect2()
var exit_zone := Rect2()
var memory_point := Vector2.ZERO
var wind_strength := 0.0
var wind_base := 0.0
var wind_direction := 1.0
var wind_cycle := 0.0
var echo_active := false
var echo_timer := 0.0
var echo_latched := false
var echo_point := Vector2.ZERO
var fragile_platforms: Array[Dictionary] = []
var ending_zones: Array[Dictionary] = []
var final_reveal := false
var intro_time := 0.0
var mechanic_hint := ""
var mechanic_hint_time := 0.0
var hint_seen: Dictionary = {}
var camera_offset := Vector2.ZERO
var screen_shake := 0.0
var thread_flash := 0.0
var sfx_player: AudioStreamPlayer
var dragged_slider := -1

func _ready() -> void:
	font = ThemeDB.fallback_font
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = &"Master"
	add_child(sfx_player)
	for i in range(64):
		particles.append({"p": Vector2(fposmod(float(i * 137), 1920.0), fposmod(float(i * 83), 1080.0)), "speed": 2.0 + float(i % 6), "alpha": 0.05 + float(i % 4) * 0.03})
	_load_save()
	_configure_room(0, false)
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	if app_state != AppState.PAUSE:
		state_time += delta
	for particle in particles:
		particle.p.x -= particle.speed * delta
		if particle.p.x < -8.0:
			particle.p.x = 1928.0
	if fade > 0.0:
		fade = max(0.0, fade - delta * 1.8)
	if room_message_time > 0.0:
		room_message_time = max(0.0, room_message_time - delta)
	if mechanic_hint_time > 0.0:
		mechanic_hint_time = max(0.0, mechanic_hint_time - delta)
	screen_shake = maxf(0.0, screen_shake - delta * 2.8)
	thread_flash = maxf(0.0, thread_flash - delta * 2.4)
	if app_state == AppState.LOADING:
		loading = min(1.0, loading + delta * 1.3)
		if loading >= 1.0:
			_start_prologue()
	elif app_state == AppState.PROLOGUE:
		_update_prologue(delta)
	elif app_state == AppState.GAME:
		_update_game(delta)
	elif app_state == AppState.INTRO:
		intro_time += delta
		if intro_time >= 14.0:
			app_state = AppState.MENU
			state_time = 0.0
	_update_camera(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = _to_canvas(event.position)
		cursor_trail.push_front(mouse)
		if cursor_trail.size() > 10:
			cursor_trail.pop_back()
		mouse_moved = true
		_update_hover_from_mouse()
		if app_state == AppState.SETTINGS and dragged_slider >= 0:
			_set_slider(dragged_slider, int(clampf((mouse.x - 900.0) / 3.9, 0.0, 100.0)))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(mouse)
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dragged_slider = -1
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)
	if event is InputEventJoypadButton and event.pressed:
		_joy_button(event.button_index, event.device)

func _key(key: Key) -> void:
	if app_state == AppState.INTRO:
		if intro_time >= 2.0 and key in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			app_state = AppState.MENU
			state_time = 0.0
		return
	if app_state == AppState.PROLOGUE:
		if key in [KEY_A, KEY_W, KEY_S, KEY_D] and prologue_state == PrologueState.WAKE:
			pin_awake = min(1.0, pin_awake + 0.35)
		elif key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and prologue_state == PrologueState.WAKE:
			pan_awake = min(1.0, pan_awake + 0.35)
		elif key in [KEY_SPACE, KEY_ENTER] and prologue_elapsed >= 3.0 and not (prologue_elapsed >= 26.0 and prologue_elapsed < 35.0):
			_finish_prologue()
		elif key == KEY_ESCAPE:
			_open_pause()
		return
	if app_state == AppState.GAME:
		if key == KEY_ESCAPE:
			_open_pause()
		elif key == KEY_W:
			pin_jump = true
		elif key == KEY_UP:
			pan_jump = true
		elif key == KEY_E:
			_try_bind()
		elif key in [KEY_SHIFT, KEY_SLASH]:
			_try_cut_or_ignite()
		return
	if app_state == AppState.MENU:
		if key in [KEY_DOWN, KEY_S]:
			menu_focus = (menu_focus + 1) % _menu_options().size()
		elif key in [KEY_UP, KEY_W]:
			menu_focus = posmod(menu_focus - 1, _menu_options().size())
		elif key in [KEY_ENTER, KEY_SPACE]:
			_activate_menu(menu_focus)
		elif key == KEY_ESCAPE:
			app_state = AppState.EXIT_CONFIRM
			state_time = 0.0
		return
	if app_state == AppState.SETTINGS:
		if key in [KEY_DOWN, KEY_S]:
			settings_focus = (settings_focus + 1) % _settings_rows().size()
		elif key in [KEY_UP, KEY_W]:
			settings_focus = posmod(settings_focus - 1, _settings_rows().size())
		elif key == KEY_LEFT:
			_adjust_setting(-1)
		elif key == KEY_RIGHT:
			_adjust_setting(1)
		elif key in [KEY_ENTER, KEY_SPACE]:
			_activate_setting(settings_focus)
		elif key == KEY_ESCAPE:
			_close_settings()
		return
	if app_state == AppState.PAUSE:
		if key in [KEY_DOWN, KEY_S]:
			pause_focus = (pause_focus + 1) % 3
		elif key in [KEY_UP, KEY_W]:
			pause_focus = posmod(pause_focus - 1, 3)
		elif key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			if key == KEY_ESCAPE:
				_close_pause()
			else:
				_activate_pause(pause_focus)
		return
	if app_state == AppState.ACT_COMPLETE:
		if key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_return_to_menu()
		return
	if app_state == AppState.CREDITS:
		if key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_return_to_menu()
		return
	if app_state == AppState.EXIT_CONFIRM:
		if key in [KEY_ENTER, KEY_SPACE]:
			get_tree().quit()
		elif key == KEY_ESCAPE:
			app_state = AppState.MENU
			state_time = 0.0

func _joy_button(button: JoyButton, device: int) -> void:
	if app_state == AppState.GAME:
		if button == JOY_BUTTON_START:
			_open_pause()
		elif button == JOY_BUTTON_A:
			if device == 0:
				pin_jump = true
			else:
				pan_jump = true
		elif button == JOY_BUTTON_X:
			_try_bind()
		elif button == JOY_BUTTON_Y:
			_try_cut_or_ignite()
	elif app_state == AppState.PROLOGUE:
		if button == JOY_BUTTON_START and prologue_elapsed >= 3.0:
			_finish_prologue()
		elif prologue_state == PrologueState.WAKE:
			if device == 0:
				pin_awake = min(1.0, pin_awake + 0.35)
			else:
				pan_awake = min(1.0, pan_awake + 0.35)
	elif button == JOY_BUTTON_A:
		if app_state == AppState.MENU:
			_activate_menu(menu_focus)
		elif app_state == AppState.PAUSE:
			_activate_pause(pause_focus)

func _click(p: Vector2) -> void:
	if app_state == AppState.INTRO:
		if intro_time >= 2.0:
			app_state = AppState.MENU
			state_time = 0.0
		return
	if app_state == AppState.MENU:
		var index := _menu_hit(p)
		if index >= 0:
			menu_focus = index
			_activate_menu(index)
	elif app_state == AppState.SETTINGS:
		var row := _settings_hit(p)
		if row >= 0:
			settings_focus = row
			if row < 4:
				var value := int(clamp((p.x - 900.0) / 3.9, 0.0, 100.0))
				_set_slider(row, value)
				dragged_slider = row
			else:
				_activate_setting(row)
	elif app_state == AppState.PAUSE:
		var pause_index := _pause_hit(p)
		if pause_index >= 0:
			pause_focus = pause_index
			_activate_pause(pause_index)
	elif app_state == AppState.PROLOGUE and p.x > 1520.0 and p.y > 930.0 and prologue_elapsed >= 3.0:
		_finish_prologue()
	elif app_state == AppState.EXIT_CONFIRM:
		if Rect2(690, 520, 270, 64).has_point(p):
			get_tree().quit()
		elif Rect2(970, 520, 270, 64).has_point(p):
			app_state = AppState.MENU
			state_time = 0.0
	elif app_state == AppState.ACT_COMPLETE:
		_return_to_menu()
	elif app_state == AppState.CREDITS:
		_return_to_menu()

func _update_hover_from_mouse() -> void:
	if app_state == AppState.MENU:
		var i := _menu_hit(mouse)
		if i >= 0:
			menu_focus = i
	elif app_state == AppState.SETTINGS:
		var row := _settings_hit(mouse)
		if row >= 0:
			settings_focus = row
	elif app_state == AppState.PAUSE:
		var pause_index := _pause_hit(mouse)
		if pause_index >= 0:
			pause_focus = pause_index

func _menu_options() -> Array[String]:
	var options: Array[String] = []
	options.append("ПРОДОЛЖИТЬ" if game_started and not act_complete else "ИГРАТЬ")
	if game_started:
		options.append("НАЧАТЬ ЗАНОВО")
	options.append("НАСТРОЙКИ")
	options.append("ВЫХОД")
	return options

func _menu_hit(p: Vector2) -> int:
	for i in _menu_options().size():
		if Rect2(156.0, 540.0 + i * 76.0, 470.0, 60.0).grow(18.0).has_point(p):
			return i
	return -1

func _activate_menu(index: int) -> void:
	var options := _menu_options()
	if index < 0 or index >= options.size():
		return
	match options[index]:
		"ИГРАТЬ", "НАЧАТЬ ЗАНОВО":
			_start_new_game()
		"ПРОДОЛЖИТЬ":
			if app_state == AppState.MENU:
				_begin_act_gameplay(checkpoint_room)
		"НАСТРОЙКИ":
			settings_return = AppState.MENU
			app_state = AppState.SETTINGS
			settings_focus = 0
			state_time = 0.0
		"ВЫХОД":
			app_state = AppState.EXIT_CONFIRM
			state_time = 0.0

func _start_new_game() -> void:
	game_started = true
	act_complete = false
	checkpoint_room = 0
	memory_nodes = 0
	memories.clear()
	ending = ""
	_save_progress()
	app_state = AppState.LOADING
	loading = 0.0
	state_time = 0.0
	fade = 0.35

func _return_to_menu() -> void:
	app_state = AppState.MENU
	state_time = 0.0
	fade = 0.35
	menu_focus = 0
	_save_progress()

func _settings_rows() -> Array[String]:
	return ["ГРОМКОСТЬ", "МУЗЫКА", "ЭФФЕКТЫ", "НАТЯЖЕНИЕ НИТИ", "СИМВОЛЫ РОЛЕЙ", "УМЕНЬШИТЬ ДВИЖЕНИЕ", "ВЫСОКИЙ КОНТРАСТ", "НАЗАД"]

func _settings_hit(p: Vector2) -> int:
	for i in _settings_rows().size():
		if Rect2(415.0, 318.0 + i * 62.0, 1080.0, 52.0).has_point(p):
			return i
	return -1

func _set_slider(index: int, value: int) -> void:
	match index:
		0: settings.master = value
		1: settings.music = value
		2: settings.sfx = value
		3: settings.thread = value
	_save_progress()

func _adjust_setting(direction: int) -> void:
	if settings_focus < 4:
		var values := [int(settings.master), int(settings.music), int(settings.sfx), int(settings.thread)]
		_set_slider(settings_focus, clampi(values[settings_focus] + direction * 5, 0, 100))
	else:
		_activate_setting(settings_focus)

func _activate_setting(index: int) -> void:
	match index:
		4: settings.symbols = not bool(settings.symbols)
		5: settings.motion = not bool(settings.motion)
		6: settings.contrast = not bool(settings.contrast)
		7: _close_settings()
	_save_progress()

func _close_settings() -> void:
	app_state = settings_return
	state_time = 0.0

func _open_pause() -> void:
	if app_state != AppState.GAME and app_state != AppState.PROLOGUE:
		return
	paused_from_game = app_state == AppState.GAME
	paused_state_time = state_time
	app_state = AppState.PAUSE
	pause_focus = 0
	state_time = 0.0

func _close_pause() -> void:
	app_state = AppState.GAME if paused_from_game else AppState.PROLOGUE
	state_time = paused_state_time

func _pause_hit(p: Vector2) -> int:
	for i in range(3):
		if Rect2(690.0, 410.0 + i * 80.0, 540.0, 58.0).has_point(p):
			return i
	return -1

func _activate_pause(index: int) -> void:
	match index:
		0: _close_pause()
		1:
			settings_return = AppState.PAUSE
			app_state = AppState.SETTINGS
			settings_focus = 0
		2: _return_to_menu()

func _start_prologue() -> void:
	app_state = AppState.PROLOGUE
	prologue_state = PrologueState.WAKE
	prologue_elapsed = 0.0
	state_time = 0.0
	pin_awake = 0.0
	pan_awake = 0.0
	pin_pos = Vector2(840.0, 510.0)
	pan_pos = Vector2(1080.0, 510.0)
	pin_vel = Vector2.ZERO
	pan_vel = Vector2.ZERO
	letterbox = 90.0
	fade = 1.0

func _set_prologue(next_state: PrologueState) -> void:
	prologue_state = next_state
	state_time = 0.0
	if next_state == PrologueState.HAND:
		input_lock = 1.0
	if next_state == PrologueState.LAND:
		pin_pos = Vector2(820.0, 720.0)
		pan_pos = Vector2(1080.0, 720.0)
		pin_vel = Vector2.ZERO
		pan_vel = Vector2.ZERO
		input_lock = 0.5

func _update_prologue(delta: float) -> void:
	prologue_elapsed += delta
	input_lock = maxf(0.0, input_lock - delta)
	if prologue_state == PrologueState.WAKE:
		if (pin_awake >= 1.0 and pan_awake >= 1.0 and state_time > 0.8) or state_time > 10.0:
			pin_awake = 1.0
			pan_awake = 1.0
			_set_prologue(PrologueState.MOVE)
	elif prologue_state == PrologueState.MOVE:
		_update_free_motion(delta, 0.82)
		_update_thread_constraint()
		if state_time > 14.0:
			_set_prologue(PrologueState.HAND)
	elif prologue_state == PrologueState.HAND:
		hand_progress = clampf(state_time / 7.0, 0.0, 1.0)
		if state_time > 1.0:
			_update_free_motion(delta, 0.45)
			_update_thread_constraint()
		if state_time > 7.0:
			_set_prologue(PrologueState.BREAK)
	elif prologue_state == PrologueState.BREAK:
		if state_time > 1.2:
			_set_prologue(PrologueState.FALL)
	elif prologue_state == PrologueState.FALL:
		if state_time > 9.0:
			_set_prologue(PrologueState.LAND)
	elif prologue_state == PrologueState.LAND:
		if state_time > 1.0:
			_update_free_motion(delta, 0.85)
			_update_thread_constraint()
		if state_time > 12.0:
			_finish_prologue()

func _finish_prologue() -> void:
	_begin_act_gameplay(0)

func _update_free_motion(delta: float, multiplier: float) -> void:
	if input_lock > 0.0:
		return
	var pin_input := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var pan_input := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	var left_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var right_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if left_stick.length() > 0.25:
		pin_input = left_stick
	if right_stick.length() > 0.25:
		pan_input = right_stick
	pin_vel = pin_vel.lerp(pin_input.limit_length(1.0) * 150.0 * multiplier, minf(1.0, delta * 8.0))
	pan_vel = pan_vel.lerp(pan_input.limit_length(1.0) * 185.0 * multiplier, minf(1.0, delta * 10.0))
	pin_pos += pin_vel * delta
	pan_pos += pan_vel * delta
	var bounds := Rect2(430.0, 350.0, 1060.0, 440.0)
	if prologue_state == PrologueState.LAND:
		bounds = Rect2(80.0, 570.0, 1740.0, 230.0)
	pin_pos = Vector2(clampf(pin_pos.x, bounds.position.x, bounds.end.x), clampf(pin_pos.y, bounds.position.y, bounds.end.y))
	pan_pos = Vector2(clampf(pan_pos.x, bounds.position.x, bounds.end.x), clampf(pan_pos.y, bounds.position.y, bounds.end.y))

func _begin_act_gameplay(target_room: int) -> void:
	app_state = AppState.GAME
	_configure_room(clampi(target_room, 0, ACT_ONE_LAST_ROOM), true)
	letterbox = 0.0
	state_time = 0.0
	fade = 0.8

func _configure_room(index: int, announce: bool) -> void:
	room = clampi(index, 0, ACT_ONE_LAST_ROOM)
	room_time = 0.0
	bind_active = false
	bridge_active = false
	door_open = false
	enemies.clear()
	traps.clear()
	pads.clear()
	fragile_platforms.clear()
	ending_zones.clear()
	memory_point = Vector2.ZERO
	wind_strength = 0.0
	wind_base = 0.0
	wind_direction = 1.0
	wind_cycle = 0.0
	echo_active = false
	echo_timer = 0.0
	echo_latched = false
	echo_point = Vector2.ZERO
	final_reveal = false
	gate = Rect2()
	platforms.clear()
	match room:
		0:
			world = World.FIELDS
			room_title = "ЛЬНЯНЫЕ ПОЛЯ"
			room_subtitle = "ПЕРВЫЕ ШАГИ"
			platforms = [Rect2(0, 820, 560, 300), Rect2(650, 760, 270, 40), Rect2(1030, 690, 280, 40), Rect2(1410, 800, 510, 320)]
			exit_zone = Rect2(1710, 650, 180, 240)
		1:
			world = World.FIELDS
			room_title = "ЛЬНЯНЫЕ ПОЛЯ"
			room_subtitle = "ДВЕРЬ"
			platforms = [Rect2(0, 820, 1920, 300)]
			pads = [Rect2(620, 790, 95, 30), Rect2(950, 790, 95, 30)]
			gate = Rect2(1300, 490, 42, 330)
			exit_zone = Rect2(1660, 650, 190, 240)
		2:
			world = World.FIELDS
			room_title = "ЛЬНЯНЫЕ ПОЛЯ"
			room_subtitle = "ПЕРВЫЙ УЗЕЛ"
			platforms = [Rect2(0, 820, 680, 300), Rect2(1190, 760, 730, 360)]
			anchor_point = Vector2(570, 750)
			memory_point = Vector2(360, 750)
			exit_zone = Rect2(1690, 620, 180, 250)
		3:
			world = World.FIELDS
			room_title = "ЛЬНЯНЫЕ ПОЛЯ"
			room_subtitle = "СПУСК"
			platforms = [Rect2(0, 760, 420, 360), Rect2(490, 810, 300, 300), Rect2(860, 730, 260, 390), Rect2(1200, 780, 720, 340)]
			memory_point = Vector2(610, 750)
			exit_zone = Rect2(1690, 600, 180, 270)
		4:
			world = World.FOREST
			room_title = "ШЕРСТЯНОЙ ЛЕС"
			room_subtitle = "ПЕРВАЯ ВСТРЕЧА"
			platforms = [Rect2(0, 820, 1920, 300)]
			enemies.append({"pos": Vector2(980, 760), "home": 980.0, "range": 170.0, "dir": 1.0, "bound": false, "cut": false, "alert": 0.0})
			exit_zone = Rect2(1660, 650, 190, 240)
		5:
			world = World.FOREST
			room_title = "ШЕРСТЯНОЙ ЛЕС"
			room_subtitle = "КАТУШКИ"
			platforms = [Rect2(0, 820, 620, 300), Rect2(710, 740, 270, 380), Rect2(1090, 810, 830, 310)]
			traps = [Rect2(770, 702, 55, 38), Rect2(1240, 772, 65, 38), Rect2(1470, 772, 65, 38)]
			enemies.append({"pos": Vector2(930, 570), "home": 930.0, "range": 210.0, "dir": 1.0, "bound": false, "cut": false, "drone": true, "alert": 0.0})
			exit_zone = Rect2(1660, 650, 190, 240)
		6:
			world = World.FOREST
			room_title = "ШЕРСТЯНОЙ ЛЕС"
			room_subtitle = "ПОГОНЯ"
			platforms = [Rect2(0, 820, 520, 300), Rect2(600, 750, 270, 370), Rect2(970, 690, 260, 430), Rect2(1320, 800, 600, 320)]
			enemies.append({"pos": Vector2(120, 760), "home": 120.0, "range": 1000.0, "dir": 1.0, "bound": false, "cut": false, "chaser": true, "alert": 1.0})
			exit_zone = Rect2(1690, 610, 180, 270)
		7:
			world = World.PEAKS
			room_title = "ШЁЛКОВЫЕ ПИКИ"
			room_subtitle = "ПЕРВЫЙ ПОРЫВ"
			platforms = [Rect2(0, 820, 700, 300), Rect2(760, 820, 1160, 300)]
			wind_strength = 70.0
			wind_base = 70.0
			wind_direction = 1.0
			memory_point = Vector2(420, 760)
			exit_zone = Rect2(1680, 650, 180, 240)
		8:
			world = World.PEAKS
			room_title = "ШЁЛКОВЫЕ ПИКИ"
			room_subtitle = "СКОЛЬЗКИЙ КАРНИЗ"
			platforms = [Rect2(0, 820, 540, 300), Rect2(720, 710, 280, 410), Rect2(1190, 800, 730, 320)]
			anchor_point = Vector2(470, 748)
			wind_strength = 120.0
			wind_base = 120.0
			wind_direction = -1.0
			exit_zone = Rect2(1680, 620, 180, 270)
		9:
			world = World.PEAKS
			room_title = "ШЁЛКОВЫЕ ПИКИ"
			room_subtitle = "РАЗОРВАННАЯ НИТЬ"
			platforms = [Rect2(0, 810, 520, 310), Rect2(610, 755, 260, 365), Rect2(960, 700, 300, 420), Rect2(1360, 800, 560, 320)]
			wind_strength = 85.0
			wind_base = 85.0
			wind_direction = 1.0
			memory_point = Vector2(1110, 640)
			exit_zone = Rect2(1680, 620, 180, 270)
		10:
			world = World.PEAKS
			room_title = "ШЁЛКОВЫЕ ПИКИ"
			room_subtitle = "ПОЛОТНИЩЕ-СТРАЖ"
			platforms = [Rect2(0, 820, 480, 300), Rect2(590, 745, 250, 375), Rect2(950, 670, 260, 450), Rect2(1320, 800, 600, 320)]
			wind_strength = 145.0
			wind_base = 145.0
			wind_direction = -1.0
			gate = Rect2(1220, 430, 40, 340)
			exit_zone = Rect2(1680, 620, 180, 270)
		11:
			world = World.ECHO
			room_title = "ЗАЛ ЭХА"
			room_subtitle = "ПЕРВЫЙ ОТГОЛОСОК"
			platforms = [Rect2(0, 820, 1920, 300)]
			echo_point = Vector2(700, 760)
			gate = Rect2(1120, 490, 42, 330)
			memory_point = Vector2(450, 760)
			exit_zone = Rect2(1660, 650, 190, 240)
		12:
			world = World.ECHO
			room_title = "ЗАЛ ЭХА"
			room_subtitle = "ДВЕ ФАЗЫ"
			platforms = [Rect2(0, 820, 1920, 300)]
			pads = [Rect2(650, 790, 95, 30), Rect2(980, 790, 95, 30)]
			echo_point = Vector2(540, 760)
			gate = Rect2(1320, 490, 42, 330)
			exit_zone = Rect2(1660, 650, 190, 240)
		13:
			world = World.ECHO
			room_title = "ЗАЛ ЭХА"
			room_subtitle = "РУКА ТКАЧА"
			platforms = [Rect2(0, 820, 1920, 300)]
			final_reveal = true
			exit_zone = Rect2(1660, 650, 190, 240)
		14:
			world = World.WASTES
			room_title = "ИСТРЁПАННЫЕ ПУСТОШИ"
			room_subtitle = "ПЕРВЫЙ РАЗЛОМ"
			platforms = [Rect2(0, 820, 580, 300), Rect2(1320, 800, 600, 320)]
			fragile_platforms = [{"rect": Rect2(650, 765, 250, 38), "touched": -1.0, "gone": false}, {"rect": Rect2(990, 710, 240, 38), "touched": -1.0, "gone": false}]
			memory_point = Vector2(530, 760)
			exit_zone = Rect2(1680, 620, 180, 270)
		15:
			world = World.WASTES
			room_title = "ИСТРЁПАННЫЕ ПУСТОШИ"
			room_subtitle = "РОЙ ВОЗВРАЩАЕТСЯ"
			platforms = [Rect2(0, 820, 500, 300), Rect2(590, 750, 250, 370), Rect2(940, 685, 260, 435), Rect2(1300, 800, 620, 320)]
			enemies.append({"pos": Vector2(90, 760), "home": 90.0, "range": 1200.0, "dir": 1.0, "bound": false, "cut": false, "chaser": true, "alert": 1.0})
			enemies.append({"pos": Vector2(10, 760), "home": 10.0, "range": 1200.0, "dir": 1.0, "bound": false, "cut": false, "chaser": true, "alert": 1.0})
			exit_zone = Rect2(1680, 620, 180, 270)
		16:
			world = World.WASTES
			room_title = "ИСТРЁПАННЫЕ ПУСТОШИ"
			room_subtitle = "КРАЙ ПУСТОШЕЙ"
			platforms = [Rect2(0, 820, 1920, 300)]
			memory_point = Vector2(960, 760)
			exit_zone = Rect2(1660, 650, 190, 240)
		17:
			world = World.HEART
			room_title = "СЕРДЦЕ СТАНКА"
			room_subtitle = "ЗАЛ ИСПЫТАНИЯ"
			platforms = [Rect2(0, 820, 510, 300), Rect2(610, 735, 260, 385), Rect2(980, 680, 260, 440), Rect2(1340, 800, 580, 320)]
			anchor_point = Vector2(440, 750)
			enemies.append({"pos": Vector2(1030, 620), "home": 1030.0, "range": 80.0, "dir": 1.0, "bound": false, "cut": false, "alert": 0.0})
			memory_point = Vector2(760, 675)
			exit_zone = Rect2(1680, 620, 180, 270)
		18:
			world = World.HEART
			room_title = "СЕРДЦЕ СТАНКА"
			room_subtitle = "ПРИЗНАНИЕ"
			platforms = [Rect2(0, 820, 1920, 300)]
			final_reveal = true
			exit_zone = Rect2(1660, 650, 190, 240)
		19:
			world = World.HEART
			room_title = "СЕРДЦЕ СТАНКА"
			room_subtitle = "УЗЕЛ"
			platforms = [Rect2(0, 820, 1920, 300)]
			ending_zones = [
				{"rect": Rect2(290, 580, 260, 240), "id": "РАЗРЫВ"},
				{"rect": Rect2(830, 580, 260, 240), "id": "ПЕРЕПЛЕТЕНИЕ"},
				{"rect": Rect2(1370, 580, 260, 240), "id": "ВОССОЕДИНЕНИЕ"}
			]
			exit_zone = Rect2()
	pin_pos = Vector2(180, 740)
	pan_pos = Vector2(320, 740)
	pin_vel = Vector2.ZERO
	pan_vel = Vector2.ZERO
	tension = 0.0
	checkpoint_room = room
	_save_progress()
	if announce:
		room_message = room_title + "  —  " + room_subtitle
		room_message_time = 3.2
	_show_room_hint()

func _update_game(delta: float) -> void:
	room_time += delta
	wind_cycle += delta
	if wind_base > 0.0:
		var phase := fmod(wind_cycle, 5.0)
		if room == 10:
			wind_strength = wind_base if phase < 2.0 else 0.0
		elif room in [7, 8, 9]:
			wind_strength = wind_base + 65.0 * maxf(0.0, sin(phase * PI / 2.5))
	_update_player_physics(delta)
	_update_enemies(delta)
	_update_fragile_platforms(delta)
	_update_room_logic(delta)
	if pin_pos.y > 1090.0 or pan_pos.y > 1090.0:
		_reset_checkpoint("НИТЬ ВЕРНУЛА ВАС К БЕЗОПАСНОЙ ТОЧКЕ")

func _show_room_hint() -> void:
	var id := "room_" + str(room)
	if hint_seen.has(id):
		return
	hint_seen[id] = true
	match room:
		0: _show_hint("ВЕДИ PIN И PAN ОТДЕЛЬНО. ЧЕМ ДАЛЬШЕ ОНИ ДРУГ ОТ ДРУГА, ТЕМ СИЛЬНЕЕ НИТЬ.", 4.5)
		1: _show_hint("ПОСТАВЬТЕ PIN И PAN НА ДВЕ СВЕТЯЩИЕСЯ ПЛИТЫ.", 4.0)
		2: _show_hint("PIN: E У КРАСНОГО ЯКОРЯ. ОН СОЗДАСТ ОПОРУ ДЛЯ PAN.", 4.5)
		4: _show_hint("PIN: E — ЗАКРЕПИТЬ КОРРЕКТОРА. PAN: SHIFT — РАСПУСТИТЬ ЕГО.", 4.5)
		6: _show_hint("КОГДА НИТЬ НАТЯНУТА, SHIFT ДАЁТ РЫВОК СПАСЕНИЯ.", 4.0)
		7: _show_hint("ВЕТЕР СНОСИТ PAN СИЛЬНЕЕ. PIN МОЖЕТ ДЕРЖАТЬ ЯКОРЬ КЛАВИШЕЙ E.", 4.5)
		11: _show_hint("PIN НАЖИМАЕТ E У ГОЛУБОГО УЗЛА. ЭХО ПОВТОРИТ ДЕЙСТВИЕ.", 4.5)
		14: _show_hint("ТРЕСК И РЯБЬ ПРЕДУПРЕЖДАЮТ: ТКАНЬ СОРВЁТСЯ ЧЕРЕЗ МГНОВЕНИЕ.", 4.5)
		19: _show_hint("ПОДВЕДИТЕ ОБОИХ К ОДНОМУ ИЗ ТРЁХ УЗЛОВ. ТРЕТИЙ ПУТЬ ТРЕБУЕТ 8 ВОСПОМИНАНИЙ.", 5.0)

func _show_hint(message: String, duration: float) -> void:
	mechanic_hint = message
	mechanic_hint_time = duration

func _update_camera(delta: float) -> void:
	if app_state != AppState.GAME:
		camera_offset = camera_offset.lerp(Vector2.ZERO, minf(1.0, delta * 4.0))
		return
	var midpoint := (pin_pos + pan_pos) * 0.5
	var target := Vector2(clampf((960.0 - midpoint.x) * 0.08, -70.0, 70.0), clampf((590.0 - midpoint.y) * 0.05, -25.0, 25.0))
	camera_offset = camera_offset.lerp(target, minf(1.0, delta * 2.8))

func _movement_input(is_pin: bool) -> float:
	var axis := 0.0
	if is_pin:
		axis = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var joy := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		if absf(joy) > 0.25:
			axis = joy
	else:
		axis = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		var joy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		if absf(joy) > 0.25:
			axis = joy
	return axis

func _update_player_physics(delta: float) -> void:
	if input_lock > 0.0:
		return
	var pin_axis := _movement_input(true)
	var pan_axis := _movement_input(false)
	pin_vel.x = move_toward(pin_vel.x, pin_axis * 255.0, 1450.0 * delta)
	pan_vel.x = move_toward(pan_vel.x, pan_axis * 315.0, 1700.0 * delta)
	if pin_axis == 0.0:
		pin_vel.x = move_toward(pin_vel.x, 0.0, 1050.0 * delta)
	if pan_axis == 0.0:
		pan_vel.x = move_toward(pan_vel.x, 0.0, 1250.0 * delta)
	if pin_jump and pin_grounded:
		pin_vel.y = -520.0
		pin_grounded = false
		_sfx(185.0, 0.07, 0.10)
	if pan_jump and pan_grounded:
		pan_vel.y = -585.0
		pan_grounded = false
		_sfx(255.0, 0.07, 0.10)
	pin_jump = false
	pan_jump = false
	pin_vel.y += 1350.0 * delta
	pan_vel.y += 1350.0 * delta
	if wind_strength > 0.0:
		var pin_wind := 0.0 if bind_active else wind_strength * wind_direction
		pin_vel.x += pin_wind * delta
		pan_vel.x += wind_strength * wind_direction * 1.32 * delta
	pin_pos = _move_character(pin_pos, pin_vel, true, delta)
	pan_pos = _move_character(pan_pos, pan_vel, false, delta)
	_update_thread_constraint()

func _move_character(pos: Vector2, velocity: Vector2, is_pin: bool, delta: float) -> Vector2:
	var radius := 29.0
	var old_bottom := pos.y + radius
	var next := pos + velocity * delta
	var grounded := false
	for platform in platforms:
			if next.x + radius > platform.position.x and next.x - radius < platform.end.x:
				if velocity.y >= 0.0 and old_bottom <= platform.position.y + 8.0 and next.y + radius >= platform.position.y:
					next.y = platform.position.y - radius
					if is_pin:
						pin_vel.y = 0.0
					else:
						pan_vel.y = 0.0
					grounded = true
	for fragile_index in fragile_platforms.size():
		var fragile: Dictionary = fragile_platforms[fragile_index]
		if bool(fragile.gone):
			continue
		var fragile_rect: Rect2 = fragile.rect
		if next.x + radius > fragile_rect.position.x and next.x - radius < fragile_rect.end.x:
			if velocity.y >= 0.0 and old_bottom <= fragile_rect.position.y + 8.0 and next.y + radius >= fragile_rect.position.y:
				next.y = fragile_rect.position.y - radius
				if is_pin:
					pin_vel.y = 0.0
				else:
					pan_vel.y = 0.0
				grounded = true
				if float(fragile.touched) < 0.0:
					fragile.touched = room_time
					fragile_platforms[fragile_index] = fragile
	var actor_rect := Rect2(next - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	if gate.size != Vector2.ZERO and not door_open and actor_rect.intersects(gate.grow(0.0)):
		if velocity.x > 0.0 and next.x + radius > gate.position.x and pos.x < gate.position.x:
			next.x = gate.position.x - radius
			if is_pin:
				pin_vel.x = 0.0
			else:
				pan_vel.x = 0.0
	if is_pin:
		pin_grounded = grounded
	else:
		pan_grounded = grounded
	return next

func _update_thread_constraint() -> void:
	var delta_pos := pan_pos - pin_pos
	var distance := delta_pos.length()
	tension = clampf((distance - 260.0) / 185.0, 0.0, 1.0)
	if distance > 445.0:
		var correction := delta_pos.normalized() * (distance - 445.0) * 0.5
		pin_pos += correction
		pan_pos -= correction
	if tension > 0.74:
		ignite_ready = true
		thread_flash = maxf(thread_flash, tension * 0.34)

func _try_bind() -> void:
	if app_state != AppState.GAME:
		return
	if room == 2 and not bind_active and pin_pos.distance_to(anchor_point) < 115.0:
		bind_active = true
		bridge_active = true
		thread_flash = 0.75
		screen_shake = 0.12
		platforms.append(Rect2(650, 735, 570, 36))
		_show_message("PIN ЗАКРЕПИЛ НИТЬ — ПУТЬ СОЗДАН", 2.6)
		_sfx(155.0, 0.16, 0.22)
		return
	if world == World.PEAKS and anchor_point != Vector2.ZERO and pin_pos.distance_to(anchor_point) < 120.0:
		bind_active = not bind_active
		_show_message("PIN ДЕРЖИТСЯ ПРОТИВ ВЕТРА" if bind_active else "PIN ОТПУСТИЛ ЯКОРЬ", 1.8)
		_sfx(145.0 if bind_active else 205.0, 0.12, 0.16)
		return
	if world == World.ECHO and echo_point != Vector2.ZERO and pin_pos.distance_to(echo_point) < 130.0:
		echo_active = true
		echo_timer = 1.5
		_show_message("ЭХО ПОВТОРИТ ДЕЙСТВИЕ ЧЕРЕЗ МГНОВЕНИЕ", 1.8)
		_sfx(410.0, 0.20, 0.14)
		return
	for enemy in enemies:
		if not bool(enemy.cut) and not bool(enemy.bound) and pin_pos.distance_to(enemy.pos) < 145.0:
			enemy.bound = true
			thread_flash = 0.55
			_show_message("КОРРЕКТОР ЗАКРЕПЛЁН", 1.8)
			_sfx(170.0, 0.16, 0.20)
			return
	_show_message("PIN МОЖЕТ ЗАКРЕПИТЬ ЯКОРЬ ИЛИ КОРРЕКТОРА", 1.5)

func _try_cut_or_ignite() -> void:
	if app_state != AppState.GAME:
		return
	if room == 6 and tension > 0.4:
		var direction := (pan_pos - pin_pos).normalized()
		pin_vel += direction * 390.0
		pan_vel -= direction * 210.0
		_show_message("IGNITE — НИТЬ ВЫТЯНУЛА ПАРТНЁРА", 1.6)
		_sfx(560.0, 0.18, 0.26)
		thread_flash = 0.95
		screen_shake = 0.18
		return
	for enemy in enemies:
		if not bool(enemy.cut) and pan_pos.distance_to(enemy.pos) < 155.0:
			enemy.cut = true
			enemy.bound = false
			thread_flash = 0.60
			_show_message("PAN РАСПУСТИЛ СВЯЗЬ", 1.8)
			_sfx(390.0, 0.15, 0.20)
			return
	_show_message("PAN МОЖЕТ РАСПУСТИТЬ УГРОЗУ ИЛИ ВЫСВОБОДИТЬ РЫВОК", 1.5)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		if bool(enemy.cut) or bool(enemy.bound):
			continue
		var speed := 75.0 if not enemy.has("chaser") else 160.0
		if enemy.has("drone"):
			enemy.pos.x += float(enemy.dir) * speed * delta
			if absf(enemy.pos.x - float(enemy.home)) > float(enemy.range):
				enemy.dir = -float(enemy.dir)
		elif enemy.has("chaser"):
			var target := minf(pin_pos.x, pan_pos.x)
			enemy.pos.x = move_toward(enemy.pos.x, target - 85.0, speed * delta)
			chase_pressure = clampf(chase_pressure + delta * 0.11, 0.0, 1.0)
		else:
			enemy.pos.x += float(enemy.dir) * speed * delta
			if absf(enemy.pos.x - float(enemy.home)) > float(enemy.range):
				enemy.dir = -float(enemy.dir)
		if enemy.pos.distance_to(pin_pos) < 48.0 or enemy.pos.distance_to(pan_pos) < 48.0:
			_reset_checkpoint("КОРРЕКТОР ПОЧТИ РАЗДЕЛИЛ ВАС")
	for trap in traps:
		if trap.grow(15.0).has_point(pin_pos) or trap.grow(15.0).has_point(pan_pos):
			_reset_checkpoint("УЗЕЛ УДЕРЖАЛ ОДНОГО ИЗ ВАС")

func _update_room_logic(delta: float) -> void:
	if memory_point != Vector2.ZERO and not memories.has(room):
		if pin_pos.distance_to(memory_point) < 70.0 or pan_pos.distance_to(memory_point) < 70.0:
			memories.append(room)
			memory_nodes = memories.size()
			_show_message("УЗЕЛ ПАМЯТИ СОХРАНЁН  " + str(memory_nodes) + "/8", 2.4)
			_sfx(520.0, 0.24, 0.16)
			_save_progress()
	if world == World.ECHO and echo_active:
		echo_timer -= delta
		if echo_timer <= 0.0:
			echo_active = false
			echo_latched = true
			if room == 11:
				door_open = true
			_show_message("ЭХО УДЕРЖАЛО МЕХАНИЗМ", 1.8)
			_sfx(330.0, 0.22, 0.16)
	if room == 1:
		var both_on_pads := pads.size() == 2 and ((pads[0].grow(20.0).has_point(pin_pos) and pads[1].grow(20.0).has_point(pan_pos)) or (pads[1].grow(20.0).has_point(pin_pos) and pads[0].grow(20.0).has_point(pan_pos)))
		if both_on_pads and not door_open:
			door_open = true
			_show_message("ДВЕРЬ ОТКРЫТА — ВЫ СДЕЛАЛИ ЭТО ВМЕСТЕ", 2.5)
	if room == 12:
		var two_phase := pads.size() == 2 and (pads[0].grow(25.0).has_point(pin_pos) or pads[0].grow(25.0).has_point(pan_pos)) and (pads[1].grow(25.0).has_point(pin_pos) or pads[1].grow(25.0).has_point(pan_pos))
		if two_phase and echo_latched:
			door_open = true
			_show_message("ДВЕ ФАЗЫ СОШЛИСЬ В ОДИН ПРОХОД", 2.4)
	if room == 10 and bind_active and wind_strength <= 0.0:
		if not door_open:
			door_open = true
			_show_message("ШТИЛЬ. ЯКОРЬ ДЕРЖИТ ПРОХОД ОТКРЫТЫМ.", 2.4)
	if room == 13 and room_time > 4.0:
		_show_message("РУКА ТКАЧА ПОВТОРИЛА ВАШЕ ДВИЖЕНИЕ", 2.0)
	if room == 19:
		_update_final_choice()
		return
	if room == 4:
		var resolved := true
		for enemy in enemies:
			resolved = resolved and (bool(enemy.bound) or bool(enemy.cut))
		if not resolved and minf(pin_pos.x, pan_pos.x) > 1300.0:
			_show_message("КОРРЕКТОР ПЕРЕКРЫВАЕТ ПУТЬ", 1.5)
	if exit_zone.grow(20.0).has_point(pin_pos) and exit_zone.grow(20.0).has_point(pan_pos):
		if room == 4:
			var resolved := true
			for enemy in enemies:
				resolved = resolved and (bool(enemy.bound) or bool(enemy.cut))
			if not resolved:
				return
		_next_room()

func _next_room() -> void:
	if room >= ACT_ONE_LAST_ROOM:
		act_complete = true
		app_state = AppState.ACT_COMPLETE
		state_time = 0.0
		_save_progress()
		return
	_configure_room(room + 1, true)

func _update_fragile_platforms(delta: float) -> void:
	for fragile_index in fragile_platforms.size():
		var fragile: Dictionary = fragile_platforms[fragile_index]
		if not bool(fragile.gone) and float(fragile.touched) >= 0.0 and room_time - float(fragile.touched) >= 0.7:
			fragile.gone = true
			fragile_platforms[fragile_index] = fragile
			_show_message("ТКАНЬ СОРВАЛАСЬ — ИЩИТЕ ОПОРУ", 1.5)
			screen_shake = 0.20
			_sfx(95.0, 0.22, 0.24)

func _update_final_choice() -> void:
	for choice in ending_zones:
		var rect: Rect2 = choice.rect
		if rect.has_point(pin_pos) and rect.has_point(pan_pos):
			var choice_id: String = choice.id
			if choice_id == "ВОССОЕДИНЕНИЕ" and memory_nodes < 8:
				_show_message("ОБРЫВОК ТКАЧА СЛИШКОМ ДАЛЕКО", 1.6)
				return
			ending = choice_id
			act_complete = true
			app_state = AppState.ACT_COMPLETE
			_save_progress()
			return

func _reset_checkpoint(message: String) -> void:
	_configure_room(checkpoint_room, false)
	_show_message(message, 2.4)

func _show_message(message: String, duration: float) -> void:
	room_message = message
	room_message_time = duration

func _sfx(frequency: float, duration: float, gain: float = 0.18) -> void:
	if sfx_player == null:
		return
	var volume := float(settings.master) / 100.0 * float(settings.sfx) / 100.0
	if volume <= 0.001:
		return
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var fade_out := 1.0 - float(i) / float(samples)
		var value := int(sin(TAU * frequency * float(i) / float(rate)) * 32767.0 * gain * fade_out)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	sfx_player.stream = stream
	sfx_player.volume_db = linear_to_db(maxf(0.001, volume))
	sfx_player.play()

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "started", game_started)
	config.set_value("progress", "act_complete", act_complete)
	config.set_value("progress", "checkpoint_room", checkpoint_room)
	config.set_value("progress", "memory_nodes", memory_nodes)
	config.set_value("progress", "memories", memories)
	config.set_value("progress", "ending", ending)
	config.set_value("settings", "master", settings.master)
	config.set_value("settings", "music", settings.music)
	config.set_value("settings", "sfx", settings.sfx)
	config.set_value("settings", "thread", settings.thread)
	config.set_value("settings", "symbols", settings.symbols)
	config.set_value("settings", "motion", settings.motion)
	config.set_value("settings", "contrast", settings.contrast)
	config.save("user://pinpan.save")

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://pinpan.save") != OK:
		return
	game_started = bool(config.get_value("progress", "started", false))
	act_complete = bool(config.get_value("progress", "act_complete", false))
	checkpoint_room = int(config.get_value("progress", "checkpoint_room", 0))
	memory_nodes = int(config.get_value("progress", "memory_nodes", 0))
	memories.assign(config.get_value("progress", "memories", []))
	ending = str(config.get_value("progress", "ending", ""))
	settings.master = int(config.get_value("settings", "master", 80))
	settings.music = int(config.get_value("settings", "music", 80))
	settings.sfx = int(config.get_value("settings", "sfx", 80))
	settings.thread = int(config.get_value("settings", "thread", 65))
	settings.symbols = bool(config.get_value("settings", "symbols", false))
	settings.motion = bool(config.get_value("settings", "motion", false))
	settings.contrast = bool(config.get_value("settings", "contrast", false))

func _draw() -> void:
	var scale_factor: float = min(get_viewport_rect().size.x / SIZE.x, get_viewport_rect().size.y / SIZE.y)
	var offset: Vector2 = (get_viewport_rect().size - SIZE * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	match app_state:
		AppState.INTRO:
			_draw_intro()
		AppState.MENU, AppState.SETTINGS, AppState.LOADING, AppState.EXIT_CONFIRM:
			_draw_menu_screen()
		AppState.PROLOGUE:
			_draw_prologue()
		AppState.GAME:
			_draw_game()
		AppState.PAUSE:
			if paused_from_game:
				_draw_game()
			else:
				_draw_prologue()
				_draw_pause()
		AppState.ACT_COMPLETE:
			_draw_act_complete()
		AppState.CREDITS:
			_draw_credits()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if fade > 0.0:
		draw_rect(get_viewport_rect(), Color(0.0, 0.0, 0.0, fade), true)

func _draw_intro() -> void:
	# A silent, in-engine 14 second prologue: a thread is made, pulled apart, then falls.
	# It establishes the relationship without a line of dialogue or a pre-rendered movie.
	draw_rect(Rect2(Vector2.ZERO, SIZE), VOID, true)
	var t := intro_time
	for i in range(16):
		var x := 170.0 + float(i) * 116.0
		var sway := sin(t * 0.7 + float(i) * 0.61) * 13.0
		draw_line(Vector2(x + sway, -40), Vector2(x - 130.0 + sway, 870), Color(LOOM, 0.18), 7.0)
	var weave := clampf(t / 3.0, 0.0, 1.0)
	var pin_intro := Vector2(770, 500).lerp(Vector2(730, 520), weave)
	var pan_intro := Vector2(1150, 500).lerp(Vector2(1190, 485), weave)
	if t < 9.4:
		var strand_amount := 0.10 + weave * 0.52
		_draw_thread(pin_intro, pan_intro, strand_amount, WARM)
		_draw_character(pin_intro, true, 0.72 + weave * 0.20, -2.0)
		_draw_character(pan_intro, false, 0.72 + weave * 0.20, 3.0)
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
			draw_line(Vector2(110 + i * 142, y), Vector2(250 + i * 142, y + 108), Color(FABRIC, 0.32), 13.0)
		_draw_thread(a, b, 0.28, WARM)
		_draw_character(a, true, 0.88, -8.0)
		_draw_character(b, false, 0.88, 8.0)
		if t > 12.1:
			var title_alpha := clampf((t - 12.1) / 1.2, 0.0, 1.0)
			_draw_text("PIN&PAN", Vector2(708, 280), 62, Color(UI, title_alpha), 3.0)
	if t > 9.15 and t < 9.65:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1.0, 0.98, 0.93, sin((t - 9.15) / 0.5 * PI) * 0.82), true)

func _draw_menu_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), VOID, true)
	_draw_menu_background()
	_draw_cloth(Vector2(1420, 610), LINEN)
	var idle := sin(time * TAU / 7.0)
	_draw_thread(Vector2(1315, 535), Vector2(1515, 490), 0.18 + absf(idle) * 0.12, WARM)
	_draw_character(Vector2(1315, 535), true, 1.0 + idle * 0.025, 0.0)
	_draw_character(Vector2(1515, 490), false, 0.98 - idle * 0.025, 4.0 + sin(time * 0.7) * 5.0)
	_draw_text("PIN&PAN", Vector2(180, 200), 64, UI, 3.0)
	_draw_text("НИТЬ, КОТОРАЯ ВЕДЁТ ДАЛЬШЕ", Vector2(184, 238), 15, MUTED, 1.2)
	if app_state == AppState.MENU or app_state == AppState.LOADING:
		_draw_menu_options()
	elif app_state == AppState.SETTINGS:
		_draw_menu_options(0.26)
		_draw_settings()
	elif app_state == AppState.EXIT_CONFIRM:
		_draw_menu_options(0.26)
		_draw_exit_confirm()
	if app_state == AppState.LOADING:
		_draw_loading()
	_draw_cursor()

func _draw_menu_background() -> void:
	for i in range(8):
		var x := 1100.0 + i * 115.0
		draw_line(Vector2(x, 80), Vector2(x - 90, 850), Color(LOOM, 0.22), 14.0)
	for y in [260.0, 350.0, 760.0]:
		draw_line(Vector2(990, y), Vector2(1920, y + 90), Color(LOOM, 0.16), 18.0)
	for particle in particles:
		draw_circle(particle.p, 1.6, Color(WARM, particle.alpha))
	for i in range(9):
		var x := fposmod(time * (9.0 + i) + i * 223.0, 2200.0) - 120.0
		var y := 190.0 + fposmod(float(i * 97), 650.0)
		draw_line(Vector2(x, y), Vector2(x + 72, y + 18), Color(FABRIC, 0.22), 5.0)

func _draw_menu_options(alpha := 1.0) -> void:
	var options := _menu_options()
	for i in options.size():
		var y := 595.0 + i * 76.0
		var focused := i == menu_focus and app_state != AppState.LOADING
		if focused:
			draw_style_box(_focus_style(), Rect2(158, y - 43, 470, 60))
		_draw_text(options[i], Vector2(180, y), 32.0 * (1.05 if focused else 1.0), Color(UI if focused else MUTED, alpha), 2.1)

func _focus_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(FOCUS, 0.06)
	box.border_color = Color(FOCUS, 0.92)
	box.set_border_width_all(2)
	box.corner_radius_top_left = 7
	box.corner_radius_top_right = 7
	box.corner_radius_bottom_left = 7
	box.corner_radius_bottom_right = 7
	return box

func _draw_settings() -> void:
	draw_rect(Rect2(350, 110, 1220, 850), Color("121218f5"), true)
	draw_rect(Rect2(350, 110, 1220, 850), Color(FOCUS, 0.38), false, 2.0)
	_draw_text("НАСТРОЙКИ", Vector2(425, 190), 40, UI, 2.0)
	_draw_text("МЫШЬЮ: ТЯНИ ПОЛЗУНОК.  ESC: НАЗАД", Vector2(427, 225), 16, MUTED, 1.0)
	var rows := _settings_rows()
	for i in rows.size():
		var y := 355.0 + i * 62.0
		var focused := i == settings_focus
		if focused:
			draw_style_box(_focus_style(), Rect2(414, y - 39, 1085, 52))
		_draw_text(rows[i], Vector2(448, y), 24, UI if focused else MUTED, 1.4)
		if i < 4:
			var values := [int(settings.master), int(settings.music), int(settings.sfx), int(settings.thread)]
			draw_rect(Rect2(900, y - 22, 390, 8), Color(MUTED, 0.30), true)
			draw_rect(Rect2(900, y - 22, values[i] * 3.9, 8), FOCUS, true)
			draw_circle(Vector2(900 + values[i] * 3.9, y - 18), 9, FOCUS)
			_draw_text(str(values[i]), Vector2(1340, y), 21, UI, 1.0)
		elif i == 4:
			_draw_text("ВКЛ" if bool(settings.symbols) else "ВЫКЛ", Vector2(1190, y), 22, FOCUS, 1.0)
		elif i == 5:
			_draw_text("ВКЛ" if bool(settings.motion) else "ВЫКЛ", Vector2(1190, y), 22, FOCUS, 1.0)
		elif i == 6:
			_draw_text("ВКЛ" if bool(settings.contrast) else "ВЫКЛ", Vector2(1190, y), 22, FOCUS, 1.0)

func _draw_exit_confirm() -> void:
	draw_rect(Rect2(610, 350, 700, 370), Color("121218fa"), true)
	draw_rect(Rect2(610, 350, 700, 370), Color(FOCUS, 0.5), false, 2.0)
	_draw_text("ВЫЙТИ ИЗ ИГРЫ?", Vector2(730, 465), 36, UI, 1.5)
	_draw_button(Rect2(690, 520, 270, 64), "ВЫЙТИ", true)
	_draw_button(Rect2(970, 520, 270, 64), "НАЗАД", false)

func _draw_loading() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(VOID, 0.72), true)
	_draw_text("НИТЬ ВЕДЁТ ВПЕРЁД", Vector2(715, 520), 28, UI, 1.8)
	draw_rect(Rect2(720, 558, 480, 8), Color(MUTED, 0.3), true)
	draw_rect(Rect2(720, 558, 480 * loading, 8), WARM, true)

func _draw_prologue() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), VOID, true)
	if prologue_state == PrologueState.LAND:
		_draw_linen_background()
	else:
		_draw_workshop_background()
	if prologue_state == PrologueState.WAKE or prologue_state == PrologueState.MOVE or prologue_state == PrologueState.HAND:
		var amount := clampf(pin_pos.distance_to(pan_pos) / 450.0, 0.0, 1.0)
		_draw_thread(pin_pos, pan_pos, amount, WARM)
		_draw_character(pin_pos, true, 0.72 + pin_awake * 0.28, 0.0)
		_draw_character(pan_pos, false, 0.72 + pan_awake * 0.28, 4.0)
		if prologue_state == PrologueState.WAKE:
			var breathe := 48.0 + sin(time * TAU / 1.2) * 10.0
			draw_circle(pin_pos, breathe, Color(PIN_GLOW, 0.10))
			draw_circle(pan_pos, breathe, Color(PAN_GLOW, 0.10))
		if prologue_state == PrologueState.HAND:
			_draw_weaver_hand()
	elif prologue_state == PrologueState.BREAK:
		var alpha := sin(clampf(state_time / 1.2, 0.0, 1.0) * PI) * 0.94
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1.0, 0.98, 0.94, alpha), true)
	elif prologue_state == PrologueState.FALL:
		_draw_fall()
	else:
		_draw_thread(pin_pos, pan_pos, tension, WARM)
		_draw_character(pin_pos, true, 1.0, 0.0)
		_draw_character(pan_pos, false, 1.0, 4.0)
	_draw_letterbox()
	if prologue_elapsed >= 3.0:
		_draw_text("SPACE — ПРОПУСТИТЬ", Vector2(1565, 1000), 14, Color(MUTED, 0.8), 1.0)

func _draw_workshop_background() -> void:
	for i in range(18):
		var x := 110.0 + i * 100.0
		draw_line(Vector2(x, 20), Vector2(x + 90, 790), Color(LOOM, 0.13), 5.0)
	if prologue_state == PrologueState.FALL:
		for i in range(12):
			var y := fposmod(float(i * 97) + state_time * 95.0, 1160.0) - 40.0
			var x := 140.0 + fposmod(float(i * 157), 1540.0)
			draw_line(Vector2(x, y), Vector2(x + 220, y + 110), Color(FABRIC, 0.44), 18.0 + float(i % 3) * 7.0)

func _draw_weaver_hand() -> void:
	var enter := clampf(state_time / 2.0, 0.0, 1.0)
	var palm := Vector2(1530, -80).lerp(Vector2(1220, 300), enter)
	draw_circle(palm, 95, Color("524552"))
	for i in range(5):
		var a := palm + Vector2(-55 + i * 28, 40)
		var b := a + Vector2(-90 + i * 25, 180)
		draw_line(a, b, Color("635262"), 30)
		draw_circle(b, 15, Color("796573"))

func _draw_weaver_figure() -> void:
	var body := Vector2(960, 430)
	draw_circle(body, 92.0, Color("40313b", 0.90))
	draw_circle(body + Vector2(0, -112), 48.0, Color("4d3b45", 0.86))
	draw_rect(Rect2(884, 502, 152, 260), Color("40313b", 0.88), true)
	draw_line(Vector2(890, 535), Vector2(690, 690), Color("725964", 0.74), 32.0)
	draw_line(Vector2(1030, 535), Vector2(1230, 690), Color("725964", 0.74), 32.0)
	draw_arc(Vector2(960, 420), 112.0, 0.0, TAU, 28, Color(WARM, 0.18), 2.0)
	draw_circle(Vector2(960, 500), 12.0, Color(WARM, 0.75))

func _draw_fall() -> void:
	var center := Vector2(960, 480 + sin(state_time * 2.2) * 14)
	var separation := 180.0 + sin(state_time * 1.4) * 45.0
	var a := center + Vector2(-separation * 0.5, -15)
	var b := center + Vector2(separation * 0.5, 20)
	_draw_thread(a, b, 0.42, WARM)
	_draw_character(a, true, 0.86, -5)
	_draw_character(b, false, 0.86, 8)

func _draw_game() -> void:
	match world:
		World.FIELDS: _draw_linen_background()
		World.FOREST: _draw_forest_background()
		World.PEAKS: _draw_peaks_background()
		World.ECHO: _draw_echo_background()
		World.WASTES: _draw_wastes_background()
		World.HEART: _draw_heart_background()
	_draw_platforms()
	_draw_interactives()
	_draw_enemies()
	_draw_thread(pin_pos, pan_pos, tension, WARM)
	_draw_character(pin_pos, true, 1.0, 0.0)
	_draw_character(pan_pos, false, 1.0, 4.0)
	_draw_game_hud()
	if app_state == AppState.PAUSE:
		_draw_pause()

func _draw_linen_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("24222b"), true)
	draw_circle(Vector2(1550, 270), 180, Color("657b98", 0.10))
	for i in range(150):
		var x := fposmod(float(i * 71), 1920.0)
		var base_y := 690.0 + fposmod(float(i * 37), 400.0)
		var sway := 0.0 if bool(settings.motion) else sin(time * 1.2 + i) * 5.0
		draw_line(Vector2(x, base_y), Vector2(x + sway, base_y - 85.0 - float(i % 5) * 11.0), Color(LINEN, 0.42), 2.0)
	for i in range(8):
		var x := 1050.0 + i * 94.0
		draw_line(Vector2(x, 120), Vector2(x - 55, 660), Color(LOOM, 0.25), 13.0)

func _draw_forest_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("18202b"), true)
	for i in range(28):
		var x := fposmod(float(i * 157), 2050.0) - 80.0
		var y := 80.0 + float(i % 6) * 110.0
		draw_line(Vector2(x, y), Vector2(x + sin(time + i) * 25.0, 940), Color(WOOL, 0.60), 32.0)
	for particle in particles:
		draw_circle(particle.p, 2.0, Color(WOOL_LIGHT, particle.alpha + 0.06))

func _draw_peaks_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("23273d"), true)
	for i in range(9):
		var x := -180.0 + i * 260.0
		var ridge := PackedVector2Array([Vector2(x, 880), Vector2(x + 145, 180 + float(i % 3) * 80), Vector2(x + 280, 880)])
		draw_colored_polygon(ridge, Color("4b4d70", 0.70))
		draw_polyline(PackedVector2Array([ridge[0], ridge[1], ridge[2]]), Color("b9adca", 0.28), 3.0)
	for i in range(34):
		var y := 180.0 + float(i) * 22.0
		var drift := 0.0 if bool(settings.motion) else sin(time * 2.0 + i * 0.4) * 35.0
		draw_line(Vector2(80 + drift, y), Vector2(740 + drift, y - 15), Color("c6d8ff", 0.11), 2.0)
	if wind_strength > 0.0:
		var arrow_x := 1660.0 if wind_direction < 0.0 else 260.0
		var sign := -1.0 if wind_direction < 0.0 else 1.0
		for i in range(3):
			var y := 210.0 + i * 32.0
			draw_line(Vector2(arrow_x, y), Vector2(arrow_x + sign * 105.0, y), Color("d5e4ff", 0.64), 3.0)
			draw_line(Vector2(arrow_x + sign * 105.0, y), Vector2(arrow_x + sign * 82.0, y - 13), Color("d5e4ff", 0.64), 3.0)
			draw_line(Vector2(arrow_x + sign * 105.0, y), Vector2(arrow_x + sign * 82.0, y + 13), Color("d5e4ff", 0.64), 3.0)

func _draw_echo_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("161923"), true)
	for i in range(7):
		var x := 120.0 + i * 300.0
		draw_arc(Vector2(x, 690), 180.0, PI, TAU, 28, Color("536077", 0.34), 20.0)
		draw_arc(Vector2(x, 690), 160.0, PI, TAU, 28, Color("9fb4d6", 0.09), 3.0)
	for i in range(18):
		var y := 190.0 + i * 33.0
		draw_line(Vector2(0, y), Vector2(1920, y + sin(time + i) * 5.0), Color("8fa5ca", 0.055), 1.5)
	if echo_active or echo_timer > 0.0:
		draw_circle(echo_point, 72.0 + sin(time * 7.0) * 5.0, Color("aebee8", 0.12))

func _draw_wastes_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("292630"), true)
	for i in range(24):
		var x := fposmod(float(i * 179), 2050.0) - 80.0
		var y := 150.0 + float(i % 5) * 128.0
		draw_line(Vector2(x, y), Vector2(x + 180, y + 90), Color("79616d", 0.28), 12.0)
		draw_line(Vector2(x + 30, y - 15), Vector2(x + 250, y + 120), Color("4a404c", 0.45), 5.0)
	for particle in particles:
		draw_circle(particle.p, 1.8, Color("c49598", particle.alpha + 0.03))

func _draw_heart_background() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("17151e"), true)
	for i in range(11):
		var x := 300.0 + i * 130.0
		draw_line(Vector2(x, 0), Vector2(x - 35, 830), Color("5c4551", 0.52), 18.0)
		draw_line(Vector2(x + 18, 0), Vector2(x - 17, 830), Color("d0aa81", 0.15), 2.0)
	draw_circle(Vector2(960, 310), 210, Color("e3c69a", 0.055))
	draw_arc(Vector2(960, 310), 160.0, 0.0, TAU, 48, Color("d5a978", 0.30), 4.0)
	if final_reveal:
		_draw_weaver_figure()

func _draw_platforms() -> void:
	for platform in platforms:
		var col := LINEN
		var hi := LINEN_LIGHT
		if world == World.FOREST:
			col = WOOL
			hi = WOOL_LIGHT
		elif world == World.PEAKS:
			col = Color("70698c")
			hi = Color("d4caeb")
		elif world == World.ECHO:
			col = Color("303849")
			hi = Color("9fb4d6")
		elif world == World.WASTES:
			col = Color("5d4a57")
			hi = Color("b5848d")
		elif world == World.HEART:
			col = Color("624951")
			hi = Color("deb486")
		draw_rect(platform, col, true)
		draw_line(platform.position, Vector2(platform.end.x, platform.position.y), hi, 3.0)
		for x in range(int(platform.position.x) + 16, int(platform.end.x), 28):
			draw_line(Vector2(x, platform.position.y + 4), Vector2(x + 16, platform.position.y + minf(platform.size.y, 42)), Color(hi, 0.22), 1.0)
	for fragile in fragile_platforms:
		if bool(fragile.gone):
			continue
		var fragile_rect: Rect2 = fragile.rect
		var warned := float(fragile.touched) >= 0.0
		var col := Color("b36f76") if warned else Color("765961")
		draw_rect(fragile_rect, col, true)
		draw_line(fragile_rect.position, Vector2(fragile_rect.end.x, fragile_rect.position.y), Color("f0a6a1", 0.75), 3.0)
		for x in range(int(fragile_rect.position.x) + 12, int(fragile_rect.end.x), 24):
			draw_line(Vector2(x, fragile_rect.position.y + 5), Vector2(x + 12, fragile_rect.end.y - 4), Color("271d27", 0.42), 2.0)

func _draw_interactives() -> void:
	for pad in pads:
		draw_rect(pad, Color(FOCUS, 0.32), true)
		draw_rect(pad, FOCUS, false, 2.0)
	if gate.size != Vector2.ZERO and not door_open:
		draw_rect(gate, Color("604e55"), true)
		draw_line(gate.position, Vector2(gate.position.x, gate.end.y), WARM, 3.0)
	if anchor_point != Vector2.ZERO:
		draw_circle(anchor_point, 22.0, Color(PIN_GLOW, 0.20))
		draw_arc(anchor_point, 22.0, 0.0, TAU, 20, PIN_GLOW, 2.0)
		if bind_active:
			draw_line(anchor_point, pin_pos, WARM, 3.0)
	if echo_point != Vector2.ZERO:
		draw_arc(echo_point, 25.0, 0.0, TAU, 16, Color("b2c6f5", 0.8), 2.0)
		draw_circle(echo_point, 14.0 + sin(time * 4.0) * 3.0, Color("b2c6f5", 0.13))
	if memory_point != Vector2.ZERO and not memories.has(room):
		draw_circle(memory_point, 28.0 + sin(time * 3.0) * 4.0, Color(WARM, 0.12))
		draw_arc(memory_point, 16.0, 0.0, TAU, 12, WARM, 2.0)
	for trap in traps:
		draw_colored_polygon(PackedVector2Array([trap.position + Vector2(0, trap.size.y), trap.position + Vector2(trap.size.x * 0.5, 0), trap.end]), DANGER)
	if exit_zone.size != Vector2.ZERO:
		draw_rect(exit_zone, Color(WARM, 0.08), true)
		draw_line(Vector2(exit_zone.position.x, exit_zone.position.y), Vector2(exit_zone.position.x, exit_zone.end.y), Color(WARM, 0.42), 3.0)
	for choice in ending_zones:
		var choice_rect: Rect2 = choice.rect
		var allowed: bool = choice.id != "ВОССОЕДИНЕНИЕ" or memory_nodes >= 8
		draw_rect(choice_rect, Color(WARM if allowed else MUTED, 0.10), true)
		draw_rect(choice_rect, Color(WARM if allowed else MUTED, 0.42), false, 2.0)
		_draw_text(choice.id, Vector2(choice_rect.position.x + 24, choice_rect.position.y + 105), 18, WARM if allowed else MUTED, 0.8)

func _draw_enemies() -> void:
	for enemy in enemies:
		if bool(enemy.cut):
			for i in range(5):
				draw_line(enemy.pos + Vector2(-18 + i * 9, -16), enemy.pos + Vector2(-28 + i * 14, 22), Color(WOOL_LIGHT, 0.35), 2.0)
			continue
		var col := Color("a87589") if bool(enemy.bound) else Color("bd8da0")
		draw_circle(enemy.pos, 25.0, Color(col, 0.20))
		draw_line(enemy.pos + Vector2(0, -38), enemy.pos + Vector2(0, 38), col, 5.0)
		draw_line(enemy.pos + Vector2(-18, -12), enemy.pos + Vector2(18, 16), col, 3.0)
		if bool(enemy.bound):
			draw_arc(enemy.pos, 36.0, 0.0, TAU, 16, WARM, 2.0)
		elif enemy.has("chaser"):
			draw_circle(enemy.pos, 58.0 + sin(time * 8.0) * 4.0, Color(DANGER, 0.10))

func _draw_game_hud() -> void:
	draw_rect(Rect2(36, 32, 660, 128), Color(VOID, 0.52), true)
	_draw_text(room_title, Vector2(62, 78), 23, UI, 1.5)
	_draw_text(room_subtitle, Vector2(62, 110), 16, FOCUS, 1.1)
	var controls := "PIN  A/D W E     PAN  ←/→ ↑ SHIFT     ESC  ПАУЗА"
	if world == World.PEAKS:
		controls = "PIN  E — ЯКОРЬ ПРОТИВ ВЕТРА     PAN БЫСТРЕЕ, НО ЕГО СНОСИТ"
	elif world == World.ECHO:
		controls = "PIN  E У ЭХА — ПОВТОР ДЕЙСТВИЯ ЧЕРЕЗ 1,5 СЕКУНДЫ"
	elif world == World.WASTES:
		controls = "РВУЩАЯСЯ ТКАНЬ ПРЕДУПРЕЖДАЕТ ЗА МГНОВЕНИЕ"
	elif world == World.HEART:
		controls = "ВСЕ РЕШЕНИЯ ВОЗВРАЩАЮТСЯ К ВАМ"
	_draw_text(controls, Vector2(62, 140), 13, MUTED, 0.45)
	_draw_text("УЗЛЫ ПАМЯТИ: " + str(memory_nodes), Vector2(1450, 55), 16, WARM, 0.7)
	if room_message_time > 0.0:
		draw_rect(Rect2(450, 910, 1020, 66), Color(VOID, 0.70), true)
		_draw_text(room_message, Vector2(960 - _text_width(room_message, 18, 1.0) * 0.5, 951), 18, UI, 1.0)
	if mechanic_hint_time > 0.0:
		draw_rect(Rect2(310, 825, 1300, 58), Color("15151df2"), true)
		draw_rect(Rect2(310, 825, 1300, 58), Color(FOCUS, 0.30), false, 1.0)
		_draw_text(mechanic_hint, Vector2(960 - _text_width(mechanic_hint, 16, 0.65) * 0.5, 861), 16, UI, 0.65)
	if tension > 0.68:
		_draw_text("НИТЬ НА ПРЕДЕЛЕ", Vector2(1470, 85), 16, Color(PIN_GLOW, 0.95), 1.0)
	if wind_strength > 0.0:
		_draw_text("ПОРЫВ", Vector2(1510, 112), 16, Color("d5e4ff"), 1.0)

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.0, 0.0, 0.0, 0.58), true)
	draw_rect(Rect2(620, 295, 680, 480), Color("121218f6"), true)
	draw_rect(Rect2(620, 295, 680, 480), Color(FOCUS, 0.48), false, 2.0)
	_draw_text("ПАУЗА", Vector2(850, 375), 42, UI, 2.0)
	for i in range(3):
		var labels := ["ПРОДОЛЖИТЬ", "НАСТРОЙКИ", "В ГЛАВНОЕ МЕНЮ"]
		_draw_button(Rect2(690, 410 + i * 80, 540, 58), labels[i], i == pause_focus)

func _draw_act_complete() -> void:
	_draw_forest_background()
	draw_rect(Rect2(0, 0, 1920, 1080), Color(VOID, 0.55), true)
	_draw_thread(Vector2(820, 570), Vector2(1100, 520), 0.26, WARM)
	_draw_character(Vector2(820, 570), true, 1.18, 0.0)
	_draw_character(Vector2(1100, 520), false, 1.12, 5.0)
	_draw_text("КОНЕЦ АКТА I", Vector2(690, 330), 58, UI, 2.4)
	_draw_text("ВЫ НАУЧИЛИСЬ ДЕРЖАТЬСЯ ВМЕСТЕ — И УШЛИ ОТ ПОГОНИ.", Vector2(420, 420), 21, FOCUS, 0.55)
	_draw_text("ДАЛЬШЕ — ШЁЛКОВЫЕ ПИКИ. ИХ НЕТ В ЭТОЙ СБОРКЕ.", Vector2(570, 465), 18, UI, 0.45)
	_draw_text("ENTER / SPACE — В ГЛАВНОЕ МЕНЮ", Vector2(675, 780), 19, UI, 1.0)

func _draw_credits() -> void:
	_draw_heart_background()
	draw_rect(Rect2(0, 0, 1920, 1080), Color(VOID, 0.54), true)
	_draw_thread(Vector2(820, 590), Vector2(1100, 530), 0.24, WARM)
	_draw_character(Vector2(820, 590), true, 1.14, 0.0)
	_draw_character(Vector2(1100, 530), false, 1.10, 5.0)
	_draw_text("PIN&PAN", Vector2(710, 300), 62, UI, 3.0)
	_draw_text("НИТЬ ПРОДОЛЖАЕТСЯ", Vector2(744, 355), 22, FOCUS, 1.6)
	var final_line := "КОНЦОВКА: " + (ending if ending != "" else "ЕЩЁ НЕ ВЫБРАНА")
	_draw_text(final_line, Vector2(960 - _text_width(final_line, 18, 1.0) * 0.5, 760), 18, UI, 1.0)
	_draw_text("ENTER / ESC — В ГЛАВНОЕ МЕНЮ", Vector2(690, 835), 18, MUTED, 1.0)

func _draw_button(rect: Rect2, label: String, focused: bool) -> void:
	if focused:
		draw_style_box(_focus_style(), rect)
	var color := UI if focused else MUTED
	var width := _text_width(label, 22, 1.3)
	_draw_text(label, Vector2(rect.get_center().x - width * 0.5, rect.get_center().y + 8), 22, color, 1.3)

func _draw_cloth(center: Vector2, color: Color) -> void:
	var sway := 0.0 if bool(settings.motion) else sin(time * TAU / 6.4) * 3.0
	var pts := PackedVector2Array([center + Vector2(-235, 40 + sway), center + Vector2(-150, -70), center + Vector2(10, -92), center + Vector2(220, -15), center + Vector2(185, 78), center + Vector2(-110, 98)])
	draw_colored_polygon(pts, Color(color, 0.46))
	for i in range(6):
		draw_line(pts[i], pts[(i + 1) % 6], Color(WARM, 0.18), 2.0)

func _draw_character(pos: Vector2, is_pin: bool, scale_factor: float, tilt: float) -> void:
	var r := 35.0 * scale_factor
	var core := PIN if is_pin else PAN
	var deep := PIN_DEEP if is_pin else PAN_DEEP
	var glow := PIN_GLOW if is_pin else PAN_GLOW
	var outline := UI if bool(settings.contrast) else deep
	draw_circle(pos, r * 1.75, Color(glow, 0.10))
	draw_circle(pos, r * 1.25, Color(glow, 0.17))
	if is_pin:
		var points := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r * 0.85, -r * 0.14), pos + Vector2(r * 0.56, r * 0.80), pos + Vector2(-r * 0.56, r * 0.80), pos + Vector2(-r * 0.85, -r * 0.14)])
		draw_colored_polygon(points, outline)
		var inside := PackedVector2Array([pos + Vector2(0, -r * 0.72), pos + Vector2(r * 0.58, 0), pos + Vector2(r * 0.30, r * 0.60), pos + Vector2(-r * 0.32, r * 0.60), pos + Vector2(-r * 0.58, 0)])
		draw_colored_polygon(inside, core)
		if bool(settings.symbols):
			var marker := PackedVector2Array([pos + Vector2(0, -r * 1.8), pos + Vector2(-7, -r * 1.54), pos + Vector2(7, -r * 1.54)])
			draw_polyline(PackedVector2Array([marker[0], marker[1], marker[2], marker[0]]), UI, 1.5)
	else:
		draw_circle(pos, r, outline)
		draw_circle(pos + Vector2(-r * 0.12, -r * 0.10), r * 0.77, core)
		draw_circle(pos + Vector2(r * 0.43, -r * 0.27), r * 0.34, core)
		if bool(settings.symbols):
			draw_arc(pos + Vector2(0, -r * 1.68), 8.0, 0.0, TAU, 8, UI, 1.5)

func _draw_thread(a: Vector2, b: Vector2, amount: float, color: Color) -> void:
	var midpoint := (a + b) * 0.5 + Vector2(0, 54.0 * (1.0 - amount))
	var pts := PackedVector2Array()
	for i in range(17):
		var t := float(i) / 16.0
		var p := a.lerp(midpoint, t * 2.0) if t < 0.5 else midpoint.lerp(b, (t - 0.5) * 2.0)
		pts.append(p)
	var thread_color := color.lerp(Color.WHITE, thread_flash)
	draw_polyline(pts, Color(thread_color, 0.58 + amount * 0.36), 2.0 + amount * 2.0 + thread_flash * 1.5, true)

func _draw_letterbox() -> void:
	if letterbox > 0.0:
		draw_rect(Rect2(0, 0, 1920, letterbox), Color.BLACK, true)
		draw_rect(Rect2(0, 1080 - letterbox, 1920, letterbox), Color.BLACK, true)

func _draw_cursor() -> void:
	if app_state == AppState.PROLOGUE or app_state == AppState.GAME or app_state == AppState.PAUSE:
		return
	if cursor_trail.size() > 1:
		for i in range(cursor_trail.size() - 1):
			var alpha := 0.42 * (1.0 - float(i) / float(cursor_trail.size()))
			draw_line(cursor_trail[i], cursor_trail[i + 1], Color(WARM, alpha), 2.0 + float(cursor_trail.size() - i) * 0.18)
	draw_circle(mouse, 6.0, WARM)
	draw_circle(mouse, 12.0, Color(WARM, 0.18))

func _draw_text(text: String, pos: Vector2, size: float, color: Color, spacing := 0.0) -> void:
	if spacing <= 0.0:
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		return
	var x := pos.x
	for ch in text:
		draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_char_size(ch.unicode_at(0), size).x + spacing

func _text_width(text: String, size: float, spacing: float) -> float:
	var width := 0.0
	for ch in text:
		width += font.get_char_size(ch.unicode_at(0), size).x + spacing
	return width

func _to_canvas(p: Vector2) -> Vector2:
	var scale_factor: float = min(get_viewport_rect().size.x / SIZE.x, get_viewport_rect().size.y / SIZE.y)
	var offset: Vector2 = (get_viewport_rect().size - SIZE * scale_factor) * 0.5
	return (p - offset) / scale_factor
