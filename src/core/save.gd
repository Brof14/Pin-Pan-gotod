class_name PinPanSave
extends RefCounted
## Прогресс игрока: user://savegame.cfg.
## Схема ключей из production-документа: checkpoint, memoryNodes, endingFlags.

const SAVE_PATH := "user://savegame.cfg"

var game_started := false
var prologue_done := false
var act_one_complete := false
var checkpoint := "PROLOGUE"
var checkpoint_room := 0
var memory_nodes := 0
var memories: Array[int] = []
var ending_flags := {}


func mark_new_game() -> void:
	game_started = true
	prologue_done = false
	act_one_complete = false
	checkpoint = "PROLOGUE"
	checkpoint_room = 0
	memory_nodes = 0
	memories.clear()
	ending_flags.clear()
	save()


func mark_prologue_done() -> void:
	prologue_done = true
	checkpoint = "ACT1_ROOM_0"
	checkpoint_room = 0
	save()


func set_checkpoint(room: int) -> void:
	checkpoint = "ACT1_ROOM_%d" % room
	checkpoint_room = room
	save()


func can_continue() -> bool:
	return game_started


## -1 — сохранение указывает на Пролог, иначе номер комнаты Акта I.
func continue_room() -> int:
	if not prologue_done:
		return -1
	return checkpoint_room


static func load() -> PinPanSave:
	var s := PinPanSave.new()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return s
	s.game_started = cfg.get_value("progress", "game_started", false)
	s.prologue_done = cfg.get_value("progress", "prologue_done", false)
	s.act_one_complete = cfg.get_value("progress", "act_one_complete", false)
	s.checkpoint = cfg.get_value("progress", "checkpoint", "PROLOGUE")
	s.checkpoint_room = cfg.get_value("progress", "checkpoint_room", 0)
	s.memory_nodes = cfg.get_value("memoryNodes", "count", 0)
	var raw_memories: Array = cfg.get_value("memoryNodes", "list", [])
	s.memories.clear()
	for m in raw_memories:
		s.memories.append(int(m))
	var raw_flags: Dictionary = cfg.get_value("endingFlags", "flags", {})
	s.ending_flags = raw_flags.duplicate()
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "game_started", game_started)
	cfg.set_value("progress", "prologue_done", prologue_done)
	cfg.set_value("progress", "act_one_complete", act_one_complete)
	cfg.set_value("progress", "checkpoint", checkpoint)
	cfg.set_value("progress", "checkpoint_room", checkpoint_room)
	cfg.set_value("memoryNodes", "count", memory_nodes)
	cfg.set_value("memoryNodes", "list", memories)
	cfg.set_value("endingFlags", "flags", ending_flags)
	cfg.save(SAVE_PATH)
