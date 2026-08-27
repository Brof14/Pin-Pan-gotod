class_name PinPanCore
extends Node
## Ядро PIN&PAN: настройки, сохранения, аудио-хозяйство.
## Автозагрузка «PinPan». Код обращается через PinPanCore.I — это работает
## и в обычном запуске, и в headless-тестах (там autoload не регистрируется
## как глобальный идентификатор, но узел в дереве есть).

static var I: PinPanCore = null

var settings: PinPanSettings
var save: PinPanSave
var sfx: PinPanSfx
var ui: PinPanUIAudio

var _ambience: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _wind_level := 0.0
var _wind_target := 0.0
var _duck_hold := 0.0
var _flash_mute := 0.0


func _ready() -> void:
	I = self
	settings = PinPanSettings.load()
	save = PinPanSave.load()
	settings.apply_audio_buses()
	sfx = PinPanSfx.new()
	sfx.setup(self)
	ui = PinPanUIAudio.new()
	ui.setup(self, duck)
	# Фоновые петли строим после первого кадра, чтобы старт не спотыкался.
	call_deferred("_start_beds")


func _start_beds() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	_ambience.stream = Synth.pad_loop()
	add_child(_ambience)
	_ambience.play()
	_wind = AudioStreamPlayer.new()
	_wind.bus = &"Ambience"
	_wind.stream = Synth.wind_loop()
	_wind.volume_db = -60.0
	add_child(_wind)
	_wind.play()


func _process(delta: float) -> void:
	if _ambience == null:
		return
	if _duck_hold > 0.0:
		_duck_hold = maxf(0.0, _duck_hold - delta)
	if _flash_mute > 0.0:
		_flash_mute = maxf(0.0, _flash_mute - delta)
	var duck_db := -4.0 if _duck_hold > 0.0 else 0.0
	var base := linear_to_db(maxf(0.0001, settings.ambience / 100.0))
	if settings.ambience <= 0:
		base = -80.0
	_ambience.volume_db = base + duck_db if _flash_mute <= 0.0 else -80.0
	_wind_level = move_toward(_wind_level, _wind_target, delta * 0.6)
	var wind_db := linear_to_db(maxf(0.0001, _wind_level)) if _wind_level > 0.001 else -80.0
	_wind.volume_db = wind_db if _flash_mute <= 0.0 else -80.0


## Приглушение фона на 4 дБ при UI-событии, релиз ~300 мс.
func duck() -> void:
	_duck_hold = 0.3


## Тишина на мгновение (белая вспышка Пролога).
func flash_mute(duration := 0.5) -> void:
	_flash_mute = duration


func set_wind(level: float) -> void:
	_wind_target = clampf(level, 0.0, 1.0)


func save_settings() -> void:
	settings.apply_audio_buses()
	settings.save()
