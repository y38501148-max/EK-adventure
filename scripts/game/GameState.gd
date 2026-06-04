extends RefCounted
class_name GameState

const CardInstanceStateScript := preload("res://scripts/game/CardInstanceState.gd")
const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")

const BASE_PLAYER_HEALTH := 50
const BASE_ENERGY_PER_TURN := 4
const BASE_ATTACK := 15
const BASE_BLOCK := 10
const HAND_LIMIT := 10
const DRAW_PER_TURN := 5
const TAG_RETAIN := &"保留"
const TAG_EVAPORATE := &"蒸发"
const TAG_EXHAUST := &"消耗"

signal phase_changed(phase: int)
signal state_changed

enum Phase { SETUP, DRAW, MAIN, TARGETING, RESOLVE, END, GAME_OVER }

var seed: int = 0
var rng := RandomNumberGenerator.new()
var phase: int = Phase.SETUP
var turn: int = 0
var player_max_health: int = BASE_PLAYER_HEALTH
var player_health: int = BASE_PLAYER_HEALTH
var player_block: int = 0
var player_energy: int = BASE_ENERGY_PER_TURN
var max_energy: int = BASE_ENERGY_PER_TURN
var base_attack: int = BASE_ATTACK
var base_block: int = BASE_BLOCK
var player_gold: int = 0
var player_level: int = 1
var hand_limit: int = HAND_LIMIT
var draw_per_turn: int = DRAW_PER_TURN
var is_cheating: bool = false
var has_lost: bool = false
var has_won: bool = false
var enemy_name: String = "样例评测机"
var enemy_max_health: int = 120
var enemy_health: int = 120
var enemy_algorithm_attribute: StringName = &"模拟"
var enemy_base_action_countdown: int = 3
var enemy_action_countdown: int = 3
var enemy_base_attack: int = 12
var enemy_attack: int = 12
var enemy_action_name: String = "普通攻击"
var enemy_action_damage_percent: int = 100
var enemy_actions: Array[Dictionary] = []
var enemy_action_index: int = 0
var enemy_description: String = ""
var enemy_acted_this_turn: bool = false
var encounter_id: StringName = &"default"
var victory_gold_reward: int = 0
var victory_reward_claimed: bool = false
var last_event_log: String = ""
var next_card_id: int = 1
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

func setup(config: Resource) -> void:
	seed = config.seed
	player_max_health = config.starting_health
	player_health = config.starting_health
	max_energy = config.starting_energy
	player_energy = max_energy
	base_attack = config.base_attack
	base_block = config.base_block
	player_gold = config.starting_gold
	player_level = max(1, config.starting_level)
	hand_limit = HAND_LIMIT
	draw_per_turn = DRAW_PER_TURN
	player_block = 0
	is_cheating = false
	has_lost = false
	has_won = false
	enemy_name = config.enemy_name
	enemy_max_health = config.enemy_health
	enemy_health = enemy_max_health
	enemy_algorithm_attribute = config.enemy_algorithm_attribute
	enemy_base_action_countdown = max(1, config.enemy_action_countdown)
	enemy_action_countdown = enemy_base_action_countdown
	enemy_base_attack = config.enemy_attack
	enemy_attack = enemy_base_attack
	enemy_actions = config.enemy_actions.duplicate(true)
	enemy_action_index = 0
	enemy_description = config.enemy_description
	enemy_acted_this_turn = false
	encounter_id = config.encounter_id
	victory_gold_reward = max(0, config.victory_gold_reward)
	victory_reward_claimed = false
	rng.seed = seed
	_prepare_enemy_action(false)
	last_event_log = "战斗开始。"
	turn = 0
	next_card_id = 1
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()

	for definition in config.starting_deck:
		var card := CardInstanceStateScript.new(next_card_id, definition)
		next_card_id += 1
		draw_pile.append(card)

	_shuffle_draw_pile()
	_set_phase(Phase.SETUP)
	state_changed.emit()

