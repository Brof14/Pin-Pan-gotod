class_name PinPanSave
extends RefCounted

const SAVE_PATH := "user://pinpan.save"
const SAVE_VERSION := 1

var version: int = SAVE_VERSION
var checksum: String = ""
var has_valid_save: bool = false
var save_corrupt: bool = false
var game_started: bool = false
var prologue_complete: bool = false
var act_one_complete: bool = false
var checkpoint: String = ""
var checkpoint_room: int = 0
var memory_nodes: int = 0
var memories: Array[int] = []
var ending_flags: int = 0

func compute_checksum(data: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in data.keys():
		parts.append(str(key) + "=" + str(data[key]))
	parts.sort()
	return str(hash(parts.join("|")))

func load() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		has_valid_save = false
		return false
	version = int(config.get_value("header", "version", 0))
	if version > SAVE_VERSION:
		save_corrupt = true
		has_valid_save = false
		return false
	game_started = bool(config.get_value("progress", "started", false))
	prologue_complete = bool(config.get_value("progress", "prologue_complete", false))
	act_one_complete = bool(config.get_value("progress", "act_one_complete", false))
	checkpoint = str(config.get_value("progress", "checkpoint", ""))
	checkpoint_room = int(config.get_value("progress", "checkpoint_room", 0))
	memory_nodes = int(config.get_value("progress", "memory_nodes", 0))
	memories.assign(config.get_value("progress", "memories", []))
	ending_flags = int(config.get_value("progress", "ending_flags", 0))
	var stored_checksum := str(config.get_value("header", "checksum", ""))
	var verify := {
		"started": game_started,
		"prologue_complete": prologue_complete,
		"checkpoint": checkpoint,
		"checkpoint_room": checkpoint_room,
	}
	checksum = compute_checksum(verify)
	if stored_checksum != "" and stored_checksum != checksum:
		save_corrupt = true
		has_valid_save = false
		return false
	has_valid_save = game_started and prologue_complete and checkpoint != ""
	save_corrupt = false
	return true

func save(settings: PinPanSettings) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var verify := {
		"started": game_started,
		"prologue_complete": prologue_complete,
		"checkpoint": checkpoint,
		"checkpoint_room": checkpoint_room,
	}
	checksum = compute_checksum(verify)
	config.set_value("header", "version", SAVE_VERSION)
	config.set_value("header", "checksum", checksum)
	config.set_value("progress", "started", game_started)
	config.set_value("progress", "prologue_complete", prologue_complete)
	config.set_value("progress", "act_one_complete", act_one_complete)
	config.set_value("progress", "checkpoint", checkpoint)
	config.set_value("progress", "checkpoint_room", checkpoint_room)
	config.set_value("progress", "memory_nodes", memory_nodes)
	config.set_value("progress", "memories", memories)
	config.set_value("progress", "ending_flags", ending_flags)
	settings.save_to(config)
	config.save(SAVE_PATH)
	has_valid_save = game_started and prologue_complete and checkpoint != ""

func can_continue() -> bool:
	return has_valid_save and not save_corrupt

func mark_new_game() -> void:
	game_started = true
	prologue_complete = false
	act_one_complete = false
	checkpoint = ""
	checkpoint_room = 0
	memory_nodes = 0
	memories.clear()
	ending_flags = 0

func mark_prologue_done() -> void:
	prologue_complete = true
	checkpoint = "ACT1_START"
	checkpoint_room = 0
