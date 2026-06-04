extends Control
class_name GameRoot

const CardCatalogScript := preload("res://scripts/data/CardCatalog.gd")
const GameStateScript := preload("res://scripts/game/GameState.gd")
const MonsterMarkdownLoaderScript := preload("res://scripts/data/MonsterMarkdownLoader.gd")
const RunConfigScript := preload("res://scripts/data/RunConfig.gd")

signal return_to_menu_requested

@onready var hud := $Root/Hud
@onready var player_view := $Root/PlayerView
@onready var monster_view := $Root/MonsterView
@onready var hand_view := $Root/HandPanel/HandView
@onready var log_label: Label = $Root/LogLabel
@onready var battle_end_dialog: AcceptDialog = $BattleEndDialog

var state := GameStateScript.new()
var save_slot: int = 1
var pending_snapshot: Dictionary = {}
var pending_encounter_id: StringName = &"training_test"
var autosave_enabled: bool = false
var battle_end_shown: bool = false

func configure(slot: int, snapshot: Dictionary = {}, encounter_id: StringName = &"training_test") -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	pending_snapshot = snapshot
	pending_encounter_id = encounter_id

func _ready() -> void:
	state.state_changed.connect(_on_state_changed)
	state.phase_changed.connect(_on_phase_changed)
	hud.draw_requested.connect(_on_draw_requested)
	hud.end_turn_requested.connect(_on_end_turn_requested)
	hud.return_to_menu_requested.connect(_on_return_to_menu_requested)
	hand_view.card_selected.connect(_on_card_selected)
	hand_view.card_drag_released.connect(_on_card_drag_released)
	monster_view.card_dropped_on_enemy.connect(_on_card_dropped_on_enemy)
	battle_end_dialog.confirmed.connect(_on_battle_end_confirmed)

	if pending_encounter_id == &"resume" and not pending_snapshot.is_empty():
		state.apply_snapshot(pending_snapshot)
	else:
		state.setup(_build_placeholder_config())
		_apply_profile_from_snapshot(pending_snapshot)
		state.begin_turn()
	autosave_enabled = true
	_on_state_changed()

func _on_state_changed() -> void:
	var reward := state.claim_victory_reward()
	if reward > 0:
		state.last_event_log += " 获得 %d 金钱。" % reward
	hud.render(state)
	player_view.render(state)
	monster_view.render(state)
	hand_view.render(state.hand, state)
	if (state.has_won or state.has_lost) and not battle_end_shown:
		_show_battle_end_dialog()
	if autosave_enabled:
		SaveManager.save_snapshot(save_slot, state.to_snapshot())

func _on_phase_changed(_phase: int) -> void:
	pass

func _on_draw_requested() -> void:
	var drawn := state.draw_cards(1)
	if drawn > 0:
		_append_log("抽牌：补充 %d 张。" % drawn)
	elif state.hand.size() >= state.hand_limit:
		_append_log("手牌已达上限，无法继续抽牌。")
	else:
		_append_log("抽牌区已空，没有可抽的牌。")
	_on_state_changed()

func _on_end_turn_requested() -> void:
	state.end_turn()
	_append_log(state.last_event_log)
	if not state.has_lost and not state.has_won:
		state.begin_turn()

func _on_card_selected(card_id: int) -> void:
	if state.card_requires_target(card_id):
		_append_log("攻击牌需要拖动到敌人图片上释放。")
		return
	if state.play_card(card_id):
		_append_log(state.last_event_log)
	else:
		_append_log("现在还不能打出卡牌 #%d。" % card_id)

func _on_card_dropped_on_enemy(card_id: int, enemy_id: int) -> void:
	if state.play_card(card_id, [enemy_id]):
		_append_log(state.last_event_log)
	else:
		_append_log("现在还不能对敌人 #%d 打出卡牌 #%d。" % [enemy_id, card_id])

func _on_card_drag_released(card_id: int, release_global_position: Vector2) -> void:
	if monster_view.get_global_rect().has_point(release_global_position):
		_on_card_dropped_on_enemy(card_id, 0)
		return
	if state.card_requires_target(card_id):
		_append_log("攻击牌需要拖动到敌人图片上释放。")
	elif state.play_card(card_id):
		_append_log(state.last_event_log)
	else:
		_append_log("现在还不能打出卡牌 #%d。" % card_id)

func _on_return_to_menu_requested() -> void:
	if autosave_enabled:
		SaveManager.save_snapshot(save_slot, state.to_snapshot())
	return_to_menu_requested.emit()

func _on_battle_end_confirmed() -> void:
	return_to_menu_requested.emit()

func _append_log(message: String) -> void:
	log_label.text = message

func _show_battle_end_dialog() -> void:
	battle_end_shown = true
	battle_end_dialog.title = "战斗结束"
	var result_text := "副本已完成" if state.has_won else "战斗失败"
	battle_end_dialog.dialog_text = "%s\n%s，返回主菜单。" % [state.last_event_log, result_text]
	battle_end_dialog.popup_centered()

func _build_placeholder_config() -> Resource:
	var config := RunConfigScript.new()
	config.hero_name = Settings.HERO_NAME
	config.seed = int(Time.get_unix_time_from_system())
	config.starting_health = 50
	config.starting_energy = 4
	config.base_attack = 15
	config.base_block = 10
	config.starting_gold = int(pending_snapshot.get("gold", 0))
	config.starting_level = int(pending_snapshot.get("level", 1))
	config.encounter_id = pending_encounter_id
	config.victory_gold_reward = 100 if pending_encounter_id == &"training_test" else 0
	var monster := MonsterMarkdownLoaderScript.load_first_monster()
	config.enemy_name = monster.title
	config.enemy_health = monster.max_health
	config.enemy_algorithm_attribute = monster.algorithm_attribute
	config.enemy_action_countdown = monster.action_countdown
	config.enemy_attack = monster.attack
	config.enemy_actions = monster.actions
	config.enemy_description = monster.description
	config.starting_deck = _build_deck_from_profile()
	return config

func _build_deck_from_profile() -> Array[Resource]:
	var profile := SaveManager.ensure_profile_defaults(pending_snapshot.duplicate(true))
	var deck: Array[Resource] = []
	for raw_card_id in profile.get("deck_cards", []):
		deck.append(CardCatalogScript.get_definition(StringName(str(raw_card_id))))
	return deck

func _apply_profile_from_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	state.player_gold = int(snapshot.get("gold", state.player_gold))
	state.player_level = int(snapshot.get("level", state.player_level))
