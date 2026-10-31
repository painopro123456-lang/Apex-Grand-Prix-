extends CharacterBody3D
class_name F1CarController

## Early vehicle simulation layer: speed-sensitive steering, gears, aero load,
## traction limiting, ERS deployment, DRS, tyre temperature and tyre wear.
## Values are prototype tuning and need telemetry-driven validation.

@export_group("Power unit")
@export var max_speed_kmh: float = 350.0
@export var engine_force: float = 31.0
@export var service_brake: float = 105.0
@export var reverse_speed_kmh: float = 12.0
@export var gear_up_rpm: float = 11800.0
@export var gear_down_rpm: float = 5200.0
@export var ers_power: float = 8.0

@export_group("Chassis and aero")
@export var low_speed_steer: float = 2.0
@export var high_speed_steer: float = 0.48
@export var mechanical_grip: float = 10.0
@export var downforce_coefficient: float = 0.00082
@export var drag_coefficient: float = 0.0021
@export var drs_drag_multiplier: float = 0.72

@export_group("Tyres")
@export var tyre_wear_rate: float = 0.000012
@export var target_tyre_temp: float = 92.0

var speed_kmh: float = 0.0
var crash_damage: float = 0.0
var retired: bool = false
var impact_cooldown: float = 0.0
var circuit: Node = null
var tyre_gravel_overlays: Array[MeshInstance3D] = []
var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0
var handbrake_input: bool = false
var drs_active: bool = false
var ers_active: bool = false
var ers_charge: float = 100.0
var tyre_wear: float = 0.0
var tyre_temperature: float = 82.0
var engine_rpm: float = 4500.0
var current_gear: int = 1
var lateral_g: float = 0.0
var _longitudinal_speed: float = 0.0
var _heading: float = 0.0
var _last_lateral_speed: float = 0.0
var _shift_lock: float = 0.0

const GEAR_RATIOS := [0.0, 3.10, 2.45, 1.98, 1.65, 1.42, 1.24, 1.10, 0.98]

func _ready() -> void:
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(55.0)
	_heading = rotation.y
	_build_tyre_visuals()
	_build_aero_visuals()

func _physics_process(delta: float) -> void:
	if retired:
		velocity = Vector3.ZERO
		return
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	_read_controls()
	_update_power_unit(delta)
	_update_steering(delta)
	_update_vehicle_dynamics(delta)
	var impact_velocity := velocity
	move_and_slide()
	_process_impact_collisions(impact_velocity)
	speed_kmh = absf(_longitudinal_speed) * 3.6
	_update_tyre_model(delta)

func _read_controls() -> void:
	throttle_input = Input.get_action_strength("accelerate")
	brake_input = Input.get_action_strength("brake")
	steer_input = Input.get_axis("steer_left", "steer_right")
	handbrake_input = Input.is_action_pressed("handbrake")
	drs_active = Input.is_action_pressed("drs") and speed_kmh > 80.0
	ers_active = Input.is_action_pressed("ers_deploy") and ers_charge > 0.5

func _update_power_unit(delta: float) -> void:
	_shift_lock = maxf(0.0, _shift_lock - delta)
	var speed_ratio := clampf(absf(_longitudinal_speed) / 95.0, 0.0, 1.0)
	engine_rpm = lerpf(4200.0, 12500.0, speed_ratio) * GEAR_RATIOS[current_gear] / GEAR_RATIOS[1]
	if _longitudinal_speed < 1.0:
		engine_rpm = lerpf(engine_rpm, 4200.0, 0.08)

	if _shift_lock <= 0.0:
		if engine_rpm > gear_up_rpm and current_gear < 8:
			current_gear += 1
			_shift_lock = 0.16
		elif engine_rpm < gear_down_rpm and current_gear > 1 and speed_kmh > 35.0:
			current_gear -= 1
			_shift_lock = 0.12

	if throttle_input > 0.0 and _longitudinal_speed >= 0.0:
		var power := engine_force * (1.0 + (0.24 if ers_active else 0.0))
		_longitudinal_speed += power * throttle_input * delta
		if ers_active:
			ers_charge = maxf(0.0, ers_charge - 8.5 * delta)
	else:
		ers_charge = minf(100.0, ers_charge + (2.8 + brake_input * 8.0) * delta)

	if brake_input > 0.0:
		if _longitudinal_speed > 0.7:
			_longitudinal_speed = move_toward(_longitudinal_speed, 0.0, service_brake * brake_input * delta)
		else:
			_longitudinal_speed = move_toward(_longitudinal_speed, -reverse_speed_kmh / 3.6, engine_force * 0.3 * delta)

	var speed_limit := max_speed_kmh / 3.6
	_longitudinal_speed = clampf(_longitudinal_speed, -reverse_speed_kmh / 3.6, speed_limit)

