extends Control
class_name TrainingMenu

signal back_requested
signal training_test_requested

const PAGE_COUNT := 2
const DUNGEONS_PER_PAGE := 8
const DUNGEON_BUTTON_SIZE := Vector2(478.0, 72.0)
const DUNGEON_BUTTON_TOPS := [0.0, 72.0, 144.0, 216.0, 288.0, 360.0, 432.0, 504.0]
const SOURCE_CANVAS_SIZE := Vector2(1536.0, 1024.0)
const DESIGN_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const COMPONENT_SOURCE_RECTS := {
	"Shell": Rect2(60.0, 40.0, 1378.0, 930.0),
	"BackButtonFrame": Rect2(92.0, 70.0, 72.0, 64.0),
	"ProgressLights": Rect2(199.0, 88.0, 124.0, 18.0),
	"DetailPreviewFrame": Rect2(752.0, 174.0, 340.0, 301.0),
	"DetailStatRows": Rect2(1124.0, 228.0, 260.0, 210.0),
	"DescriptionPanel": Rect2(752.0, 538.0, 638.0, 352.0),
	"PreviousPageFrame": Rect2(144.0, 846.0, 104.0, 68.0),
	"NextPageFrame": Rect2(624.0, 836.0, 94.0, 66.0),
}
const SLOT_SELECTED_TEXTURE := preload("res://assets/art/ui/training_menu_components/dungeon_slot_selected.png")
const SLOT_NORMAL_TEXTURE := preload("res://assets/art/ui/training_menu_components/dungeon_slot_normal.png")
const DOT_ACTIVE_TEXTURE := preload("res://assets/art/ui/training_menu_components/page_dot_active.png")
const DOT_INACTIVE_TEXTURE := preload("res://assets/art/ui/training_menu_components/page_dot_inactive.png")

const TRAINING_DUNGEONS := [
	{
		"id": &"training_test",
		"name": "测试训练 Test",
		"subtitle": "基础训练",
		"recommended_level": 1,
		"entry_gold": 0,
		"restriction": "完成角色初始化后可进入",
		"reward": "胜利获得 100 金钱",
		"description": "用于熟悉训练战斗的基础流程：查看费用、抽牌、出牌、拖拽攻击、获得护盾、结束回合并领取胜利奖励。\n\n推荐先用这个副本确认手牌费用和顶部费用槽是否同步变化，再测试攻击牌拖拽到目标时的结算反馈。后续这里会承载更完整的机制提示、可获得奖励和特殊限制。"
	}
]

@onready var slot_label: Label = $Overlay/BottomSummary/SlotLabel
@onready var gold_label: Label = $Overlay/BottomSummary/GoldLabel
@onready var level_label: Label = $Overlay/BottomSummary/LevelLabel
@onready var dungeon_list: Control = $Overlay/DungeonList
@onready var detail_title_label: Label = $Overlay/Detail/DetailTitleLabel
@onready var detail_subtitle_label: Label = $Overlay/Detail/DetailSubtitleLabel
@onready var requirement_label: Label = $Overlay/Detail/RequirementLabel
@onready var reward_label: Label = $Overlay/Detail/RewardLabel
@onready var description_scroll: ScrollContainer = $Overlay/Detail/DescriptionScroll
@onready var description_label: Label = $Overlay/Detail/DescriptionScroll/DescriptionLabel
@onready var enter_button: Button = $Overlay/Detail/EnterButton
@onready var status_label: Label = $Overlay/StatusLabel
@onready var components: Control = $Components
@onready var previous_page_button: Button = $Overlay/PreviousPageButton
@onready var next_page_button: Button = $Overlay/NextPageButton
@onready var page_dots: Array[Panel] = [
	$Overlay/PageDots/PageDot1,
	$Overlay/PageDots/PageDot2
]

var save_slot: int = 1
var snapshot: Dictionary = {}
var selected_index: int = 0
var current_page: int = 0
var dungeon_buttons: Array[Button] = []

func configure(slot: int, state_snapshot: Dictionary = {}) -> void:
	save_slot = clampi(slot, 1, SaveManager.SLOT_COUNT)
	snapshot = state_snapshot
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	resized.connect(_layout_cut_components)
	_layout_cut_components()
	_build_dungeon_list()
	_apply_enter_button_style()
	_refresh_page_controls()
	_refresh()

