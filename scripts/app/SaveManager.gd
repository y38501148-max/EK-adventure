extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

func save_snapshot(slot: int, snapshot: Dictionary) -> void:
	_ensure_save_dir()
	var envelope := {
		"version": 1,
		"slot": clampi(slot, 1, SLOT_COUNT),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"state": snapshot
	}
	var file := FileAccess.open(get_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: %s" % get_slot_path(slot))
		return
	file.store_string(JSON.stringify(envelope, "\t"))

func load_snapshot(slot: int = 1) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(get_slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("无法读取存档: %s" % get_slot_path(slot))
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func get_slot_summary(slot: int) -> Dictionary:
	var envelope := load_snapshot(slot)
	if envelope.is_empty():
		return {
			"slot": slot,
			"has_save": false,
			"title": "空档位",
			"detail": "无存档"
		}

	var state: Dictionary = envelope.get("state", {})
	return {
		"slot": slot,
		"has_save": true,
		"title": "档位 %d  等级 %d  金钱 %d" % [
			slot,
			int(state.get("level", 1)),
			int(state.get("gold", 0))
		],
		"detail": "%s  生命 %d/%d  %s" % [
			str(envelope.get("saved_at_text", "")),
			int(state.get("player_health", 0)),
			int(state.get("player_max_health", 0)),
			str(state.get("enemy_name", ""))
		]
	}

func get_slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot, 1, SLOT_COUNT)]

func _ensure_save_dir() -> void:
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	if not user_dir.dir_exists("saves"):
		user_dir.make_dir_recursive("saves")
