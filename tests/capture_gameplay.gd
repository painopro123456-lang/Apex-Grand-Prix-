extends SceneTree

func _initialize() -> void:
	call_deferred("_capture_gameplay")

func _capture_gameplay() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Gameplay screenshot: main scene could not be loaded.")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	root.size = Vector2i(1600, 900)
	game.call("_enter_race")
	var started := false
	for frame in range(600):
		await process_frame
		await physics_frame
		if bool(game.get("race_started")):
			started = true
			break
	if not started:
		push_error("Gameplay screenshot: race start sequence did not complete.")
		quit(1)
		return
	Input.action_press("accelerate")
	for frame in range(36):
		await physics_frame
	Input.action_release("accelerate")
	for frame in range(8):
		await process_frame
	var screenshot := root.get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		push_error("Gameplay screenshot: viewport image was empty.")
		quit(1)
		return
	var save_error := screenshot.save_png("/tmp/apex-gameplay.png")
	if save_error != OK:
		push_error("Gameplay screenshot: unable to save image.")
		quit(1)
		return
	print("GAMEPLAY SCREENSHOT SAVED: /tmp/apex-gameplay.png")
	quit(0)
