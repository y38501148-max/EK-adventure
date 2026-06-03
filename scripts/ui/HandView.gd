extends HBoxContainer
class_name HandView

signal card_selected(card_id: int)

const CARD_VIEW_SCENE := preload("res://scenes/cards/CardView.tscn")

func render(cards: Array) -> void:
	for child in get_children():
		child.queue_free()

	for card in cards:
		var view := CARD_VIEW_SCENE.instantiate()
		add_child(view)
		view.render(card)
		view.card_selected.connect(_on_card_selected)

func _on_card_selected(card_id: int) -> void:
	card_selected.emit(card_id)