func begin_turn() -> void:
	if _is_combat_over():
		return
	turn += 1
	player_energy = max_energy
	player_block = 0
	enemy_acted_this_turn = false
	_prepare_enemy_action()
	_set_phase(Phase.DRAW)
	draw_cards(draw_per_turn)
	_set_phase(Phase.MAIN)
	state_changed.emit()

func end_turn() -> void:
	if _is_combat_over():
		return
	_set_phase(Phase.END)
	last_event_log = "结束出牌阶段。"
	if not enemy_acted_this_turn:
		_perform_enemy_action()
	var retained_hand: Array = []
	for card in hand:
		if _card_has_tag(card, TAG_RETAIN):
			card.zone = &"hand"
			retained_hand.append(card)
		elif _card_has_tag(card, TAG_EVAPORATE):
			card.zone = &"exhaust_pile"
			exhaust_pile.append(card)
		else:
			card.zone = &"discard_pile"
			discard_pile.append(card)
	hand = retained_hand
	state_changed.emit()

func draw_cards(amount: int) -> int:
	var drawn := 0
	for _index in range(amount):
		if hand.size() >= hand_limit:
			break
		_shuffle_discard_into_draw_if_low()
		if draw_pile.is_empty():
			break

		var card: Variant = draw_pile.pop_back()
		card.zone = &"hand"
		hand.append(card)
		drawn += 1
	return drawn

func get_drawable_card_count() -> int:
	return draw_pile.size() + discard_pile.size()

func can_play_card(card_id: int, targets: Array = []) -> bool:
	var card: Variant = get_hand_card(card_id)
	return (
		card != null
		and phase == Phase.MAIN
		and not _is_combat_over()
		and player_energy >= effective_card_cost(card)
		and _has_required_targets(card, targets)
	)

func play_card(card_id: int, targets: Array = []) -> bool:
	var card: Variant = get_hand_card(card_id)
	if card == null or not can_play_card(card_id, targets):
		return false

	player_energy -= effective_card_cost(card)
	_resolve_card(card, targets)
	for effect in card.definition.effects:
		if effect.can_apply(self, card_id, targets):
			effect.apply(self, card_id, targets)

	_move_played_card(card)
	_after_player_card()
	state_changed.emit()
	return true

func effective_card_cost(card: Variant) -> int:
	var cheat_delta := 1 if is_cheating else 0
	return card.display_cost(cheat_delta)

func get_hand_card(card_id: int) -> Variant:
	for card in hand:
		if card.runtime_id == card_id:
			return card
	return null

func card_requires_target(card_id: int) -> bool:
	return _card_requires_target(get_hand_card(card_id))

func claim_victory_reward() -> int:
	if not has_won or victory_reward_claimed or victory_gold_reward <= 0:
		return 0
	victory_reward_claimed = true
	player_gold += victory_gold_reward
	return victory_gold_reward

func to_snapshot() -> Dictionary:
	return {
		"seed": seed,
		"turn": turn,
		"phase": phase,
		"player_max_health": player_max_health,
		"player_health": player_health,
		"player_block": player_block,
		"player_energy": player_energy,
		"gold": player_gold,
		"level": player_level,
		"hand_limit": hand_limit,
		"is_cheating": is_cheating,
		"has_lost": has_lost,
		"has_won": has_won,
		"enemy_name": enemy_name,
		"enemy_health": enemy_health,
		"enemy_algorithm_attribute": enemy_algorithm_attribute,
		"enemy_action_countdown": enemy_action_countdown,
		"enemy_action_name": enemy_action_name,
		"enemy_attack": enemy_attack,
		"enemy_base_attack": enemy_base_attack,
		"enemy_actions": enemy_actions,
		"enemy_action_index": enemy_action_index,
		"enemy_description": enemy_description,
		"encounter_id": str(encounter_id),
		"victory_gold_reward": victory_gold_reward,
		"victory_reward_claimed": victory_reward_claimed,
		"next_card_id": next_card_id,
		"last_event_log": last_event_log,
		"draw_pile": _cards_to_snapshot(draw_pile),
		"hand": _cards_to_snapshot(hand),
		"discard_pile": _cards_to_snapshot(discard_pile),
		"exhaust_pile": _cards_to_snapshot(exhaust_pile)
	}

