extends Node

const GAME_TITLE := "爆炸蒟蒻历险记"
const HERO_NAME := "ExplodingKonjac"
const SAVE_SLOT := "user://exploding_konjac_save.json"

var master_volume: float = 1.0
var language: StringName = &"zh_CN"

func apply_defaults() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

