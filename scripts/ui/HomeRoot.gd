extends Control
class_name HomeRoot

const CardCatalogScript := preload("res://scripts/data/CardCatalog.gd")
const RECORD_COMPONENT_TEXTURE := "res://assets/art/ui/record_components/deck_config_components.png"

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
var record_owned_rows: VBoxContainer
var record_deck_rows: VBoxContainer
var record_detail_label: Label
var record_count_label: Label
var record_status_label: Label
var selected_record_card_id: String = SaveManager.DEFAULT_CARD_ID

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
	if record_overlay == null:
		_build_record_panel()
	_refresh_record_panel()
	record_overlay.show()
	status_label.text = "正在配置出战卡组。"

func _build_record_panel() -> void:
	record_overlay = Control.new()
	record_overlay.name = "RecordOverlay"
	record_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(record_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	record_overlay.add_child(dim)

	var shell := Control.new()
	shell.position = Vector2(150.0, 58.0)
	shell.size = Vector2(980.0, 604.0)
	record_overlay.add_child(shell)

	var texture := TextureRect.new()
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(RECORD_COMPONENT_TEXTURE):
		texture.texture = load(RECORD_COMPONENT_TEXTURE)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.modulate = Color(1.0, 1.0, 1.0, 0.84)
	shell.add_child(texture)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_record_panel_style())
	shell.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title_row := HBoxContainer.new()
	rows.add_child(title_row)

	var title := Label.new()
	title.text = "记录 / 卡组配置"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)

	record_count_label = Label.new()
	record_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	record_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_count_label.add_theme_font_size_override("font_size", 18)
	title_row.add_child(record_count_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	rows.add_child(columns)

	record_owned_rows = _make_record_column(columns, "拥有卡牌", Vector2(260, 420))
	record_deck_rows = _make_record_column(columns, "出战卡组", Vector2(360, 420))

	var detail_box := VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(250, 420)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 10)
	columns.add_child(detail_box)

	var detail_title := Label.new()
	detail_title.text = "卡牌详情"
	detail_title.add_theme_font_size_override("font_size", 18)
	detail_box.add_child(detail_title)

	record_detail_label = Label.new()
	record_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	record_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	record_detail_label.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(record_detail_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 12)
	rows.add_child(button_row)

	record_status_label = Label.new()
	record_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button_row.add_child(record_status_label)

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.custom_minimum_size = Vector2(110, 38)
	save_button.pressed.connect(_on_record_save_pressed)
	button_row.add_child(save_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(110, 38)
	close_button.pressed.connect(_on_record_close_pressed)
	button_row.add_child(close_button)

	record_overlay.hide()

func _make_record_column(parent: Control, title_text: String, minimum_size: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = minimum_size
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	return rows

func _refresh_record_panel() -> void:
	_clear_children(record_owned_rows)
	_clear_children(record_deck_rows)

	var owned_counts: Dictionary = snapshot.get("owned_card_counts", {})
	for card_id in owned_counts.keys():
		var count := int(owned_counts[card_id])
		if count <= 0:
			continue
		var used := _count_deck_card(str(card_id))
		var button := Button.new()
		button.text = "%s  %d/%d" % [_card_title(str(card_id)), used, count]
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(_on_owned_card_pressed.bind(str(card_id)))
		record_owned_rows.add_child(button)

	var deck_cards: Array = snapshot.get("deck_cards", [])
	for index in range(deck_cards.size()):
		var card_id := str(deck_cards[index])
		var button := Button.new()
		button.text = "%02d  %s" % [index + 1, _card_title(card_id)]
		button.custom_minimum_size = Vector2(0, 32)
		button.pressed.connect(_on_deck_card_pressed.bind(index, card_id))
		record_deck_rows.add_child(button)

	record_count_label.text = "出战 %d 张 / 拥有 %d 张" % [deck_cards.size(), _total_owned_cards()]
	_refresh_record_detail()

func _refresh_record_detail() -> void:
	var card: Resource = CardCatalogScript.get_definition(StringName(selected_record_card_id))
	var owned := int(snapshot.get("owned_card_counts", {}).get(selected_record_card_id, 0))
	var used := _count_deck_card(selected_record_card_id)
	record_detail_label.text = "%s\n费用：%d\n类型：%s\n拥有：%d\n出战：%d\n\n%s" % [
		card.title,
		card.cost,
		_card_type_text(card),
		owned,
		used,
		card.description
	]

func _on_owned_card_pressed(card_id: String) -> void:
	selected_record_card_id = card_id
	var owned := int(snapshot.get("owned_card_counts", {}).get(card_id, 0))
	if _count_deck_card(card_id) >= owned:
		record_status_label.text = "这张牌已经全部加入出战卡组。"
	else:
		var deck_cards: Array = snapshot.get("deck_cards", [])
		deck_cards.append(card_id)
		snapshot["deck_cards"] = deck_cards
		record_status_label.text = "已加入：%s" % _card_title(card_id)
	_refresh_record_panel()

func _on_deck_card_pressed(index: int, card_id: String) -> void:
	selected_record_card_id = card_id
	var deck_cards: Array = snapshot.get("deck_cards", [])
	if index >= 0 and index < deck_cards.size():
		deck_cards.remove_at(index)
		snapshot["deck_cards"] = deck_cards
		record_status_label.text = "已移出：%s" % _card_title(card_id)
	_refresh_record_panel()

func _on_record_save_pressed() -> void:
	SaveManager.ensure_profile_defaults(snapshot)
	record_updated.emit(snapshot.duplicate(true))
	record_status_label.text = "卡组已保存。"
	status_label.text = "记录已更新。"
	_refresh_record_panel()

func _on_record_close_pressed() -> void:
	record_overlay.hide()

func _count_deck_card(card_id: String) -> int:
	var count := 0
	for raw_card_id in snapshot.get("deck_cards", []):
		if str(raw_card_id) == card_id:
			count += 1
	return count

func _total_owned_cards() -> int:
	var total := 0
	for count in snapshot.get("owned_card_counts", {}).values():
		total += int(count)
	return total

func _card_title(card_id: String) -> String:
	return CardCatalogScript.get_definition(StringName(card_id)).title

func _card_type_text(card: Resource) -> String:
	match card.card_type:
		0:
			return "攻击 / %s" % str(card.algorithm_attribute)
		1:
			return "格挡"
		2:
			return "技能"
		3:
			return "能力"
		4:
			return "事件"
		_:
			return "未知"

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _make_record_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.90)
	style.border_color = Color(0.35, 0.78, 0.86, 0.64)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style
