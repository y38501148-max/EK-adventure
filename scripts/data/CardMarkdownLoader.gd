extends RefCounted
class_name CardMarkdownLoader

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")

const CARD_DIR := "res://cards-md"

static func load_all_cards() -> Array[Resource]:
	var cards: Array[Resource] = []
	var directory := DirAccess.open(CARD_DIR)
	if directory == null:
		return cards

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".md"):
			cards.append_array(_load_cards_from_file("%s/%s" % [CARD_DIR, file_name]))
		file_name = directory.get_next()
	directory.list_dir_end()
	return cards

static func _load_cards_from_file(path: String) -> Array[Resource]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []

	var cards: Array[Resource] = []
	var current: Resource = null
	var reading_effect := false
	var effect_lines: Array[String] = []

	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("## "):
			if current != null:
				_apply_effect_text(current, effect_lines)
				cards.append(current)
			current = CardDefinitionScript.new()
			current.title = _parse_title(line)
			current.id = StringName(current.title.to_snake_case())
			reading_effect = false
			effect_lines = []
		elif current != null and line.begins_with("费用："):
			current.cost = int(line.trim_prefix("费用：").strip_edges())
		elif current != null and line.begins_with("属性："):
			current.algorithm_attribute = StringName(line.trim_prefix("属性：").strip_edges())
		elif current != null and line.begins_with("类型："):
			current.card_type = _parse_card_type(line.trim_prefix("类型：").strip_edges())
		elif current != null and line.begins_with("标签："):
			current.tags = _parse_tags(line.trim_prefix("标签：").strip_edges())
		elif current != null and line.begins_with("效果："):
			reading_effect = true
			var inline_effect := line.trim_prefix("效果：").strip_edges()
			if inline_effect != "":
				effect_lines.append(inline_effect)
		elif current != null and reading_effect and line != "":
			effect_lines.append(line)

	if current != null:
		_apply_effect_text(current, effect_lines)
		cards.append(current)

	return cards

static func _parse_title(line: String) -> String:
	var title := line.trim_prefix("## ").strip_edges()
	var dot_index := title.find(".")
	if dot_index >= 0:
		title = title.substr(dot_index + 1).strip_edges()
	return title

static func _parse_card_type(raw_type: String) -> int:
	match raw_type:
		"攻击":
			return CardDefinitionScript.CardType.ATTACK
		"格挡", "护盾":
			return CardDefinitionScript.CardType.BLOCK
		"技能":
			return CardDefinitionScript.CardType.SKILL
		"能力":
			return CardDefinitionScript.CardType.POWER
		"事件":
			return CardDefinitionScript.CardType.EVENT
		_:
			return CardDefinitionScript.CardType.SKILL

static func _parse_tags(raw_tags: String) -> Array[StringName]:
	var tags: Array[StringName] = []
	var normalized := raw_tags.replace("，", ",").replace("、", ",")
	for raw_tag in normalized.split(","):
		var tag := raw_tag.strip_edges()
		if tag != "":
			tags.append(StringName(tag))
	return tags

static func _apply_effect_text(card: Resource, effect_lines: Array[String]) -> void:
	if effect_lines.is_empty():
		card.description = _default_description(card)
	else:
		card.description = "\n".join(effect_lines)
	_apply_numeric_effects(card, card.description)

static func _apply_numeric_effects(card: Resource, effect_text: String) -> void:
	var percent_index := effect_text.find("%伤害")
	if card.card_type == CardDefinitionScript.CardType.ATTACK and percent_index > 0:
		var start := percent_index - 1
		while start >= 0 and effect_text.substr(start, 1).is_valid_int():
			start -= 1
		var raw_percent := effect_text.substr(start + 1, percent_index - start - 1)
		if raw_percent.is_valid_int():
			card.damage_percent = int(raw_percent)

static func _default_description(card: Resource) -> String:
	match card.card_type:
		CardDefinitionScript.CardType.ATTACK:
			return "造成基础攻击力伤害。若命中怪物弱点算法属性，伤害翻倍。"
		CardDefinitionScript.CardType.BLOCK:
			return "获得基础护盾。"
		_:
			return "效果待补充。"
