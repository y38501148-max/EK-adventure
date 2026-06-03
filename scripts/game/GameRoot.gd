extends Control
class_name GameRoot

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")
const GameStateScript := preload("res://scripts/game/GameState.gd")
const RunConfigScript := preload("res://scripts/data/RunConfig.gd")

signal return_to_menu_requested

@onready var hud := $Root/Hud
@onready var hand_view := $Root/HandPanel/HandMargin/HandView
@onready var log_label: Label = $Root/LogLabel

var state := GameStateScript.new()

func _ready() -> void:
	state.state_changed.connect(_render)
	state.phase_changed.connect(_on_phase_changed)
	hud.draw_requested.connect(_on_draw_requested)
	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.return_to_menu_requested.connect(_on_return_to_menu_requested)
	hand_view.card_selected.connect(_on_card_selected)

	state.setup(_build_placeholder_config())
	state.begin_turn()

func _render() -> void:
	hud.render(state)
	hand_view.render(state.hand)

func _on_phase_changed(_phase: int) -> void:
	pass

func _on_draw_requested() -> void:
	state.draw_cards(1)
	_append_log("调试抽牌：补 1 张占位卡。")
	_render()

func _on_end_turn_requested() -> void:
	state.end_turn()
	_append_log("回合结束，手牌进入弃牌堆。")
	state.begin_turn()

func _on_card_selected(card_id: int) -> void:
	if state.play_card(card_id):
		_append_log("打出卡牌 #%d。" % card_id)
	else:
		_append_log("现在还不能打出卡牌 #%d。" % card_id)
	_render()

func _on_return_to_menu_requested() -> void:
	return_to_menu_requested.emit()

func _append_log(message: String) -> void:
	log_label.text = message

func _build_placeholder_config() -> Resource:
	var config := RunConfigScript.new()
	config.hero_name = Settings.HERO_NAME
	config.seed = int(Time.get_unix_time_from_system())
	config.starting_health = 80
	config.starting_energy = 3
	config.starting_deck = [
		_make_card(&"array_slash", "数组切片", CardDefinitionScript.CardType.ATTACK, 1, "造成基础伤害。后续会接入真实效果。"),
		_make_card(&"dp_guard", "DP 转移", CardDefinitionScript.CardType.SKILL, 1, "获得基础防御。后续会接入真实效果。"),
		_make_card(&"wa_debug", "WA 调试", CardDefinitionScript.CardType.SKILL, 0, "检视下一步行动。后续会接入真实效果。"),
		_make_card(&"icpc_balloon", "罚时气球", CardDefinitionScript.CardType.POWER, 2, "建立长期优势。后续会接入真实效果。"),
		_make_card(&"segment_tree", "线段树展开", CardDefinitionScript.CardType.ATTACK, 2, "面向复杂局面。后续会接入真实效果。")
	]
	return config

func _make_card(id: StringName, title: String, card_type: int, cost: int, description: String) -> Resource:
	var card := CardDefinitionScript.new()
	card.id = id
	card.title = title
	card.card_type = card_type
	card.cost = cost
	card.description = description
	return card