func _build_dungeon_list() -> void:
	for child in dungeon_list.get_children():
		child.queue_free()
	dungeon_buttons.clear()

	for slot in range(DUNGEONS_PER_PAGE):
		var button := Button.new()
		button.position = Vector2(0.0, float(DUNGEON_BUTTON_TOPS[slot]))
		button.size = DUNGEON_BUTTON_SIZE
		button.custom_minimum_size = button.size
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_dungeon_slot_pressed.bind(slot))
		dungeon_list.add_child(button)
		dungeon_buttons.append(button)

func _refresh() -> void:
	slot_label.text = "档位 %d" % save_slot
	gold_label.text = "金钱：%d" % _player_gold()
	level_label.text = "等级：%d" % _player_level()
	if TRAINING_DUNGEONS.is_empty():
		current_page = 0
		_refresh_page()
		_show_empty_page_detail()
	else:
		_select_dungeon(clampi(selected_index, 0, TRAINING_DUNGEONS.size() - 1))

func _select_dungeon(index: int) -> void:
	if not _is_valid_dungeon_index(index):
		return
	selected_index = index
	current_page = clampi(floori(float(selected_index) / float(DUNGEONS_PER_PAGE)), 0, PAGE_COUNT - 1)
	var dungeon: Dictionary = TRAINING_DUNGEONS[selected_index]
	_refresh_page()

	detail_title_label.text = str(dungeon["name"])
	detail_subtitle_label.text = str(dungeon["subtitle"])
	requirement_label.text = "消耗金币：%d" % int(dungeon["entry_gold"])
	reward_label.text = "推荐等级：%d\n奖励：%s" % [int(dungeon["recommended_level"]), str(dungeon["reward"])]
	description_label.text = str(dungeon["description"])
	description_scroll.scroll_vertical = 0

	var can_enter := _can_enter(dungeon)
	enter_button.disabled = not can_enter
	status_label.text = "选择副本后点击进入。" if can_enter else _get_block_reason(dungeon)

func _refresh_page() -> void:
	current_page = clampi(current_page, 0, PAGE_COUNT - 1)
	for slot in range(dungeon_buttons.size()):
		var button := dungeon_buttons[slot]
		var dungeon_index := current_page * DUNGEONS_PER_PAGE + slot
		var has_dungeon := _is_valid_dungeon_index(dungeon_index)
		var is_selected := has_dungeon and dungeon_index == selected_index
		button.button_pressed = is_selected
		button.disabled = not has_dungeon
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_dungeon else Control.CURSOR_ARROW
		if has_dungeon:
			button.text = _format_dungeon_button(TRAINING_DUNGEONS[dungeon_index])
		else:
			button.text = "  未开放\n  敬请期待"
		_apply_dungeon_button_style(button, is_selected, not has_dungeon)
	_refresh_page_controls()

func _refresh_page_controls() -> void:
	previous_page_button.disabled = current_page <= 0
	next_page_button.disabled = current_page >= PAGE_COUNT - 1
	_apply_page_button_style(previous_page_button)
	_apply_page_button_style(next_page_button)
	for index in range(page_dots.size()):
		var dot := page_dots[index]
		dot.add_theme_stylebox_override("panel", _make_dot_style(index == current_page))

func _show_empty_page_detail() -> void:
	detail_title_label.text = "暂无开放副本"
	detail_subtitle_label.text = "敬请期待"
	requirement_label.text = "消耗金币：-"
	reward_label.text = "推荐等级：-\n奖励：-"
	description_label.text = "这一页的训练副本还在准备中。"
	description_scroll.scroll_vertical = 0
	enter_button.disabled = true
	status_label.text = "这一页暂无可进入的训练副本。"

