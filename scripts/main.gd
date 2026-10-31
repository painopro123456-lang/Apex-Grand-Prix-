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
var frontend_layer: CanvasLayer
var frontend_root: Control
var frontend_page: String = "home"
var frontend_page_title: Label
var frontend_page_body: Label
var garage_status: Label
var selected_garage_item: String = "APEX GP-01"

func _ready() -> void:
	_setup_input()
	_build_environment()
	var track := TrackScript.new()
	track.name = "TestCircuit"
	add_child(track)
	_build_car()
	_build_camera()
	_build_hud()
	_build_frontend()
	hud.visible = false
	last_car_position = car.global_position
	# The player enters the race from the front end, not automatically.\n\nfunc _process(delta: float) -> void:
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


# --- Premium front end: home, race weekend and garage ---
func _build_frontend() -> void:
	frontend_layer = CanvasLayer.new()
	frontend_layer.layer = 20
	add_child(frontend_layer)
	frontend_root = Control.new()
	frontend_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend_layer.add_child(frontend_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.025, 0.037, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend_root.add_child(backdrop)

	# Restrained motorsport-red signature stripe; the screen itself stays neutral.
	var top_rule := ColorRect.new()
	top_rule.color = Color(0.88, 0.12, 0.13)
	top_rule.position = Vector2(0, 0)
	top_rule.size = Vector2(420, 4)
	frontend_root.add_child(top_rule)

	var header := Panel.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 42
	header.offset_right = -42
	header.offset_top = 22
	header.offset_bottom = 88
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.035, 0.047, 0.064, 0.96)
	header_style.border_color = Color(0.18, 0.22, 0.28, 0.8)
	header_style.set_border_width_all(1)
	header_style.set_corner_radius_all(7)
	header.add_theme_stylebox_override("panel", header_style)
	frontend_root.add_child(header)

	var logo := _label(header, "APEX", 25, Color(0.96, 0.97, 0.99))
	logo.position = Vector2(22, 12)
	var logo_sub := _label(header, "GRAND PRIX", 9, Color(0.62, 0.68, 0.76))
	logo_sub.position = Vector2(24, 41)
	var season := _label(header, "WORLD MOTORSPORT SERIES     /     SEASON 2026", 10, Color(0.65, 0.71, 0.79))
	season.position = Vector2(205, 26)
	season.size = Vector2(440, 20)
	var online := _label(header, "●  LOCAL SESSION", 10, Color(0.55, 0.78, 0.68))
	online.anchor_left = 1.0
	online.anchor_right = 1.0
	online.position = Vector2(-170, 27)
	online.size = Vector2(145, 18)
	online.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var nav := HBoxContainer.new()
	nav.position = Vector2(42, 112)
	nav.size = Vector2(650, 44)
	nav.add_theme_constant_override("separation", 8)
	frontend_root.add_child(nav)
	_add_frontend_nav(nav, "HOME", "home")
	_add_frontend_nav(nav, "RACE WEEKEND", "race")
	_add_frontend_nav(nav, "GARAGE", "garage")
	_add_frontend_nav(nav, "SETTINGS", "settings")

	frontend_page_title = _label(frontend_root, "THE GRID IS YOURS.", 38, Color(0.97, 0.98, 1.0))
	frontend_page_title.position = Vector2(54, 218)
	frontend_page_title.size = Vector2(760, 54)
	frontend_page_body = _label(frontend_root, "Build your weekend. Find the limit. Own every lap.", 15, Color(0.66, 0.72, 0.8))
	frontend_page_body.position = Vector2(58, 276)
	frontend_page_body.size = Vector2(720, 30)

	var feature := _panel(frontend_root, Vector2(52, 340), Vector2(700, 300))
	var feature_style := StyleBoxFlat.new()
	feature_style.bg_color = Color(0.045, 0.058, 0.075, 0.98)
	feature_style.border_color = Color(0.22, 0.27, 0.34, 0.9)
	feature_style.set_border_width_all(1)
	feature_style.set_corner_radius_all(10)
	feature.add_theme_stylebox_override("panel", feature_style)
	_accent_bar(feature, Vector2(0, 0), Vector2(4, 300), Color(0.88, 0.12, 0.13))
	var feature_kicker := _label(feature, "FEATURED EVENT     /     GRAND PRIX", 10, Color(0.78, 0.34, 0.35))
	feature_kicker.position = Vector2(28, 25)
	var feature_title := _label(feature, "RACE DAY", 34, Color.WHITE)
	feature_title.position = Vector2(28, 62)
	var feature_desc := _label(feature, "Take your place on the grid. Five lights.\nOne launch. Every corner matters.", 15, Color(0.7, 0.75, 0.82))
	feature_desc.position = Vector2(30, 116)
	feature_desc.size = Vector2(520, 54)
	var event_meta := _label(feature, "PRACTICE  •  QUALIFYING  •  GRAND PRIX", 10, Color(0.58, 0.66, 0.76))
	event_meta.position = Vector2(30, 205)
	var start_button := _frontend_button(feature, "ENTER RACE WEEKEND", true)
	start_button.position = Vector2(28, 244)
	start_button.size = Vector2(250, 42)
	start_button.pressed.connect(_enter_race)

	var side := _panel(frontend_root, Vector2(784, 218), Vector2(350, 422))
	var side_title := _label(side, "YOUR TEAM", 11, Color(0.62, 0.7, 0.79))
	side_title.position = Vector2(22, 22)
	var team_name := _label(side, "APEX MOTORSPORT", 21, Color.WHITE)
	team_name.position = Vector2(22, 56)
	var team_sub := _label(side, "CONSTRUCTOR     /     FACTORY ENTRY", 9, Color(0.58, 0.66, 0.75))
	team_sub.position = Vector2(24, 88)
	var separator := ColorRect.new()
	separator.position = Vector2(22, 126)
	separator.size = Vector2(306, 1)
	separator.color = Color(0.22, 0.27, 0.34)
	side.add_child(separator)
	var garage_heading := _label(side, "GARAGE", 10, Color(0.62, 0.7, 0.79))
	garage_heading.position = Vector2(22, 151)
	var garage_car := _label(side, "APEX GP-01", 22, Color.WHITE)
	garage_car.position = Vector2(22, 180)
	var garage_info := _label(side, "OPEN-WHEEL  /  HYBRID POWER UNIT", 9, Color(0.58, 0.66, 0.75))
	garage_info.position = Vector2(24, 213)
	var garage_button := _frontend_button(side, "OPEN GARAGE", false)
	garage_button.position = Vector2(22, 340)
	garage_button.size = Vector2(306, 42)
	garage_button.pressed.connect(func(): _show_frontend_page("garage"))

	var footer := _label(frontend_root, "APEX GRAND PRIX     •     DEVELOPMENT BUILD", 9, Color(0.39, 0.45, 0.54))
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.position = Vector2(48, -30)
	footer.size = Vector2(500, 18)

	# Dedicated garage and settings content is built once and switched by page.
	_build_garage_page()
	_show_frontend_page("home")

