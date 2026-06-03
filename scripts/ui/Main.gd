extends Control

const GAME_ROOT_SCENE := preload("res://scenes/game/GameRoot.tscn")

@onready var menu_panel: VBoxContainer = $Root/MenuPanel
@onready var game_mount: Control = $GameMount
@onready var subtitle_label: Label = $Root/MenuPanel/SubtitleLabel

var game_root: Node

func _ready() -> void:
	Settings.apply_defaults()
	subtitle_label.text = "%s 正在准备他的第一场算法冒险" % Settings.HERO_NAME

func _on_start_button_pressed() -> void:
	menu_panel.hide()
	game_root = GAME_ROOT_SCENE.instantiate()
	game_mount.add_child(game_root)
	game_root.connect("return_to_menu_requested", _on_return_to_menu_requested)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_return_to_menu_requested() -> void:
	if game_root != null:
		game_root.queue_free()
		game_root = null
	menu_panel.show()
