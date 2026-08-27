class_name MenuBackdrop
extends Node2D
## Фон меню: стена мастерской, луч света, дальний силуэт станка,
## свисающие нити, средний слой ткани и пыль. Всё процедурно, слои с параллаксом.

const SIZE := Vector2(1920, 1080)

var _motes: Array[Dictionary] = []
var _time := 0.0
var _parallax := Vector2.ZERO


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	for i in range(130):
		var in_beam := i < 70
		_motes.append({
			"p": Vector2(rng.randf_range(100.0, 1820.0), rng.randf_range(40.0, 1040.0)),
			"v": Vector2(rng.randf_range(6.0, 16.0), rng.randf_range(4.0, 11.0)),
			"r": rng.randf_range(1.1, 2.4) if in_beam else rng.randf_range(1.0, 1.8),
			"beam": in_beam,
			"phase": rng.randf_range(0.0, TAU),
		})


func set_parallax(p: Vector2) -> void:
	_parallax = p
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for mote in _motes:
		var p: Vector2 = mote["p"]
		p += Vector2(mote["v"]) * delta
		if p.x < 60.0:
			p.x = 1860.0
		if p.y > 1060.0:
			p.y = 60.0
		mote["p"] = p
	queue_redraw()


func _draw() -> void:
	# 1. Стена: вертикальный градиент через вершинные цвета.
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)]),
		PackedColorArray([Color("0b0b10"), Color("0b0b10"), Color("121016"), Color("121016")]))
	# слабая фактура стены — редкие штрихи ткани
	for i in range(46):
		var x := fposmod(float(i * 137.7), SIZE.x)
		var y := fposmod(float(i * 61.3), SIZE.y)
		draw_line(Vector2(x, y), Vector2(x + 26, y + 9), Color(PinPanPalette.FABRIC, 0.06), 2.0)

	_draw_light_shaft()
	_draw_loom()
	_draw_hanging_threads()
	_draw_drape()
	_draw_dust()


func _draw_light_shaft() -> void:
	draw_set_transform(-_parallax * 0.25, 0.0, Vector2.ONE)
	var breathe := 0.85 + 0.15 * sin(_time * 0.23)
	var sway := sin(_time * 0.13) * 9.0
	# внешний и внутренний лучи из правого верхнего угла
	draw_polygon(
		PackedVector2Array([
			Vector2(1480 + sway, -20), Vector2(1940, -20), Vector2(1130 + sway, 1100), Vector2(560, 1100),
		]),
		PackedColorArray([
			Color("fff3d8", 0.10 * breathe), Color("fff3d8", 0.07 * breathe),
			Color("fff3d8", 0.0), Color("fff3d8", 0.0),
		]))
	draw_polygon(
		PackedVector2Array([
			Vector2(1640 + sway, -20), Vector2(1940, -20), Vector2(1330 + sway, 1100), Vector2(980, 1100),
		]),
		PackedColorArray([
			Color("fff3d8", 0.06 * breathe), Color("fff3d8", 0.05 * breathe),
			Color("fff3d8", 0.0), Color("fff3d8", 0.0),
		]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loom() -> void:
	draw_set_transform(-_parallax * 0.55, 0.0, Vector2.ONE)
	var fog := Color(PinPanPalette.LOOM, 0.8)
	# стойки и верхний/нижний навои
	draw_rect(Rect2(1170, 130, 26, 720), fog)
	draw_rect(Rect2(1700, 130, 26, 720), fog)
	draw_rect(Rect2(1150, 118, 560, 24), fog)
	draw_rect(Rect2(1120, 700, 620, 30), Color(PinPanPalette.LOOM, 0.9))
	# основа — вертикальные нити, слегка колышутся
	for i in range(34):
		var x := 1215.0 + float(i) * 13.6
		var sway := sin(_time * 0.4 + float(i) * 0.55) * 2.0
		var a := 0.34 - float(i % 5) * 0.03
		draw_line(Vector2(x, 142), Vector2(x + sway, 700), Color(PinPanPalette.LOOM, a), 2.0)
	# ремизка и подножки
	draw_rect(Rect2(1190, 380, 520, 12), Color(PinPanPalette.LOOM, 0.55))
	draw_line(Vector2(1260, 730), Vector2(1400, 900), Color(PinPanPalette.LOOM, 0.5), 8.0)
	draw_line(Vector2(1640, 730), Vector2(1500, 900), Color(PinPanPalette.LOOM, 0.5), 8.0)
	# челнок
	draw_arc(Vector2(1420 + sin(_time * 0.35) * 30.0, 520), 14.0, 0.0, TAU, 12, Color(PinPanPalette.WARM, 0.16), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hanging_threads() -> void:
	draw_set_transform(-_parallax * 0.8, 0.0, Vector2.ONE)
	for i in range(6):
		var x := 70.0 + float(i) * 118.0
		var sway := sin(_time * 0.5 + float(i) * 1.7) * 6.0
		var length := 560.0 + fposmod(float(i * 97), 300.0)
		draw_line(Vector2(x, 0), Vector2(x + sway, length), Color(PinPanPalette.LOOM, 0.4), 2.0)
		draw_circle(Vector2(x + sway, length), 4.0, Color(PinPanPalette.WARM, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_drape() -> void:
	draw_set_transform(-_parallax * 1.0, 0.0, Vector2.ONE)
	var wave := sin(_time * 0.5) * 4.0
	var top := PackedVector2Array([
		Vector2(1010, 1080), Vector2(1120, 780 + wave), Vector2(1330, 712 - wave),
		Vector2(1560, 745 + wave), Vector2(1920, 700 - wave), Vector2(1920, 1080),
	])
	draw_colored_polygon(top, Color(PinPanPalette.FABRIC, 0.94))
	# складки — тёмные клинья
	for i in range(4):
		var x := 1180.0 + float(i) * 170.0
		var lean := 60.0 + float(i) * 30.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 790 + wave), Vector2(x + lean, 1080), Vector2(x + lean + 70, 1080), Vector2(x + 40, 800 + wave),
		]), Color(PinPanPalette.DEEP, 0.42))
	# блик по верхней кромке и подшивка
	for i in range(top.size() - 2):
		draw_line(top[i], top[i + 1], Color(PinPanPalette.LINEN, 0.22), 2.5)
		TextFX.stitch_line(self, top[i], top[i + 1], Color(PinPanPalette.WARM, 0.24), 1.6, 7.0, 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dust() -> void:
	draw_set_transform(-_parallax * 1.2, 0.0, Vector2.ONE)
	for mote in _motes:
		var p: Vector2 = mote["p"]
		var twinkle := 0.7 + 0.3 * sin(_time * 1.7 + float(mote["phase"]))
		if bool(mote["beam"]):
			# пыль в луче заметнее
			var in_shaft := p.x > 1000.0 and p.x < 1900.0
			var alpha := (0.15 if in_shaft else 0.05) * twinkle
			draw_circle(p, float(mote["r"]), Color(PinPanPalette.WARM, alpha))
		else:
			draw_circle(p, float(mote["r"]), Color(PinPanPalette.WARM, 0.05 * twinkle))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
