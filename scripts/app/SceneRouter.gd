extends Node

signal scene_change_requested(scene_path: String)

var current_scene_path: String = ""

func request_scene(scene_path: String) -> void:
	current_scene_path = scene_path
	scene_change_requested.emit(scene_path)