func _update_steering(delta: float) -> void:
	var speed_ratio := clampf(absf(_longitudinal_speed) / (max_speed_kmh / 3.6), 0.0, 1.0)
	var steer_rate := lerpf(low_speed_steer, high_speed_steer, speed_ratio)
	var wear_grip := 1.0 - tyre_wear * 0.28
	var grip_factor := (0.52 if handbrake_input else 1.0) * wear_grip
	_heading -= steer_input * steer_rate * grip_factor * clampf(absf(_longitudinal_speed) / 4.0, 0.0, 1.0) * delta
	rotation.y = _heading

func _update_vehicle_dynamics(delta: float) -> void:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var speed := absf(_longitudinal_speed)
	var speed_squared := speed * speed
	var aero_load := speed_squared * downforce_coefficient
	var tyre_grip := mechanical_grip * (1.0 - tyre_wear * 0.3)
	var load_grip := 1.0 + minf(aero_load * 0.012, 0.65)
	var grip := tyre_grip * load_grip

	var desired_forward := forward * _longitudinal_speed
	var current_lateral := right * velocity.dot(right)
	var lateral_damping := grip * (0.32 if handbrake_input else 1.0)
	var lateral_velocity := current_lateral.move_toward(Vector3.ZERO, lateral_damping * delta)
	var drag_scale := drs_drag_multiplier if drs_active else 1.0
	var drag := drag_coefficient * drag_scale * _longitudinal_speed * absf(_longitudinal_speed)
	_longitudinal_speed -= drag * delta

	var new_lateral_speed := lateral_velocity.length()
	lateral_g = absf(new_lateral_speed - _last_lateral_speed) / maxf(delta, 0.001) / 9.81
	_last_lateral_speed = new_lateral_speed
	velocity = desired_forward + lateral_velocity
	velocity.y = -1.0

func _process_impact_collisions(incoming_velocity: Vector3) -> void:
	if impact_cooldown > 0.0:
		return
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		var horizontal_normal := Vector3(normal.x, 0.0, normal.z).normalized()
		if horizontal_normal.length_squared() < 0.5:
			continue
		var impact_speed := absf(incoming_velocity.dot(horizontal_normal))
		if impact_speed < 7.0:
			continue
		impact_cooldown = 0.55
		crash_damage = clampf(crash_damage + (impact_speed - 6.0) * 1.35, 0.0, 100.0)
		var severity := clampf((impact_speed - 7.0) / 28.0, 0.0, 0.9)
		_longitudinal_speed *= 1.0 - severity
		velocity = velocity.slide(horizontal_normal) * (1.0 - severity * 0.55)
		var contact_side := signf(global_transform.basis.x.dot(horizontal_normal))
		_heading += contact_side * minf(impact_speed * 0.006, 0.24)
		rotation.y = _heading
		if crash_damage >= 100.0:
			retired = true
			_longitudinal_speed = 0.0
			velocity = Vector3.ZERO
		break


func set_circuit(track_node: Node) -> void:
	circuit = track_node

