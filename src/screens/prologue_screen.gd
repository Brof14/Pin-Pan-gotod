class_name PrologueScreen
extends Node2D
## Пролог «Нить, которой не должно было быть»: растерянность → любопытство →
## первый успех → тревога → падение → осознанное движение. Без единого слова.
## Bind/Cut/Ignite здесь нет — только движение и нить.

signal finished
signal pause_requested

enum PState { WAKE, MOVE, HAND, BREAK, FALL, LAND }

var _state := PState.WAKE
var _elapsed := 0.0
var _state_time := 0.0
var _time := 0.0
var _input_lock := 0.0
var _active := false
var _heart_clock := 0.0
var _last_tension_step := -1
var _landing_played := false
var _pull_played := false

var _pin_pos := Vector2(840.0, 510.0)
var _pan_pos := Vector2(1080.0, 510.0)
var _pin_vel := Vector2.ZERO
var _pan_vel := Vector2.ZERO
var _pin_awake := 0.0
var _pan_awake := 0.0
var _tension := 0.0
var _letterbox := 90.0


func play() -> void:
	_active = true
	_state = PState.WAKE
	_elapsed = 0.0
	_state_time = 0.0
	_pin_pos = Vector2(840.0, 510.0)
	_pan_pos = Vector2(1080.0, 510.0)
	_pin_vel = Vector2.ZERO
	_pan_vel = Vector2.ZERO
	_pin_awake = 0.0
	_pan_awake = 0.0
	_input_lock = 0.0
	_letterbox = 90.0
	_landing_played = false
	_pull_played = false
	_last_tension_step = -1
	PinPanCore.I.set_wind(0.0)
	visible = true
	set_process(true)


func stop() -> void:
	_active = false
	visible = false
	set_process(false)


## Пропуск недоступен в момент «захвата» (управление отобрано) — как в документе.
func can_skip() -> bool:
	return _elapsed >= 3.0 and not (_elapsed >= 26.0 and _elapsed < 35.0)


func skip() -> void:
	if can_skip():
		finished.emit()


func nudge(is_pin: bool) -> void:
	if _state == PState.WAKE:
		if is_pin:
			_pin_awake = minf(1.0, _pin_awake + 0.35)
		else:
			_pan_awake = minf(1.0, _pan_awake + 0.35)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_elapsed += delta
	_state_time += delta
	_input_lock = maxf(0.0, _input_lock - delta)
	_heart_clock += delta
	match _state:
		PState.WAKE:
			if _heart_clock >= 1.2: # 50 BPM
				_heart_clock = 0.0
				PinPanCore.I.sfx.play("heartbeat")
			if (_pin_awake >= 1.0 and _pan_awake >= 1.0 and _state_time > 0.8) or _state_time > 10.0:
				_pin_awake = 1.0
				_pan_awake = 1.0
				_enter(PState.MOVE)
		PState.MOVE:
			_free_motion(delta, 0.82)
			_thread_constraint()
			var step := clampi(int(_tension * 6.0), 0, 5)
			if step != _last_tension_step:
				_last_tension_step = step
				PinPanCore.I.sfx.play_tension(_tension)
			if _state_time > 14.0:
				_enter(PState.HAND)
		PState.HAND:
			if not _pull_played:
				_pull_played = true
				PinPanCore.I.sfx.play("fabric_snap")
			if _state_time > 1.0:
				_free_motion(delta, 0.45)
				_thread_constraint()
			if _state_time > 7.0:
				_enter(PState.BREAK)
		PState.BREAK:
			if _state_time > 1.2:
				_enter(PState.FALL)
		PState.FALL:
			if _state_time > 9.0:
				_enter(PState.LAND)
		PState.LAND:
			if _state_time > 1.0:
				_free_motion(delta, 0.85)
				_thread_constraint()
			if _state_time > 1.4 and not _landing_played:
				_landing_played = true
				PinPanCore.I.sfx.play("land")
				PinPanCore.I.set_wind(0.22)
			if _letterbox > 0.0:
				_letterbox = maxf(0.0, _letterbox - delta * 90.0)
			if _state_time > 12.0:
				finished.emit()
	queue_redraw()


