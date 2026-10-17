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
var _road_min_x := -INF
var _road_max_x := INF
var _road_height := -INF


func attach_to(target_node: Node3D) -> void:
	target = target_node
	if target is TruckController:
		_road_min_x = target.road_min_x
		_road_max_x = target.road_max_x
		_road_height = target.global_position.y
		target.respawned.connect(snap_to_target)
	snap_to_target()


func snap_to_target() -> void:
	if target == null or not is_inside_tree():
		return
	global_position = _follow_position() + world_offset
	_smoothed_aim = _desired_aim()
	look_at(_smoothed_aim, Vector3.UP)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired_position := _follow_position() + world_offset
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
	return _follow_position() + Vector3.UP * look_height + forward * look_ahead


func _follow_position() -> Vector3:
	# Stay above the road while the truck falls into the surrounding blue.
	var position_on_road := target.global_position
	position_on_road.x = clampf(position_on_road.x, _road_min_x, _road_max_x)
	position_on_road.y = maxf(position_on_road.y, _road_height)
	return position_on_road