func _add_frontend_nav(parent: HBoxContainer, caption: String, page: String) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(142, 42)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.058, 0.075, 0.75)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.15, 0.19, 1.0)
	hover.set_corner_radius_all(5)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(func(): _show_frontend_page(page))
	parent.add_child(button)

func _frontend_button(parent: Control, caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.78, 0.1, 0.12) if primary else Color(0.09, 0.12, 0.16)
	normal.border_color = Color(0.92, 0.2, 0.2) if primary else Color(0.27, 0.33, 0.41)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.94, 0.16, 0.17) if primary else Color(0.15, 0.19, 0.25)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
	button.add_theme_stylebox_override("hover", hover)
	parent.add_child(button)
	return button

func _build_garage_page() -> void:
	var garage := Control.new()
	garage.name = "GaragePage"
	garage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	garage.visible = false
	frontend_root.add_child(garage)
	var heading := _label(garage, "THE GARAGE", 34, Color.WHITE)
	heading.position = Vector2(54, 215)
	var intro := _label(garage, "Your machine. Your setup. Your race.", 14, Color(0.65, 0.72, 0.8))
	intro.position = Vector2(58, 265)
	var car_bay := _panel(garage, Vector2(52, 315), Vector2(690, 325))
	var bay_kicker := _label(car_bay, "CHASSIS PRESENTATION     /     FACTORY BAY 01", 10, Color(0.65, 0.72, 0.8))
	bay_kicker.position = Vector2(24, 22)
	var car_name := _label(car_bay, "APEX GP-01", 31, Color.WHITE)
	car_name.position = Vector2(24, 74)
	var car_type := _label(car_bay, "2026 HYBRID GRAND PRIX CHASSIS", 10, Color(0.58, 0.68, 0.79))
	car_type.position = Vector2(27, 120)
	var bay_line := ColorRect.new()
	bay_line.position = Vector2(25, 170)
	bay_line.size = Vector2(640, 1)
	bay_line.color = Color(0.23, 0.29, 0.37)
	car_bay.add_child(bay_line)
	var bay_note := _label(car_bay, "VEHICLE MODEL PREVIEW  /  IN DEVELOPMENT", 10, Color(0.78, 0.5, 0.5))
	bay_note.position = Vector2(25, 192)
	var bay_desc := _label(car_bay, "The garage interface is ready for the detailed,\nfully modelled car presentation pass.", 13, Color(0.68, 0.74, 0.82))
	bay_desc.position = Vector2(25, 221)
	bay_desc.size = Vector2(600, 48)

	var setup := _panel(garage, Vector2(772, 315), Vector2(362, 325))
	var setup_title := _label(setup, "CAR CONFIGURATION", 11, Color(0.67, 0.74, 0.82))
	setup_title.position = Vector2(22, 22)
	var selected := _label(setup, selected_garage_item, 23, Color.WHITE)
	selected.position = Vector2(22, 58)
	garage_status = _label(setup, "FACTORY SPECIFICATION", 9, Color(0.58, 0.68, 0.78))
	garage_status.position = Vector2(24, 94)
	var setup_rule := ColorRect.new()
	setup_rule.position = Vector2(22, 126)
	setup_rule.size = Vector2(318, 1)
	setup_rule.color = Color(0.23, 0.29, 0.37)
	setup.add_child(setup_rule)
	var chassis_button := _frontend_button(setup, "GP-01  /  FACTORY", false)
	chassis_button.position = Vector2(22, 150)
	chassis_button.size = Vector2(318, 38)
	chassis_button.pressed.connect(func(): _select_garage_item("APEX GP-01"))
	var aero_button := _frontend_button(setup, "AERODYNAMICS  /  SETUP", false)
	aero_button.position = Vector2(22, 198)
	aero_button.size = Vector2(318, 38)
	aero_button.pressed.connect(func(): _select_garage_item("AERODYNAMICS"))
	var tyre_button := _frontend_button(setup, "TYRES  /  COMPOUND", false)
	tyre_button.position = Vector2(22, 246)
	tyre_button.size = Vector2(318, 38)
	tyre_button.pressed.connect(func(): _select_garage_item("TYRE STRATEGY"))

