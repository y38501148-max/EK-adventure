extends PanelContainer
class_name CardView

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")

signal card_selected(card_id: int)

@onready var title_label: Label = $Margin/Rows/TopRow/TitleLabel
@onready var cost_label: Label = $Margin/Rows/TopRow/CostLabel
@onready var type_label: Label = $Margin/Rows/TypeLabel
@onready var description_label: Label = $Margin/Rows/DescriptionLabel

var instance: Variant

func render(card: Variant, state: Variant = null) -> void:
	instance = card
	if card == null or card.definition == null:
		title_label.text = "未定义"
		cost_label.text = "-"
		type_label.text = "?"
		description_label.text = ""
		return

	title_label.text = card.definition.title
	cost_label.text = str(state.effective_card_cost(card) if state != null else card.display_cost())
	type_label.text = _type_text(card.definition.card_type, card.definition.algorithm_attribute)
	description_label.text = card.definition.description

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if instance != null:
			card_selected.emit(instance.runtime_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if instance == null:
		return null

	set_drag_preview(_build_drag_preview())
	return {
		"kind": "card",
		"card_id": instance.runtime_id
	}

func _build_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(150, 64)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	preview.add_child(margin)

	var label := Label.new()
	label.text = instance.definition.title if instance != null and instance.definition != null else "卡牌"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)
	return preview

func _type_text(card_type: int, algorithm_attribute: StringName) -> String:
	var base_type := ""
	match card_type:
		CardDefinitionScript.CardType.ATTACK:
			base_type = "攻击"
		CardDefinitionScript.CardType.BLOCK:
			base_type = "格挡"
		CardDefinitionScript.CardType.SKILL:
			base_type = "技能"
		CardDefinitionScript.CardType.POWER:
			base_type = "能力"
		CardDefinitionScript.CardType.EVENT:
			base_type = "事件"
		_:
			base_type = "未知"
	if algorithm_attribute == &"":
		return base_type
	return "%s / %s" % [base_type, algorithm_attribute]
