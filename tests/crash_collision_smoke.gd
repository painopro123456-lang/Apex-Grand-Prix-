extends SceneTree

const CarScript = preload("res://scripts/f1_car.gd")

## Exercises the real Godot physics collision path against a static barrier.
func _initialize() -> void:
	call_deferred("_run_crash_smoke")

func _run_crash_smoke() -> void:
	var car = CarScript.new()
	car.name = "CrashTestCar"
	var car_shape := CollisionShape3D.new()
	var car_box := BoxShape3D.new()
	car_box.size = Vector3(1.8, 0.8, 4.8)
	car_shape.shape = car_box
	car.add_child(car_shape)
	root.add_child(car)

	var barrier := StaticBody3D.new()
	barrier.name = "TestBarrier"
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(0.9, 3.0, 20.0)
	barrier_shape.shape = barrier_box
	barrier.add_child(barrier_shape)
	barrier.position = Vector3(6.0, 0.0, 0.0)
	root.add_child(barrier)

	await process_frame
	await physics_frame

	# Start close enough that one physics step produces a genuine body collision.
	car.global_position = Vector3(4.2, 0.0, 0.0)
	car._longitudinal_speed = 35.0
	car.velocity = Vector3(35.0, 0.0, 0.0)
	var incoming_velocity: Vector3 = car.velocity
	car.move_and_slide()
	if car.get_slide_collision_count() == 0:
		push_error("Crash smoke test: car did not physically collide with the barrier.")
		quit(1)
		return

	car._process_impact_collisions(incoming_velocity)
	if car.crash_damage <= 0.0:
		push_error("Crash smoke test: barrier impact did not add crash damage.")
		quit(1)
		return
	if car._longitudinal_speed >= 35.0:
		push_error("Crash smoke test: barrier impact did not reduce longitudinal speed.")
		quit(1)
		return
	if car.impact_cooldown <= 0.0:
		push_error("Crash smoke test: impact cooldown was not applied.")
		quit(1)
		return

	var moderate_damage: float = car.crash_damage
	var post_impact_speed: float = car._longitudinal_speed

	# A second severe impact must reach the retirement threshold.
	car.impact_cooldown = 0.0
	car._process_impact_collisions(Vector3(120.0, 0.0, 0.0))
	if not car.retired or car.crash_damage < 100.0:
		push_error("Crash smoke test: severe barrier impact did not retire the car.")
		quit(1)
		return
	if car._longitudinal_speed != 0.0 or car.velocity != Vector3.ZERO:
		push_error("Crash smoke test: retired car was not stopped.")
		quit(1)
		return

	print("CRASH SMOKE PASS: real barrier collision, damage (%.1f%%), speed loss (%.1f to %.1f m/s), impact cooldown and severe-impact retirement." % [moderate_damage, 35.0, post_impact_speed])
	quit(0)
