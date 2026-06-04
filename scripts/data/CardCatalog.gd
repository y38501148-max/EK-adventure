extends RefCounted
class_name CardCatalog

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")
const CardMarkdownLoaderScript := preload("res://scripts/data/CardMarkdownLoader.gd")

const ENUMERATE_CARD_ID := "enumerate"

static func load_all_definitions() -> Array[Resource]:
	var cards: Array[Resource] = CardMarkdownLoaderScript.load_all_cards()
	var has_enumerate := false
	for card in cards:
		if _matches_id(card, ENUMERATE_CARD_ID):
			has_enumerate = true
			break
	if not has_enumerate:
		cards.push_front(make_fallback_enumerate())
	return cards

static func get_definition(card_id: StringName) -> Resource:
	var raw_id := str(card_id)
	for card in load_all_definitions():
		if _matches_id(card, raw_id):
			return card
	return make_fallback_enumerate()

static func make_fallback_enumerate() -> Resource:
	var card := CardDefinitionScript.new()
	card.id = &"enumerate"
	card.title = "枚举"
	card.card_type = CardDefinitionScript.CardType.ATTACK
	card.algorithm_attribute = &"模拟"
	card.cost = 1
	card.damage_percent = 100
	card.description = "对单个敌人造成100%伤害"
	return card

static func _matches_id(card: Resource, raw_id: String) -> bool:
	if card == null:
		return false
	return str(card.id) == raw_id or card.title.to_snake_case() == raw_id
