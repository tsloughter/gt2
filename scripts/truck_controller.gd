class_name TruckController
extends CharacterBody3D

## Forgiving arcade driving for a young player.
## The truck points down its local -X axis in the imported Blender model.

# Blender cylinders are authored along local Z, but the glTF Y-up conversion
# remaps their mesh axis to local Y. The imported wheel node's 90-degree X
# rotation then places this axis across the width of the truck.
const WHEEL_ROLL_AXIS := Vector3.UP

@export var maximum_forward_speed := 8.4
@export var maximum_reverse_speed := 3.4
@export var acceleration := 5.2
@export var direction_change_braking := 8.5
@export var coast_drag := 2.8
@export var active_braking := 12.0
@export var steering_rate := 0.92
@export var heading_assist := 0.72
@export var road_min_x := -35.0
@export var road_max_x := 35.0
@export var road_min_z := -3.55
@export var road_max_z := 3.55

var current_speed := 0.0
var controls_locked := false
var _visual_root: Node3D
var _wheels: Array[Node3D] = []
var _test_input_enabled := false
var _test_throttle := 0.0
var _test_steering := 0.0
var _test_brake := false
var _engine_audio: AudioStreamPlayer3D
var _reverse_beep: AudioStreamPlayer3D
var _reverse_beep_timer := 0.0


func _ready() -> void:
	_setup_audio()


func attach_visual(model_root: Node3D) -> void:
	_visual_root = model_root
	_wheels.clear()
	for child in model_root.find_children("Wheel_*", "Node3D", true, false):
		_wheels.append(child as Node3D)


func set_test_input(throttle: float, steering: float, braking: bool = false) -> void:
	_test_input_enabled = true
	_test_throttle = clampf(throttle, -1.0, 1.0)
	_test_steering = clampf(steering, -1.0, 1.0)
	_test_brake = braking


func clear_test_input() -> void:
	_test_input_enabled = false
	_test_throttle = 0.0
	_test_steering = 0.0
	_test_brake = false


func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	if locked:
		current_speed = 0.0


func speed_kph() -> float:
	return absf(current_speed) * 3.6


func _physics_process(delta: float) -> void:
	var controls := _read_controls()
	_apply_speed(controls.x, controls.z > 0.5, delta)
	_apply_steering(controls.y, delta)
	_move_truck(delta)
	_animate_visuals(controls.y, delta)
	_update_audio(delta)


func _read_controls() -> Vector3:
	if controls_locked:
		return Vector3(0.0, 0.0, 1.0)
	if _test_input_enabled:
		return Vector3(_test_throttle, _test_steering, 1.0 if _test_brake else 0.0)

	var throttle := 0.0
	var steering := 0.0
	var braking := Input.is_key_pressed(KEY_SPACE)

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steering -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steering += 1.0

	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var joypad_id: int = joypads[0]
		var stick_x := Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X)
		var stick_y := -Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y)
		if absf(stick_x) > 0.16:
			steering = stick_x
		if absf(stick_y) > 0.16:
			throttle = stick_y
		if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_A):
			throttle = 1.0
		if Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_B):
			throttle = -1.0
		braking = braking or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_X)

	return Vector3(clampf(throttle, -1.0, 1.0), clampf(steering, -1.0, 1.0), 1.0 if braking else 0.0)


func _apply_speed(throttle: float, braking: bool, delta: float) -> void:
	if braking:
		current_speed = move_toward(current_speed, 0.0, active_braking * delta)
		return

	if absf(throttle) < 0.01:
		current_speed = move_toward(current_speed, 0.0, coast_drag * delta)
		return

	var target_speed := throttle * (maximum_forward_speed if throttle > 0.0 else maximum_reverse_speed)
	var changing_direction := signf(target_speed) != signf(current_speed) and absf(current_speed) > 0.05
	var rate := direction_change_braking if changing_direction else acceleration
	current_speed = move_toward(current_speed, target_speed, rate * delta)


func _apply_steering(steering: float, delta: float) -> void:
	var speed_ratio := clampf(absf(current_speed) / maximum_forward_speed, 0.0, 1.0)
	if absf(steering) > 0.03 and speed_ratio > 0.015:
		var reverse_direction := 1.0 if current_speed >= 0.0 else -1.0
		var low_speed_help := lerpf(0.52, 1.0, speed_ratio)
		rotation.y += steering * steering_rate * low_speed_help * reverse_direction * delta
	elif speed_ratio > 0.06:
		# Gently settle toward the nearest direction along the street. This keeps
		# accidental steering inputs from leaving a young player sideways.
		var wrapped_yaw := wrapf(rotation.y, -PI, PI)
		var preferred_heading := 0.0 if absf(wrapped_yaw) < PI * 0.5 else PI
		rotation.y = lerp_angle(rotation.y, preferred_heading, 1.0 - exp(-heading_assist * delta))


func _move_truck(delta: float) -> void:
	var forward := -global_transform.basis.x.normalized()
	velocity = forward * current_speed
	move_and_slide()

	var before_clamp := global_position
	global_position.x = clampf(global_position.x, road_min_x, road_max_x)
	global_position.z = clampf(global_position.z, road_min_z, road_max_z)
	if not global_position.is_equal_approx(before_clamp):
		current_speed = move_toward(current_speed, 0.0, active_braking * delta * 2.0)


func _animate_visuals(steering: float, delta: float) -> void:
	var wheel_turn := -(current_speed * delta) / 0.64
	for wheel in _wheels:
		wheel.rotate_object_local(WHEEL_ROLL_AXIS, wheel_turn)

	if _visual_root != null:
		var speed_ratio := clampf(absf(current_speed) / maximum_forward_speed, 0.0, 1.0)
		var target_lean := deg_to_rad(-1.8 * steering * speed_ratio)
		_visual_root.rotation.x = lerpf(
			_visual_root.rotation.x,
			target_lean,
			1.0 - exp(-5.5 * delta),
		)


func _setup_audio() -> void:
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.name = "EngineSound"
	var engine_stream := load("res://assets/audio/engine_idle.wav").duplicate() as AudioStreamWAV
	engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_engine_audio.stream = engine_stream
	_engine_audio.volume_db = -12.0
	_engine_audio.max_distance = 45.0
	add_child(_engine_audio)
	_engine_audio.play()

	_reverse_beep = AudioStreamPlayer3D.new()
	_reverse_beep.name = "ReverseBeep"
	_reverse_beep.stream = load("res://assets/audio/reverse_beep.wav")
	_reverse_beep.volume_db = -7.0
	_reverse_beep.max_distance = 42.0
	add_child(_reverse_beep)


func _update_audio(delta: float) -> void:
	var speed_ratio := clampf(absf(current_speed) / maximum_forward_speed, 0.0, 1.0)
	_engine_audio.pitch_scale = lerpf(0.82, 1.42, speed_ratio)
	_engine_audio.volume_db = lerpf(-13.0, -6.5, speed_ratio)

	if current_speed < -0.18 and not controls_locked:
		_reverse_beep_timer -= delta
		if _reverse_beep_timer <= 0.0:
			_reverse_beep.play()
			_reverse_beep_timer = 0.78
	else:
		_reverse_beep_timer = 0.0
