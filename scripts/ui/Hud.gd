extends Control
class_name Hud

const GameStateScript := preload("res://scripts/game/GameState.gd")

signal end_turn_requested
signal draw_requested
signal return_to_menu_requested

@onready var hero_label: Label = $HeroLabel
@onready var phase_label: Label = $PhaseLabel
@onready var stats_label: Label = $StatsLabel
@onready var enemy_label: Label = $EnemyLabel
@onready var piles_label: Label = $PilesLabel
@onready var draw_pile_label: Label = $DrawPileLabel
@onready var end_turn_button: Button = $EndTurnButton

func _ready() -> void:
	_apply_end_turn_button_style()

func render(state: Variant) -> void:
	hero_label.text = Settings.HERO_NAME
	phase_label.text = "%s，回合 %d" % [_phase_text(state.phase), state.turn]
	var cheat_text := "  骗分中" if state.is_cheating else ""
	stats_label.text = "费用 %d/%d%s" % [
		state.player_energy,
		state.max_energy,
		cheat_text
	]
	enemy_label.text = ""
	var drawable_count: int = state.get_drawable_card_count()
	draw_pile_label.text = "抽牌区\n%d 张" % drawable_count
	piles_label.text = "抽牌区 %d  手牌 %d/%d  弃牌 %d  消耗 %d" % [
		drawable_count,
		state.hand.size(),
		state.hand_limit,
		state.discard_pile.size(),
		state.exhaust_pile.size()
	]

func _on_draw_button_pressed() -> void:
	draw_requested.emit()

func _on_end_turn_button_pressed() -> void:
	end_turn_requested.emit()

func _on_menu_button_pressed() -> void:
	return_to_menu_requested.emit()

func _apply_end_turn_button_style() -> void:
	end_turn_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.15, 0.42, 0.48, 0.96)))
	end_turn_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.20, 0.54, 0.60, 1.0)))
	end_turn_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.10, 0.31, 0.36, 1.0)))
	end_turn_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.10, 0.14, 0.16, 0.78)))
	end_turn_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	end_turn_button.add_theme_color_override("font_color", Color(0.93, 1.0, 1.0, 1.0))
	end_turn_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	end_turn_button.add_theme_color_override("font_pressed_color", Color(0.88, 1.0, 1.0, 1.0))

func _make_button_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style

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
