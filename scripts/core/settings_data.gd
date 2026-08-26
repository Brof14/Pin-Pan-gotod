class_name PinPanSettings
extends RefCounted

var master: int = 80
var music: int = 80
var sfx: int = 80
var ambience: int = 70
var thread_tension: int = 65
var screen_shake: int = 100
var brightness: int = 100
var ui_scale: int = 100
var vibration: int = 80
var color_preset: String = "BASE"
var symbols: bool = false
var high_contrast: bool = false
var reduce_motion: bool = false
var reduced_flash: bool = false

const PRESET_NAMES: Array[String] = ["BASE", "PROTANOPIA", "DEUTERANOPIA", "TRITANOPIA"]

func load_from(config: ConfigFile) -> void:
	master = clampi(int(config.get_value("settings", "master", 80)), 0, 100)
	music = clampi(int(config.get_value("settings", "music", 80)), 0, 100)
	sfx = clampi(int(config.get_value("settings", "sfx", 80)), 0, 100)
	ambience = clampi(int(config.get_value("settings", "ambience", 70)), 0, 100)
	thread_tension = clampi(int(config.get_value("settings", "thread", 65)), 0, 100)
	screen_shake = clampi(int(config.get_value("settings", "screen_shake", 100)), 0, 100)
	brightness = clampi(int(config.get_value("settings", "brightness", 100)), 50, 150)
	ui_scale = clampi(int(config.get_value("settings", "ui_scale", 100)), 100, 200)
	vibration = clampi(int(config.get_value("settings", "vibration", 80)), 0, 100)
	color_preset = str(config.get_value("settings", "color_preset", "BASE"))
	if color_preset not in PRESET_NAMES:
		color_preset = "BASE"
	symbols = bool(config.get_value("settings", "symbols", false))
	high_contrast = bool(config.get_value("settings", "contrast", false))
	reduce_motion = bool(config.get_value("settings", "motion", false))
	reduced_flash = bool(config.get_value("settings", "reduced_flash", false))

func save_to(config: ConfigFile) -> void:
	config.set_value("settings", "master", master)
	config.set_value("settings", "music", music)
	config.set_value("settings", "sfx", sfx)
	config.set_value("settings", "ambience", ambience)
	config.set_value("settings", "thread", thread_tension)
	config.set_value("settings", "screen_shake", screen_shake)
	config.set_value("settings", "brightness", brightness)
	config.set_value("settings", "ui_scale", ui_scale)
	config.set_value("settings", "vibration", vibration)
	config.set_value("settings", "color_preset", color_preset)
	config.set_value("settings", "symbols", symbols)
	config.set_value("settings", "contrast", high_contrast)
	config.set_value("settings", "motion", reduce_motion)
	config.set_value("settings", "reduced_flash", reduced_flash)

func apply_audio_buses() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.001, float(master) / 100.0)))
	for bus_name in ["Music", "SFX", "Ambience"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var vol: int = master
		match bus_name:
			"Music": vol = music
			"SFX": vol = sfx
			"Ambience": vol = ambience
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, float(vol) / 100.0 * float(master) / 100.0)))

func brightness_tint() -> Color:
	var b := float(brightness) / 100.0
	return Color(b, b, b, 1.0)
