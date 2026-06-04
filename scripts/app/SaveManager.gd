extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 5
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
