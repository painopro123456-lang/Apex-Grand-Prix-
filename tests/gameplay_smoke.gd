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

	var frontend := game.get("frontend_root") as Control
	var team_picker := game.get("team_picker") as OptionButton
	var driver_picker := game.get("driver_picker") as OptionButton
	if frontend == null or team_picker == null or driver_picker == null:
		push_error("Gameplay smoke test: garage/front-end controls were not created.")
		quit(1)
		return
	if team_picker.item_count != 11 or driver_picker.item_count != 2:
		push_error("Gameplay smoke test: expected 11 teams and 2 drivers in the selected team.")
		quit(1)
		return
	game.call("_show_frontend_page", "garage")
	if not bool(frontend.get_node("GaragePage").visible):
		push_error("Gameplay smoke test: garage page did not open.")
		quit(1)
		return
	game.call("_show_frontend_page", "settings")
	if not bool(frontend.get_node("SettingsPage").visible):
		push_error("Gameplay smoke test: settings page did not open.")
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
	var acceleration_speed := car.speed_kmh

	Input.action_press("drs")
	Input.action_press("ers_deploy")
	for frame in range(30):
		await physics_frame
	Input.action_release("drs")
	Input.action_release("ers_deploy")
	if not car.drs_active or car.ers_charge >= 100.0:
		push_error("Gameplay smoke test: DRS or ERS deployment did not activate.")
		quit(1)
		return
	if car.tyre_wear <= 0.0:
		push_error("Gameplay smoke test: tyre wear did not update.")
		quit(1)
		return

	var speed_before_braking := car.speed_kmh
	Input.action_press("brake")
	for frame in range(30):
		await physics_frame
	Input.action_release("brake")
	if car.speed_kmh >= speed_before_braking:
		push_error("Gameplay smoke test: service braking did not reduce speed.")
		quit(1)
		return

	game.set("lap_number", 1)
	game.set("lap_time", 62.5)
	game.set("last_car_position", Vector3(105.0, car.global_position.y, -1.0))
	car.global_position = Vector3(105.0, car.global_position.y, 1.0)
	game.call("_update_lap_detection", 1.0 / 60.0)
	if int(game.get("lap_number")) != 2:
		push_error("Gameplay smoke test: start/finish crossing did not increment the lap.")
		quit(1)
		return
	if absf(float(game.get("best_lap_time")) - 62.5) > 0.01:
		push_error("Gameplay smoke test: best-lap timing did not record.")
		quit(1)
		return

	car.reset_vehicle(Vector3(105.0, 1.0, -8.0), PI)
	if car.speed_kmh > 0.1 or car.crash_damage > 0.0 or car.retired:
		push_error("Gameplay smoke test: vehicle reset did not restore the car state.")
		quit(1)
		return

	print("GAMEPLAY SMOKE PASS: front end, garage/settings navigation, roster, five-light start, acceleration (%.1f km/h), DRS, ERS, tyre wear, braking, lap/best-lap gate and reset." % acceleration_speed)
	quit(0)
