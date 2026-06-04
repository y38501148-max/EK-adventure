extends Control
class_name HomeRoot

const RECORD_DECK_CONFIG_SCENE := preload("res://scenes/home/RecordDeckConfig.tscn")

signal training_menu_requested
signal record_updated(snapshot: Dictionary)

@onready var slot_label: Label = $Overlay/Info/SlotLabel
@onready var hero_label: Label = $Overlay/Info/HeroLabel
@onready var level_label: Label = $Overlay/Info/LevelLabel
@onready var experience_label: Label = $Overlay/Info/ExperienceLabel
@onready var status_label: Label = $Overlay/StatusLabel

var save_slot: int = 1
var snapshot: Dictionary = {}
var record_panel: Control

func configure(slot: int, state_snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	snapshot = state_snapshot
	SaveManager.ensure_profile_defaults(snapshot)
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	SaveManager.ensure_profile_defaults(snapshot)
	_refresh()

func _refresh() -> void:
	slot_label.text = "档位 %d" % save_slot
	hero_label.text = Settings.HERO_NAME
	level_label.text = "等级：%d" % int(snapshot.get("level", 1))
	experience_label.text = "经验：%d/%d" % [_experience(), _next_level_experience()]
	status_label.text = "欢迎来到ExplodingKonjac的历险记！一起成为ACM大神，获得World Final 金牌吧！"

func update_snapshot(state_snapshot: Dictionary) -> void:
	snapshot = state_snapshot
	SaveManager.ensure_profile_defaults(snapshot)
	_refresh()

func _on_training_button_pressed() -> void:
	status_label.text = "正在进入训练菜单。"
	training_menu_requested.emit()

func _on_attribute_button_pressed() -> void:
	_set_pending_status("属性")

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

func _on_record_button_pressed() -> void:
	_open_record_panel()

func _set_pending_status(feature_name: String) -> void:
	status_label.text = "%s 功能等待下一步制作。" % feature_name

func _experience() -> int:
	return int(snapshot.get("experience", snapshot.get("xp", 0)))

func _next_level_experience() -> int:
	return max(1, int(snapshot.get("experience_to_next", snapshot.get("next_level_exp", 100))))

func _open_record_panel() -> void:
	SaveManager.ensure_profile_defaults(snapshot)
	if record_panel == null:
		record_panel = RECORD_DECK_CONFIG_SCENE.instantiate()
		record_panel.record_updated.connect(_on_record_panel_updated)
		record_panel.closed.connect(_on_record_panel_closed)
		add_child(record_panel)
	record_panel.configure(save_slot, snapshot)
	record_panel.show()
	status_label.text = "正在配置出战卡组。"

func _on_record_panel_updated(updated_snapshot: Dictionary) -> void:
	snapshot = updated_snapshot
	_refresh()
	status_label.text = "记录已更新。"
	record_updated.emit(snapshot.duplicate(true))

func _on_record_panel_closed() -> void:
	status_label.text = "记录配置已关闭。"
