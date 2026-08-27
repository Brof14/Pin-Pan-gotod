class_name GameScreen
extends Node2D
## Акт I: Мир 1 «Льняные поля» (осознание) и Мир 2 «Шерстяной лес» (контроль).
## Комнаты 0–6: движение → совместный прыжок → плиты → Bind-якорь → узел памяти →
## первый Корректор → катушка-дрон → погоня с Ignite. Фейл возвращает на чекпоинт ≤3 с.

signal act_complete
signal pause_requested

enum World { FIELDS, FOREST }

const LAST_ROOM := 6
const ACT_TITLES := [
	["ЛЬНЯНЫЕ ПОЛЯ", "ПЕРВЫЕ ШАГИ"],
	["ЛЬНЯНЫЕ ПОЛЯ", "ДВЕРЬ"],
	["ЛЬНЯНЫЕ ПОЛЯ", "ПЕРВЫЙ УЗЕЛ"],
	["ЛЬНЯНЫЕ ПОЛЯ", "СПУСК"],
	["ШЕРСТЯНОЙ ЛЕС", "ПЕРВАЯ ВСТРЕЧА"],
	["ШЕРСТЯНОЙ ЛЕС", "КАТУШКИ"],
	["ШЕРСТЯНОЙ ЛЕС", "ПОГОНЯ"],
]
const HINTS := {
	0: ["ВЕДИТЕ PIN И PAN. НИТЬ НЕ ДАЁТ ИМ РАЗОЙТИСЬ СЛИШКОМ ДАЛЕКО.", 4.5],
	1: ["ОДНОВРЕМЕННО ВСТАНЬТЕ НА ДВЕ ПЛИТЫ — ДВЕРЬ ОТКРОЕТСЯ.", 4.0],
	2: ["PIN: E У КРАСНОГО ЯКОРЯ — ОН СОТКАНЁТ ОПОРУ ДЛЯ PAN.", 4.5],
	3: ["ПОДБЕРИТЕСЬ К СВЕТЯЩЕМУСЯ УЗЛУ — ОН ДОБРОВОЛЬНЫЙ.", 3.5],
	4: ["PIN: E — ЗАКРЕПИТЬ КОРРЕКТОРА. PAN: SHIFT — РАСПУСТИТЬ ЕГО СВЯЗЬ.", 4.5],
	5: ["УЗЛОВЫЕ ЛОВУШКИ КАТУШКИ МОЖНО ОБЙТИ ИЛИ СРЕЗАТЬ.", 4.0],
	6: ["КОГДА НИТЬ НАТЯНУТА, SHIFT ДАЁТ РЫВОК — IGNITE.", 4.0],
}

var world := World.FIELDS
var room := 0
var _active := false
var _time := 0.0
var _room_time := 0.0
var _input_lock := 0.0
var _message := ""
var _message_time := 0.0
var _hint := ""
var _hint_time := 0.0
var _hint_seen: Dictionary = {}
var _shake := 0.0
var _flash := 0.0
var _camera := Vector2.ZERO

var _pin_pos := Vector2.ZERO
var _pan_pos := Vector2.ZERO
var _pin_vel := Vector2.ZERO
var _pan_vel := Vector2.ZERO
var _pin_grounded := false
var _pan_grounded := false
var _pin_jump := false
var _pan_jump := false
var _tension := 0.0
var _last_tension_step := -1
var _ignite_ready := false

var _platforms: Array[Rect2] = []
var _pads: Array[Rect2] = []
var _gate := Rect2()
var _exit_zone := Rect2()
var _memory_point := Vector2.ZERO
var _anchor_point := Vector2.ZERO
var _bind_active := false
var _door_open := false
var _enemies: Array[Dictionary] = []
var _traps: Array[Rect2] = []
var _trap_armed: Array[float] = []
var _chase_pressure := 0.0
var _motes: Array[Dictionary] = []


func play(start_room: int) -> void:
	_active = true
	visible = true
	set_process(true)
	configure_room(start_room, true)


func stop() -> void:
	_active = false
	visible = false
	set_process(false)


