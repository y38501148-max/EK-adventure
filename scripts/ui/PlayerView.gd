extends PanelContainer
class_name PlayerView

@onready var name_label: Label = $Margin/Rows/NameLabel
@onready var hp_label: Label = $Margin/Rows/HpLabel
@onready var status_label: Label = $Margin/Rows/StatusLabel

func render(state: Variant) -> void:
	name_label.text = Settings.HERO_NAME
	hp_label.text = "HP %d/%d  护盾 %d" % [
		state.player_health,
		state.player_max_health,
		state.player_block
	]
	status_label.text = "骗分状态" if state.is_cheating else "准备解题"

