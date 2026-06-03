extends Control

const GAME_ROOT_SCENE := preload("res://scenes/game/GameRoot.tscn")

@onready var menu_panel: VBoxContainer = $Root/MenuPanel
@onready var slot_panel: VBoxContainer = $Root/SlotPanel
@onready var slot_title_label: Label = $Root/SlotPanel/SlotTitleLabel
@onready var slot_buttons: VBoxContainer = $Root/SlotPanel/SlotButtons
@onready var slot_status_label: Label = $Root/SlotPanel/SlotStatusLabel
@onready var game_mount: Control = $GameMount
@onready var subtitle_label: Label = $Root/MenuPanel/SubtitleLabel

var game_root: Node
var slot_mode: StringName = &"new"

func _ready() -> void:
	Settings.apply_defaults()
	subtitle_label.text = "%s 正在准备他的第一场算法冒险" % Settings.HERO_NAME
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
	if game_root != null:
		game_root.queue_free()
	game_root = GAME_ROOT_SCENE.instantiate()
	if game_root.has_method("configure"):
		game_root.configure(slot, snapshot)
	game_mount.add_child(game_root)
	game_root.connect("return_to_menu_requested", _on_return_to_menu_requested)

func _on_return_to_menu_requested() -> void:
	if game_root != null:
		game_root.queue_free()
		game_root = null
	menu_panel.show()
	slot_panel.hide()
	_refresh_slot_buttons()
