extends Node2D
## PIN&PAN — корневой узел игры. Держит экраны (интро, меню, пролог, акт I),
## маршрутизирует ввод, управляет переходами через FadeLayer и паузой.

enum State { INTRO, MENU, PROLOGUE, GAME, ACT_COMPLETE }

const SIZE := Vector2(1920, 1080)

var state := State.INTRO
var _intro: IntroScreen
var _menu: MenuScreen
var _prologue: PrologueScreen
var _game: GameScreen
var _act_complete: ActCompleteScreen
var _fade: FadeLayer
var _pause: PauseOverlay
var _settings_panel: SettingsPanel
var _paused := false
var _paused_state := State.MENU
var _after_fade: Callable = Callable()
var _had_gamepad := false


func _ready() -> void:
	_intro = IntroScreen.new()
	add_child(_intro)
	_menu = MenuScreen.new()
	add_child(_menu)
	_prologue = PrologueScreen.new()
	add_child(_prologue)
	_game = GameScreen.new()
	add_child(_game)
	_act_complete = ActCompleteScreen.new()
	add_child(_act_complete)
	_fade = FadeLayer.new()
	add_child(_fade)
	_intro.done.connect(_to_menu)
	_menu.play_requested.connect(_start_new_game)
	_menu.continue_requested.connect(_start_continue)
	_menu.quit_requested.connect(_quit)
	_prologue.finished.connect(_finish_prologue)
	_game.act_complete.connect(_show_act_complete)
	_hide_all()
	_intro.play()
	_fade.target = 0.0
	_fade.fade = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _hide_all() -> void:
	_intro.stop()
	_menu.visible = false
	_menu.set_process(false)
	_prologue.stop()
	_game.stop()
	_act_complete.stop()


func _process(delta: float) -> void:
	if _fade.is_done() and _after_fade.is_valid():
		var cb := _after_fade
		_after_fade = Callable()
		cb.call()
	_track_gamepad()


func _track_gamepad() -> void:
	var has_pad := not Input.get_connected_joypads().is_empty()
	if has_pad:
		_had_gamepad = true
	if _pause != null:
		_pause.device_lost = _had_gamepad and not has_pad


## Запускает переход: затемнение → действие → рассвет.
func _transition(callback: Callable, fade_speed := 2.6) -> void:
	_fade.speed = fade_speed
	_fade.target = 1.0
	_after_fade = callback


func _to_menu() -> void:
	state = State.MENU
	_hide_all()
	_menu.reset()
	_menu.visible = true
	_menu.set_process(true)
	_fade.target = 0.0


func _start_new_game() -> void:
	_transition(_do_new_game)


func _do_new_game() -> void:
	PinPanCore.I.save.mark_new_game()
	state = State.PROLOGUE
	_hide_all()
	_prologue.play()
	_fade.target = 0.0


func _start_continue() -> void:
	_transition(_do_continue)


func _do_continue() -> void:
	var room := PinPanCore.I.save.continue_room()
	_hide_all()
	if room < 0:
		state = State.PROLOGUE
		_prologue.play()
	else:
		state = State.GAME
		_game.play(room)
	_fade.target = 0.0


func _finish_prologue() -> void:
	_transition(_do_finish_prologue, 3.3)


func _do_finish_prologue() -> void:
	PinPanCore.I.save.mark_prologue_done()
	state = State.GAME
	_hide_all()
	_game.play(0)
	_fade.target = 0.0


func _show_act_complete() -> void:
	_transition(_do_act_complete)


func _do_act_complete() -> void:
	state = State.ACT_COMPLETE
	_hide_all()
	_act_complete.play()
	_fade.target = 0.0


func _quit() -> void:
	get_tree().quit()


# --- Пауза ---

