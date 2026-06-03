extends PanelContainer
class_name MonsterView

signal card_dropped_on_enemy(card_id: int, enemy_id: int)

@onready var name_label: Label = $Margin/Rows/Header/NameLabel
@onready var hp_label: Label = $Margin/Rows/Header/HpLabel
@onready var attribute_label: Label = $Margin/Rows/Body/InfoColumn/AttributeLabel
@onready var countdown_label: Label = $Margin/Rows/Body/InfoColumn/CountdownLabel
@onready var intent_label: Label = $Margin/Rows/Body/InfoColumn/IntentLabel
@onready var description_label: Label = $Margin/Rows/DescriptionLabel

var enemy_id: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

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

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var can_drop: bool = data is Dictionary and data.get("kind", "") == "card" and data.has("card_id")
	modulate = Color(1.1, 1.1, 1.1, 1.0) if can_drop else Color.WHITE
	return can_drop

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	modulate = Color.WHITE
	card_dropped_on_enemy.emit(int(data.get("card_id", -1)), enemy_id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