func _enter(next: PState) -> void:
	_state = next
	_state_time = 0.0
	match next:
		PState.HAND:
			_input_lock = 1.0
			_heart_clock = 0.0
		PState.BREAK:
			PinPanCore.I.flash_mute(0.5)
			PinPanCore.I.sfx.play("flash")
		PState.FALL:
			PinPanCore.I.sfx.play("whoosh")
		PState.LAND:
			_pin_pos = Vector2(820.0, 700.0)
			_pan_pos = Vector2(1080.0, 700.0)
			_pin_vel = Vector2.ZERO
			_pan_vel = Vector2.ZERO
			_input_lock = 0.5


func _free_motion(delta: float, multiplier: float) -> void:
	if _input_lock > 0.0:
		return
	var pin_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var pan_input := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	var left_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var right_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if Input.get_connected_joypads().size() >= 2:
		left_stick = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		right_stick = Vector2(Input.get_joy_axis(1, JOY_AXIS_LEFT_X), Input.get_joy_axis(1, JOY_AXIS_LEFT_Y))
	if left_stick.length() > 0.25:
		pin_input = left_stick
	if right_stick.length() > 0.25:
		pan_input = right_stick
	_pin_vel = _pin_vel.lerp(pin_input.limit_length(1.0) * 150.0 * multiplier, minf(1.0, delta * 8.0))
	_pan_vel = _pan_vel.lerp(pan_input.limit_length(1.0) * 185.0 * multiplier, minf(1.0, delta * 10.0))
	_pin_pos += _pin_vel * delta
	_pan_pos += _pan_vel * delta
	var bounds := Rect2(430.0, 350.0, 1060.0, 440.0)
	if _state == PState.LAND:
		bounds = Rect2(80.0, 560.0, 1740.0, 240.0)
	_pin_pos = Vector2(clampf(_pin_pos.x, bounds.position.x, bounds.end.x), clampf(_pin_pos.y, bounds.position.y, bounds.end.y))
	_pan_pos = Vector2(clampf(_pan_pos.x, bounds.position.x, bounds.end.x), clampf(_pan_pos.y, bounds.position.y, bounds.end.y))


func _thread_constraint() -> void:
	var limits := PinPanCore.I.settings.thread_limits()
	var delta_pos := _pan_pos - _pin_pos
	var distance := delta_pos.length()
	_tension = clampf((distance - limits.x) / maxf(1.0, limits.y - limits.x), 0.0, 1.0)
	if distance > limits.y:
		var correction := delta_pos.normalized() * (distance - limits.y) * 0.5
		_pin_pos += correction
		_pan_pos -= correction


