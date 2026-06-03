extends Control
class_name HomeRoot

signal training_test_requested

@onready var slot_label: Label = $Root/Columns/InfoColumn/SlotLabel
@onready var hero_label: Label = $Root/Columns/InfoColumn/HeroLabel
@onready var gold_label: Label = $Root/Columns/InfoColumn/GoldLabel
@onready var level_label: Label = $Root/Columns/InfoColumn/LevelLabel
@onready var health_label: Label = $Root/Columns/InfoColumn/HealthLabel
@onready var status_label: Label = $Root/Columns/InfoColumn/StatusLabel

var save_slot: int = 1
var snapshot: Dictionary = {}

func configure(slot: int, state_snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	snapshot = state_snapshot
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	slot_label.text = "档位 %d" % save_slot
	hero_label.text = Settings.HERO_NAME
	gold_label.text = "金钱：%d" % int(snapshot.get("gold", 0))
	level_label.text = "等级：%d" % int(snapshot.get("level", 1))
	health_label.text = "生命：%d/%d" % [
		int(snapshot.get("player_health", 50)),
		int(snapshot.get("player_max_health", 50))
	]
	status_label.text = "主页已载入。"

func update_snapshot(state_snapshot: Dictionary) -> void:
	snapshot = state_snapshot
	_refresh()

func _on_training_button_pressed() -> void:
	status_label.text = "训练副本 Test：1 节点 / A+B Problem。"
	training_test_requested.emit()

func _on_sortie_button_pressed() -> void:
	_set_pending_status("出击")

func _on_story_button_pressed() -> void:
	_set_pending_status("故事")

func _on_study_button_pressed() -> void:
	_set_pending_status("学习")

func _on_relic_button_pressed() -> void:
	_set_pending_status("遗物")

func _on_bag_button_pressed() -> void:
	_set_pending_status("背包")

func _set_pending_status(feature_name: String) -> void:
	status_label.text = "%s 功能等待下一步制作。" % feature_name
