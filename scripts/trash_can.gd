class_name CollectibleTrashCan
extends Node3D

## A reusable wrapper around the imported residential-can model.

var container_group := "collectible_cans"
var marker_height := 1.82
var emptied := false
var visual_root: Node3D
var lid_pivot: Node3D
var home_parent: Node
var home_transform := Transform3D.IDENTITY
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _marker_time := 0.0


func configure(can_visual: Node3D) -> void:
	visual_root = can_visual
	lid_pivot = can_visual.find_child("ResidentialCan_LidPivot", true, false) as Node3D
	home_parent = get_parent()
	home_transform = global_transform
	add_to_group(container_group)
	_build_marker()


func _process(delta: float) -> void:
	if _marker == null or not _marker.visible:
		return
	_marker_time += delta
	_marker.position.y = marker_height + sin(_marker_time * 4.2) * 0.11
	_marker.rotation.y += delta * 1.8


func set_targeted(targeted: bool) -> void:
	if _marker == null or emptied:
		return
	_marker.visible = targeted
	if targeted:
		_marker_material.albedo_color = Color("#ffd84d")
		_marker_material.emission = Color("#ffd84d")
		_marker.scale = Vector3.ONE


func prepare_for_pickup() -> void:
	home_parent = get_parent()
	home_transform = global_transform
	set_targeted(false)


func attach_to_loader(loader_grip: Node3D) -> void:
	reparent(loader_grip, true)


func return_home() -> void:
	reparent(home_parent, true)
	global_transform = home_transform


func dump_origin() -> Vector3:
	if lid_pivot != null:
		return lid_pivot.global_position
	return global_position + Vector3.UP * 1.25


func mark_emptied() -> void:
	emptied = true
	if _marker == null:
		return
	_marker.visible = true
	_marker_material.albedo_color = Color("#66ed87")
	_marker_material.emission = Color("#66ed87")
	_marker.scale = Vector3.ONE * 1.55
	var celebration := create_tween()
	celebration.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	celebration.tween_property(_marker, "scale", Vector3.ONE, 0.42)
	celebration.tween_interval(1.1)
	celebration.tween_property(_marker, "scale", Vector3.ZERO, 0.24)
	celebration.tween_callback(func() -> void: _marker.visible = false)


func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "ReadyMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.30
	mesh.height = 0.34
	mesh.radial_segments = 4
	_marker.mesh = mesh
	_marker.position = Vector3(0.0, marker_height, 0.0)
	_marker.rotation_degrees.z = 180.0
	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = Color("#ffd84d")
	_marker_material.emission_enabled = true
	_marker_material.emission = Color("#ffd84d")
	_marker_material.emission_energy_multiplier = 1.7
	_marker_material.roughness = 0.35
	_marker.material_override = _marker_material
	_marker.visible = false
	add_child(_marker)

