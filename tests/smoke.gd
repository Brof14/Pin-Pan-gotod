extends SceneTree

func _init() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(game)
	assert(game.app_state == game.AppState.INTRO)
	game.intro_time = 14.0
	game._process(0.01)
	assert(game.app_state == game.AppState.MENU)
	game._start_new_game()
	for i in range(20):
		game._process(0.1)
	assert(game.app_state == game.AppState.PROLOGUE or game.app_state == game.AppState.LOADING)
	while game.app_state == game.AppState.LOADING:
		game._process(0.1)
	assert(game.app_state == game.AppState.PROLOGUE)
	game.pin_awake = 1.0
	game.pan_awake = 1.0
	for i in range(10):
		game._process(0.1)
	assert(game.prologue_state == game.PrologueState.MOVE)
	game._finish_prologue()
	assert(game.app_state == game.AppState.GAME)
	game._configure_room(0, false)
	game._update_game(0.2)
	assert(game.pin_grounded)
	assert(game.pan_grounded)
	for room_index in range(7):
		game._configure_room(room_index, false)
		assert(game.room == room_index)
		game._update_game(0.016)
	game._configure_room(99, false)
	assert(game.room == 6)
	game._next_room()
	assert(game.app_state == game.AppState.ACT_COMPLETE)
	game.app_state = game.AppState.GAME
	game._open_pause()
	assert(game.app_state == game.AppState.PAUSE)
	game._close_pause()
	assert(game.app_state == game.AppState.GAME)
	game.settings_return = game.AppState.GAME
	game.app_state = game.AppState.SETTINGS
	game._click(Vector2(1095, 300))
	assert(game.settings_data.master == 50)
	assert(game.dragged_slider == 0)
	game.dragged_slider = -1
	game._set_slider(0, 42)
	assert(game.settings_data.master == 42)
	game._close_settings()
	assert(game.app_state == game.AppState.GAME)
	assert(game.save_data.can_continue())
	print("SMOKE_OK")
	quit()