func _draw() -> void:
	var settings := PinPanCore.I.settings
	var colors := PinPanPalette.role_pair(settings.color_preset)
	draw_rect(Rect2(-400, -400, 2720, 1880), PinPanPalette.VOID, true)
	if _state == PState.LAND:
		_draw_linen_world(colors)
	else:
		_draw_workshop()
	match _state:
		PState.WAKE, PState.MOVE, PState.HAND:
			var amount := clampf(_pin_pos.distance_to(_pan_pos) / 450.0, 0.0, 1.0)
			Actors.thread(self, _pin_pos, _pan_pos, amount, PinPanPalette.WARM)
			Actors.character(self, _pin_pos, true, 0.72 + _pin_awake * 0.28, 0.0, colors, settings.symbols, settings.high_contrast)
			Actors.character(self, _pan_pos, false, 0.72 + _pan_awake * 0.28, 4.0, colors, settings.symbols, settings.high_contrast)
			if _state == PState.WAKE:
				var breathe := 48.0 + sin(_time * TAU / 1.2) * 10.0
				draw_circle(_pin_pos, breathe, Color(colors["pin_glow"], 0.10 * (1.0 - _pin_awake)))
				draw_circle(_pan_pos, breathe, Color(colors["pan_glow"], 0.10 * (1.0 - _pan_awake)))
			if _state == PState.HAND:
				_draw_weaver_hand()
		PState.BREAK:
			var alpha := sin(clampf(_state_time / 1.2, 0.0, 1.0) * PI) * 0.94
			if settings.reduced_flash:
				alpha *= 0.35
			draw_rect(Rect2(-400, -400, 2720, 1880), Color(1.0, 0.98, 0.94, alpha), true)
		PState.FALL:
			var center := Vector2(960, 480 + sin(_state_time * 2.2) * 14.0)
			var separation := 180.0 + sin(_state_time * 1.4) * 45.0
			var a := center + Vector2(-separation * 0.5, -15)
			var b := center + Vector2(separation * 0.5, 20)
			Actors.thread(self, a, b, 0.42, PinPanPalette.WARM)
			Actors.character(self, a, true, 0.86, -5, colors, settings.symbols, settings.high_contrast)
			Actors.character(self, b, false, 0.86, 8, colors, settings.symbols, settings.high_contrast)
		PState.LAND:
			Actors.thread(self, _pin_pos, _pan_pos, _tension, PinPanPalette.WARM)
			Actors.character(self, _pin_pos, true, 1.0, 0.0, colors, settings.symbols, settings.high_contrast)
			Actors.character(self, _pan_pos, false, 1.0, 4.0, colors, settings.symbols, settings.high_contrast)
	if _letterbox > 0.0:
		draw_rect(Rect2(-400, -400, 2720, 400 + _letterbox), Color.BLACK, true)
		draw_rect(Rect2(-400, 1080 - _letterbox, 2720, 400 + _letterbox), Color.BLACK, true)
	if can_skip():
		TextFX.spaced(self, ThemeDB.fallback_font, "SPACE — ПРОПУСТИТЬ", Vector2(1565, 1000), 14, Color(PinPanPalette.MUTED, 0.8), 1.0)


func _draw_workshop() -> void:
	for i in range(18):
		var x := 110.0 + float(i) * 100.0
		draw_line(Vector2(x, 20), Vector2(x + 90, 790), Color(PinPanPalette.LOOM, 0.13), 5.0)


func _draw_linen_world(colors: Dictionary) -> void:
	draw_rect(Rect2(-400, 460, 2720, 1020), Color("24222b"), true)
	draw_rect(Rect2(-400, -400, 2720, 860), Color("1b1a22"), true)
	draw_circle(Vector2(1550, 270), 180, Color("657b98", 0.10))
	var reduce := PinPanCore.I.settings.reduce_motion
	for i in range(150):
		var x := fposmod(float(i * 71), 1920.0)
		var base_y := 690.0 + fposmod(float(i * 37), 400.0)
		var sway := 0.0 if reduce else sin(_time * 1.2 + i) * 5.0
		draw_line(Vector2(x, base_y), Vector2(x + sway, base_y - 85.0 - float(i % 5) * 11.0), Color(PinPanPalette.LINEN, 0.42), 2.0)
	for i in range(8):
		var x := 1050.0 + float(i) * 94.0
		draw_line(Vector2(x, 120), Vector2(x - 55, 660), Color(PinPanPalette.LOOM, 0.25), 13.0)


func _draw_weaver_hand() -> void:
	var enter := clampf(_state_time / 2.0, 0.0, 1.0)
	var palm := Vector2(1530, -80).lerp(Vector2(1220, 300), enter)
	draw_circle(palm, 95, Color("524552"))
	for i in range(5):
		var a := palm + Vector2(-55 + i * 28, 40)
		var b := a + Vector2(-90 + i * 25, 180)
		draw_line(a, b, Color("635262"), 30)
		draw_circle(b, 15, Color("796573"))
