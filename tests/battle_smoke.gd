extends SceneTree

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")
const CardMarkdownLoaderScript := preload("res://scripts/data/CardMarkdownLoader.gd")
const GameStateScript := preload("res://scripts/game/GameState.gd")
const MonsterMarkdownLoaderScript := preload("res://scripts/data/MonsterMarkdownLoader.gd")
const RunConfigScript := preload("res://scripts/data/RunConfig.gd")

var _failed := false

func _init() -> void:
	_run()
	quit(1 if _failed else 0)

func _run() -> void:
	var enumerate_card := _load_enumerate_card()
	_expect(enumerate_card.title == "枚举", "应加载第一张测试卡：枚举")
	_expect(enumerate_card.cost == 1, "枚举费用应为 1")
	_expect(enumerate_card.card_type == CardDefinitionScript.CardType.ATTACK, "枚举应为攻击牌")
	_expect(enumerate_card.algorithm_attribute == &"模拟", "枚举算法属性应为模拟")
	_expect(enumerate_card.damage_percent == 100, "枚举应造成 100% 伤害")
	_test_monster_loader()
	_test_victory_reward(enumerate_card)

	var state: Variant = _build_state(enumerate_card)
	state.begin_turn()
	_expect(state.player_health == 50, "初始血量应为 50")
	_expect(state.max_energy == 4 and state.player_energy == 4, "每回合费用应为 4")
	_expect(state.hand.size() == 5, "测试牌组应抽到 5 张枚举")
	_expect(state.draw_cards(1) == 0, "只有 5 张枚举时，初始抽满后不应再抽到新牌")
	_expect(state.get_drawable_card_count() == 0, "只有 5 张枚举且都在手牌时，抽牌区应显示 0")

	var first_attack_id: int = state.hand[0].runtime_id
	_expect(not state.can_play_card(first_attack_id), "攻击牌没有目标时不应可打出")
	_expect(not state.play_card(first_attack_id), "攻击牌没有目标时不应被打出")
	state.play_card(first_attack_id, [0])
	_expect(state.enemy_health == 90, "模拟弱点应让 15 点基础伤害翻倍为 30")
	_expect(state.enemy_action_countdown == 2, "每出一张牌，怪物倒计时 -1")

	state.play_card(state.hand[0].runtime_id, [0])
	state.play_card(state.hand[0].runtime_id, [0])
	_expect(state.enemy_health == 30, "三张枚举后怪物应剩 30 血")
	_expect(state.enemy_acted_this_turn, "倒计时归 0 时怪物应立刻行动")
	_expect(state.player_health == 38, "怪物行动应造成 12 点伤害")
	state.end_turn()
	_expect(state.player_health == 38, "怪物已在出牌阶段行动时，回合结束不应再次行动")

	_test_card_zone_rules()
	_test_hand_limit_and_shuffle()

	var cheat_state: Variant = _build_state(enumerate_card)
	cheat_state.begin_turn()
	cheat_state.player_health = 1
	cheat_state.enemy_action_countdown = 1
	cheat_state.play_card(cheat_state.hand[0].runtime_id, [0])
	_expect(cheat_state.is_cheating, "生命归 0 应进入骗分状态")
	_expect(cheat_state.last_event_log.contains("开始骗分"), "生命归 0 时应提示开始骗分")
	_expect(not cheat_state.has_lost, "第一次归 0 不应立刻失败")
	_expect(cheat_state.effective_card_cost(cheat_state.hand[0]) == 2, "骗分状态下所有卡费用 +1")
	cheat_state.end_turn()
	cheat_state.begin_turn()
	cheat_state.end_turn()
	_expect(cheat_state.has_lost, "骗分状态下再次被怪物攻击应失败")
	_expect(cheat_state.last_event_log.contains("骗分失败"), "骗分失败时应有明确提示")

	if not _failed:
		print("Battle smoke passed.")

