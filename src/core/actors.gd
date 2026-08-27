class_name Actors
extends RefCounted
## Рисованные актёры и реквизит: Pin (булавка-щит), Pan (капля), нить, ткань.
## Используются меню, Прологом и Актом I — герои везде одинаковые.

## brightness — пульс свечения idle-цикла, rotation_deg — общий наклон (AFK-вращение),
## squash — дыхание (1.0 = спокойно).
static func character(canvas: CanvasItem, pos: Vector2, is_pin: bool, scale_f: float, tilt_deg: float,
		colors: Dictionary, symbols: bool, high_contrast: bool,
		brightness := 1.0, rotation_deg := 0.0, squash := 1.0) -> void:
	var core: Color = colors["pin"] if is_pin else colors["pan"]
	var deep: Color = colors["pin_deep"] if is_pin else colors["pan_deep"]
	var glow: Color = colors["pin_glow"] if is_pin else colors["pan_glow"]
	var outline := PinPanPalette.UI if high_contrast else deep
	core = Color(core.r * brightness, core.g * brightness, core.b * brightness)
	glow = Color(glow.r * brightness, glow.g * brightness, glow.b * brightness)
	var tilt := deg_to_rad(tilt_deg)
	var droplet := Vector2(sin(tilt) * 6.0, 0.0)
	canvas.draw_set_transform(pos, deg_to_rad(rotation_deg), Vector2(scale_f, scale_f * squash))
	var r := 35.0
	canvas.draw_circle(droplet, r * 1.75, Color(glow, 0.10))
	canvas.draw_circle(droplet, r * 1.25, Color(glow, 0.17))
	if is_pin:
		var points := PackedVector2Array([
			Vector2(0, -r), Vector2(r * 0.85, -r * 0.14), Vector2(r * 0.56, r * 0.80),
			Vector2(-r * 0.56, r * 0.80), Vector2(-r * 0.85, -r * 0.14),
		])
		canvas.draw_colored_polygon(points, outline)
		var inside := PackedVector2Array([
			Vector2(0, -r * 0.72), Vector2(r * 0.58, 0), Vector2(r * 0.30, r * 0.60),
			Vector2(-r * 0.32, r * 0.60), Vector2(-r * 0.58, 0),
		])
		canvas.draw_colored_polygon(inside, core)
		# шляпка булавки — блик
		canvas.draw_circle(Vector2(0, -r * 0.55), r * 0.16, Color(glow, 0.5))
		if symbols:
			canvas.draw_polyline(PackedVector2Array([
				Vector2(0, -r * 1.8), Vector2(-7, -r * 1.54), Vector2(7, -r * 1.54), Vector2(0, -r * 1.8),
			]), PinPanPalette.UI, 1.5)
	else:
		canvas.draw_circle(droplet, r, outline)
		canvas.draw_circle(droplet + Vector2(-r * 0.12, -r * 0.10), r * 0.77, core)
		canvas.draw_circle(droplet + Vector2(r * 0.43, -r * 0.27), r * 0.34, core)
		if symbols:
			canvas.draw_arc(droplet + Vector2(0, -r * 1.68), 8.0, 0.0, TAU, 8, PinPanPalette.UI, 1.5)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Нить между героями: провисает в покое, натягивается и светлеет с tension.
static func thread(canvas: CanvasItem, a: Vector2, b: Vector2, amount: float, color: Color, flash := 0.0) -> void:
	var midpoint := (a + b) * 0.5 + Vector2(0, 54.0 * (1.0 - amount))
	var pts := PackedVector2Array()
	for i in range(17):
		var t := float(i) / 16.0
		var p := a.lerp(midpoint, t * 2.0) if t < 0.5 else midpoint.lerp(b, (t - 0.5) * 2.0)
		pts.append(p)
	var thread_color := color.lerp(Color.WHITE, flash)
	canvas.draw_polyline(pts, Color(thread_color, 0.58 + amount * 0.36), 2.0 + amount * 2.0 + flash * 1.5, true)


## Лоскут ткани: неровный многоугольник, переплетение, подшитый край.
static func cloth_patch(canvas: CanvasItem, center: Vector2, size: Vector2, color: Color, time: float, reduce_motion: bool, stitch_color: Color) -> void:
	var pts := PackedVector2Array()
	var count := 9
	for i in range(count):
		var ang := TAU * float(i) / float(count)
		var wobble := 1.0 + 0.10 * sin(float(i) * 2.7) + 0.04 * sin(time * 0.6 + float(i))
		pts.append(center + Vector2(cos(ang) * size.x * 0.5 * wobble, sin(ang) * size.y * 0.5 * wobble))
	canvas.draw_colored_polygon(pts, Color(color, 0.92))
	# тень под нижней кромкой
	var shade := PackedVector2Array(pts.slice(3, 8))
	canvas.draw_colored_polygon(shade, Color(PinPanPalette.VOID, 0.16))
	# переплетение
	for i in range(7):
		var k := (float(i) + 0.5) / 7.0
		var a := center + Vector2(-size.x * 0.42, (k - 0.5) * size.y * 0.82)
		var b := center + Vector2(size.x * 0.42, (k - 0.5) * size.y * 0.82)
		canvas.draw_line(a, b, Color(PinPanPalette.DEEP, 0.22), 1.5)
	for i in range(11):
		var k := (float(i) + 0.5) / 11.0
		var a := center + Vector2((k - 0.5) * size.x * 0.84, -size.y * 0.40)
		var b := center + Vector2((k - 0.5) * size.x * 0.84, size.y * 0.40)
		canvas.draw_line(a, b, Color(PinPanPalette.LINEN_LIGHT, 0.10), 1.2)
	# подшитый край
	for i in range(count):
		TextFX.stitch_line(canvas, pts[i], pts[(i + 1) % count], Color(stitch_color, 0.5), 2.0, 6.0, 5.0)


## Контактная тень под героем.
static func contact_shadow(canvas: CanvasItem, pos: Vector2, radius: float) -> void:
	canvas.draw_circle(pos + Vector2(0, radius * 1.05), radius * 0.9, Color(PinPanPalette.VOID, 0.30))