func _open_pause() -> void:
	if _paused or not (state == State.PROLOGUE or state == State.GAME):
		return
	_paused = true
	_paused_state = state
	if state == State.PROLOGUE:
		_prologue.set_process(false)
	else:
		_game.set_process(false)
	_pause = PauseOverlay.new()
	_pause.resume_requested.connect(_close_pause)
	_pause.settings_requested.connect(_open_pause_settings)
	_pause.menu_requested.connect(_pause_to_menu)
	add_child(_pause)


func _close_pause() -> void:
	if not _paused:
		return
	_paused = false
	if _settings_panel != null:
		_settings_panel.queue_free()
		_settings_panel = null
	_pause.queue_free()
	_pause = null
	if _paused_state == State.PROLOGUE:
		_prologue.set_process(true)
	else:
		_game.set_process(true)


func _open_pause_settings() -> void:
	if _settings_panel != null:
		return
	_settings_panel = SettingsPanel.new()
	_settings_panel.closed.connect(func() -> void:
		if _settings_panel != null:
			_settings_panel.queue_free()
			_settings_panel = null
		PinPanCore.I.ui.play(PinPanUIAudio.Event.BACK))
	add_child(_settings_panel)


func _pause_to_menu() -> void:
	_close_pause()
	_transition(_to_menu)


# --- Ввод ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if state == State.MENU and not _paused:
			_menu.handle_mouse_motion()
		return
	if event is InputEventMouseButton:
		_handle_mouse(event)
		return
	if _paused:
		_handle_paused_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		_handle_joy(event.button_index, event.device)
	elif event is InputEventJoypadMotion:
		_menu._process_joy_motion(event.device, event.axis, event.axis_value)


func _handle_mouse(event: InputEventMouseButton) -> void:
	if not event.pressed:
		if state == State.MENU and not _paused:
			_menu.handle_mouse_release()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	match state:
		State.INTRO:
			_intro.skip()
		State.MENU:
			_menu.handle_click(event.position)
		State.PROLOGUE, State.GAME, State.ACT_COMPLETE:
			pass


func _handle_key(key: Key) -> void:
	match state:
		State.INTRO:
			if key in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				_intro.skip()
		State.MENU:
			_menu.handle_key(key)
		State.PROLOGUE:
			if key == KEY_ESCAPE:
				_open_pause()
			elif key in [KEY_SPACE, KEY_ENTER]:
				_prologue.skip()
			elif key in [KEY_A, KEY_D, KEY_W, KEY_S]:
				_prologue.nudge(true)
			elif key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
				_prologue.nudge(false)
		State.GAME:
			if key == KEY_ESCAPE:
				_open_pause()
			else:
				_game.handle_key(key)
		State.ACT_COMPLETE:
			if key in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
				_transition(_to_menu)


func _handle_joy(button: JoyButton, device: int) -> void:
	match state:
		State.INTRO:
			if button in [JOY_BUTTON_A, JOY_BUTTON_START]:
				_intro.skip()
		State.MENU:
			_menu.handle_joy_button(button, device)
		State.PROLOGUE:
			if button == JOY_BUTTON_START:
				_open_pause()
			elif button == JOY_BUTTON_A:
				_prologue.skip()
			elif device == 0:
				_prologue.nudge(true)
			else:
				_prologue.nudge(false)
		State.GAME:
			if button == JOY_BUTTON_START:
				_open_pause()
			else:
				_game.handle_joy_button(button, device)
		State.ACT_COMPLETE:
			if button in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_B]:
				_transition(_to_menu)


func _handle_paused_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _settings_panel != null:
			_settings_panel.handle_key(event.keycode)
		else:
			_pause.handle_key(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		if _settings_panel != null:
			_settings_panel.handle_joy_button(event.button_index)
		else:
			_pause.handle_joy_button(event.button_index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _settings_panel != null:
			_settings_panel.handle_click(event.position)
		else:
			_pause.handle_click(event.position)
	elif event is InputEventMouseMotion:
		if _settings_panel != null:
			_settings_panel.handle_drag(event.position)
		else:
			_pause.handle_motion(event.position)
