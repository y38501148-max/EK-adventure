extends Control
class_name RecordDeckConfig

const CardCatalogScript := preload("res://scripts/data/CardCatalog.gd")
const CardInstanceStateScript := preload("res://scripts/game/CardInstanceState.gd")
const CardViewScene := preload("res://scenes/cards/CardView.tscn")

const RECORD_BUTTON_TEXTURES := {
	&"tab": {
		&"normal": preload("res://assets/art/ui/record_components/sliced/deck_tab_normal.png"),
		&"hover": preload("res://assets/art/ui/record_components/sliced/deck_tab_hover.png"),
		&"pressed": preload("res://assets/art/ui/record_components/sliced/deck_tab_pressed.png"),
		&"disabled": preload("res://assets/art/ui/record_components/sliced/deck_tab_disabled.png")
	},
	&"action": {
		&"normal": preload("res://assets/art/ui/record_components/sliced/action_button_normal.png"),
		&"hover": preload("res://assets/art/ui/record_components/sliced/action_button_hover.png"),
		&"pressed": preload("res://assets/art/ui/record_components/sliced/action_button_pressed.png"),
		&"disabled": preload("res://assets/art/ui/record_components/sliced/action_button_disabled.png")
	}
}

signal record_updated(snapshot: Dictionary)
signal closed

@onready var record_count_label: Label = $Shell/RecordCountLabel
@onready var record_status_label: Label = $Shell/RecordStatusLabel
@onready var tabs: VBoxContainer = $Shell/Tabs
@onready var record_owned_grid: GridContainer = $Shell/OwnedScroll/OwnedGrid
@onready var record_deck_grid: GridContainer = $Shell/DeckScroll/DeckGrid
@onready var save_button: Button = $Shell/SaveButton
@onready var close_button: Button = $Shell/CloseButton

var save_slot: int = 1
var snapshot: Dictionary = {}
var record_tab_buttons: Array[Button] = []
var selected_record_card_id: String = SaveManager.DEFAULT_CARD_ID
var selected_record_deck_index: int = 0
var record_card_runtime_id: int = 1

func configure(slot: int, state_snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	snapshot = state_snapshot
	SaveManager.ensure_profile_defaults(snapshot)
	selected_record_deck_index = clampi(
		int(snapshot.get("active_deck_index", 0)),
		0,
		SaveManager.DEFAULT_DECK_SLOT_COUNT - 1
	)
	if is_inside_tree():
		_refresh_record_panel()

func _ready() -> void:
	_build_tabs()
	_apply_record_button_style(save_button, &"action")
	_apply_record_button_style(close_button, &"action")
	_refresh_record_panel()

func _build_tabs() -> void:
	for child in tabs.get_children():
		child.queue_free()
	record_tab_buttons.clear()
	for index in range(SaveManager.DEFAULT_DECK_SLOT_COUNT):
		var tab_button := Button.new()
		tab_button.text = "卡组 %d" % [index + 1]
		tab_button.custom_minimum_size = Vector2(112.0, 44.0)
		_apply_record_button_style(tab_button, &"tab")
		tab_button.pressed.connect(_on_record_tab_pressed.bind(index))
		tabs.add_child(tab_button)
		record_tab_buttons.append(tab_button)

func _refresh_record_panel() -> void:
	_clear_children(record_owned_grid)
	_clear_children(record_deck_grid)
	record_card_runtime_id = 1

	var deck_cards := _get_active_deck_cards()
	var owned_counts: Dictionary = snapshot.get("owned_card_counts", {})
	for card_id in owned_counts.keys():
		var count: int = int(owned_counts[card_id])
		if count <= 0:
			continue
		var used := _count_card_in_deck(str(card_id), deck_cards)
		record_owned_grid.add_child(_make_record_card_slot(
			str(card_id),
			"剩余 %d/%d" % [max(0, count - used), count],
			_on_owned_record_card_selected.bind(str(card_id))
		))

	var deck_counts := _count_cards_by_id(deck_cards)
	for card_id in deck_counts.keys():
		var count: int = int(deck_counts[card_id])
		record_deck_grid.add_child(_make_record_card_slot(
			card_id,
			"出战 %d / 点击移出 1 张" % count,
			_on_deck_record_card_selected.bind(card_id)
		))

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

func _on_owned_record_card_selected(_runtime_id: int, card_id: String) -> void:
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

func _on_deck_record_card_selected(_runtime_id: int, card_id: String) -> void:
	selected_record_card_id = card_id
	var deck_cards := _get_active_deck_cards()
	var index := deck_cards.find(card_id)
	if index >= 0:
		deck_cards.remove_at(index)
		_set_active_deck_cards(deck_cards)
		record_status_label.text = "已移出：%s" % _card_title(card_id)
	_refresh_record_panel()

func _on_save_button_pressed() -> void:
	_set_active_deck_cards(_get_active_deck_cards())
	snapshot["active_deck_index"] = selected_record_deck_index
	SaveManager.ensure_profile_defaults(snapshot)
	record_updated.emit(snapshot.duplicate(true))
	record_status_label.text = "卡组 %d 已保存。" % [selected_record_deck_index + 1]
	_refresh_record_panel()

func _on_close_button_pressed() -> void:
	hide()
	closed.emit()

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

func _make_record_card_slot(card_id: String, footer_text: String, selected_callable: Callable) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(178.0, 212.0)

	var card_instance := CardInstanceStateScript.new(
		record_card_runtime_id,
		CardCatalogScript.get_definition(StringName(card_id))
	)
	record_card_runtime_id += 1

	var card_view := CardViewScene.instantiate()
	card_view.position = Vector2(4.0, 0.0)
	card_view.size = Vector2(170.0, 180.0)
	card_view.custom_minimum_size = Vector2(170.0, 180.0)
	card_view.drag_enabled = false
	slot.add_child(card_view)
	card_view.render(card_instance, null)
	card_view.card_selected.connect(selected_callable)

	var footer := Label.new()
	footer.position = Vector2(0.0, 182.0)
	footer.size = Vector2(178.0, 26.0)
	footer.text = footer_text
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.80, 0.92, 0.94, 0.92))
	slot.add_child(footer)
	return slot

func _count_card_in_deck(card_id: String, deck_cards: Array) -> int:
	var count := 0
	for raw_card_id in deck_cards:
		if str(raw_card_id) == card_id:
			count += 1
	return count

func _count_cards_by_id(cards: Array) -> Dictionary:
	var counts: Dictionary = {}
	for raw_card_id in cards:
		var card_id := str(raw_card_id)
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts

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
	button.add_theme_font_size_override("font_size", 18)

func _make_record_button_style(kind: StringName, state: StringName) -> StyleBox:
	var style := StyleBoxTexture.new()
	var textures: Dictionary = RECORD_BUTTON_TEXTURES.get(kind, {})
	style.texture = textures.get(state, null)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.texture_margin_left = 12.0
	style.texture_margin_right = 12.0
	style.texture_margin_top = 10.0
	style.texture_margin_bottom = 10.0
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style