func configure_room(index: int, announce: bool) -> void:
	room = clampi(index, 0, LAST_ROOM)
	_room_time = 0.0
	_bind_active = false
	_door_open = false
	_enemies.clear()
	_traps.clear()
	_trap_armed.clear()
	_pads.clear()
	_platforms.clear()
	_memory_point = Vector2.ZERO
	_anchor_point = Vector2.ZERO
	_gate = Rect2()
	_chase_pressure = 0.0
	world = World.FOREST if room >= 4 else World.FIELDS
	match room:
		0:
			_platforms = [Rect2(0, 820, 560, 300), Rect2(650, 760, 270, 40), Rect2(1030, 690, 280, 40), Rect2(1410, 800, 510, 320)]
			_exit_zone = Rect2(1710, 650, 180, 240)
		1:
			_platforms = [Rect2(0, 820, 1920, 300)]
			_pads = [Rect2(620, 790, 95, 30), Rect2(950, 790, 95, 30)]
			_gate = Rect2(1300, 490, 42, 330)
			_exit_zone = Rect2(1660, 650, 190, 240)
		2:
			_platforms = [Rect2(0, 820, 680, 300), Rect2(1190, 760, 730, 360)]
			_anchor_point = Vector2(570, 750)
			_memory_point = Vector2(360, 750)
			_exit_zone = Rect2(1690, 620, 180, 250)
		3:
			_platforms = [Rect2(0, 760, 420, 360), Rect2(490, 810, 300, 300), Rect2(860, 730, 260, 390), Rect2(1200, 780, 720, 340)]
			_memory_point = Vector2(610, 750)
			_exit_zone = Rect2(1690, 600, 180, 270)
		4:
			_platforms = [Rect2(0, 820, 1920, 300)]
			_enemies.append({"pos": Vector2(980, 760), "home": 980.0, "range": 170.0, "dir": 1.0, "bound": false, "cut": false, "alert": 0.0, "kind": "patrol"})
			_exit_zone = Rect2(1660, 650, 190, 240)
		5:
			_platforms = [Rect2(0, 820, 620, 300), Rect2(710, 740, 270, 380), Rect2(1090, 810, 830, 310)]
			_traps = [Rect2(770, 702, 55, 38), Rect2(1240, 772, 65, 38), Rect2(1470, 772, 65, 38)]
			_enemies.append({"pos": Vector2(930, 570), "home": 930.0, "range": 210.0, "dir": 1.0, "bound": false, "cut": false, "alert": 0.0, "kind": "drone"})
			_exit_zone = Rect2(1660, 650, 190, 240)
		6:
			_platforms = [Rect2(0, 820, 520, 300), Rect2(600, 750, 270, 370), Rect2(970, 690, 260, 430), Rect2(1320, 800, 600, 320)]
			_enemies.append({"pos": Vector2(120, 760), "home": 120.0, "range": 1000.0, "dir": 1.0, "bound": false, "cut": false, "alert": 1.0, "kind": "chaser"})
			_exit_zone = Rect2(1690, 610, 180, 270)
	for t in _traps:
		_trap_armed.append(0.0)
	_pin_pos = Vector2(180, 740)
	_pan_pos = Vector2(320, 740)
	_pin_vel = Vector2.ZERO
	_pan_vel = Vector2.ZERO
	_tension = 0.0
	_last_tension_step = -1
	_ignite_ready = false
	PinPanCore.I.save.set_checkpoint(room)
	if announce:
		var title: Array = ACT_TITLES[room]
		_show(title[0] + "  —  " + title[1], 3.2)
	if HINTS.has(room) and not _hint_seen.has(room):
		_hint_seen[room] = true
		_hint = HINTS[room][0]
		_hint_time = HINTS[room][1]


func handle_key(key: Key) -> void:
	if not _active:
		return
	match key:
		KEY_W:
			_pin_jump = true
		KEY_UP:
			_pan_jump = true
		KEY_E:
			_try_bind()
		KEY_SHIFT, KEY_SLASH:
			_try_cut_or_ignite()


