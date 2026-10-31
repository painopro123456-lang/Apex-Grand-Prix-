extends Node3D

const CarScript = preload("res://scripts/f1_car.gd")
const TrackScript = preload("res://scripts/oval_circuit.gd")

var car: F1CarController
var camera: Camera3D
var hud: CanvasLayer
var countdown_label: Label
var status_label: Label
var speed_label: Label
var position_label: Label
var race_time_label: Label
var telemetry_label: Label
var start_lights: Array[ColorRect] = []
var countdown_step: int = -1
var countdown_timer: float = 0.0
var race_started: bool = false
var race_time: float = 0.0
var lap_number: int = 0
var lap_time: float = 0.0
var best_lap_time: float = 0.0
var last_car_position: Vector3 = Vector3.ZERO
var lap_label: Label
var best_lap_label: Label

func _ready() -> void:
	_setup_input()
	_build_environment()
	var track := TrackScript.new()
	track.name = "TestCircuit"
	add_child(track)
	_build_car()
	_build_camera()
	_build_hud()
	last_car_position = car.global_position
	_begin_start_sequence()

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud(delta)
	_update_start_sequence(delta)
	_update_lap_detection(delta)

func _setup_input() -> void:
	_add_key_action("accelerate", KEY_W)
	_add_key_action("accelerate", KEY_UP)
	_add_key_action("brake", KEY_S)
	_add_key_action("brake", KEY_DOWN)
	_add_key_action("steer_left", KEY_A)
	_add_key_action("steer_left", KEY_LEFT)
	_add_key_action("steer_right", KEY_D)
	_add_key_action("steer_right", KEY_RIGHT)
	_add_key_action("handbrake", KEY_SPACE)
	_add_key_action("reset_car", KEY_R)
	_add_key_action("drs", KEY_F)
	_add_key_action("ers_deploy", KEY_E)

func _add_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.14, 0.25)
	sky_material.sky_horizon_color = Color(0.52, 0.58, 0.66)
	sky_material.ground_bottom_color = Color(0.08, 0.09, 0.1)
	sky_material.ground_horizon_color = Color(0.32, 0.34, 0.36)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_strength = 0.7
	environment.glow_bloom = 0.08
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.06
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _build_car() -> void:
	car = CarScript.new()
	car.name = "PlayerCar"
	car.position = Vector3(105, 1.0, -8)
	car.rotation.y = PI
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.8, 4.8)
	collider.shape = shape
	car.add_child(collider)
	add_child(car)
	car.set_physics_process(false)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.current = true
	camera.fov = 72.0
	add_child(camera)
	camera.global_position = car.global_position + Vector3(0, 7, 13)
	camera.look_at(car.global_position + Vector3(0, 1.2, 0), Vector3.UP)

