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
	velocity = Vector3.ZERO
	current_gear = 1
	engine_rpm = 4200.0
	crash_damage = 0.0
	retired = false
	impact_cooldown = 0.0
