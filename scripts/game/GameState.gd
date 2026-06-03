extends RefCounted
class_name GameState

const CardInstanceStateScript := preload("res://scripts/game/CardInstanceState.gd")

signal phase_changed(phase: int)
signal state_changed

enum Phase { SETUP, DRAW, MAIN, TARGETING, RESOLVE, END, GAME_OVER }

var seed: int = 0
var rng := RandomNumberGenerator.new()
var phase: int = Phase.SETUP
var turn: int = 0
var player_health: int = 80
var player_energy: int = 3
var max_energy: int = 3
var next_card_id: int = 1
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

func setup(config: Resource) -> void:
	seed = config.seed
	player_health = config.starting_health
	max_energy = config.starting_energy
	player_energy = max_energy
	rng.seed = seed
	turn = 0
	next_card_id = 1
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()

	for definition in config.starting_deck:
		var card := CardInstanceStateScript.new(next_card_id, definition)
		next_card_id += 1
		draw_pile.append(card)

	_shuffle_draw_pile()
	_set_phase(Phase.SETUP)
	state_changed.emit()

func begin_turn() -> void:
	turn += 1
	player_energy = max_energy
	_set_phase(Phase.DRAW)
	draw_cards(5)
	_set_phase(Phase.MAIN)
	state_changed.emit()

func end_turn() -> void:
	_set_phase(Phase.END)
	for card in hand:
		card.zone = &"discard_pile"
		discard_pile.append(card)
	hand.clear()
	state_changed.emit()

func draw_cards(amount: int) -> void:
	for _index in range(amount):
		if draw_pile.is_empty():
			_refill_draw_pile()
		if draw_pile.is_empty():
			break

		var card: Variant = draw_pile.pop_back()
		card.zone = &"hand"
		hand.append(card)

func can_play_card(card_id: int) -> bool:
	var card: Variant = get_hand_card(card_id)
	return card != null and phase == Phase.MAIN and player_energy >= card.display_cost()

func play_card(card_id: int, targets: Array[int] = []) -> bool:
	var card: Variant = get_hand_card(card_id)
	if card == null or not can_play_card(card_id):
		return false

	player_energy -= card.display_cost()
	for effect in card.definition.effects:
		if effect.can_apply(self, card_id, targets):
			effect.apply(self, card_id, targets)

	hand.erase(card)
	card.zone = &"discard_pile"
	discard_pile.append(card)
	state_changed.emit()
	return true

func get_hand_card(card_id: int) -> Variant:
	for card in hand:
		if card.runtime_id == card_id:
			return card
	return null

func to_snapshot() -> Dictionary:
	return {
		"seed": seed,
		"turn": turn,
		"phase": phase,
		"player_health": player_health,
		"player_energy": player_energy,
		"draw_pile_count": draw_pile.size(),
		"hand_count": hand.size(),
		"discard_pile_count": discard_pile.size(),
		"exhaust_pile_count": exhaust_pile.size()
	}

func _refill_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle_draw_pile()

func _shuffle_draw_pile() -> void:
	if draw_pile.size() < 2:
		return
	for index in range(draw_pile.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current: Variant = draw_pile[index]
		draw_pile[index] = draw_pile[swap_index]
		draw_pile[swap_index] = current

func _set_phase(next_phase: int) -> void:
	phase = next_phase
	phase_changed.emit(phase)
