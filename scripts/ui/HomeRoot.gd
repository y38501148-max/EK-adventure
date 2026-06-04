extends Control
class_name HomeRoot

const CardCatalogScript := preload("res://scripts/data/CardCatalog.gd")
const RECORD_COMPONENT_TEXTURE := "res://assets/art/ui/record_components/sliced/record_background_clean.png"
const RECORD_BUTTON_TEXTURES := {
	&"tab": {
		&"normal": "res://assets/art/ui/record_components/sliced/deck_tab_normal.png",
		&"hover": "res://assets/art/ui/record_components/sliced/deck_tab_hover.png",
		&"pressed": "res://assets/art/ui/record_components/sliced/deck_tab_pressed.png",
		&"disabled": "res://assets/art/ui/record_components/sliced/deck_tab_disabled.png"
	},
	&"action": {
		&"normal": "res://assets/art/ui/record_components/sliced/action_button_normal.png",
		&"hover": "res://assets/art/ui/record_components/sliced/action_button_hover.png",
		&"pressed": "res://assets/art/ui/record_components/sliced/action_button_pressed.png",
		&"disabled": "res://assets/art/ui/record_components/sliced/action_button_disabled.png"
	},
	&"row": {
		&"normal": "res://assets/art/ui/record_components/sliced/list_row_normal.png",
		&"hover": "res://assets/art/ui/record_components/sliced/list_row_hover.png",
		&"pressed": "res://assets/art/ui/record_components/sliced/list_row_pressed.png",
		&"disabled": "res://assets/art/ui/record_components/sliced/list_row_disabled.png"
	}
}

signal training_menu_requested
signal record_updated(snapshot: Dictionary)

@onready var slot_label: Label = $Overlay/Info/SlotLabel
@onready var hero_label: Label = $Overlay/Info/HeroLabel
@onready var level_label: Label = $Overlay/Info/LevelLabel
@onready var experience_label: Label = $Overlay/Info/ExperienceLabel
@onready var status_label: Label = $Overlay/StatusLabel

var save_slot: int = 1
var snapshot: Dictionary = {}
var record_overlay: Control
var record_tab_buttons: Array[Button] = []
var record_owned_rows: VBoxContainer
var record_deck_rows: VBoxContainer
var record_count_label: Label
var record_status_label: Label
var selected_record_card_id: String = SaveManager.DEFAULT_CARD_ID
var selected_record_deck_index: int = 0

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
	selected_record_deck_index = clampi(int(snapshot.get("active_deck_index", 0)), 0, SaveManager.DEFAULT_DECK_SLOT_COUNT - 1)
	if record_overlay == null:
		_build_record_panel()
	_refresh_record_panel()
	record_overlay.show()
	status_label.text = "正在配置出战卡组。"

