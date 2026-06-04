extends Control
class_name HandView

signal card_selected(card_id: int)
signal card_drag_released(card_id: int, release_global_position: Vector2)

const CARD_VIEW_SCENE := preload("res://scenes/cards/CardView.tscn")
const CARD_SIZE := Vector2(170.0, 180.0)
const RELAXED_GAP := 12.0
const MIN_OVERLAP_STEP := 64.0

func render(cards: Array, state: Variant = null) -> void:
	for child in get_children():
		child.queue_free()

	var step: float = _card_step(cards.size())
	for index in range(cards.size()):
		var card: Variant = cards[index]
		var view := CARD_VIEW_SCENE.instantiate()
		add_child(view)
		view.custom_minimum_size = CARD_SIZE
		view.size = CARD_SIZE
		view.position = Vector2(float(index) * step, 0.0)
		view.z_index = index
		view.render(card, state)
		view.card_selected.connect(_on_card_selected)
		view.card_drag_released.connect(_on_card_drag_released)

func _on_card_selected(card_id: int) -> void:
	card_selected.emit(card_id)

func _on_card_drag_released(card_id: int, release_global_position: Vector2) -> void:
	card_drag_released.emit(card_id, release_global_position)

func _card_step(card_count: int) -> float:
	if card_count <= 1:
		return CARD_SIZE.x + RELAXED_GAP
	var relaxed_step: float = CARD_SIZE.x + RELAXED_GAP
	var available_width: float = maxf(CARD_SIZE.x, size.x)
	var compressed_step: float = (available_width - CARD_SIZE.x) / float(card_count - 1)
	if card_count <= 5:
		return min(relaxed_step, max(CARD_SIZE.x * 0.86, compressed_step))
	return clampf(compressed_step, MIN_OVERLAP_STEP, relaxed_step)
