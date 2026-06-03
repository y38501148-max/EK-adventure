extends Node

func has_save() -> bool:
	return FileAccess.file_exists(Settings.SAVE_SLOT)

func save_snapshot(snapshot: Dictionary) -> void:
	var file := FileAccess.open(Settings.SAVE_SLOT, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: %s" % Settings.SAVE_SLOT)
		return
	file.store_string(JSON.stringify(snapshot, "\t"))

func load_snapshot() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(Settings.SAVE_SLOT, FileAccess.READ)
	if file == null:
		push_error("无法读取存档: %s" % Settings.SAVE_SLOT)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