func apply_snapshot(snapshot: Dictionary) -> void:
	seed = int(snapshot.get("seed", seed))
	turn = int(snapshot.get("turn", turn))
	phase = int(snapshot.get("phase", phase))
	player_max_health = int(snapshot.get("player_max_health", player_max_health))
	player_health = int(snapshot.get("player_health", player_health))
	player_block = int(snapshot.get("player_block", player_block))
	player_energy = int(snapshot.get("player_energy", player_energy))
	player_gold = int(snapshot.get("gold", player_gold))
	player_level = int(snapshot.get("level", player_level))
	hand_limit = int(snapshot.get("hand_limit", hand_limit))
	is_cheating = bool(snapshot.get("is_cheating", is_cheating))
	has_lost = bool(snapshot.get("has_lost", has_lost))
	has_won = bool(snapshot.get("has_won", has_won))
	enemy_name = str(snapshot.get("enemy_name", enemy_name))
	enemy_max_health = int(snapshot.get("enemy_max_health", enemy_max_health))
	enemy_health = int(snapshot.get("enemy_health", enemy_health))
	enemy_algorithm_attribute = StringName(str(snapshot.get("enemy_algorithm_attribute", enemy_algorithm_attribute)))
	enemy_action_countdown = int(snapshot.get("enemy_action_countdown", enemy_action_countdown))
	enemy_action_name = str(snapshot.get("enemy_action_name", enemy_action_name))
	enemy_attack = int(snapshot.get("enemy_attack", enemy_attack))
	enemy_base_attack = int(snapshot.get("enemy_base_attack", enemy_base_attack))
	enemy_actions = _normalize_actions(snapshot.get("enemy_actions", enemy_actions))
	enemy_action_index = int(snapshot.get("enemy_action_index", enemy_action_index))
	enemy_description = str(snapshot.get("enemy_description", enemy_description))
	encounter_id = StringName(str(snapshot.get("encounter_id", encounter_id)))
	victory_gold_reward = int(snapshot.get("victory_gold_reward", victory_gold_reward))
	victory_reward_claimed = bool(snapshot.get("victory_reward_claimed", victory_reward_claimed))
	next_card_id = int(snapshot.get("next_card_id", next_card_id))
	last_event_log = str(snapshot.get("last_event_log", last_event_log))
	draw_pile = _cards_from_snapshot(snapshot.get("draw_pile", []), &"draw_pile")
	hand = _cards_from_snapshot(snapshot.get("hand", []), &"hand")
	discard_pile = _cards_from_snapshot(snapshot.get("discard_pile", []), &"discard_pile")
	exhaust_pile = _cards_from_snapshot(snapshot.get("exhaust_pile", []), &"exhaust_pile")
	_set_phase(phase)
	state_changed.emit()

func _move_played_card(card: Variant) -> void:
	hand.erase(card)
	if _card_has_tag(card, TAG_EXHAUST):
		card.zone = &"exhaust_pile"
		exhaust_pile.append(card)
	else:
		card.zone = &"discard_pile"
		discard_pile.append(card)

func _cards_to_snapshot(cards: Array) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for card in cards:
		snapshots.append(_card_to_snapshot(card))
	return snapshots

