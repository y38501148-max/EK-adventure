extends PanelContainer
class_name CardView

const CardDefinitionScript := preload("res://scripts/data/CardDefinition.gd")
const DRAG_START_DISTANCE := 8.0

signal card_selected(card_id: int)
signal card_drag_released(card_id: int, release_global_position: Vector2)

@onready var title_label: Label = $Margin/Rows/TopRow/TitleLabel
@onready var cost_label: Label = $Margin/Rows/TopRow/CostLabel
@onready var type_label: Label = $Margin/Rows/TypeLabel
@onready var description_label: Label = $Margin/Rows/DescriptionLabel

var instance: Variant
var _is_dragging := false
var _press_active := false
var _press_global_position := Vector2.ZERO
var _drag_origin_position := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _original_z_index := 0

func _ready() -> void:
	set_process(false)

func render(card: Variant, state: Variant = null) -> void:
	_ensure_node_refs()
	instance = card
	if card == null or card.definition == null:
		title_label.text = "未定义"
		cost_label.text = "-"
		type_label.text = "?"
		description_label.text = ""
		return

	title_label.text = card.definition.title
	cost_label.text = str(state.effective_card_cost(card) if state != null else card.display_cost())
	type_label.text = _type_text(card.definition.card_type, card.definition.algorithm_attribute)
	description_label.text = card.definition.description

func _ensure_node_refs() -> void:
	if title_label == null:
		title_label = $Margin/Rows/TopRow/TitleLabel
	if cost_label == null:
		cost_label = $Margin/Rows/TopRow/CostLabel
	if type_label == null:
		type_label = $Margin/Rows/TypeLabel
	if description_label == null:
		description_label = $Margin/Rows/DescriptionLabel

func _gui_input(event: InputEvent) -> void:
	if instance == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position := get_viewport().get_mouse_position()
		if event.pressed:
			_begin_press(mouse_position)
			accept_event()
		elif _is_dragging:
			_finish_drag(mouse_position)
			accept_event()
		elif _press_active:
			_press_active = false
			card_selected.emit(instance.runtime_id)
			accept_event()
	elif event is InputEventMouseMotion and _press_active:
		_maybe_start_drag(get_viewport().get_mouse_position())

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	var mouse_position := get_viewport().get_mouse_position()
	if event is InputEventMouseMotion:
		_update_drag(mouse_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(mouse_position)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _is_dragging:
		_update_drag(get_viewport().get_mouse_position())

func _begin_press(mouse_position: Vector2) -> void:
	_press_active = true
	_press_global_position = mouse_position
	_drag_origin_position = position
	_drag_offset = mouse_position - global_position

func _maybe_start_drag(mouse_position: Vector2) -> void:
	if mouse_position.distance_to(_press_global_position) < DRAG_START_DISTANCE:
		return
	_press_active = false
	_is_dragging = true
	_original_z_index = z_index
	z_index = 1000
	set_process(true)
	_update_drag(mouse_position)

func _update_drag(mouse_position: Vector2) -> void:
	global_position = mouse_position - _drag_offset

func _finish_drag(mouse_position: Vector2) -> void:
	if instance == null:
		_reset_drag_state()
		return
	var card_id: int = instance.runtime_id
	_reset_drag_state()
	card_drag_released.emit(card_id, mouse_position)

func _reset_drag_state() -> void:
	_press_active = false
	_is_dragging = false
	position = _drag_origin_position
	z_index = _original_z_index
	set_process(false)

func _type_text(card_type: int, algorithm_attribute: StringName) -> String:
	var base_type := ""
	match card_type:
		CardDefinitionScript.CardType.ATTACK:
			base_type = "攻击"
		CardDefinitionScript.CardType.BLOCK:
			base_type = "格挡"
		CardDefinitionScript.CardType.SKILL:
			base_type = "技能"
		CardDefinitionScript.CardType.POWER:
			base_type = "能力"
		CardDefinitionScript.CardType.EVENT:
			base_type = "事件"
		_:
			base_type = "未知"
	if algorithm_attribute == &"":
		return base_type
	return "%s / %s" % [base_type, algorithm_attribute]