func _test_card_zone_rules() -> void:
	var retain_card := _make_test_card("保留测试", CardDefinitionScript.CardType.SKILL, [&"保留"])
	var evaporate_card := _make_test_card("蒸发测试", CardDefinitionScript.CardType.SKILL, [&"蒸发"])
	var exhaust_card := _make_test_card("消耗测试", CardDefinitionScript.CardType.SKILL, [&"消耗"])
	var normal_card := _make_test_card("普通测试", CardDefinitionScript.CardType.SKILL, [])
	var state: Variant = _build_state_with_deck([retain_card, evaporate_card, exhaust_card, normal_card])
	state.begin_turn()

	var exhaust_id := _find_hand_card_id(state, "消耗测试")
	state.play_card(exhaust_id)
	_expect(state.exhaust_pile.size() == 1, "打出含「消耗」标签的牌应进入删除区")

	state.end_turn()
	_expect(_hand_has_card(state, "保留测试"), "含「保留」标签的牌回合结束后应留在手牌")
	_expect(not _hand_has_card(state, "蒸发测试"), "含「蒸发」标签的未打出手牌不应留在手牌")
	_expect(state.exhaust_pile.size() == 2, "蒸发牌与消耗牌都应进入删除区")
	_expect(_discard_has_card(state, "普通测试"), "无特殊标签的未打出手牌应进入弃牌堆")

func _test_hand_limit_and_shuffle() -> void:
	var cards: Array[Resource] = []
	for index in range(12):
		cards.append(_make_test_card("上限测试%d" % index, CardDefinitionScript.CardType.SKILL, []))
	var state: Variant = _build_state_with_deck(cards)
	state.begin_turn()
	state.draw_cards(20)
	_expect(state.hand.size() == 10, "手牌上限应为 10")

	var shuffle_card := _make_test_card("洗牌测试", CardDefinitionScript.CardType.SKILL, [])
	var shuffle_state: Variant = _build_state_with_deck([shuffle_card, shuffle_card, shuffle_card, shuffle_card, shuffle_card])
	shuffle_state.begin_turn()
	shuffle_state.play_card(shuffle_state.hand[0].runtime_id)
	_expect(shuffle_state.discard_pile.size() == 1, "打出的无消耗牌应进入弃牌堆")
	shuffle_state.draw_cards(1)
	_expect(shuffle_state.discard_pile.is_empty(), "抽牌区不足本次抽牌数量时应将弃牌堆洗回抽牌区")
	_expect(shuffle_state.hand.size() == 5, "洗回后应能继续抽牌")

	var enough_cards: Array[Resource] = []
	for index in range(11):
		enough_cards.append(_make_test_card("充足抽牌%d" % index, CardDefinitionScript.CardType.SKILL, []))
	var enough_state: Variant = _build_state_with_deck(enough_cards)
	enough_state.begin_turn()
	enough_state.play_card(enough_state.hand[0].runtime_id)
	enough_state.draw_cards(5)
	_expect(enough_state.discard_pile.size() == 1, "抽牌区足够完成本次抽牌时不应提前洗回弃牌区")

func _test_monster_loader() -> void:
	var monster: Resource = MonsterMarkdownLoaderScript.load_first_monster()
	_expect(monster.title != "", "第一只怪物应有名称")
	_expect(monster.max_health > 0, "第一只怪物应有正数血量")
	_expect(monster.algorithm_attribute != &"", "第一只怪物应有算法属性")

	if monster.title == "A+B Problem":
		_expect(monster.max_health == 129, "A+B Problem 血量应为 129")
		_expect(monster.attack == 3, "A+B Problem 基础攻击应为 3")
		_expect(monster.actions.size() == 2, "A+B Problem 应有两种攻击")
		_expect(monster.actions[0].get("name") == "普通攻击", "第一种攻击应为普通攻击")
		_expect(monster.actions[0].get("countdown") == 5, "普通攻击行动值应为 5")
		_expect(monster.actions[0].get("damage_percent") == 100, "普通攻击应造成 100% 伤害")
		_expect(monster.actions[1].get("name") == "WA", "第二种攻击应为 WA")
		_expect(monster.actions[1].get("countdown") == 7, "WA 行动值应为 7")
		_expect(monster.actions[1].get("damage_percent") == 200, "WA 应造成 200% 伤害")

		var config: Resource = RunConfigScript.new()
		var deck: Array[Resource] = [_make_test_card("轮换测试", CardDefinitionScript.CardType.SKILL, [])]
		config.starting_deck = deck
		config.enemy_name = monster.title
		config.enemy_health = monster.max_health
		config.enemy_algorithm_attribute = monster.algorithm_attribute
		config.enemy_action_countdown = monster.action_countdown
		config.enemy_attack = monster.attack
		config.enemy_actions = monster.actions
		config.enemy_description = monster.description

		var state: Variant = GameStateScript.new()
		state.setup(config)
		state.begin_turn()
		_expect(["普通攻击", "WA"].has(state.enemy_action_name), "首个意图应从行动列表中随机选择")
		_expect(
			state.enemy_action_countdown == 5 or state.enemy_action_countdown == 7,
			"随机意图应使用自身行动值"
		)
		_expect(state.enemy_attack == 3 or state.enemy_attack == 6, "随机意图应使用自身伤害倍率")
		_test_random_enemy_actions()

