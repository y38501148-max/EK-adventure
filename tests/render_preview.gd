extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var preview_target := OS.get_environment("GAME1_PREVIEW_TARGET")
	var scene_path := "res://scenes/game/GameRoot.tscn"
	var output_path := "res://.preview_battle.png"
	if preview_target == "training_menu":
		scene_path = "res://scenes/home/TrainingMenu.tscn"
		output_path = "res://.preview_training_menu.png"
	elif preview_target == "record_deck_config":
		scene_path = "res://scenes/home/RecordDeckConfig.tscn"
		output_path = "res://.preview_record_deck_config.png"
	var scene: PackedScene = load(scene_path)
	var instance := scene.instantiate()
	root.add_child(instance)
	if instance.has_method("configure"):
		var snapshot := {
			"gold": 0,
			"level": 1,
			"experience": 0,
			"experience_to_next": 100,
			"active_deck_index": 0,
			"owned_card_counts": {"enumeration": 10},
			"deck_slots": [
				["enumeration", "enumeration", "enumeration", "enumeration", "enumeration"],
				[],
				[],
				[],
				[],
				[],
				[],
				[]
			],
			"deck_cards": ["enumeration", "enumeration", "enumeration", "enumeration", "enumeration"]
		}
		instance.configure(1, snapshot)
	await process_frame
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("Preview capture is unavailable with the current rendering backend.")
		quit(1)
		return
	var image := texture.get_image()
	image.save_png(output_path)
	quit()