func _select_garage_item(item: String) -> void:
	selected_garage_item = item
	if garage_status != null:
		garage_status.text = "SETUP OPTIONS COMING IN THE VEHICLE SETUP PASS"

func _show_frontend_page(page: String) -> void:
	frontend_page = page
	if frontend_page_title == null:
		return
	var garage_page := frontend_root.get_node_or_null("GaragePage")
	if garage_page != null:
		garage_page.visible = page == "garage"
	for child in frontend_root.get_children():
		if child is Panel or child is HBoxContainer:
			if child.name != "GaragePage":
				child.visible = page == "home"
	frontend_page_title.visible = page != "garage"
	frontend_page_body.visible = page != "garage"
	if page == "home":
		frontend_page_title.text = "THE GRID IS YOURS."
		frontend_page_body.text = "Build your weekend. Find the limit. Own every lap."
	elif page == "race":
		frontend_page_title.text = "RACE WEEKEND"
		frontend_page_body.text = "Your test circuit is ready. Enter the cockpit when you are."
	elif page == "settings":
		frontend_page_title.text = "RACE SETTINGS"
		frontend_page_body.text = "Graphics, controls and assists will be configured here."
	elif page == "garage":
		frontend_page_title.visible = false
		frontend_page_body.visible = false

func _enter_race() -> void:
	frontend_layer.visible = false
	hud.visible = true
	car.reset_vehicle(Vector3(105, 1.0, -8), PI)
	last_car_position = car.global_position
	car.set_physics_process(false)
	race_started = false
	race_time = 0.0
	lap_number = 0
	lap_time = 0.0
	_begin_start_sequence()
