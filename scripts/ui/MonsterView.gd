extends Control
class_name MonsterView

signal card_dropped_on_enemy(card_id: int, enemy_id: int)

@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HpLabel
@onready var attribute_label: Label = $AttributeLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var intent_label: Label = $IntentLabel
@onready var description_label: Label = $DescriptionLabel
@onready var action_badge: Panel = $ActionBadge
@onready var action_badge_label: Label = $ActionBadge/ActionBadgeLabel
@onready var action_type_label: Label = $ActionTypeLabel

var enemy_id: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_action_badge_style()

func render(state: Variant) -> void:
	name_label.text = state.enemy_name
	hp_label.text = "%d/%d" % [state.enemy_health, state.enemy_max_health]
	attribute_label.text = "算法属性：%s" % state.enemy_algorithm_attribute
	action_badge_label.text = str(state.enemy_action_countdown)
	action_type_label.text = str(state.enemy_action_name)
	countdown_label.text = ""
	intent_label.text = ""
	description_label.text = state.enemy_description

func _apply_action_badge_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.47, 0.18, 0.94)
	style.border_color = Color(1.0, 0.82, 0.42, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	action_badge.add_theme_stylebox_override("panel", style)
	action_badge_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	action_type_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.95, 1.0))

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
