extends CharacterBody3D
class_name F1CarController

## First-pass vehicle dynamics. Tuned as a foundation, not presented as final
## simulation-grade F1 physics. Replace the visual rig with a detailed asset.

@export_group("Powertrain")
@export var max_speed_kmh: float = 340.0
@export var acceleration: float = 34.0
@export var braking: float = 88.0
@export var reverse_speed_kmh: float = 18.0

@export_group("Handling")
@export var low_speed_steer: float = 2.25
@export var high_speed_steer: float = 0.62
@export var lateral_grip: float = 8.5
@export var rolling_resistance: float = 1.4
@export var aero_drag: float = 0.0022

var speed_kmh: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var steer_input: float = 0.0
var handbrake_input: bool = false
var _longitudinal_speed: float = 0.0
var _heading: float = 0.0

func _ready() -> void:
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(55.0)
	_heading = rotation.y

func _physics_process(delta: float) -> void:
	_read_controls()
	_update_powertrain(delta)
	_update_steering(delta)
	_update_velocity(delta)
	move_and_slide()
	speed_kmh = absf(_longitudinal_speed) * 3.6

func _read_controls() -> void:
	throttle_input = Input.get_action_strength("accelerate")
	brake_input = Input.get_action_strength("brake")
	steer_input = Input.get_axis("steer_left", "steer_right")
	handbrake_input = Input.is_action_pressed("handbrake")

func _update_powertrain(delta: float) -> void:
	if throttle_input > 0.0:
		_longitudinal_speed += acceleration * throttle_input * delta
	elif brake_input > 0.0:
		if _longitudinal_speed > 0.8:
			_longitudinal_speed = move_toward(_longitudinal_speed, 0.0, braking * brake_input * delta)
		else:
			_longitudinal_speed = move_toward(_longitudinal_speed, -reverse_speed_kmh / 3.6, acceleration * 0.35 * delta)
	else:
		_longitudinal_speed = move_toward(_longitudinal_speed, 0.0, rolling_resistance * delta)

	var speed_limit := max_speed_kmh / 3.6
	_longitudinal_speed = clampf(_longitudinal_speed, -reverse_speed_kmh / 3.6, speed_limit)
	var drag := aero_drag * _longitudinal_speed * absf(_longitudinal_speed)
	_longitudinal_speed -= drag * delta

func _update_steering(delta: float) -> void:
	var speed_ratio := clampf(absf(_longitudinal_speed) / (max_speed_kmh / 3.6), 0.0, 1.0)
	var steer_rate := lerpf(low_speed_steer, high_speed_steer, speed_ratio)
	var grip_factor := 0.55 if handbrake_input else 1.0
	_heading -= steer_input * steer_rate * grip_factor * clampf(absf(_longitudinal_speed) / 5.0, 0.0, 1.0) * delta
	rotation.y = _heading

func _update_velocity(delta: float) -> void:
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var desired_forward := forward * _longitudinal_speed
	var current_forward := forward * velocity.dot(forward)
	var current_lateral := right * velocity.dot(right)
	var lateral_damping := lateral_grip * (0.35 if handbrake_input else 1.0)
	var lateral_velocity := current_lateral.move_toward(Vector3.ZERO, lateral_damping * delta)
	velocity = desired_forward + lateral_velocity
	velocity.y = -1.0

func reset_vehicle(at_position: Vector3, heading: float = 0.0) -> void:
	global_position = at_position
	_heading = heading
	rotation.y = heading
	_longitudinal_speed = 0.0
	velocity = Vector3.ZERO
