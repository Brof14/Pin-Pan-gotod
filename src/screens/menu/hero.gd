class_name MenuHero
extends Node2D
## Герои в меню: Pin и Pan на лоскуте ткани справа.
## Живут по idle-циклу MenuSystem: противофазное свечение, наклон Pan,
## дыхание нити, а после 45 сек бездействия Pan дёргает нить и оба поворачиваются.

var _menu: MenuSystem
var _time := 0.0


func setup(menu: MenuSystem) -> void:
	_menu = menu


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _menu == null:
		return
	var settings := PinPanCore.I.settings
	var colors := PinPanPalette.role_pair(settings.color_preset)
	var idle := _menu.idle_phase()
	var reduce_motion := settings.reduce_motion
	var bob := 0.0 if reduce_motion else sin(_time * 0.8) * 4.0

	# тень под лоскутом
	draw_circle(Vector2(1430, 690), 240.0, Color(PinPanPalette.VOID, 0.35))
	Actors.cloth_patch(self, Vector2(1430, 640 + bob), Vector2(590, 310), PinPanPalette.LINEN, _time, reduce_motion, PinPanPalette.FOCUS)

	var tug := float(idle["tug_t"])
	var spin := float(idle["spin"])
	var pin_pos := Vector2(1300, 556 + bob * 0.6)
	var pan_pos := Vector2(1572, 545 + bob * 0.85)
	# Pan дёргает нить: откидывается назад, нить распрямляется
	pan_pos += Vector2(20.0, 7.0) * tug

	Actors.thread(self, pin_pos + Vector2(30, 6), pan_pos + Vector2(-28, 8),
		0.16 + float(idle["thread_tension"]) + tug * 0.55, PinPanPalette.WARM)
	Actors.contact_shadow(self, pin_pos + Vector2(6, 44), 34.0)
	Actors.contact_shadow(self, pan_pos + Vector2(4, 42), 32.0)
	Actors.character(self, pin_pos, true, 1.5, 0.0, colors, settings.symbols, settings.high_contrast,
		float(idle["pin_brightness"]), spin, 1.0 + (0.0 if reduce_motion else sin(_time * 1.6) * 0.015))
	Actors.character(self, pan_pos, false, 1.42, float(idle["pan_tilt"]), colors, settings.symbols, settings.high_contrast,
		float(idle["pan_brightness"]), spin, 1.0 + (0.0 if reduce_motion else sin(_time * 1.9 + 1.2) * 0.02))
