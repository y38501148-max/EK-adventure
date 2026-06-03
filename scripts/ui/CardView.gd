extends PanelContainer
class_name CardView

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")

signal card_selected(card_id: int)

@onready var title_label: Label = $Margin/Rows/TopRow/TitleLabel
@onready var cost_label: Label = $Margin/Rows/TopRow/CostLabel
@onready var type_label: Label = $Margin/Rows/TypeLabel
@onready var description_label: Label = $Margin/Rows/DescriptionLabel

var instance: Variant

func render(card: Variant) -> void:
	instance = card
	if card == null or card.definition == null:
		title_label.text = "未定义"
		cost_label.text = "-"
		type_label.text = "?"
		description_label.text = ""
		return

	title_label.text = card.definition.title
	cost_label.text = str(card.display_cost())
	type_label.text = _type_text(card.definition.card_type)
	description_label.text = card.definition.description

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if instance != null:
			card_selected.emit(instance.runtime_id)

func _type_text(card_type: int) -> String:
	match card_type:
		CardDefinitionScript.CardType.ATTACK:
			return "攻击"
		CardDefinitionScript.CardType.SKILL:
			return "技能"
		CardDefinitionScript.CardType.POWER:
			return "能力"
		CardDefinitionScript.CardType.EVENT:
			return "事件"
		_:
			return "未知"
