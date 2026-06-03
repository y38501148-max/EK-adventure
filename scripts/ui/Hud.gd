extends PanelContainer
class_name Hud

const GameStateScript := preload("res://scripts/game/GameState.gd")

signal end_turn_requested
signal draw_requested
signal return_to_menu_requested

@onready var hero_label: Label = $Margin/Rows/TopRow/HeroLabel
@onready var phase_label: Label = $Margin/Rows/TopRow/PhaseLabel
@onready var stats_label: Label = $Margin/Rows/TopRow/StatsLabel
@onready var enemy_label: Label = $Margin/Rows/EnemyLabel
@onready var piles_label: Label = $Margin/Rows/BottomRow/PilesLabel

func render(state: Variant) -> void:
	hero_label.text = "%s  |  回合 %d" % [Settings.HERO_NAME, state.turn]
	phase_label.text = "阶段：%s" % _phase_text(state.phase)
	var cheat_text := "  骗分中" if state.is_cheating else ""
	stats_label.text = "生命 %d/%d  护盾 %d  费用 %d/%d%s" % [
		state.player_health,
		state.player_max_health,
		state.player_block,
		state.player_energy,
		state.max_energy,
		cheat_text
	]
	enemy_label.text = "%s  生命 %d/%d  算法属性 %s  行动倒计时 %d  本回合%s行动" % [
		state.enemy_name,
		state.enemy_health,
		state.enemy_max_health,
		state.enemy_algorithm_attribute,
		state.enemy_action_countdown,
		"已" if state.enemy_acted_this_turn else "未"
	]
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