func _update_camera(delta: float) -> void:
	if car == null or camera == null:
		return
	var forward := -car.global_transform.basis.z
	var target_position := car.global_position - forward * 11.0 + Vector3.UP * 5.0
	camera.global_position = camera.global_position.lerp(target_position, 1.0 - exp(-5.0 * delta))
	camera.look_at(car.global_position + forward * 5.0 + Vector3.UP * 1.0, Vector3.UP)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	# Top-left identity and session card.
	var identity := _panel(root, Vector2(28, 24), Vector2(360, 112))
	_accent_bar(identity, Vector2(0, 0), Vector2(4, 112), Color(0.12, 0.72, 1.0))
	var brand := _label(identity, "APEX", 25, Color(0.96, 0.98, 1.0))
	brand.position = Vector2(20, 12)
	brand.add_theme_color_override("font_shadow_color", Color(0.1, 0.55, 1.0, 0.35))
	brand.add_theme_constant_override("shadow_offset_x", 0)
	brand.add_theme_constant_override("shadow_offset_y", 1)
	var subtitle := _label(identity, "GRAND PRIX  /  MOTORSPORT", 10, Color(0.48, 0.72, 0.9))
	subtitle.position = Vector2(94, 23)
	status_label = _label(identity, "●  TEST SESSION     OUT LAP", 12, Color(0.55, 0.88, 1.0))
	status_label.position = Vector2(20, 67)
	position_label = _label(identity, "P 01", 23, Color.WHITE)
	position_label.position = Vector2(292, 15)
	position_label.size = Vector2(54, 32)
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pos_caption := _label(identity, "POSITION", 9, Color(0.48, 0.58, 0.7))
	pos_caption.position = Vector2(286, 48)
	pos_caption.size = Vector2(60, 16)
	pos_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Race control / timing card in the upper-right.
	var timing := _panel(root, Vector2(0, 24), Vector2(258, 126))
	timing.anchor_left = 1.0
	timing.anchor_right = 1.0
	timing.position.x = -286
	_accent_bar(timing, Vector2(254, 0), Vector2(4, 126), Color(1.0, 0.24, 0.19))
	var timing_title := _label(timing, "RACE CONTROL", 10, Color(0.55, 0.68, 0.82))
	timing_title.position = Vector2(18, 10)
	race_time_label = _label(timing, "00:00.000", 27, Color.WHITE)
	race_time_label.position = Vector2(16, 28)
	lap_label = _label(timing, "LAP  0 / 5", 13, Color(0.83, 0.9, 1.0))
	lap_label.position = Vector2(18, 75)
	best_lap_label = _label(timing, "BEST  --:--.---", 11, Color(0.35, 0.78, 1.0))
	best_lap_label.position = Vector2(18, 99)

	# Central start-light gantry.
	var lights_panel := _panel(root, Vector2(0, 22), Vector2(326, 74))
	lights_panel.anchor_left = 0.5
	lights_panel.anchor_right = 0.5
	lights_panel.position.x = -163
	var gantry_title := _label(lights_panel, "START  /  LIGHTS", 9, Color(0.56, 0.68, 0.82))
	gantry_title.position = Vector2(14, 5)
	for i in range(5):
		var light := ColorRect.new()
		light.color = Color(0.12, 0.025, 0.035)
		light.position = Vector2(17 + i * 60, 28)
		light.size = Vector2(43, 31)
		var light_style := StyleBoxFlat.new()
		light_style.bg_color = Color(0.12, 0.025, 0.035)
		light_style.set_corner_radius_all(8)
		light.add_theme_stylebox_override("panel", light_style)
		lights_panel.add_child(light)
		start_lights.append(light)

	# Bottom-center speed instrument.
	var speed_panel := _panel(root, Vector2(0, 0), Vector2(286, 124))
	speed_panel.anchor_left = 0.5
	speed_panel.anchor_right = 0.5
	speed_panel.anchor_top = 1.0
	speed_panel.anchor_bottom = 1.0
	speed_panel.position = Vector2(-143, -150)
	_accent_bar(speed_panel, Vector2(0, 0), Vector2(286, 3), Color(0.08, 0.68, 1.0))
	var speed_caption := _label(speed_panel, "LIVE SPEED", 9, Color(0.5, 0.68, 0.82))
	speed_caption.position = Vector2(18, 12)
	speed_label = _label(speed_panel, "000", 58, Color.WHITE)
	speed_label.position = Vector2(17, 23)
	speed_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.45, 0.9, 0.28))
	speed_label.add_theme_constant_override("shadow_offset_y", 2)
	var unit := _label(speed_panel, "KM/H", 12, Color(0.36, 0.78, 1.0))
	unit.position = Vector2(148, 61)
	var speed_note := _label(speed_panel, "FULL THROTTLE  /  RACE MODE", 8, Color(0.42, 0.52, 0.64))
	speed_note.position = Vector2(18, 98)

	# Telemetry card, lower-right.
	var telemetry_panel := _panel(root, Vector2(0, 0), Vector2(258, 116))
	telemetry_panel.anchor_left = 1.0
	telemetry_panel.anchor_right = 1.0
	telemetry_panel.anchor_top = 1.0
	telemetry_panel.anchor_bottom = 1.0
	telemetry_panel.position = Vector2(-286, -150)
	_accent_bar(telemetry_panel, Vector2(254, 0), Vector2(4, 116), Color(0.08, 0.68, 1.0))
	var telemetry_title := _label(telemetry_panel, "VEHICLE TELEMETRY", 9, Color(0.5, 0.68, 0.82))
	telemetry_title.position = Vector2(16, 10)
	telemetry_label = _label(telemetry_panel, "GEAR 1    RPM 4,200\nERS 100%    TYRES 82°C\nDRS CLOSED", 12, Color(0.9, 0.94, 1.0))
	telemetry_label.position = Vector2(16, 31)

	countdown_label = _label(root, "", 72, Color.WHITE)
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_top = 0.34
	countdown_label.anchor_bottom = 0.34
	countdown_label.position = Vector2(-100, 0)
	countdown_label.size = Vector2(200, 100)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.4, 0.9, 0.65))
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)

