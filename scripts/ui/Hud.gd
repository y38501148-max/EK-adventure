extends PanelContainer
class_name Hud

const GameStateScript := preload("res://scripts/game/GameState.gd")

signal end_turn_requested
signal draw_requested
signal return_to_menu_requested

@onready var hero_label: Label = $Margin/Rows/TopRow/HeroLabel
@onready var phase_label: Label = $Margin/Rows/TopRow/PhaseLabel
@onready var stats_label: Label = $Margin/Rows/TopRow/StatsLabel
@onready var piles_label: Label = $Margin/Rows/BottomRow/PilesLabel

func render(state: Variant) -> void:
	hero_label.text = "%s  |  回合 %d" % [Settings.HERO_NAME, state.turn]
	phase_label.text = "阶段：%s" % _phase_text(state.phase)
	stats_label.text = "生命 %d  能量 %d/%d" % [state.player_health, state.player_energy, state.max_energy]
	piles_label.text = "抽牌堆 %d  手牌 %d  弃牌堆 %d  消耗 %d" % [
		state.draw_pile.size(),
		state.hand.size(),
		state.discard_pile.size(),
		state.exhaust_pile.size()
	]

func _on_draw_button_pressed() -> void:
	draw_requested.emit()

func _on_end_turn_button_pressed() -> void:
	end_turn_requested.emit()

func _on_menu_button_pressed() -> void:
	return_to_menu_requested.emit()

func _phase_text(phase: int) -> String:
	match phase:
		GameStateScript.Phase.SETUP:
			return "准备"
		GameStateScript.Phase.DRAW:
			return "抽牌"
		GameStateScript.Phase.MAIN:
			return "行动"
		GameStateScript.Phase.TARGETING:
			return "选择目标"
		GameStateScript.Phase.RESOLVE:
			return "结算"
		GameStateScript.Phase.END:
			return "结束"
		GameStateScript.Phase.GAME_OVER:
			return "终局"
		_:
			return "未知"
