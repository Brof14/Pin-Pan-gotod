class_name PinPanSettings
extends RefCounted
## Модель настроек. Хранится отдельно от прогресса: user://settings.cfg.
## Каждое изменение применяется сразу (шины аудио, физика нити) и сохраняется на диск.

const SETTINGS_PATH := "user://settings.cfg"
const PRESET_NAMES: Array[String] = ["BASE", "PROTANOPIA", "DEUTERANOPIA", "TRITANOPIA"]

var master := 90
var music := 80
var sfx := 85
var ambience := 60
var thread_tension := 50 # 0 — нить свободная, 100 — тугая
var brightness := 100 # 50–150
var screen_shake := 100 # 0–100
var color_preset := "BASE"
var symbols := false # у ролей появляется форма-маркер
var reduce_motion := false
var reduced_flash := false
var high_contrast := false


func apply_audio_buses() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	_set_bus("Ambience", ambience)


func _set_bus(bus: String, value: int) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, value / 100.0)))
	AudioServer.set_bus_mute(idx, value <= 0)


## Пара (покой, предел) длины нити в пикселях: «НАТЯЖЕНИЕ НИТИ» реально меняет физику.
func thread_limits() -> Vector2:
	var k := thread_tension / 100.0
	return Vector2(lerpf(300.0, 215.0, k), lerpf(505.0, 385.0, k))


func shake_scale() -> float:
	return screen_shake / 100.0


func brightness_tint() -> Color:
	if brightness >= 100:
		return Color(1.0, 0.95, 0.82) # тёплый подъём яркости
	return Color(0.0, 0.0, 0.0) # затемнение


func brightness_alpha() -> float:
	return absf(float(brightness) - 100.0) / 100.0 * 0.25


static func load() -> PinPanSettings:
	var s := PinPanSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return s
	s.master = cfg.get_value("audio", "master", s.master)
	s.music = cfg.get_value("audio", "music", s.music)
	s.sfx = cfg.get_value("audio", "sfx", s.sfx)
	s.ambience = cfg.get_value("audio", "ambience", s.ambience)
	s.thread_tension = cfg.get_value("gameplay", "thread_tension", s.thread_tension)
	s.brightness = cfg.get_value("video", "brightness", s.brightness)
	s.screen_shake = cfg.get_value("video", "screen_shake", s.screen_shake)
	s.color_preset = cfg.get_value("access", "color_preset", s.color_preset)
	s.symbols = cfg.get_value("access", "symbols", s.symbols)
	s.reduce_motion = cfg.get_value("access", "reduce_motion", s.reduce_motion)
	s.reduced_flash = cfg.get_value("access", "reduced_flash", s.reduced_flash)
	s.high_contrast = cfg.get_value("access", "high_contrast", s.high_contrast)
	if not PRESET_NAMES.has(s.color_preset):
		s.color_preset = "BASE"
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "ambience", ambience)
	cfg.set_value("gameplay", "thread_tension", thread_tension)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("access", "color_preset", color_preset)
	cfg.set_value("access", "symbols", symbols)
	cfg.set_value("access", "reduce_motion", reduce_motion)
	cfg.set_value("access", "reduced_flash", reduced_flash)
	cfg.set_value("access", "high_contrast", high_contrast)
	cfg.save(SETTINGS_PATH)
