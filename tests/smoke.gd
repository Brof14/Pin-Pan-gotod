extends SceneTree
## Smoke-тест: прогоняем путь игрока headless — меню → пролог → акт I → чекпоинты.

var _game: Node
var _started := false


func _init() -> void:
	var root_node := root
	if root_node.get_node_or_null("PinPan") == null:
		var core = load("res://src/core/core.gd").new()
		core.name = "PinPan"
		root_node.add_child(core)
	_game = load("res://scenes/Main.tscn").instantiate()
	root_node.add_child(_game)


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	quit()
	return true


func _run() -> void:
	# тест всегда начинается с чистого прогресса
	PinPanCore.I.save = PinPanSave.new()
	assert(_game.state == _game.State.INTRO)
	# --- меню ---
	_game._intro._time = 4.0
	_game._intro.skip()
	_step(0.3)
	assert(_game.state == _game.State.MENU)
	assert(PinPanCore.I.save.can_continue() == false)
	# ИГРАТЬ без сохранения — сразу загрузка в пролог
	_game._menu.handle_key(KEY_ENTER)
	_step(0.3)
	assert(_game._menu._system.state == _game._menu._system.MenuState.LOADING)
	# ждём готовность загрузки
	var guard := 0
	while _game._menu._pending != "" or _game._menu._system.state == _game._menu._system.MenuState.LOADING:
		_game._menu._process(0.1)
		guard += 1
		assert(guard < 300)
	_step(0.6)
	assert(_game.state == _game.State.PROLOGUE)
	# --- пролог: пробуждение ---
	for i in range(10):
		_game._prologue.nudge(true)
		_game._prologue.nudge(false)
		_game._prologue._process(0.1)
	assert(_game._prologue._state == _game._prologue.PState.MOVE)
	_game._prologue._state_time = 14.1
	_game._prologue._process(0.1)
	assert(_game._prologue._state == _game._prologue.PState.HAND)
	_game._prologue._elapsed = 40.0
	_game._prologue.skip()
	_step(0.6)
	assert(_game.state == _game.State.GAME)
	# --- акт I: физика и комнаты ---
	_game._game._process(0.2)
	assert(_game._game._pin_grounded)
	assert(_game._game._pan_grounded)
	for room_index in range(7):
		_game._game.configure_room(room_index, false)
		assert(_game._game.room == room_index)
		_game._game._process(0.016)
	_game._game.configure_room(99, false)
	assert(_game._game.room == 6)
	_game._game._next_room()
	_step(0.6)
	assert(_game.state == _game.State.ACT_COMPLETE)
	# --- пауза недоступна вне игры, доступна в игре ---
	_game._transition(_game._do_continue)
	_step(0.6)
	assert(_game.state == _game.State.GAME)
	_game._open_pause()
	assert(_game._paused)
	_game._close_pause()
	assert(not _game._paused)
	# --- настройки применяются и сохраняются ---
	var panel := SettingsPanel.new()
	PinPanCore.I.add_child(panel)
	panel._set_slider(0, 42)
	assert(PinPanCore.I.settings.master == 42)
	var symbols_before := PinPanCore.I.settings.symbols
	panel._activate(8)
	assert(PinPanCore.I.settings.symbols != symbols_before)
	# --- сохранение существует, НАСТРОЙКИ/ПРОДОЛЖИТЬ на месте ---
	assert(PinPanCore.I.save.can_continue())
	var rows: Array = _game._menu._system.rows(PinPanCore.I.save)
	assert(rows.size() == 4)
	assert(rows[1]["enabled"])
	print("SMOKE_OK")
	quit()


func _step(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var delta := minf(0.1, left)
		_game._fade._process(delta)
		_game._process(delta)
		match _game.state:
			_game.State.MENU:
				_game._menu._process(delta)
			_game.State.PROLOGUE:
				_game._prologue._process(delta)
			_game.State.GAME:
				_game._game._process(delta)
			_game.State.ACT_COMPLETE:
				_game._act_complete._process(delta)
		left -= delta
