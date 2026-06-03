extends RefCounted
class_name MonsterMarkdownLoader

const MonsterDefinitionScript := preload("res://scripts/data/MonsterDefinition.gd")

const MONSTER_DIR := "res://monsters-md"

static func load_first_monster() -> Resource:
	var monsters := load_all_monsters()
	if monsters.is_empty():
		return default_monster()
	return monsters[0]

static func load_all_monsters() -> Array[Resource]:
	var monsters: Array[Resource] = []
	var directory := DirAccess.open(MONSTER_DIR)
	if directory == null:
		return monsters

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".md"):
			var monster := _load_monster_from_file("%s/%s" % [MONSTER_DIR, file_name])
			if monster != null:
				monsters.append(monster)
		file_name = directory.get_next()
	directory.list_dir_end()
	return monsters

static func default_monster() -> Resource:
	return MonsterDefinitionScript.new()

static func _load_monster_from_file(path: String) -> Resource:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	if text.strip_edges() == "":
		return null

	var monster := MonsterDefinitionScript.new()
	var reading_description := false
	var description_lines: Array[String] = []

	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		if line.begins_with("## "):
			monster.title = _parse_title(line)
			monster.id = StringName(monster.title.to_snake_case())
			reading_description = false
		elif line.begins_with("名字："):
			monster.title = line.trim_prefix("名字：").strip_edges()
			monster.id = StringName(monster.title.to_snake_case())
		elif line.begins_with("名称："):
			monster.title = line.trim_prefix("名称：").strip_edges()
			monster.id = StringName(monster.title.to_snake_case())
		elif line.begins_with("血量："):
			monster.max_health = int(line.trim_prefix("血量：").strip_edges())
		elif line.begins_with("生命："):
			monster.max_health = int(line.trim_prefix("生命：").strip_edges())
		elif line.begins_with("属性："):
			monster.algorithm_attribute = StringName(line.trim_prefix("属性：").strip_edges())
		elif line.begins_with("基础攻击："):
			monster.attack = int(line.trim_prefix("基础攻击：").strip_edges())
		elif line.begins_with("行动倒计时："):
			monster.action_countdown = int(line.trim_prefix("行动倒计时：").strip_edges())
		elif line.begins_with("攻击："):
			monster.attack = int(line.trim_prefix("攻击：").strip_edges())
		elif line.contains("行动值") and line.contains("%伤害"):
			monster.actions.append(_parse_action(line))
		elif line.begins_with("描述："):
			reading_description = true
			var inline_description := line.trim_prefix("描述：").strip_edges()
			if inline_description != "":
				description_lines.append(inline_description)
		elif reading_description:
			description_lines.append(line)

	if not description_lines.is_empty():
		monster.description = "\n".join(description_lines)
	if not monster.actions.is_empty():
		monster.action_countdown = int(monster.actions[0].get("countdown", monster.action_countdown))
	return monster

static func _parse_title(line: String) -> String:
	var title := line.trim_prefix("## ").strip_edges()
	var dot_index := title.find(".")
	if dot_index >= 0:
		title = title.substr(dot_index + 1).strip_edges()
	return title

static func _parse_action(line: String) -> Dictionary:
	var action_name := "普通攻击"
	var colon_index := line.find("：")
	if colon_index >= 0:
		var raw_name := line.substr(0, colon_index).strip_edges()
		var dot_index := raw_name.find(".")
		if dot_index >= 0:
			raw_name = raw_name.substr(dot_index + 1).strip_edges()
		action_name = raw_name

	return {
		"name": action_name,
		"countdown": _extract_int_after(line, "行动值", 3),
		"damage_percent": _extract_percent(line, 100)
	}

static func _extract_int_after(text: String, marker: String, fallback: int) -> int:
	var marker_index := text.find(marker)
	if marker_index < 0:
		return fallback
	var start := marker_index + marker.length()
	while start < text.length() and not text.substr(start, 1).is_valid_int():
		start += 1
	var end := start
	while end < text.length() and text.substr(end, 1).is_valid_int():
		end += 1
	var raw_value := text.substr(start, end - start)
	return int(raw_value) if raw_value.is_valid_int() else fallback

static func _extract_percent(text: String, fallback: int) -> int:
	var percent_index := text.find("%伤害")
	if percent_index <= 0:
		return fallback
	var start := percent_index - 1
	while start >= 0 and text.substr(start, 1).is_valid_int():
		start -= 1
	var raw_percent := text.substr(start + 1, percent_index - start - 1)
	return int(raw_percent) if raw_percent.is_valid_int() else fallback