func handle_joy_button(button: JoyButton, device: int) -> void:
	if not _active:
		return
	match button:
		JOY_BUTTON_A:
			if device == 0:
				_pin_jump = true
			else:
				_pan_jump = true
		JOY_BUTTON_X:
			_try_bind()
		JOY_BUTTON_Y:
			_try_cut_or_ignite()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_room_time += delta
	_input_lock = maxf(0.0, _input_lock - delta)
	_message_time = maxf(0.0, _message_time - delta)
	_hint_time = maxf(0.0, _hint_time - delta)
	_shake = maxf(0.0, _shake - delta * 2.8)
	_flash = maxf(0.0, _flash - delta * 2.4)
	if world == World.FOREST:
		PinPanCore.I.set_wind(0.10 + _chase_pressure * 0.3)
	else:
		PinPanCore.I.set_wind(0.06)
	_update_physics(delta)
	_update_enemies(delta)
	_update_room_logic()
	var midpoint := (_pin_pos + _pan_pos) * 0.5
	var target := Vector2(clampf((960.0 - midpoint.x) * 0.08, -70.0, 70.0), clampf((590.0 - midpoint.y) * 0.05, -25.0, 25.0))
	if PinPanCore.I.settings.reduce_motion:
		target = Vector2.ZERO
	_camera = _camera.lerp(target, minf(1.0, delta * 2.8))
	if _pin_pos.y > 1090.0 or _pan_pos.y > 1090.0:
		_reset("НИТЬ ВЕРНУЛА ВАС К БЕЗОПАСНОЙ ТОЧКЕ")
	queue_redraw()


func _movement_axis(is_pin: bool) -> float:
	var axis := 0.0
	var pads := Input.get_connected_joypads()
	if is_pin:
		axis = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		if pads.size() >= 1:
			var joy := Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X)
			if absf(joy) > 0.25:
				axis = joy
	else:
		axis = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		if pads.size() >= 2:
			var joy := Input.get_joy_axis(pads[1], JOY_AXIS_LEFT_X)
			if absf(joy) > 0.25:
				axis = joy
		else:
			var joy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
			if absf(joy) > 0.25:
				axis = joy
	return axis


func _update_physics(delta: float) -> void:
	if _input_lock > 0.0:
		return
	var pin_axis := _movement_axis(true)
	var pan_axis := _movement_axis(false)
	_pin_vel.x = move_toward(_pin_vel.x, pin_axis * 255.0, 1450.0 * delta)
	_pan_vel.x = move_toward(_pan_vel.x, pan_axis * 315.0, 1700.0 * delta)
	if pin_axis == 0.0:
		_pin_vel.x = move_toward(_pin_vel.x, 0.0, 1050.0 * delta)
	if pan_axis == 0.0:
		_pan_vel.x = move_toward(_pan_vel.x, 0.0, 1250.0 * delta)
	if _pin_jump and _pin_grounded:
		_pin_vel.y = -520.0
		_pin_grounded = false
		PinPanCore.I.sfx.play("jump_pin")
	if _pan_jump and _pan_grounded:
		_pan_vel.y = -585.0
		_pan_grounded = false
		PinPanCore.I.sfx.play("jump_pan")
	_pin_jump = false
	_pan_jump = false
	_pin_vel.y += 1350.0 * delta
	_pan_vel.y += 1350.0 * delta
	_pin_pos = _move_character(_pin_pos, _pin_vel, true, delta)
	_pan_pos = _move_character(_pan_pos, _pan_vel, false, delta)
	_thread_constraint()