func _accent_bar(parent: Control, pos: Vector2, bar_size: Vector2, tint: Color) -> void:
	var bar := ColorRect.new()
	bar.position = pos
	bar.size = bar_size
	bar.color = tint
	parent.add_child(bar)

func _panel(parent: Control, pos: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.025, 0.045, 0.91)
	style.border_color = Color(0.18, 0.34, 0.48, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _begin_start_sequence() -> void:
	countdown_step = 0
	countdown_timer = 0.0
	countdown_label.text = "READY"

func _update_start_sequence(delta: float) -> void:
	if race_started:
		return
	countdown_timer += delta
	if countdown_timer < 1.0:
		return
	countdown_timer = 0.0
	countdown_step += 1
	if countdown_step <= 5:
		start_lights[countdown_step - 1].color = Color(0.95, 0.035, 0.045)
		countdown_label.text = str(countdown_step)
	else:
		for light in start_lights:
			light.color = Color(0.16, 0.95, 0.48)
		countdown_label.text = "GO!"
		status_label.text = "RACE SESSION  •  LIGHTS OUT"
		race_started = true
		race_time = 0.0
		car.set_physics_process(true)

func _update_hud(delta: float) -> void:
	if car == null:
		return
	if race_started:
		race_time += delta
		if lap_number > 0:
			lap_time += delta
	speed_label.text = "%03d" % int(car.speed_kmh)
	telemetry_label.text = "GEAR %d   RPM %05d\nERS %02d%%   TYRES %d°C   WEAR %d%%\nDRS %s" % [car.current_gear, int(car.engine_rpm), int(car.ers_charge), int(car.tyre_temperature), int(car.tyre_wear * 100.0), "OPEN" if car.drs_active else "CLOSED"]
	race_time_label.text = _format_time(race_time)
	lap_label.text = "LAP  %d / 5" % lap_number
	best_lap_label.text = "BEST  %s" % (_format_time(best_lap_time) if best_lap_time > 0.0 else "--:--.---")
	if Input.is_action_just_pressed("reset_car"):
		car.reset_vehicle(Vector3(105, 1.0, -8), PI)
		last_car_position = car.global_position

func _format_time(value: float) -> String:
	var minutes := int(value / 60.0)
	var seconds := fmod(value, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]

func _update_lap_detection(delta: float) -> void:
	if car == null:
		return
	var current_position := car.global_position
	if race_started and last_car_position.z < 0.0 and current_position.z >= 0.0 and current_position.x > 92.0 and current_position.x < 132.0:
		if lap_number > 0 and lap_time > 5.0:
			if best_lap_time <= 0.0 or lap_time < best_lap_time:
				best_lap_time = lap_time
			lap_time = 0.0
		lap_number += 1
	last_car_position = current_position
