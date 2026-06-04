extends Control
class_name PlayerView

@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HpLabel
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	_apply_status_tag_style()

func render(state: Variant) -> void:
	name_label.text = Settings.HERO_NAME
	hp_label.text = "HP %d/%d  护盾 %d" % [
		state.player_health,
		state.player_max_health,
		state.player_block
	]
	status_label.text = "骗分状态" if state.is_cheating else "准备解题"

func _apply_status_tag_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.36, 0.35, 0.88)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	status_label.add_theme_stylebox_override("normal", style)
	status_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.94, 1.0))
