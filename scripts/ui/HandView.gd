extends Control
class_name HandView

signal card_selected(card_id: int)
signal card_drag_released(card_id: int, release_global_position: Vector2)

const CARD_VIEW_SCENE := preload("res://scenes/cards/CardView.tscn")
const CARD_SIZE := Vector2(170.0, 180.0)
const RELAXED_GAP := 12.0
const MIN_OVERLAP_STEP := 64.0

func render(
	cards: Array,
	state: Variant = null,
	animated_card_ids: Array[int] = [],
	animation_origin_global: Vector2 = Vector2.INF
) -> void:
	for child in get_children():
		child.queue_free()

	var step: float = _card_step(cards.size())
	for index in range(cards.size()):
		var card: Variant = cards[index]
		var view := CARD_VIEW_SCENE.instantiate()
		add_child(view)
		view.custom_minimum_size = CARD_SIZE
		view.size = CARD_SIZE
		var final_position := Vector2(float(index) * step, 0.0)
		view.position = final_position
		view.z_index = index
		view.render(card, state)
		view.card_selected.connect(_on_card_selected)
		view.card_drag_released.connect(_on_card_drag_released)
		if animated_card_ids.has(card.runtime_id) and animation_origin_global != Vector2.INF:
			_animate_card_entry(view, final_position, animation_origin_global, index)

func get_card_global_center(card_id: int) -> Vector2:
	for child in get_children():
		if child is CardView and child.instance != null and child.instance.runtime_id == card_id:
			return child.get_global_rect().get_center()
	return get_global_rect().get_center()

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

func _animate_card_entry(view: Control, final_position: Vector2, origin_global: Vector2, index: int) -> void:
	view.pivot_offset = CARD_SIZE * 0.5
	view.position = origin_global - get_global_rect().position - CARD_SIZE * 0.5
	view.scale = Vector2(0.42, 0.42)
	view.modulate.a = 0.15

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(view, "position", final_position, 0.34).set_delay(0.045 * float(index)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "scale", Vector2.ONE, 0.34).set_delay(0.045 * float(index)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate:a", 1.0, 0.18).set_delay(0.045 * float(index))
