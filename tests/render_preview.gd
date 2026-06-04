extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var preview_target := OS.get_environment("GAME1_PREVIEW_TARGET")
	var is_training_menu := preview_target == "training_menu"
	var scene_path := "res://scenes/home/TrainingMenu.tscn" if is_training_menu else "res://scenes/game/GameRoot.tscn"
	var scene: PackedScene = load(scene_path)
	var instance := scene.instantiate()
	root.add_child(instance)
	if instance.has_method("configure"):
		instance.configure(1, {"gold": 0, "level": 1, "experience": 0, "experience_to_next": 100})
	await process_frame
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("Preview capture is unavailable with the current rendering backend.")
		quit(1)
		return
	var image := texture.get_image()
	var output_path := "res://.preview_training_menu.png" if is_training_menu else "res://.preview_battle.png"
	image.save_png(output_path)
	quit()
