extends SceneTree

func _initialize() -> void:
	call_deferred("_run_gameplay_smoke")

func _run_gameplay_smoke() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Gameplay smoke test: main scene could not be loaded.")
		quit(1)
		return

	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	var car := game.get("car") as F1CarController
	if car == null:
		push_error("Gameplay smoke test: player car was not created.")
		quit(1)
		return

	game.call("_enter_race")
	for frame in range(600):
		await physics_frame
		if bool(game.get("race_started")):
			break

	if not bool(game.get("race_started")):
		push_error("Gameplay smoke test: five-light start sequence did not reach lights out.")
		quit(1)
		return

	Input.action_press("accelerate")
	for frame in range(60):
		await physics_frame
	Input.action_release("accelerate")

	if car.speed_kmh < 10.0:
		push_error("Gameplay smoke test: car did not accelerate; speed was %.2f km/h." % car.speed_kmh)
		quit(1)
		return

	print("GAMEPLAY SMOKE PASS: main scene, race start and player acceleration. Speed: %.1f km/h" % car.speed_kmh)
	quit(0)