func _test_victory_reward(card: Resource) -> void:
	var config: Resource = RunConfigScript.new()
	config.seed = 2
	config.starting_health = 50
	config.starting_energy = 4
	config.base_attack = 15
	config.base_block = 10
	config.starting_gold = 0
	config.starting_level = 1
	config.encounter_id = &"training_test"
	config.victory_gold_reward = 100
	config.enemy_name = "A+B Problem"
	config.enemy_health = 30
	config.enemy_algorithm_attribute = &"模拟"
	config.enemy_action_countdown = 3
	config.enemy_attack = 3
	var deck: Array[Resource] = [card]
	config.starting_deck = deck

	var state: Variant = GameStateScript.new()
	state.setup(config)
	state.begin_turn()
	state.play_card(state.hand[0].runtime_id, [0])
	_expect(state.has_won, "训练 Test 击败 A+B Problem 后应胜利")
	_expect(state.claim_victory_reward() == 100, "训练 Test 胜利后应获得 100 金钱")
	_expect(state.player_gold == 100, "金钱应累计到角色状态")
	_expect(state.claim_victory_reward() == 0, "胜利奖励不应重复领取")

func _test_random_enemy_actions() -> void:
	var config: Resource = RunConfigScript.new()
	config.seed = 20260604
	var deck: Array[Resource] = []
	config.starting_deck = deck
	config.enemy_attack = 0
	config.enemy_action_countdown = 1
	var actions: Array[Dictionary] = [
		{"name": "普通攻击", "countdown": 1, "damage_percent": 100},
		{"name": "WA", "countdown": 1, "damage_percent": 200},
		{"name": "TLE", "countdown": 1, "damage_percent": 300}
	]
	config.enemy_actions = actions

	var state: Variant = GameStateScript.new()
	state.setup(config)
	var names: Array[String] = []
	for _index in range(6):
		state.begin_turn()
		names.append(state.enemy_action_name)
		state.end_turn()

	_expect(names != ["普通攻击", "WA", "TLE", "普通攻击", "WA", "TLE"], "怪物行动不应按列表顺序轮换")
	for name in names:
		_expect(["普通攻击", "WA", "TLE"].has(name), "随机行动必须来自行动列表")

func _load_enumerate_card() -> Resource:
	for card in CardMarkdownLoaderScript.load_all_cards():
		if card.title == "枚举":
			return card

	var fallback := CardDefinitionScript.new()
	fallback.id = &"enumerate"
	fallback.title = "枚举"
	fallback.card_type = CardDefinitionScript.CardType.ATTACK
	fallback.algorithm_attribute = &"模拟"
	fallback.cost = 1
	fallback.damage_percent = 100
	fallback.description = "对单个敌人造成100%伤害"
	return fallback

func _build_state(card: Resource) -> Variant:
	return _build_state_with_deck([card, card, card, card, card])

func _build_state_with_deck(deck: Array[Resource]) -> Variant:
	var config: Resource = RunConfigScript.new()
	config.seed = 1
	config.starting_health = 50
	config.starting_energy = 4
	config.base_attack = 15
	config.base_block = 10
	config.enemy_name = "模拟题守门员"
	config.enemy_health = 120
	config.enemy_algorithm_attribute = &"模拟"
	config.enemy_action_countdown = 3
	config.enemy_attack = 12
	config.starting_deck = deck

	var state: Variant = GameStateScript.new()
	state.setup(config)
	return state

func _make_test_card(title: String, card_type: int, tags: Array[StringName]) -> Resource:
	var card := CardDefinitionScript.new()
	card.id = StringName(title)
	card.title = title
	card.card_type = card_type
	card.cost = 0
	card.tags = tags
	card.description = "测试牌"
	return card

func _find_hand_card_id(state: Variant, title: String) -> int:
	for card in state.hand:
		if card.definition.title == title:
			return card.runtime_id
	return -1

func _hand_has_card(state: Variant, title: String) -> bool:
	for card in state.hand:
		if card.definition.title == title:
			return true
	return false

func _discard_has_card(state: Variant, title: String) -> bool:
	for card in state.discard_pile:
		if card.definition.title == title:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