func _layout_cut_components() -> void:
	if components == null:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_VIEWPORT_SIZE
	var scale: float = max(viewport_size.x / SOURCE_CANVAS_SIZE.x, viewport_size.y / SOURCE_CANVAS_SIZE.y)
	var origin := (viewport_size - SOURCE_CANVAS_SIZE * scale) * 0.5
	for node_name: String in COMPONENT_SOURCE_RECTS.keys():
		var node := components.get_node_or_null(NodePath(node_name)) as TextureRect
		if node == null:
			continue
		var source_rect: Rect2 = COMPONENT_SOURCE_RECTS[node_name]
		var target_position := (origin + source_rect.position * scale).round()
		var target_size := (source_rect.size * scale).round()
		node.position = target_position
		node.size = target_size

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

func _on_dungeon_slot_pressed(slot: int) -> void:
	var dungeon_index := current_page * DUNGEONS_PER_PAGE + slot
	_select_dungeon(dungeon_index)

func _on_previous_page_button_pressed() -> void:
	_change_page(current_page - 1)

func _on_next_page_button_pressed() -> void:
	_change_page(current_page + 1)

func _change_page(page: int) -> void:
	var next_page := clampi(page, 0, PAGE_COUNT - 1)
	if next_page == current_page:
		return
	current_page = next_page
	var first_dungeon_on_page := current_page * DUNGEONS_PER_PAGE
	if _is_valid_dungeon_index(first_dungeon_on_page):
		selected_index = first_dungeon_on_page
		_select_dungeon(selected_index)
	else:
		_refresh_page()
		_show_empty_page_detail()

func _on_enter_button_pressed() -> void:
	if not _is_valid_dungeon_index(selected_index):
		status_label.text = "请选择一个可进入的训练副本。"
		return
	var dungeon: Dictionary = TRAINING_DUNGEONS[selected_index]
	if not _can_enter(dungeon):
		status_label.text = _get_block_reason(dungeon)
		return
	if dungeon["id"] == &"training_test":
		status_label.text = "进入测试训练 Test。"
		training_test_requested.emit()

func _on_back_button_pressed() -> void:
	back_requested.emit()

func _format_dungeon_button(dungeon: Dictionary) -> String:
	return "  %s\n  推荐等级 %d    消耗金币 %d" % [
		str(dungeon["name"]),
		int(dungeon["recommended_level"]),
		int(dungeon["entry_gold"])
	]

func _is_valid_dungeon_index(index: int) -> bool:
	return index >= 0 and index < TRAINING_DUNGEONS.size()

func _apply_dungeon_button_style(button: Button, is_selected: bool, is_empty: bool) -> void:
	var normal_style := _make_slot_style(SLOT_SELECTED_TEXTURE if is_selected else SLOT_NORMAL_TEXTURE)
	var hover_style := _make_slot_style(SLOT_SELECTED_TEXTURE)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("disabled", _make_slot_style(SLOT_NORMAL_TEXTURE))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.84, 0.90, 0.91, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.95, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.58, 0.60, 0.58))

func _apply_page_button_style(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_color_override("font_color", Color(0.85, 0.93, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.63, 0.96, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.34, 0.44, 0.46, 0.55))

func _apply_enter_button_style() -> void:
	enter_button.add_theme_stylebox_override("normal", _make_plain_button_style(Color(0.17, 0.45, 0.49, 0.92)))
	enter_button.add_theme_stylebox_override("hover", _make_plain_button_style(Color(0.22, 0.56, 0.60, 0.96)))
	enter_button.add_theme_stylebox_override("pressed", _make_plain_button_style(Color(0.12, 0.35, 0.39, 1.0)))
	enter_button.add_theme_stylebox_override("disabled", _make_plain_button_style(Color(0.10, 0.14, 0.16, 0.72)))
	enter_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	enter_button.add_theme_color_override("font_color", Color(0.94, 1.0, 1.0, 1.0))
	enter_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	enter_button.add_theme_color_override("font_pressed_color", Color(0.90, 1.0, 1.0, 1.0))
	enter_button.add_theme_color_override("font_disabled_color", Color(0.58, 0.65, 0.66, 0.75))

func _make_slot_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 24.0
	style.texture_margin_right = 56.0
	style.texture_margin_top = 12.0
	style.texture_margin_bottom = 12.0
	style.content_margin_left = 24.0
	style.content_margin_right = 68.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _make_plain_button_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	return style

func _make_dot_style(is_active: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = DOT_ACTIVE_TEXTURE if is_active else DOT_INACTIVE_TEXTURE
	return style
