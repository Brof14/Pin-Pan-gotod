class_name CursorView
extends Node2D
## Слой курсоров: рисуется поверх всего UI меню.

var cursors: Array[NeedleCursor] = []


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var settings := PinPanCore.I.settings
	for c in cursors:
		c.draw_on(self, PinPanPalette.WARM, settings.high_contrast)
