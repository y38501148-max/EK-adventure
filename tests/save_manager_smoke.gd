extends SceneTree

const SaveManagerScript := preload("res://scripts/app/SaveManager.gd")

var _failed := false
var save_manager := SaveManagerScript.new()

func _init() -> void:
	save_manager.save_dir = "user://test_saves_save_manager_smoke"
	_run()
	quit(1 if _failed else 0)

func _run() -> void:
	var slot := save_manager.SLOT_COUNT
	save_manager.delete_save(slot)

	var profile_snapshot := {}
	save_manager.ensure_profile_defaults(profile_snapshot)
	_expect(int(profile_snapshot.get("owned_card_counts", {}).get("enumerate", 0)) == 10, "基础拥有卡组应包含 10 张枚举")
	_expect(profile_snapshot.get("deck_cards", []).size() == 10, "基础出战卡组应包含 10 张枚举")
	_expect(profile_snapshot.get("deck_slots", []).size() == 8, "记录功能应提供 8 个可切换卡组")

	var over_limit_deck: Array[String] = []
	for _index in range(24):
		over_limit_deck.append("enumerate")
	var over_limit_snapshot := {
		"owned_card_counts": {"enumerate": 24},
		"deck_slots": [over_limit_deck],
		"active_deck_index": 0
	}
	save_manager.ensure_profile_defaults(over_limit_snapshot)
	_expect(over_limit_snapshot.get("deck_cards", []).size() == 18, "每个卡组最多应保留 18 张初始手牌")

	var battle_snapshot := {
		"gold": 25,
		"level": 2,
		"player_health": 7,
		"player_max_health": 50,
		"encounter_id": "training_test",
		"has_won": false,
		"has_lost": false,
		"draw_pile": [],
		"hand": [{"runtime_id": 1}],
		"discard_pile": [],
		"exhaust_pile": []
	}
	save_manager.save_snapshot(slot, battle_snapshot)
	_expect(save_manager.has_unfinished_battle(slot), "未胜利/未失败且带牌堆数据的存档应识别为未完成战斗")

	save_manager.clear_unfinished_battle(slot)
	_expect(not save_manager.has_unfinished_battle(slot), "放弃未完成战斗后不应继续识别为战斗存档")
	var envelope := save_manager.load_snapshot(slot)
	var state: Dictionary = envelope.get("state", {})
	_expect(int(state.get("gold", 0)) == 25, "清理战斗数据应保留金钱")
	_expect(int(state.get("level", 0)) == 2, "清理战斗数据应保留等级")
	_expect(int(state.get("player_health", 0)) == 50, "清理战斗数据后应恢复生命")
	_expect(not state.has("encounter_id"), "清理战斗数据应移除副本标记")
	_expect(not state.has("hand"), "清理战斗数据应移除手牌")

	var finished_snapshot := battle_snapshot.duplicate(true)
	finished_snapshot["has_won"] = true
	save_manager.save_snapshot(slot, finished_snapshot)
	_expect(not save_manager.has_unfinished_battle(slot), "已胜利战斗不应提示恢复")

	save_manager.delete_save(slot)
	_expect(not save_manager.has_save(slot), "测试结束后应删除测试档")

	if not _failed:
		print("Save manager smoke passed.")
	save_manager.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
