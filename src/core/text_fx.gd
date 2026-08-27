class_name TextFX
extends RefCounted
## Текстовые утилиты: рисование с трекингом (разрядкой) и измерение ширины.

static func spaced(canvas: CanvasItem, font: Font, text: String, pos: Vector2, size: float, color: Color, spacing := 0.0) -> void:
	if spacing <= 0.0:
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		return
	var x := pos.x
	for ch in text:
		canvas.draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_char_size(ch.unicode_at(0), size).x + spacing


static func width(font: Font, text: String, size: float, spacing := 0.0) -> float:
	if spacing <= 0.0:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := 0.0
	for ch in text:
		w += font.get_char_size(ch.unicode_at(0), size).x + spacing
	return w


static func centered(canvas: CanvasItem, font: Font, text: String, center_x: float, y: float, size: float, color: Color, spacing := 0.0) -> void:
	spaced(canvas, font, text, Vector2(center_x - width(font, text, size, spacing) * 0.5, y), size, color, spacing)


## Пунктирная «стежка» поверх базовой линии — фирменный шов PIN&PAN.
static func stitch_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width := 2.0, dash := 5.0, gap := 4.0) -> void:
	canvas.draw_line(from, to, Color(color, 0.22), width)
	canvas.draw_dashed_line(from, to, color, width, dash + gap)
