extends Control

const GAME_ROOT_SCENE := preload("res://scenes/game/GameRoot.tscn")
const HOME_ROOT_SCENE := preload("res://scenes/home/HomeRoot.tscn")
const TRAINING_MENU_SCENE := preload("res://scenes/home/TrainingMenu.tscn")

@onready var menu_panel: VBoxContainer = $Root/MenuPanel
@onready var slot_panel: VBoxContainer = $Root/SlotPanel
@onready var slot_title_label: Label = $Root/SlotPanel/SlotTitleLabel
@onready var slot_buttons: VBoxContainer = $Root/SlotPanel/SlotButtons
@onready var slot_status_label: Label = $Root/SlotPanel/SlotStatusLabel
@onready var game_mount: Control = $GameMount
@onready var subtitle_label: Label = $Root/MenuPanel/SubtitleLabel

var home_root: Node
var training_menu: Node
var game_root: Node
var resume_battle_dialog: ConfirmationDialog
var slot_mode: StringName = &"new"
var current_slot: int = 1
var current_snapshot: Dictionary = {}

func _ready() -> void:
	Settings.apply_defaults()
	subtitle_label.text = "%s 正在准备他的第一场算法冒险" % Settings.HERO_NAME
	_create_resume_battle_dialog()
	_build_slot_buttons()

func _on_start_button_pressed() -> void:
	_show_slot_panel(&"new")

func _on_load_button_pressed() -> void:
	_show_slot_panel(&"load")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	slot_panel.hide()
	menu_panel.show()

func _build_slot_buttons() -> void:
	for child in slot_buttons.get_children():
		child.queue_free()

	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(420, 42)
		button.pressed.connect(_on_slot_button_pressed.bind(slot))
		slot_buttons.add_child(button)

func _show_slot_panel(mode: StringName) -> void:
	slot_mode = mode
	menu_panel.hide()
	slot_panel.show()
	slot_status_label.text = ""
	slot_title_label.text = "选择新旅途档位" if slot_mode == &"new" else "选择读取档位"
	_refresh_slot_buttons()

func _refresh_slot_buttons() -> void:
	for index in range(slot_buttons.get_child_count()):
		var slot := index + 1
		var button := slot_buttons.get_child(index) as Button
		var summary := SaveManager.get_slot_summary(slot)
		var has_slot_save := bool(summary.get("has_save", false))
		if slot_mode == &"new":
			var suffix := "覆盖：%s" % summary.get("detail", "") if has_slot_save else "空档位"
			button.text = "档位 %d  新旅途  %s" % [slot, suffix]
			button.disabled = false
		else:
			button.text = "档位 %d  %s  %s" % [slot, summary.get("title", ""), summary.get("detail", "")]
			button.disabled = not has_slot_save

func _on_slot_button_pressed(slot: int) -> void:
	if slot_mode == &"load" and not SaveManager.has_save(slot):
		slot_status_label.text = "档位 %d 暂无存档。" % slot
		return
	_start_game(slot, slot_mode == &"load")

func _start_game(slot: int, should_load: bool) -> void:
	var snapshot := {}
	if should_load:
		var envelope := SaveManager.load_snapshot(slot)
		snapshot = envelope.get("state", envelope)
		if snapshot.is_empty():
			slot_status_label.text = "档位 %d 读取失败。" % slot
			return

	menu_panel.hide()
	slot_panel.hide()
	current_slot = slot
	current_snapshot = snapshot
	_show_home(slot, snapshot)

func _show_home(slot: int, snapshot: Dictionary = {}) -> void:
	if game_root != null:
		game_root.queue_free()
		game_root = null
	if training_menu != null:
		training_menu.queue_free()
		training_menu = null
	if home_root != null:
		home_root.queue_free()
		home_root = null
	home_root = HOME_ROOT_SCENE.instantiate()
	if home_root.has_method("configure"):
		home_root.configure(slot, snapshot)
	game_mount.add_child(home_root)
	home_root.connect("training_menu_requested", _on_training_menu_requested)

func _on_training_menu_requested() -> void:
	if SaveManager.has_unfinished_battle(current_slot):
		resume_battle_dialog.dialog_text = "当前档位有未完成的训练战斗，是否进入？\n选择“否”会删除当前战斗数据并进入训练副本列表。"
		resume_battle_dialog.popup_centered()
		return
	_open_training_menu()

func _open_training_menu() -> void:
	if home_root != null:
		home_root.hide()
	if game_root != null:
		game_root.queue_free()
		game_root = null
	if training_menu != null:
		training_menu.queue_free()
		training_menu = null
	training_menu = TRAINING_MENU_SCENE.instantiate()
	if training_menu.has_method("configure"):
		training_menu.configure(current_slot, current_snapshot)
	game_mount.add_child(training_menu)
	training_menu.connect("back_requested", _on_training_menu_back_requested)
	training_menu.connect("training_test_requested", _on_training_test_requested)

func _on_training_menu_back_requested() -> void:
	if training_menu != null:
		training_menu.queue_free()
		training_menu = null
	if home_root != null:
		home_root.show()

func _on_training_test_requested() -> void:
	_start_training_battle(current_snapshot, &"training_test")

func _start_training_battle(snapshot: Dictionary, encounter_id: StringName) -> void:
	if home_root != null:
		home_root.hide()
	if training_menu != null:
		training_menu.queue_free()
		training_menu = null
	if game_root != null:
		game_root.queue_free()
		game_root = null
	game_root = GAME_ROOT_SCENE.instantiate()
	if game_root.has_method("configure"):
		game_root.configure(current_slot, snapshot, encounter_id)
	game_mount.add_child(game_root)
	game_root.connect("return_to_menu_requested", _on_return_to_menu_requested)

func _on_resume_battle_confirmed() -> void:
	var envelope := SaveManager.load_snapshot(current_slot)
	var snapshot: Dictionary = envelope.get("state", {})
	if snapshot.is_empty():
		current_snapshot = {}
		_open_training_menu()
		return
	current_snapshot = snapshot
	_start_training_battle(snapshot, &"resume")

func _on_resume_battle_canceled() -> void:
	SaveManager.clear_unfinished_battle(current_slot)
	var envelope := SaveManager.load_snapshot(current_slot)
	current_snapshot = envelope.get("state", {})
	_open_training_menu()

func _on_return_to_menu_requested() -> void:
	if game_root != null:
		game_root.queue_free()
		game_root = null
	var envelope := SaveManager.load_snapshot(current_slot)
	current_snapshot = envelope.get("state", current_snapshot)
	if home_root != null:
		if home_root.has_method("update_snapshot"):
			home_root.update_snapshot(current_snapshot)
		home_root.show()
	else:
		_show_home(current_slot, current_snapshot)
	_refresh_slot_buttons()

func _create_resume_battle_dialog() -> void:
	resume_battle_dialog = ConfirmationDialog.new()
	resume_battle_dialog.title = "未完成的战斗"
	resume_battle_dialog.ok_button_text = "进入"
	resume_battle_dialog.cancel_button_text = "不进入"
	add_child(resume_battle_dialog)
	resume_battle_dialog.confirmed.connect(_on_resume_battle_confirmed)
	resume_battle_dialog.canceled.connect(_on_resume_battle_canceled)
