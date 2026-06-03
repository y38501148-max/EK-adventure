extends PanelContainer
class_name MonsterView

@onready var name_label: Label = $Margin/Rows/Header/NameLabel
@onready var hp_label: Label = $Margin/Rows/Header/HpLabel
@onready var attribute_label: Label = $Margin/Rows/Body/InfoColumn/AttributeLabel
@onready var countdown_label: Label = $Margin/Rows/Body/InfoColumn/CountdownLabel
@onready var intent_label: Label = $Margin/Rows/Body/InfoColumn/IntentLabel
@onready var description_label: Label = $Margin/Rows/DescriptionLabel

func render(state: Variant) -> void:
	name_label.text = state.enemy_name
	hp_label.text = "%d/%d" % [state.enemy_health, state.enemy_max_health]
	attribute_label.text = "算法属性：%s" % state.enemy_algorithm_attribute
	countdown_label.text = "行动倒计时：%d" % state.enemy_action_countdown
	intent_label.text = "意图：%s  攻击 %d  %s" % [
		state.enemy_action_name,
		state.enemy_attack,
		"已行动" if state.enemy_acted_this_turn else "待行动"
	]
	description_label.text = state.enemy_description