func _move_character(pos: Vector2, velocity: Vector2, is_pin: bool, delta: float) -> Vector2:
	var radius := 29.0
	var old_bottom := pos.y + radius
	var next := pos + velocity * delta
	var grounded := false
	for platform in _platforms:
		if next.x + radius > platform.position.x and next.x - radius < platform.end.x:
			if velocity.y >= 0.0 and old_bottom <= platform.position.y + 8.0 and next.y + radius >= platform.position.y:
				next.y = platform.position.y - radius
				if is_pin:
					_pin_vel.y = 0.0
				else:
					_pan_vel.y = 0.0
				grounded = true
	var actor_rect := Rect2(next - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	if _gate.size != Vector2.ZERO and not _door_open and actor_rect.intersects(_gate):
		if velocity.x > 0.0 and next.x + radius > _gate.position.x and pos.x < _gate.position.x:
			next.x = _gate.position.x - radius
			if is_pin:
				_pin_vel.x = 0.0
			else:
				_pan_vel.x = 0.0
	if is_pin:
		_pin_grounded = grounded
	else:
		_pan_grounded = grounded
	return next


func _thread_constraint() -> void:
	var limits := PinPanCore.I.settings.thread_limits()
	var delta_pos := _pan_pos - _pin_pos
	var distance := delta_pos.length()
	_tension = clampf((distance - limits.x) / maxf(1.0, limits.y - limits.x), 0.0, 1.0)
	if distance > limits.y:
		var correction := delta_pos.normalized() * (distance - limits.y) * 0.5
		_pin_pos += correction
		_pan_pos -= correction
	if _tension > 0.74:
		_ignite_ready = true
		_flash = maxf(_flash, _tension * 0.34)
	var step := clampi(int(_tension * 6.0), 0, 5)
	if step != _last_tension_step:
		_last_tension_step = step
		PinPanCore.I.sfx.play_tension(_tension)


func _try_bind() -> void:
	if room == 2 and not _bind_active and _pin_pos.distance_to(_anchor_point) < 115.0:
		_bind_active = true
		_flash = 0.75
		_shake = 0.12
		_platforms.append(Rect2(650, 735, 570, 36))
		_show("PIN ЗАКРЕПИЛ НИТЬ — ПУТЬ СОЗДАН", 2.6)
		PinPanCore.I.sfx.play("bind")
		return
	for enemy in _enemies:
		if not enemy["cut"] and not enemy["bound"] and _pin_pos.distance_to(enemy["pos"]) < 145.0:
			enemy["bound"] = true
			_flash = 0.55
			_show("КОРРЕКТОР ЗАКРЕПЛЁН", 1.8)
			PinPanCore.I.sfx.play("bind")
			return
	_show("PIN ЗАКРЕПЛЯЕТ ЯКОРЬ ИЛИ КОРРЕКТОРА — НУЖНО БЛИЖЕ", 1.5)


func _try_cut_or_ignite() -> void:
	if room == 6 and _tension > 0.4:
		var direction := (_pan_pos - _pin_pos).normalized()
		_pin_vel += direction * 390.0
		_pan_vel -= direction * 210.0
		_show("IGNITE — НИТЬ ВЫТЯНУЛА ПАРТНЁРА", 1.6)
		PinPanCore.I.sfx.play("ignite")
		_flash = 0.95
		_shake = 0.18
		return
	for enemy in _enemies:
		if not enemy["cut"] and _pan_pos.distance_to(enemy["pos"]) < 155.0:
			enemy["cut"] = true
			enemy["bound"] = false
			_flash = 0.60
			_show("PAN РАСПУСТИЛ СВЯЗЬ", 1.8)
			PinPanCore.I.sfx.play("cut")
			return
	_show("PAN РАСПУСКАЕТ УГРОЗУ ИЛИ ДАЁТ РЫВОК НА НАТЯЖЕНИИ", 1.5)


func _update_enemies(delta: float) -> void:
	for enemy in _enemies:
		if enemy["cut"] or enemy["bound"]:
			continue
		var kind: String = enemy["kind"]
		var speed := 160.0 if kind == "chaser" else (120.0 if kind == "drone" else 75.0)
		var pos: Vector2 = enemy["pos"]
		if kind == "chaser":
			var target_x := minf(_pin_pos.x, _pan_pos.x)
			pos.x = move_toward(pos.x, target_x - 85.0, speed * delta)
			_chase_pressure = clampf(_chase_pressure + delta * 0.11, 0.0, 1.0)
		elif kind == "drone":
			pos.x += float(enemy["dir"]) * speed * delta
			pos.y = 570.0 + sin(_room_time * 2.0 + float(enemy["home"])) * 26.0
			if absf(pos.x - float(enemy["home"])) > float(enemy["range"]):
				enemy["dir"] = -float(enemy["dir"])
		else:
			pos.x += float(enemy["dir"]) * speed * delta
			if absf(pos.x - float(enemy["home"])) > float(enemy["range"]):
				enemy["dir"] = -float(enemy["dir"])
		enemy["pos"] = pos
		var alert_grow := delta * (1.5 if _pin_pos.distance_to(pos) < 200.0 or _pan_pos.distance_to(pos) < 200.0 else -1.0)
		enemy["alert"] = clampf(float(enemy["alert"]) + alert_grow, 0.0, 1.0)
		if float(enemy["alert"]) > 0.92 and kind != "chaser":
			# предупреждение 0,8 с перед возвратом: конус краснеет и звучит сигнал
			enemy["catch"] = float(enemy.get("catch", 0.0)) + delta
			if enemy["catch"] > 0.8:
				PinPanCore.I.sfx.play("danger")
				_reset("КОРРЕКТОР ПОЧТИ РАЗДЕЛИЛ ВАС")
				return
		elif kind == "chaser" and (pos.distance_to(_pin_pos) < 52.0 or pos.distance_to(_pan_pos) < 52.0):
			enemy["catch"] = float(enemy.get("catch", 0.0)) + delta
			if enemy["catch"] > 0.8:
				PinPanCore.I.sfx.play("danger")
				_reset("КОРРЕКТОР НАСТИГ — НИТЬ СОБРАЛА ВАС ОБРАТНО")
				return
		else:
			enemy["catch"] = 0.0
	for i in _traps.size():
		var trap: Rect2 = _traps[i]
		if _trap_armed[i] > 0.0:
			_trap_armed[i] = maxf(0.0, _trap_armed[i] - delta)
			if _trap_armed[i] == 0.0:
				PinPanCore.I.sfx.play("danger")
				_reset("УЗЕЛ УДЕРЖАЛ ОДНОГО ИЗ ВАС")
				return
		elif trap.grow(15.0).has_point(_pin_pos) or trap.grow(15.0).has_point(_pan_pos):
			_trap_armed[i] = 0.35 # короткая отсрочка — шанс уйти


func _update_room_logic() -> void:
	var save := PinPanCore.I.save
	if _memory_point != Vector2.ZERO and not save.memories.has(room):
		if _pin_pos.distance_to(_memory_point) < 70.0 or _pan_pos.distance_to(_memory_point) < 70.0:
			save.memories.append(room)
			save.memory_nodes = save.memories.size()
			save.save()
			_show("УЗЕЛ ПАМЯТИ СОХРАНЁН  " + str(save.memory_nodes) + "/8", 2.4)
			PinPanCore.I.sfx.play("memory")
	if room == 1 and not _door_open:
		var both := _pads.size() == 2 and ((_pads[0].grow(20.0).has_point(_pin_pos) and _pads[1].grow(20.0).has_point(_pan_pos)) or (_pads[1].grow(20.0).has_point(_pin_pos) and _pads[0].grow(20.0).has_point(_pan_pos)))
		if both:
			_door_open = true
			_show("ДВЕРЬ ОТКРЫТА — ВЫ СДЕЛАЛИ ЭТО ВМЕСТЕ", 2.5)
			PinPanCore.I.sfx.play("door")
	if room == 4:
		var resolved := true
		for enemy in _enemies:
			resolved = resolved and (enemy["bound"] or enemy["cut"])
		if not resolved and minf(_pin_pos.x, _pan_pos.x) > 1300.0:
			_show("КОРРЕКТОР ПЕРЕКРЫВАЕТ ПУТЬ — ЗАКРЕПИТЕ ИЛИ РАСПУСТИТЕ", 1.6)
	if _exit_zone.grow(20.0).has_point(_pin_pos) and _exit_zone.grow(20.0).has_point(_pan_pos):
		if room == 4:
			var resolved := true
			for enemy in _enemies:
				resolved = resolved and (enemy["bound"] or enemy["cut"])
			if not resolved:
				return
		_next_room()


func _next_room() -> void:
	if room >= LAST_ROOM:
		PinPanCore.I.save.act_one_complete = true
		PinPanCore.I.save.save()
		act_complete.emit()
		return
	configure_room(room + 1, true)


func _reset(message: String) -> void:
	configure_room(room, false)
	_input_lock = 0.25
	_show(message, 2.4)


func _show(message: String, duration: float) -> void:
	_message = message
	_message_time = duration


func _draw() -> void:
	var settings := PinPanCore.I.settings
	var colors := PinPanPalette.role_pair(settings.color_preset)
	var shake := Vector2.ZERO
	if _shake > 0.0 and not settings.reduce_motion:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * settings.shake_scale() * 9.0
	draw_set_transform(_camera + shake, 0.0, Vector2.ONE)
	if world == World.FIELDS:
		_draw_fields()
	else:
		_draw_forest()
	_draw_platforms()
	_draw_interactives(colors)
	_draw_enemies(colors)
	Actors.thread(self, _pin_pos, _pan_pos, _tension, PinPanPalette.WARM, _flash)
	Actors.contact_shadow(self, _pin_pos + Vector2(0, 44), 30.0)
	Actors.contact_shadow(self, _pan_pos + Vector2(0, 42), 28.0)
	Actors.character(self, _pin_pos, true, 1.0, 0.0, colors, settings.symbols, settings.high_contrast)
	Actors.character(self, _pan_pos, false, 1.0, 4.0, colors, settings.symbols, settings.high_contrast)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud()


func _draw_fields() -> void:
	draw_rect(Rect2(-400, -400, 2720, 1880), Color("24222b"), true)
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


func _draw_forest() -> void:
	draw_rect(Rect2(-400, -400, 2720, 1880), Color("18202b"), true)
	for i in range(28):
		var x := fposmod(float(i * 157), 2050.0) - 80.0
		var y := 80.0 + float(i % 6) * 110.0
		var reduce := PinPanCore.I.settings.reduce_motion
		var sway := 0.0 if reduce else sin(_time + i) * 25.0
		draw_line(Vector2(x, y), Vector2(x + sway, 940), Color(PinPanPalette.WOOL, 0.60), 32.0)
	for i in range(40):
		var x := fposmod(float(i * 131.7) + _time * 12.0, 2000.0) - 60.0
		var y := 160.0 + fposmod(float(i * 53.3), 760.0)
		draw_circle(Vector2(x, y), 1.8, Color(PinPanPalette.WOOL_LIGHT, 0.10))


func _draw_platforms() -> void:
	var col := PinPanPalette.LINEN if world == World.FIELDS else PinPanPalette.WOOL
	var hi := PinPanPalette.LINEN_LIGHT if world == World.FIELDS else PinPanPalette.WOOL_LIGHT
	for platform in _platforms:
		draw_rect(platform, col, true)
		draw_line(platform.position, Vector2(platform.end.x, platform.position.y), hi, 3.0)
		for x in range(int(platform.position.x) + 16, int(platform.end.x), 28):
			draw_line(Vector2(x, platform.position.y + 4), Vector2(x + 16, platform.position.y + minf(platform.size.y, 42)), Color(hi, 0.22), 1.0)


func _draw_interactives(colors: Dictionary) -> void:
	for pad in _pads:
		var pressed := pad.grow(18.0).has_point(_pin_pos) or pad.grow(18.0).has_point(_pan_pos)
		draw_rect(pad, Color(PinPanPalette.FOCUS, 0.5 if pressed else 0.32), true)
		draw_rect(pad, PinPanPalette.FOCUS, false, 2.0)
	if _gate.size != Vector2.ZERO and not _door_open:
		draw_rect(_gate, Color("604e55"), true)
		draw_line(_gate.position, Vector2(_gate.position.x, _gate.end.y), PinPanPalette.WARM, 3.0)
	if _anchor_point != Vector2.ZERO:
		draw_circle(_anchor_point, 22.0, Color(colors["pin_glow"], 0.20))
		draw_arc(_anchor_point, 22.0, 0.0, TAU, 20, colors["pin_glow"], 2.0)
		if _bind_active:
			draw_line(_anchor_point, _pin_pos, PinPanPalette.WARM, 3.0)
	var save := PinPanCore.I.save
	if _memory_point != Vector2.ZERO and not save.memories.has(room):
		draw_circle(_memory_point, 28.0 + sin(_time * 3.0) * 4.0, Color(PinPanPalette.WARM, 0.12))
		draw_arc(_memory_point, 16.0, 0.0, TAU, 12, PinPanPalette.WARM, 2.0)
	for trap in _traps:
		draw_colored_polygon(PackedVector2Array([
			trap.position + Vector2(0, trap.size.y), trap.position + Vector2(trap.size.x * 0.5, 0), trap.end]),
			Color(PinPanPalette.DANGER, 0.85))
		draw_circle(trap.get_center(), 5.0, Color(PinPanPalette.WARM, 0.5))
	if _exit_zone.size != Vector2.ZERO:
		draw_rect(_exit_zone, Color(PinPanPalette.WARM, 0.08), true)
		draw_line(_exit_zone.position, Vector2(_exit_zone.position.x, _exit_zone.end.y), Color(PinPanPalette.WARM, 0.42), 3.0)
		TextFX.spaced(self, ThemeDB.fallback_font, "ДАЛЬШЕ", Vector2(_exit_zone.position.x - 14, _exit_zone.position.y - 14), 13, Color(PinPanPalette.WARM, 0.5), 1.5)


func _draw_enemies(colors: Dictionary) -> void:
	for enemy in _enemies:
		var pos: Vector2 = enemy["pos"]
		if enemy["cut"]:
			for i in range(5):
				draw_line(pos + Vector2(-18 + i * 9, -16), pos + Vector2(-28 + i * 14, 22), Color(PinPanPalette.WOOL_LIGHT, 0.35), 2.0)
			continue
		var alert := float(enemy["alert"])
		var kind: String = enemy["kind"]
		var body := Color("bd8da0") if not enemy["bound"] else Color("a87589")
		# конус обнаружения: световой клин по направлению движения
		var dir_sign := -1.0 if float(enemy["dir"]) < 0.0 else 1.0
		if kind == "chaser":
			dir_sign = 1.0
		var cone_color := Color(PinPanPalette.WARM, 0.10 + alert * 0.08) if alert < 0.9 else Color(PinPanPalette.DANGER, 0.22)
		var cone_len := 190.0 if kind != "drone" else 150.0
		var half_ang := 0.42
		var steps := 18
		var cone := PackedVector2Array([pos])
		for s in range(steps + 1):
			var ang := -half_ang + (2.0 * half_ang) * float(s) / float(steps)
			cone.append(pos + Vector2(dir_sign * cos(ang), sin(ang) * 0.7) * cone_len)
		draw_colored_polygon(cone, cone_color)
		# силуэт игольщика
		draw_circle(pos, 25.0, Color(body, 0.20))
		draw_line(pos + Vector2(0, -38), pos + Vector2(0, 38), body, 5.0)
		draw_line(pos + Vector2(-18 * dir_sign, -12), pos + Vector2(18 * dir_sign, 16), body, 3.0)
		if kind == "drone":
			draw_circle(pos, 34.0 + sin(_time * 5.0) * 3.0, Color(body, 0.25))
		if enemy["bound"]:
			draw_arc(pos, 36.0, 0.0, TAU, 16, PinPanPalette.WARM, 2.0)
		elif kind == "chaser":
			draw_circle(pos, 58.0 + sin(_time * 8.0) * 4.0, Color(PinPanPalette.DANGER, 0.10 + _chase_pressure * 0.10))


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var save := PinPanCore.I.save
	draw_rect(Rect2(36, 32, 660, 128), Color(PinPanPalette.VOID, 0.52), true)
	TextFX.spaced(self, font, ACT_TITLES[room][0], Vector2(62, 78), 23, PinPanPalette.UI, 1.5)
	TextFX.spaced(self, font, ACT_TITLES[room][1], Vector2(62, 110), 16, PinPanPalette.FOCUS, 1.1)
	var controls := "PIN  A/D + W     PAN  ←/→ + ↑     E — BIND     SHIFT — CUT/IGNITE     ESC — ПАУЗА"
	if Input.get_connected_joypads().size() >= 2:
		controls = "PIN — СТИК 1 + Ⓐ      PAN — СТИК 2 + Ⓐ      X — BIND      Y — CUT/IGNITE"
	TextFX.spaced(self, font, controls, Vector2(62, 140), 13, Color(PinPanPalette.MUTED, 0.5), 0.6)
	TextFX.spaced(self, font, "УЗЛЫ ПАМЯТИ: " + str(save.memory_nodes), Vector2(1450, 55), 16, PinPanPalette.WARM, 0.7)
	if _tension > 0.68:
		TextFX.spaced(self, font, "НИТЬ НА ПРЕДЕЛЕ", Vector2(1470, 85), 16, Color(Color("ff8a72"), 0.95), 1.0)
	if _message_time > 0.0:
		draw_rect(Rect2(450, 910, 1020, 66), Color(PinPanPalette.VOID, 0.70), true)
		TextFX.centered(self, font, _message, 960, 951, 18, PinPanPalette.UI, 1.0)
	if _hint_time > 0.0:
		draw_rect(Rect2(310, 825, 1300, 58), Color("15151df2"), true)
		draw_rect(Rect2(310, 825, 1300, 58), Color(PinPanPalette.FOCUS, 0.30), false, 1.0)
		TextFX.centered(self, font, _hint, 960, 861, 16, PinPanPalette.UI, 0.65)