func _card_to_snapshot(card: Variant) -> Dictionary:
	var definition: Resource = card.definition
	return {
		"runtime_id": card.runtime_id,
		"owner_id": str(card.owner_id),
		"zone": str(card.zone),
		"temporary_cost_delta": card.temporary_cost_delta,
		"selected": card.selected,
		"definition": {
			"id": str(definition.id),
			"title": definition.title,
			"card_type": definition.card_type,
			"algorithm_attribute": str(definition.algorithm_attribute),
			"cost": definition.cost,
			"base_value": definition.base_value,
			"damage_percent": definition.damage_percent,
			"description": definition.description,
			"tags": _tags_to_snapshot(definition.tags)
		}
	}

func _cards_from_snapshot(cards_snapshot: Variant, fallback_zone: StringName) -> Array:
	var cards: Array = []
	if not cards_snapshot is Array:
		return cards
	for card_snapshot in cards_snapshot:
		if not card_snapshot is Dictionary:
			continue
		var definition := _definition_from_snapshot(card_snapshot.get("definition", {}))
		var card := CardInstanceStateScript.new(int(card_snapshot.get("runtime_id", 0)), definition)
		card.owner_id = StringName(str(card_snapshot.get("owner_id", "player")))
		card.zone = StringName(str(card_snapshot.get("zone", fallback_zone)))
		card.temporary_cost_delta = int(card_snapshot.get("temporary_cost_delta", 0))
		card.selected = bool(card_snapshot.get("selected", false))
		cards.append(card)
	return cards

func _definition_from_snapshot(definition_snapshot: Variant) -> Resource:
	var definition := CardDefinitionScript.new()
	if not definition_snapshot is Dictionary:
		return definition
	definition.id = StringName(str(definition_snapshot.get("id", "")))
	definition.title = str(definition_snapshot.get("title", "未命名"))
	definition.card_type = int(definition_snapshot.get("card_type", CardDefinitionScript.CardType.SKILL))
	definition.algorithm_attribute = StringName(str(definition_snapshot.get("algorithm_attribute", "")))
	definition.cost = int(definition_snapshot.get("cost", 1))
	definition.base_value = int(definition_snapshot.get("base_value", 0))
	definition.damage_percent = int(definition_snapshot.get("damage_percent", 100))
	definition.description = str(definition_snapshot.get("description", ""))
	definition.tags = _tags_from_snapshot(definition_snapshot.get("tags", []))
	return definition

func _tags_to_snapshot(tags: Array[StringName]) -> Array[String]:
	var values: Array[String] = []
	for tag in tags:
		values.append(str(tag))
	return values

func _tags_from_snapshot(raw_tags: Variant) -> Array[StringName]:
	var tags: Array[StringName] = []
	if not raw_tags is Array:
		return tags
	for tag in raw_tags:
		tags.append(StringName(str(tag)))
	return tags

