class_name TruckFollowCamera
extends Camera3D

## A fixed-world-angle follow camera. It does not orbit when the truck steers,
## keeping the loader side visible and avoiding disorienting camera motion.

@export var world_offset := Vector3(7.8, 11.8, 14.8)
@export var look_height := 1.65
@export var look_ahead := 1.8
@export var position_smoothing := 4.8
@export var aim_smoothing := 7.0

var target: Node3D
var _smoothed_aim := Vector3.ZERO


func attach_to(target_node: Node3D) -> void:
	target = target_node
	snap_to_target()


func snap_to_target() -> void:
	if target == null or not is_inside_tree():
		return
	global_position = target.global_position + world_offset
	_smoothed_aim = _desired_aim()
	look_at(_smoothed_aim, Vector3.UP)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired_position := target.global_position + world_offset
	global_position = global_position.lerp(
		desired_position,
		1.0 - exp(-position_smoothing * delta),
	)
	_smoothed_aim = _smoothed_aim.lerp(
		_desired_aim(),
		1.0 - exp(-aim_smoothing * delta),
	)
	look_at(_smoothed_aim, Vector3.UP)


func _desired_aim() -> Vector3:
	var forward := -target.global_transform.basis.x.normalized()
	return target.global_position + Vector3.UP * look_height + forward * look_ahead