func _build_tyre_visuals() -> void:
	var rubber := _visual_material(Color("#111316"), 0.02, 0.88)
	var sidewall := _visual_material(Color("#202327"), 0.0, 0.94)
	var rim := _visual_material(Color("#aeb7c2"), 0.82, 0.24)
	var hub := _visual_material(Color("#333c48"), 0.72, 0.3)
	for x in [-1.02, 1.02]:
		for z in [-1.48, 1.48]:
			var wheel := MeshInstance3D.new()
			wheel.name = "SlickTyre"
			var tyre_mesh := CylinderMesh.new()
			tyre_mesh.top_radius = 0.43
			tyre_mesh.bottom_radius = 0.43
			tyre_mesh.height = 0.34
			tyre_mesh.radial_segments = 40
			tyre_mesh.rings = 4
			wheel.mesh = tyre_mesh
			wheel.material_override = rubber
			wheel.position = Vector3(x, -0.22, z)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)

			var side_ring := MeshInstance3D.new()
			var ring_mesh := TorusMesh.new()
			ring_mesh.inner_radius = 0.34
			ring_mesh.outer_radius = 0.425
			ring_mesh.rings = 32
			ring_mesh.ring_segments = 16
			side_ring.mesh = ring_mesh
			side_ring.material_override = sidewall
			side_ring.position = wheel.position
			side_ring.rotation = wheel.rotation
			add_child(side_ring)

			var rim_face := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = 0.255
			rim_mesh.bottom_radius = 0.255
			rim_mesh.height = 0.355
			rim_mesh.radial_segments = 32
			rim_face.mesh = rim_mesh
			rim_face.material_override = rim
			rim_face.position = wheel.position
			rim_face.rotation = wheel.rotation
			add_child(rim_face)

			var center_cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.095
			cap_mesh.bottom_radius = 0.095
			cap_mesh.height = 0.37
			cap_mesh.radial_segments = 24
			center_cap.mesh = cap_mesh
			center_cap.material_override = hub
			center_cap.position = wheel.position
			center_cap.rotation = wheel.rotation
			add_child(center_cap)

			var gravel_overlay := MeshInstance3D.new()
			var overlay_mesh := TorusMesh.new()
			overlay_mesh.inner_radius = 0.305
			overlay_mesh.outer_radius = 0.445
			overlay_mesh.rings = 24
			overlay_mesh.ring_segments = 12
			gravel_overlay.mesh = overlay_mesh
			gravel_overlay.material_override = _visual_material(Color("#80694a"), 0.0, 1.0)
			gravel_overlay.position = wheel.position
			gravel_overlay.rotation = wheel.rotation
			gravel_overlay.scale = Vector3.ONE * 0.001
			add_child(gravel_overlay)
			tyre_gravel_overlays.append(gravel_overlay)

