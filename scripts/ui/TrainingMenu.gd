extends Control
class_name TrainingMenu

signal back_requested
signal training_test_requested

const TRAINING_DUNGEONS := [
	{
		"id": &"training_test",
		"name": "测试训练 Test",
		"subtitle": "A+B Problem / 1 个战斗节点",
		"recommended_level": 1,
		"entry_gold": 0,
		"restriction": "完成角色初始化后可进入",
		"reward": "胜利获得 100 金钱",
		"enemy": "算法哨兵",
		"description": "用于验证基础费用、抽牌、攻击、防御、回合结束与胜利结算的训练副本。"
	}
]

@onready var slot_label: Label = $Root/Rows/TopBar/TopMargin/TopBarRows/PlayerSummary/SlotLabel
@onready var gold_label: Label = $Root/Rows/TopBar/TopMargin/TopBarRows/PlayerSummary/GoldLabel
@onready var level_label: Label = $Root/Rows/TopBar/TopMargin/TopBarRows/PlayerSummary/LevelLabel
@onready var dungeon_list: VBoxContainer = $Root/Rows/Content/ListPanel/ListMargin/ListRows/DungeonList
@onready var detail_title_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/DetailTitleLabel
@onready var detail_subtitle_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/DetailSubtitleLabel
@onready var requirement_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/RequirementLabel
@onready var reward_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/RewardLabel
@onready var enemy_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/EnemyLabel
@onready var description_label: Label = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/DescriptionLabel
@onready var enter_button: Button = $Root/Rows/Content/DetailPanel/DetailMargin/DetailRows/EnterButton
@onready var status_label: Label = $Root/Rows/StatusLabel

var save_slot: int = 1
var snapshot: Dictionary = {}
var selected_index: int = 0
var dungeon_buttons: Array[Button] = []

func configure(slot: int, state_snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	snapshot = state_snapshot
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	_build_dungeon_list()
	_refresh()

func _build_dungeon_list() -> void:
	for child in dungeon_list.get_children():
		child.queue_free()
	dungeon_buttons.clear()

	for index in range(TRAINING_DUNGEONS.size()):
		var dungeon: Dictionary = TRAINING_DUNGEONS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(300, 72)
		button.text = "%s\n推荐等级 %d  消耗金币 %d" % [
			str(dungeon["name"]),
			int(dungeon["recommended_level"]),
			int(dungeon["entry_gold"])
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.pressed.connect(_on_dungeon_button_pressed.bind(index))
		dungeon_list.add_child(button)
		dungeon_buttons.append(button)

func _refresh() -> void:
	slot_label.text = "档位 %d" % save_slot
	gold_label.text = "金钱：%d" % _player_gold()
	level_label.text = "等级：%d" % _player_level()
	_select_dungeon(clampi(selected_index, 0, TRAINING_DUNGEONS.size() - 1))

func _select_dungeon(index: int) -> void:
	selected_index = index
	var dungeon: Dictionary = TRAINING_DUNGEONS[selected_index]
	for button_index in range(dungeon_buttons.size()):
		dungeon_buttons[button_index].button_pressed = button_index == selected_index

	detail_title_label.text = str(dungeon["name"])
	detail_subtitle_label.text = str(dungeon["subtitle"])
	requirement_label.text = "推荐等级：%d    进入限制：%s    消耗金币：%d" % [
		int(dungeon["recommended_level"]),
		str(dungeon["restriction"]),
		int(dungeon["entry_gold"])
	]
	reward_label.text = "奖励：%s" % str(dungeon["reward"])
	enemy_label.text = "预计遭遇：%s" % str(dungeon["enemy"])
	description_label.text = str(dungeon["description"])

	var can_enter := _can_enter(dungeon)
	enter_button.disabled = not can_enter
	status_label.text = "选择副本后点击进入。" if can_enter else _get_block_reason(dungeon)

func _can_enter(dungeon: Dictionary) -> bool:
	return _player_level() >= int(dungeon["recommended_level"]) and _player_gold() >= int(dungeon["entry_gold"])

func _get_block_reason(dungeon: Dictionary) -> String:
	if _player_level() < int(dungeon["recommended_level"]):
		return "等级不足，推荐等级为 %d。" % int(dungeon["recommended_level"])
	if _player_gold() < int(dungeon["entry_gold"]):
		return "金币不足，需要 %d 金钱。" % int(dungeon["entry_gold"])
	return "暂时无法进入该副本。"

func _player_gold() -> int:
	return int(snapshot.get("gold", 0))

func _player_level() -> int:
	return int(snapshot.get("level", 1))

func _on_dungeon_button_pressed(index: int) -> void:
	_select_dungeon(index)

func _on_enter_button_pressed() -> void:
	var dungeon: Dictionary = TRAINING_DUNGEONS[selected_index]
	if not _can_enter(dungeon):
		status_label.text = _get_block_reason(dungeon)
		return
	if dungeon["id"] == &"training_test":
		status_label.text = "进入测试训练 Test。"
		training_test_requested.emit()

func _on_back_button_pressed() -> void:
	back_requested.emit()