func _build_record_panel() -> void:
	record_tab_buttons.clear()
	record_overlay = Control.new()
	record_overlay.name = "RecordOverlay"
	record_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(record_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	record_overlay.add_child(dim)

	var shell := Control.new()
	shell.position = Vector2(96.0, 58.0)
	shell.size = Vector2(1088.0, 604.0)
	record_overlay.add_child(shell)

	var texture := TextureRect.new()
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(RECORD_COMPONENT_TEXTURE):
		texture.texture = load(RECORD_COMPONENT_TEXTURE)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.modulate = Color(1.0, 1.0, 1.0, 0.84)
	shell.add_child(texture)

	var title := Label.new()
	title.position = Vector2(44.0, 24.0)
	title.size = Vector2(540.0, 34.0)
	title.text = "记录 / 卡组配置"
	title.add_theme_font_size_override("font_size", 24)
	shell.add_child(title)

	record_count_label = Label.new()
	record_count_label.position = Vector2(650.0, 28.0)
	record_count_label.size = Vector2(335.0, 30.0)
	record_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	record_count_label.add_theme_font_size_override("font_size", 18)
	shell.add_child(record_count_label)

	var tabs_title := _make_record_label("卡组列表", Vector2(34.0, 70.0), Vector2(104.0, 24.0), 15)
	shell.add_child(tabs_title)

	var tabs := VBoxContainer.new()
	tabs.position = Vector2(39.0, 102.0)
	tabs.size = Vector2(112.0, 414.0)
	tabs.add_theme_constant_override("separation", 7)
	shell.add_child(tabs)
	for index in range(SaveManager.DEFAULT_DECK_SLOT_COUNT):
		var tab_button := Button.new()
		tab_button.text = "卡组 %d" % [index + 1]
		tab_button.custom_minimum_size = Vector2(112.0, 44.0)
		_apply_record_button_style(tab_button, &"tab")
		tab_button.pressed.connect(_on_record_tab_pressed.bind(index))
		tabs.add_child(tab_button)
		record_tab_buttons.append(tab_button)

	var owned_title := _make_record_label("待选卡牌", Vector2(176.0, 70.0), Vector2(330.0, 24.0), 18)
	shell.add_child(owned_title)
	record_owned_rows = _make_record_list(shell, Vector2(172.0, 104.0), Vector2(388.0, 392.0))

	var deck_title := _make_record_label("出战卡组", Vector2(610.0, 70.0), Vector2(330.0, 24.0), 18)
	shell.add_child(deck_title)
	record_deck_rows = _make_record_list(shell, Vector2(606.0, 104.0), Vector2(416.0, 392.0))

	record_status_label = Label.new()
	record_status_label.position = Vector2(172.0, 522.0)
	record_status_label.size = Vector2(410.0, 42.0)
	record_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record_status_label.add_theme_font_size_override("font_size", 15)
	shell.add_child(record_status_label)

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.position = Vector2(614.0, 515.0)
	save_button.size = Vector2(218.0, 54.0)
	_apply_record_button_style(save_button, &"action")
	save_button.pressed.connect(_on_record_save_pressed)
	shell.add_child(save_button)

	var close_button := Button.new()
	close_button.text = "退出"
	close_button.position = Vector2(842.0, 515.0)
	close_button.size = Vector2(218.0, 54.0)
	_apply_record_button_style(close_button, &"action")
	close_button.pressed.connect(_on_record_close_pressed)
	shell.add_child(close_button)

	record_overlay.hide()

func _make_record_label(text: String, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _make_record_list(parent: Control, position: Vector2, list_size: Vector2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.position = position
	scroll.size = list_size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	return rows

func _refresh_record_panel() -> void:
	_clear_children(record_owned_rows)
	_clear_children(record_deck_rows)

	var deck_cards := _get_active_deck_cards()
	var owned_counts: Dictionary = snapshot.get("owned_card_counts", {})
	for card_id in owned_counts.keys():
		var count: int = int(owned_counts[card_id])
		if count <= 0:
			continue
		var used := _count_card_in_deck(str(card_id), deck_cards)
		var button := Button.new()
		button.text = "%s  %d/%d" % [_card_title(str(card_id)), used, count]
		button.custom_minimum_size = Vector2(0, 36)
		_apply_record_button_style(button, &"row")
		button.pressed.connect(_on_owned_card_pressed.bind(str(card_id)))
		record_owned_rows.add_child(button)

	for index in range(deck_cards.size()):
		var card_id := str(deck_cards[index])
		var button := Button.new()
		button.text = "%02d  %s" % [index + 1, _card_title(card_id)]
		button.custom_minimum_size = Vector2(0, 34)
		_apply_record_button_style(button, &"row")
		button.pressed.connect(_on_deck_card_pressed.bind(index, card_id))
		record_deck_rows.add_child(button)

	for index in range(record_tab_buttons.size()):
		var tab_button := record_tab_buttons[index]
		tab_button.disabled = index == selected_record_deck_index
		tab_button.text = "卡组 %d" % [index + 1]

	record_count_label.text = "当前卡组 %d    出战 %d 张 / 拥有 %d 张" % [
		selected_record_deck_index + 1,
		deck_cards.size(),
		_total_owned_cards()
	]

func _on_record_tab_pressed(index: int) -> void:
	selected_record_deck_index = clampi(index, 0, SaveManager.DEFAULT_DECK_SLOT_COUNT - 1)
	snapshot["active_deck_index"] = selected_record_deck_index
	snapshot["deck_cards"] = _get_active_deck_cards().duplicate()
	record_status_label.text = "已切换到卡组 %d。" % [selected_record_deck_index + 1]
	_refresh_record_panel()

func _on_owned_card_pressed(card_id: String) -> void:
	selected_record_card_id = card_id
	var deck_cards := _get_active_deck_cards()
	var owned := int(snapshot.get("owned_card_counts", {}).get(card_id, 0))
	if deck_cards.size() >= SaveManager.DEFAULT_MAX_DECK_SIZE:
		record_status_label.text = "每个卡组最多支持 %d 张初始手牌。" % SaveManager.DEFAULT_MAX_DECK_SIZE
	elif _count_card_in_deck(card_id, deck_cards) >= owned:
		record_status_label.text = "这张牌已经全部加入当前卡组。"
	else:
		deck_cards.append(card_id)
		_set_active_deck_cards(deck_cards)
		record_status_label.text = "已加入：%s" % _card_title(card_id)
	_refresh_record_panel()

func _on_deck_card_pressed(index: int, card_id: String) -> void:
	selected_record_card_id = card_id
	var deck_cards := _get_active_deck_cards()
	if index >= 0 and index < deck_cards.size():
		deck_cards.remove_at(index)
		_set_active_deck_cards(deck_cards)
		record_status_label.text = "已移出：%s" % _card_title(card_id)
	_refresh_record_panel()

func _on_record_save_pressed() -> void:
	_set_active_deck_cards(_get_active_deck_cards())
	snapshot["active_deck_index"] = selected_record_deck_index
	SaveManager.ensure_profile_defaults(snapshot)
	record_updated.emit(snapshot.duplicate(true))
	record_status_label.text = "卡组 %d 已保存。" % [selected_record_deck_index + 1]
	status_label.text = "记录已更新。"
	_refresh_record_panel()

func _on_record_close_pressed() -> void:
	record_overlay.hide()

func _get_active_deck_cards() -> Array:
	var deck_slots: Array = snapshot.get("deck_slots", [])
	if selected_record_deck_index < 0 or selected_record_deck_index >= deck_slots.size():
		return []
	return deck_slots[selected_record_deck_index].duplicate()

func _set_active_deck_cards(deck_cards: Array) -> void:
	var deck_slots: Array = snapshot.get("deck_slots", [])
	while deck_slots.size() < SaveManager.DEFAULT_DECK_SLOT_COUNT:
		deck_slots.append([])
	deck_slots[selected_record_deck_index] = deck_cards.duplicate()
	snapshot["deck_slots"] = deck_slots
	snapshot["active_deck_index"] = selected_record_deck_index
	snapshot["deck_cards"] = deck_cards.duplicate()

func _count_card_in_deck(card_id: String, deck_cards: Array) -> int:
	var count := 0
	for raw_card_id in deck_cards:
		if str(raw_card_id) == card_id:
			count += 1
	return count

func _count_deck_card(card_id: String) -> int:
	return _count_card_in_deck(card_id, _get_active_deck_cards())

func _total_owned_cards() -> int:
	var total := 0
	for count in snapshot.get("owned_card_counts", {}).values():
		total += int(count)
	return total

func _card_title(card_id: String) -> String:
	return CardCatalogScript.get_definition(StringName(card_id)).title

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _apply_record_button_style(button: Button, kind: StringName) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _make_record_button_style(kind, &"normal"))
	button.add_theme_stylebox_override("hover", _make_record_button_style(kind, &"hover"))
	button.add_theme_stylebox_override("pressed", _make_record_button_style(kind, &"pressed"))
	button.add_theme_stylebox_override("disabled", _make_record_button_style(kind, &"disabled"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.78, 0.86, 0.88, 0.92))
	button.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.80, 0.95, 1.0, 0.92))
	button.add_theme_font_size_override("font_size", 17 if kind == &"row" else 18)

func _make_record_button_style(kind: StringName, state: StringName) -> StyleBox:
	var style := StyleBoxTexture.new()
	var texture_path: String = RECORD_BUTTON_TEXTURES.get(kind, {}).get(state, "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		style.texture = load(texture_path)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.texture_margin_left = 12.0
	style.texture_margin_right = 12.0
	style.texture_margin_top = 10.0
	style.texture_margin_bottom = 10.0
	if kind == &"row":
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
	else:
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
	return style