func _visual_material(color: Color, metal: float = 0.0, rough: float = 0.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	material.clearcoat_enabled = true
	material.clearcoat = 0.32
	material.clearcoat_roughness = 0.28
	return material

func _add_car_box(parent: Node3D, part_name: String, size: Vector3, at: Vector3, material: Material, bevel: float = 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.subdivide_width = 2
	mesh.subdivide_height = 2
	mesh.subdivide_depth = 2
	part.mesh = mesh
	part.material_override = material
	part.position = at
	if part_name in ["CarbonMonocoque", "TaperedNoseCone", "Sidepod", "EngineCover"]:
		part.add_to_group("livery_primary")
	if part_name in ["NoseTip"]:
		part.add_to_group("livery_accent")
	parent.add_child(part)
	return part

func _add_car_sphere(parent: Node3D, part_name: String, at: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radial_segments = 40
	mesh.rings = 24
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = scale_value
	if part_name in ["CarbonMonocoque", "Sidepod", "EngineCover"]:
		part.add_to_group("livery_primary")
	if part_name == "NoseTip":
		part.add_to_group("livery_accent")
	parent.add_child(part)
	return part

func _add_car_beam(parent: Node3D, part_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var beam := MeshInstance3D.new()
	beam.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 12
	beam.mesh = mesh
	beam.material_override = material
	beam.position = (from + to) * 0.5
	beam.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	parent.add_child(beam)

func _build_aero_visuals() -> void:
	var carbon := _visual_material(Color("#111820"), 0.58, 0.3)
	var carbon_edge := _visual_material(Color("#27313c"), 0.72, 0.27)
	var body_paint := _visual_material(Color("#d9e1eb"), 0.48, 0.23)
	var accent := _visual_material(Color("#00a7d8"), 0.42, 0.25)
	var cockpit_black := _visual_material(Color("#080d13"), 0.22, 0.16)
	var helmet_mat := _visual_material(Color("#e7edf5"), 0.32, 0.22)
	var suspension := _visual_material(Color("#a8b3c0"), 0.82, 0.25)

	# Sculpted central survival cell and tapered nose cone.
	_add_car_sphere(self, "CarbonMonocoque", Vector3(0, 0.28, 0.12), Vector3(0.57, 0.43, 1.28), body_paint)
	var nose := MeshInstance3D.new()
	nose.name = "TaperedNoseCone"
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.39
	nose_mesh.bottom_radius = 0.055
	nose_mesh.height = 2.25
	nose_mesh.radial_segments = 40
	nose_mesh.rings = 8
	nose.mesh = nose_mesh
	nose.material_override = body_paint
	nose.add_to_group("livery_primary")
	nose.position = Vector3(0, 0.24, -1.52)
	nose.rotation.x = PI * 0.5
	add_child(nose)
	_add_car_sphere(self, "NoseTip", Vector3(0, 0.25, -2.62), Vector3(0.09, 0.075, 0.2), accent)

	# Wide sculpted sidepods, cooling inlets and floor edge.
	for side in [-1.0, 1.0]:
		_add_car_sphere(self, "Sidepod", Vector3(side * 0.78, 0.12, 0.05), Vector3(0.47, 0.34, 0.92), body_paint)
		_add_car_box(self, "SidepodInlet", Vector3(0.035, 0.18, 0.48), Vector3(side * 1.17, 0.2, -0.04), carbon)
		_add_car_box(self, "FloorEdge", Vector3(0.12, 0.09, 2.15), Vector3(side * 0.92, -0.17, 0.35), carbon)
		_add_car_beam(self, "FrontWishboneUpper", Vector3(side * 0.55, 0.18, -1.35), Vector3(side * 1.0, -0.03, -1.48), 0.035, suspension)
		_add_car_beam(self, "FrontWishboneLower", Vector3(side * 0.48, -0.08, -1.25), Vector3(side * 1.0, -0.27, -1.48), 0.04, carbon_edge)
		_add_car_beam(self, "RearWishboneUpper", Vector3(side * 0.52, 0.18, 1.22), Vector3(side * 1.0, -0.03, 1.48), 0.035, suspension)
		_add_car_beam(self, "RearWishboneLower", Vector3(side * 0.48, -0.08, 1.08), Vector3(side * 1.0, -0.27, 1.48), 0.04, carbon_edge)

	# Front wing: main plane, two flaps and endplates.
	_add_car_box(self, "FrontWingMainPlane", Vector3(4.35, 0.12, 0.42), Vector3(0, -0.12, -2.72), carbon)
	_add_car_box(self, "FrontWingFlap", Vector3(4.05, 0.075, 0.2), Vector3(0, 0.0, -2.48), carbon_edge)
	var front_accent := _add_car_box(self, "FrontWingUpperFlap", Vector3(3.72, 0.055, 0.16), Vector3(0, 0.12, -2.39), accent)
	front_accent.add_to_group("livery_accent")
	for side in [-1.0, 1.0]:
		_add_car_box(self, "FrontWingEndplate", Vector3(0.075, 0.38, 0.56), Vector3(side * 2.13, 0.02, -2.63), carbon)
		_add_car_box(self, "FrontWingFootplate", Vector3(0.3, 0.045, 0.62), Vector3(side * 1.88, -0.2, -2.6), carbon_edge)

	# Cockpit tub, halo and driver helmet.
	_add_car_sphere(self, "CockpitOpening", Vector3(0, 0.64, -0.12), Vector3(0.37, 0.12, 0.59), cockpit_black)
	_add_car_sphere(self, "DriverHelmet", Vector3(0, 0.78, -0.1), Vector3(0.19, 0.2, 0.2), helmet_mat)
	_add_car_beam(self, "HaloLeft", Vector3(-0.38, 0.62, 0.22), Vector3(-0.28, 0.92, -0.35), 0.035, carbon_edge)
	_add_car_beam(self, "HaloRight", Vector3(0.38, 0.62, 0.22), Vector3(0.28, 0.92, -0.35), 0.035, carbon_edge)
	_add_car_beam(self, "HaloFront", Vector3(-0.28, 0.92, -0.35), Vector3(0.28, 0.92, -0.35), 0.04, carbon_edge)
	_add_car_beam(self, "HaloSpine", Vector3(0, 0.92, -0.35), Vector3(0, 0.72, 0.35), 0.035, carbon_edge)

	# Engine cover, air intake and high-mounted rear wing.
	_add_car_sphere(self, "EngineCover", Vector3(0, 0.47, 1.03), Vector3(0.43, 0.48, 0.9), body_paint)
	_add_car_sphere(self, "AirIntake", Vector3(0, 0.91, 0.52), Vector3(0.23, 0.17, 0.2), carbon)
	_add_car_box(self, "RearWingMainPlane", Vector3(2.35, 0.11, 0.48), Vector3(0, 1.22, 2.08), carbon)
	var rear_accent := _add_car_box(self, "RearWingUpperFlap", Vector3(2.2, 0.075, 0.22), Vector3(0, 1.4, 2.16), accent)
	rear_accent.add_to_group("livery_accent")
	_add_car_box(self, "RearWingEndplateL", Vector3(0.07, 0.52, 0.58), Vector3(-1.13, 1.17, 2.08), carbon)
	_add_car_box(self, "RearWingEndplateR", Vector3(0.07, 0.52, 0.58), Vector3(1.13, 1.17, 2.08), carbon)
	_add_car_beam(self, "RearWingSupportL", Vector3(-0.3, 0.58, 1.7), Vector3(-0.3, 1.2, 2.05), 0.045, carbon_edge)
	_add_car_beam(self, "RearWingSupportR", Vector3(0.3, 0.58, 1.7), Vector3(0.3, 1.2, 2.05), 0.045, carbon_edge)
	var crash_accent := _add_car_box(self, "RearCrashStructure", Vector3(0.22, 0.2, 0.55), Vector3(0, 0.05, 1.95), accent)
	crash_accent.add_to_group("livery_accent")

func _update_tyre_model(delta: float) -> void:
	var slip_heat := absf(steer_input) * absf(_longitudinal_speed) * 0.018
	var brake_heat := brake_input * 7.0
	var cooling := (tyre_temperature - 25.0) * 0.018
	tyre_temperature = clampf(tyre_temperature + (slip_heat + brake_heat - cooling) * delta, 25.0, 145.0)
	var temp_penalty := absf(tyre_temperature - target_tyre_temp) / 120.0
	var wear_multiplier := 1.0 + absf(steer_input) * 1.8 + maxf(temp_penalty, 0.0)
	tyre_wear = clampf(tyre_wear + tyre_wear_rate * wear_multiplier * speed_kmh * delta, 0.0, 1.0)

func reset_vehicle(at_position: Vector3, heading: float = 0.0) -> void:
	global_position = at_position
	_heading = heading
	rotation.y = heading
	_longitudinal_speed = 0.0
	speed_kmh = 0.0
	velocity = Vector3.ZERO
	current_gear = 1
	engine_rpm = 4200.0
	crash_damage = 0.0
	retired = false
	impact_cooldown = 0.0
	for overlay in tyre_gravel_overlays:
		overlay.scale = Vector3.ONE * 0.001

func set_livery(primary_color: Color) -> void:
	var primary := _visual_material(primary_color, 0.52, 0.24)
	var accent := _visual_material(primary_color.lightened(0.24), 0.48, 0.22)
	for part in get_tree().get_nodes_in_group("livery_primary"):
		if is_instance_valid(part) and part.get_parent() == self:
			part.material_override = primary
	for part in get_tree().get_nodes_in_group("livery_accent"):
		if is_instance_valid(part) and part.get_parent() == self:
			part.material_override = accent
