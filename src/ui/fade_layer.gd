class_name FadeLayer
extends Node2D
## Глобальный слой поверх всего: плавное затемнение переходов и коррекция яркости.

var fade := 1.0 # 0 — прозрачно, 1 — черно
var target := 0.0
var speed := 2.6
var brightness_tint := Color.BLACK
var brightness_alpha := 0.0


func _process(delta: float) -> void:
	fade = move_toward(fade, target, delta * speed)
	queue_redraw()


func _draw() -> void:
	if brightness_alpha > 0.001:
		draw_rect(Rect2(-400, -400, 2720, 1880), Color(brightness_tint, brightness_alpha), true)
	if fade > 0.001:
		draw_rect(Rect2(-400, -400, 2720, 1880), Color(0, 0, 0, fade), true)


func is_done() -> bool:
	return is_equal_approx(fade, target)