func _normalize_actions(raw_actions: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not raw_actions is Array:
		return normalized
	for action in raw_actions:
		if action is Dictionary:
			normalized.append(action)
	return normalized

func _resolve_card(card: Variant, _targets: Array) -> void:
	match card.definition.card_type:
		CardDefinitionScript.CardType.ATTACK:
			_attack_enemy(card)
		CardDefinitionScript.CardType.BLOCK:
			_gain_block(card)
		_:
			last_event_log = "打出 %s，效果待实现。" % card.definition.title

func _attack_enemy(card: Variant) -> void:
	var damage: int = _calculate_card_damage(card)
	enemy_health = max(0, enemy_health - damage)
	var weakness_text := "，命中算法弱点" if _hits_enemy_weakness(card) else ""
	last_event_log = "%s 造成 %d 点伤害%s。" % [card.definition.title, damage, weakness_text]
	if enemy_health <= 0:
		has_won = true
		last_event_log += " 怪物已被击败。"
		_set_phase(Phase.GAME_OVER)

func _gain_block(card: Variant) -> void:
	var amount: int = card.definition.base_value if card.definition.base_value > 0 else base_block
	player_block += amount
	last_event_log = "%s 获得 %d 点护盾。" % [card.definition.title, amount]

func _calculate_card_damage(card: Variant) -> int:
	var damage: int = card.definition.base_value
	if damage <= 0:
		damage = int(round(float(base_attack * card.definition.damage_percent) / 100.0))
	if _hits_enemy_weakness(card):
		damage *= 2
	return max(0, damage)

func _hits_enemy_weakness(card: Variant) -> bool:
	return card.definition.algorithm_attribute != &"" and card.definition.algorithm_attribute == enemy_algorithm_attribute

func _after_player_card() -> void:
	if enemy_acted_this_turn or _is_combat_over():
		return
	enemy_action_countdown = max(0, enemy_action_countdown - 1)
	if enemy_action_countdown == 0:
		_perform_enemy_action()

func _perform_enemy_action() -> void:
	if enemy_acted_this_turn or has_won or has_lost:
		return
	enemy_acted_this_turn = true
	enemy_action_countdown = 0
	if enemy_attack <= 0:
		last_event_log += " %s 本回合没有造成伤害。" % enemy_name
		return
	if is_cheating:
		has_lost = true
		last_event_log += " %s 使用%s再次攻击。骗分失败。" % [enemy_name, enemy_action_name]
		_set_phase(Phase.GAME_OVER)
		return

	var blocked: int = min(player_block, enemy_attack)
	var damage: int = enemy_attack - blocked
	player_block -= blocked
	player_health = max(0, player_health - damage)
	if player_health == 0:
		is_cheating = true
		last_event_log += " %s 使用%s造成 %d 点伤害。开始骗分。" % [enemy_name, enemy_action_name, damage]
	else:
		last_event_log += " %s 使用%s造成 %d 点伤害。" % [enemy_name, enemy_action_name, damage]

func _is_combat_over() -> bool:
	return has_lost or has_won

func _prepare_enemy_action(use_random: bool = true) -> void:
	if enemy_actions.is_empty():
		enemy_action_name = "普通攻击"
		enemy_action_damage_percent = 100
		enemy_base_action_countdown = max(1, enemy_base_action_countdown)
		enemy_action_countdown = enemy_base_action_countdown
		enemy_attack = enemy_base_attack
		return

	if use_random:
		enemy_action_index = rng.randi_range(0, enemy_actions.size() - 1)
	else:
		enemy_action_index = clampi(enemy_action_index, 0, enemy_actions.size() - 1)

	var action := enemy_actions[enemy_action_index]
	enemy_action_name = str(action.get("name", "普通攻击"))
	enemy_action_damage_percent = int(action.get("damage_percent", 100))
	enemy_base_action_countdown = max(1, int(action.get("countdown", enemy_base_action_countdown)))
	enemy_action_countdown = enemy_base_action_countdown
	enemy_attack = int(round(float(enemy_base_attack * enemy_action_damage_percent) / 100.0))

func _shuffle_discard_into_draw_if_low() -> void:
	if draw_pile.size() > 3:
		return
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle_draw_pile()

func _card_has_tag(card: Variant, tag: StringName) -> bool:
	if card == null or card.definition == null:
		return false
	return card.definition.tags.has(tag)

func _card_requires_target(card: Variant) -> bool:
	return (
		card != null
		and card.definition != null
		and card.definition.card_type == CardDefinitionScript.CardType.ATTACK
	)

func _has_required_targets(card: Variant, targets: Array) -> bool:
	if not _card_requires_target(card):
		return true
	if targets.is_empty():
		return false
	for target_id in targets:
		if int(target_id) < 0:
			return false
	return true

func _shuffle_draw_pile() -> void:
	if draw_pile.size() < 2:
		return
	for index in range(draw_pile.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current: Variant = draw_pile[index]
		draw_pile[index] = draw_pile[swap_index]
		draw_pile[swap_index] = current

func _set_phase(next_phase: int) -> void:
	phase = next_phase
	phase_changed.emit(phase)
