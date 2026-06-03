extends Control
class_name GameRoot

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")
const CardMarkdownLoaderScript := preload("res://scripts/data/CardMarkdownLoader.gd")
const GameStateScript := preload("res://scripts/game/GameState.gd")
const MonsterMarkdownLoaderScript := preload("res://scripts/data/MonsterMarkdownLoader.gd")
const RunConfigScript := preload("res://scripts/data/RunConfig.gd")

signal return_to_menu_requested

@onready var hud := $Root/Hud
@onready var player_view := $Root/EncounterArea/EncounterMargin/Battlefield/PlayerView
@onready var monster_view := $Root/EncounterArea/EncounterMargin/Battlefield/MonsterView
@onready var hand_view := $Root/HandPanel/HandMargin/HandView
@onready var log_label: Label = $Root/LogLabel

var state := GameStateScript.new()
var save_slot: int = 1
var pending_snapshot: Dictionary = {}
var autosave_enabled: bool = false

func configure(slot: int, snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	pending_snapshot = snapshot

func _ready() -> void:
	state.state_changed.connect(_on_state_changed)
	state.phase_changed.connect(_on_phase_changed)
	hud.draw_requested.connect(_on_draw_requested)
	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.return_to_menu_requested.connect(_on_return_to_menu_requested)
	hand_view.card_selected.connect(_on_card_selected)

	state.setup(_build_placeholder_config())
	if pending_snapshot.is_empty():
		state.begin_turn()
	else:
		state.apply_snapshot(pending_snapshot)
	autosave_enabled = true
	_on_state_changed()

func _on_state_changed() -> void:
	hud.render(state)
	player_view.render(state)
	monster_view.render(state)
	hand_view.render(state.hand, state)
	if autosave_enabled:
		SaveManager.save_snapshot(save_slot, state.to_snapshot())

func _on_phase_changed(_phase: int) -> void:
	pass

func _on_draw_requested() -> void:
	state.draw_cards(1)
	_append_log("调试抽牌：补 1 张占位卡。")
	_on_state_changed()

func _on_end_turn_requested() -> void:
	state.end_turn()
	_append_log(state.last_event_log)
	if not state.has_lost and not state.has_won:
		state.begin_turn()

func _on_card_selected(card_id: int) -> void:
	if state.play_card(card_id):
		_append_log(state.last_event_log)
	else:
		_append_log("现在还不能打出卡牌 #%d。" % card_id)

func _on_return_to_menu_requested() -> void:
	return_to_menu_requested.emit()

func _append_log(message: String) -> void:
	log_label.text = message

func _build_placeholder_config() -> Resource:
	var config := RunConfigScript.new()
	config.hero_name = Settings.HERO_NAME
	config.seed = int(Time.get_unix_time_from_system())
	config.starting_health = 50
	config.starting_energy = 4
	config.base_attack = 15
	config.base_block = 10
	var monster := MonsterMarkdownLoaderScript.load_first_monster()
	config.enemy_name = monster.title
	config.enemy_health = monster.max_health
	config.enemy_algorithm_attribute = monster.algorithm_attribute
	config.enemy_action_countdown = monster.action_countdown
	config.enemy_attack = monster.attack
	config.enemy_actions = monster.actions
	config.enemy_description = monster.description
	config.starting_deck = _build_markdown_deck()
	return config

func _build_markdown_deck() -> Array[Resource]:
	var cards: Array[Resource] = CardMarkdownLoaderScript.load_all_cards()
	if cards.is_empty():
		return [_make_fallback_card()]
	if cards.size() == 1:
		return [cards[0], cards[0], cards[0], cards[0], cards[0]]
	return cards

func _make_fallback_card() -> Resource:
	var card := CardDefinitionScript.new()
	card.id = &"enumerate"
	card.title = "枚举"
	card.card_type = CardDefinitionScript.CardType.ATTACK
	card.algorithm_attribute = &"模拟"
	card.cost = 1
	card.damage_percent = 100
	card.description = "对单个敌人造成100%伤害"
	return card
