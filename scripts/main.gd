extends Node3D

const CarScript = preload("res://scripts/f1_car.gd")
const TrackScript = preload("res://scripts/oval_circuit.gd")

var car: CharacterBody3D
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

func _ready() -> void:
	_setup_input()
	_build_environment()
	var track := TrackScript.new()
	track.name = "TestCircuit"
	add_child(track)
	_build_car()
	_build_camera()
	_build_hud()
	_begin_start_sequence()

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_hud(delta)
	_update_start_sequence(delta)

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
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _build_car() -> void:
	car = CarScript.new()
	car.name = "PlayerCar"
	car.position = Vector3(105, 1.0, 0)
	car.rotation.y = PI
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.8, 4.8)
	collider.shape = shape
	car.add_child(collider)
	add_child(car)

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
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)

	var top_panel := _panel(root, Vector2(28, 24), Vector2(340, 100))
	var brand := _label(top_panel, "APEX  /  GRAND PRIX", 18, Color(0.93, 0.95, 1.0))
	brand.position = Vector2(18, 10)
	status_label = _label(top_panel, "TEST SESSION  •  OUT LAP", 12, Color(0.58, 0.72, 0.9))
	status_label.position = Vector2(18, 45)
	position_label = _label(top_panel, "P 01 / 01", 15, Color.WHITE)
	position_label.position = Vector2(220, 42)

	var speed_panel := _panel(root, Vector2(0, 0), Vector2(250, 112))
	speed_panel.anchor_left = 0.5
	speed_panel.anchor_right = 0.5
	speed_panel.anchor_top = 1.0
	speed_panel.anchor_bottom = 1.0
	speed_panel.position = Vector2(-125, -132)
	speed_label = _label(speed_panel, "000", 42, Color.WHITE)
	speed_label.position = Vector2(68, 10)
	var unit := _label(speed_panel, "KM/H", 12, Color(0.65, 0.76, 0.9))
	unit.position = Vector2(102, 62)

	telemetry_label = _label(root, "GEAR 1   RPM 4,200\nERS 100%   TYRES 82°C", 14, Color(0.88, 0.92, 0.98))
	telemetry_label.anchor_left = 1.0
	telemetry_label.anchor_right = 1.0
	telemetry_label.position = Vector2(-285, 82)

	race_time_label = _label(root, "00:00.000", 22, Color.WHITE)
	race_time_label.anchor_left = 1.0
	race_time_label.anchor_right = 1.0
	race_time_label.position = Vector2(-220, 30)

	countdown_label = _label(root, "", 68, Color.WHITE)
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_top = 0.28
	countdown_label.anchor_bottom = 0.28
	countdown_label.position = Vector2(-40, 0)
	countdown_label.size = Vector2(80, 90)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var lights_panel := _panel(root, Vector2(0, 0), Vector2(310, 68))
	lights_panel.anchor_left = 0.5
	lights_panel.anchor_right = 0.5
	lights_panel.position = Vector2(-155, 22)
	for i in range(5):
		var light := ColorRect.new()
		light.color = Color(0.18, 0.035, 0.045)
		light.size = Vector2(42, 42)
		light.position = Vector2(12 + i * 58, 13)
		lights_panel.add_child(light)
		start_lights.append(light)

func _panel(parent: Control, pos: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.065, 0.88)
	style.border_color = Color(0.24, 0.34, 0.47, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
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

func _update_hud(delta: float) -> void:
	if car == null:
		return
	if race_started:
		race_time += delta
	speed_label.text = "%03d" % int(car.speed_kmh)
	telemetry_label.text = "GEAR %d   RPM %05d\nERS %02d%%   TYRES %d°C   WEAR %d%%\nDRS %s" % [car.current_gear, int(car.engine_rpm), int(car.ers_charge), int(car.tyre_temperature), int(car.tyre_wear * 100.0), "OPEN" if car.drs_active else "CLOSED"]
	race_time_label.text = _format_time(race_time)
	if Input.is_action_just_pressed("reset_car"):
		car.reset_vehicle(Vector3(105, 1.0, 0), PI)

func _format_time(value: float) -> String:
	var minutes := int(value / 60.0)
	var seconds := fmod(value, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]
