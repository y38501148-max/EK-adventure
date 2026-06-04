extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5
const DEFAULT_CARD_ID := "enumerate"
const DEFAULT_BASE_DECK_SIZE := 10
const DEFAULT_DECK_SLOT_COUNT := 8
const DEFAULT_MAX_DECK_SIZE := 18
const PROFILE_DEFAULTS := {
	"gold": 0,
	"level": 1,
	"experience": 0,
	"experience_to_next": 100,
	"player_max_health": 50,
	"player_health": 50
}
const BATTLE_STATE_KEYS := [
	"turn",
	"phase",
	"player_block",
	"player_energy",
	"hand_limit",
	"is_cheating",
	"has_lost",
	"has_won",
	"enemy_name",
	"enemy_max_health",
	"enemy_health",
	"enemy_algorithm_attribute",
	"enemy_action_countdown",
	"enemy_action_name",
	"enemy_attack",
	"enemy_base_attack",
	"enemy_actions",
	"enemy_action_index",
	"enemy_description",
	"encounter_id",
	"victory_gold_reward",
	"victory_reward_claimed",
	"next_card_id",
	"last_event_log",
	"draw_pile",
	"hand",
	"discard_pile",
	"exhaust_pile"
]

var save_dir: String = SAVE_DIR

func ensure_profile_defaults(snapshot: Dictionary) -> Dictionary:
	for key in PROFILE_DEFAULTS:
		if not snapshot.has(key):
			snapshot[key] = PROFILE_DEFAULTS[key]

	var owned_counts: Dictionary = _normalize_owned_card_counts(snapshot.get("owned_card_counts", {}))
	if int(owned_counts.get(DEFAULT_CARD_ID, 0)) < DEFAULT_BASE_DECK_SIZE:
		owned_counts[DEFAULT_CARD_ID] = DEFAULT_BASE_DECK_SIZE
	snapshot["owned_card_counts"] = owned_counts

	var legacy_deck: Array[String] = _normalize_deck_cards(snapshot.get("deck_cards", []), owned_counts)
	var deck_slots: Array = _normalize_deck_slots(snapshot.get("deck_slots", []), owned_counts, legacy_deck)
	var active_index := clampi(int(snapshot.get("active_deck_index", 0)), 0, deck_slots.size() - 1)
	snapshot["active_deck_index"] = active_index
	snapshot["deck_slots"] = deck_slots
	snapshot["deck_cards"] = deck_slots[active_index].duplicate()
	return snapshot

func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))

func has_unfinished_battle(slot: int = 1) -> bool:
	var envelope := load_snapshot(slot)
	if envelope.is_empty():
		return false
	var state: Dictionary = envelope.get("state", {})
	if state.is_empty():
		return false
	return _is_unfinished_battle_state(state)

func save_snapshot(slot: int, snapshot: Dictionary) -> void:
	_ensure_save_dir()
	ensure_profile_defaults(snapshot)
	var envelope := {
		"version": 1,
		"slot": clampi(slot, 1, SLOT_COUNT),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_text": Time.get_datetime_string_from_system(false, true),
		"state": snapshot
	}
	var file := FileAccess.open(get_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: %s" % get_slot_path(slot))
		return
	file.store_string(JSON.stringify(envelope, "\t"))

func load_snapshot(slot: int = 1) -> Dictionary:
	if not has_save(slot):
		return {}

	var file := FileAccess.open(get_slot_path(slot), FileAccess.READ)
	if file == null:
		push_error("无法读取存档: %s" % get_slot_path(slot))
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func clear_unfinished_battle(slot: int = 1) -> void:
	var envelope := load_snapshot(slot)
	if envelope.is_empty():
		delete_save(slot)
		return
	var state: Dictionary = envelope.get("state", {})
	if state.is_empty():
		delete_save(slot)
		return
	var max_health := int(state.get("player_max_health", state.get("player_health", 50)))
	for key in BATTLE_STATE_KEYS:
		state.erase(key)
	state["player_max_health"] = max_health
	state["player_health"] = max_health
	save_snapshot(slot, state)

func delete_save(slot: int = 1) -> void:
	if not has_save(slot):
		return
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return
	dir.remove(get_slot_path(slot).get_file())

func get_slot_summary(slot: int) -> Dictionary:
	var envelope := load_snapshot(slot)
	if envelope.is_empty():
		return {
			"slot": slot,
			"has_save": false,
			"title": "空档位",
			"detail": "无存档"
		}

	var state: Dictionary = envelope.get("state", {})
	ensure_profile_defaults(state)
	var battle_prefix := "未完成战斗  " if _is_unfinished_battle_state(state) else ""
	return {
		"slot": slot,
		"has_save": true,
		"title": "档位 %d  等级 %d  金钱 %d" % [
			slot,
			int(state.get("level", 1)),
			int(state.get("gold", 0))
		],
		"detail": "%s%s  生命 %d/%d  %s" % [
			battle_prefix,
			str(envelope.get("saved_at_text", "")),
			int(state.get("player_health", 0)),
			int(state.get("player_max_health", 0)),
			str(state.get("enemy_name", ""))
		]
	}

func get_slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, clampi(slot, 1, SLOT_COUNT)]

func _ensure_save_dir() -> void:
	var dir := DirAccess.open(save_dir)
	if dir != null:
		return
	var error := DirAccess.make_dir_recursive_absolute(save_dir)
	if error != OK:
		push_error("无法创建存档目录: %s" % save_dir)

func _normalize_owned_card_counts(raw_counts: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if not raw_counts is Dictionary:
		return counts
	for key in raw_counts:
		var count: int = max(0, int(raw_counts[key]))
		if count > 0:
			counts[str(key)] = count
	return counts

func _normalize_deck_cards(raw_deck: Variant, owned_counts: Dictionary) -> Array[String]:
	var deck: Array[String] = []
	if not raw_deck is Array:
		return deck

	var used_counts: Dictionary = {}
	for raw_card_id in raw_deck:
		if deck.size() >= DEFAULT_MAX_DECK_SIZE:
			break
		var card_id := str(raw_card_id)
		if card_id == "":
			continue
		var owned := int(owned_counts.get(card_id, 0))
		var used := int(used_counts.get(card_id, 0))
		if used >= owned:
			continue
		deck.append(card_id)
		used_counts[card_id] = used + 1
	return deck

func _normalize_deck_slots(raw_slots: Variant, owned_counts: Dictionary, fallback_deck: Array[String]) -> Array:
	var slots: Array = []
	if raw_slots is Array:
		for raw_slot in raw_slots:
			var deck := _normalize_deck_cards(raw_slot, owned_counts)
			if deck.is_empty():
				deck = _make_default_deck()
			slots.append(deck)

	while slots.size() < DEFAULT_DECK_SLOT_COUNT:
		var default_deck := fallback_deck.duplicate() if not fallback_deck.is_empty() else _make_default_deck()
		slots.append(default_deck)

	if slots.size() > DEFAULT_DECK_SLOT_COUNT:
		slots.resize(DEFAULT_DECK_SLOT_COUNT)
	return slots

func _make_default_deck() -> Array[String]:
	var deck: Array[String] = []
	for _index in range(DEFAULT_BASE_DECK_SIZE):
		deck.append(DEFAULT_CARD_ID)
	return deck

func _is_unfinished_battle_state(state: Dictionary) -> bool:
	return (
		state.has("encounter_id")
		and not bool(state.get("has_won", false))
		and not bool(state.get("has_lost", false))
		and (
			state.has("draw_pile")
			or state.has("hand")
			or state.has("discard_pile")
			or state.has("exhaust_pile")
		)
	)
