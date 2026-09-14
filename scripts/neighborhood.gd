extends Node3D

## Stage 1: static neighborhood blockout.
## Driving, collision, and collection behavior intentionally begin in Stage 2.

const ASSET_SET := preload("res://assets/models/little_clean_crew.glb")
const TRUCK_CONTROLLER := preload("res://scripts/truck_controller.gd")
const TRUCK_FOLLOW_CAMERA := preload("res://scripts/follow_camera.gd")
const TRASH_CAN := preload("res://scripts/trash_can.gd")
const SIDE_LOADER := preload("res://scripts/side_loader.gd")
const STREET_LENGTH := 76.0
const ROAD_HALF_WIDTH := 5.1
const CURB_Z := 5.35
const HOUSE_Z := -13.1

var _materials: Dictionary = {}
var _player_truck
var _speed_label: Label
var _status_label: Label
var _counter_label: Label
var _side_loader
var _restart_was_pressed := false
var _displayed_collected := 0
var _displayed_total := 6
var _displayed_cargo := 0


func _ready() -> void:
	_create_materials()
	_build_environment()
	_build_street()
	_build_house_lots()
	_place_truck_and_cans()
	_build_camera()
	_build_stage_label()

	var arguments := OS.get_cmdline_user_args()
	if "--capture-first-version" in arguments:
		_capture_first_version.call_deferred()
	elif "--capture-rear-dump" in arguments:
		_capture_rear_dump.call_deferred()
	elif "--capture-start" in arguments:
		_capture_start_state.call_deferred()
	elif "--smoke-dump" in arguments:
		_run_rear_dump_smoke_test.call_deferred()
	elif "--smoke-full-route" in arguments:
		_run_full_route_smoke_test.call_deferred()
	elif "--smoke-pickup" in arguments:
		_run_pickup_smoke_test.call_deferred()
	elif "--capture-stage2" in arguments:
		_capture_stage_two.call_deferred()
	elif "--smoke-driving" in arguments:
		_run_driving_smoke_test.call_deferred()


func _process(_delta: float) -> void:
	if _speed_label != null and _player_truck != null:
		_speed_label.text = "%02d\nkm/h" % roundi(_player_truck.speed_kph())
	var restart_pressed := Input.is_key_pressed(KEY_R)
	for joypad_id in Input.get_connected_joypads():
		restart_pressed = restart_pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_START)
	if restart_pressed and not _restart_was_pressed:
		get_tree().reload_current_scene()
	_restart_was_pressed = restart_pressed


func _create_materials() -> void:
	_materials = {
		"road": _material("Road", Color("#35414a"), 0.92),
		"road_edge": _material("Road edge", Color("#28343d"), 0.92),
		"yellow": _material("Lane yellow", Color("#f2c84b"), 0.72),
		"concrete": _material("Warm concrete", Color("#b9bab2"), 0.90),
		"curb": _material("Curb highlight", Color("#dedbd0"), 0.86),
		"grass": _material("Grass", Color("#64a74f"), 0.94),
		"grass_dark": _material("Dark grass", Color("#477b43"), 0.96),
		"driveway": _material("Driveway", Color("#929a99"), 0.92),
		"wood": _material("Wood", Color("#825a35"), 0.86),
		"leaf": _material("Leaf green", Color("#3c9b54"), 0.88),
		"leaf_light": _material("Leaf light", Color("#69bd59"), 0.88),
		"window": _material("House windows", Color("#285c79"), 0.23, 0.10),
		"window_glow": _material("Warm window", Color("#f7c96d"), 0.34),
		"door": _material("Door", Color("#294d67"), 0.60),
		"roof_red": _material("Red roof", Color("#a94b3e"), 0.82),
		"roof_blue": _material("Blue roof", Color("#415f79"), 0.82),
		"roof_brown": _material("Brown roof", Color("#735143"), 0.84),
		"house_cream": _material("Cream house", Color("#f0d9ad"), 0.82),
		"house_blue": _material("Blue house", Color("#8fc4cf"), 0.82),
		"house_coral": _material("Coral house", Color("#dc8874"), 0.82),
		"house_green": _material("Green house", Color("#a9c890"), 0.82),
		"house_lilac": _material("Lilac house", Color("#bea9cd"), 0.82),
		"house_yellow": _material("Yellow house", Color("#e8ca70"), 0.82),
		"white": _material("Trim", Color("#f1eee4"), 0.78),
		"metal": _material("Street metal", Color("#46545b"), 0.38, 0.48),
		"lamp": _material("Lamp glow", Color("#ffd779"), 0.28),
		"mail_red": _material("Mailbox red", Color("#b7473f"), 0.66),
	}


func _material(label: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SunnyWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#7fc7ed")
	environment.background_energy_multiplier = 0.62
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8e3e0")
	environment.ambient_light_energy = 0.22
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.78
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.light_color = Color("#fff0cc")
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.rotation_degrees = Vector3(-48.0, -35.0, -18.0)
	add_child(sun)


func _build_street() -> void:
	var street := Node3D.new()
	street.name = "StreetBlockout"
	add_child(street)

	_box(street, "Road", Vector3(0.0, -0.09, 0.0), Vector3(STREET_LENGTH, 0.18, ROAD_HALF_WIDTH * 2.0), _materials.road)
	var road_body := StaticBody3D.new()
	road_body.name = "RoadCollision"
	road_body.collision_layer = 1
	road_body.collision_mask = 3
	var road_collision := CollisionShape3D.new()
	var road_shape := BoxShape3D.new()
	road_shape.size = Vector3(STREET_LENGTH, 0.18, ROAD_HALF_WIDTH * 2.0)
	road_collision.shape = road_shape
	road_collision.position = Vector3(0.0, -0.09, 0.0)
	road_body.add_child(road_collision)
	street.add_child(road_body)
	_box(street, "FarGrass", Vector3(0.0, -0.10, -12.7), Vector3(STREET_LENGTH, 0.18, 12.0), _materials.grass)
	_box(street, "NearGrass", Vector3(0.0, -0.10, 12.7), Vector3(STREET_LENGTH, 0.18, 12.0), _materials.grass_dark)

	for side: float in [-1.0, 1.0]:
		_box(street, "Sidewalk_%s" % side, Vector3(0.0, 0.04, side * 6.65), Vector3(STREET_LENGTH, 0.24, 2.15), _materials.concrete)
		_box(street, "Curb_%s" % side, Vector3(0.0, 0.14, side * CURB_Z), Vector3(STREET_LENGTH, 0.38, 0.32), _materials.curb)

	for x: float in range(-34, 35, 7):
		_box(street, "CentreLine_%d" % int(x), Vector3(x, 0.025, 0.0), Vector3(3.6, 0.035, 0.14), _materials.yellow)

	for x: float in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
		_box(street, "Driveway_%d" % int(x), Vector3(x - 1.85, 0.035, -8.8), Vector3(3.2, 0.10, 5.4), _materials.driveway)

	for x: float in [-27.5, -3.5, 20.5]:
		_build_streetlight(street, Vector3(x, 0.0, -7.75))


func _build_house_lots() -> void:
	var houses := Node3D.new()
	houses.name = "HouseLots"
	add_child(houses)

	var body_materials: Array[Material] = [
		_materials.house_cream,
		_materials.house_blue,
		_materials.house_coral,
		_materials.house_green,
		_materials.house_lilac,
		_materials.house_yellow,
	]
	var roof_materials: Array[Material] = [
		_materials.roof_red,
		_materials.roof_blue,
		_materials.roof_brown,
	]
	var positions: Array[float] = [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]

	for index in positions.size():
		var position_x := positions[index]
		_build_house(
			houses,
			"House_%02d" % (index + 1),
			Vector3(position_x, 0.0, HOUSE_Z),
			body_materials[index],
			roof_materials[index % roof_materials.size()],
			index % 2 == 0,
		)
		_build_mailbox(houses, Vector3(position_x + 3.2, 0.0, -7.95), index)
		_build_tree(houses, Vector3(position_x + (4.5 if index % 2 == 0 else -4.4), 0.0, -11.1), index)


func _build_house(
	parent: Node3D,
	label: String,
	position: Vector3,
	body_material: Material,
	roof_material: Material,
	garage_left: bool,
) -> void:
	var house := Node3D.new()
	house.name = label
	house.position = position
	parent.add_child(house)

	_box(house, "Body", Vector3(0.0, 2.25, 0.0), Vector3(8.3, 4.5, 6.0), body_material)
	_box(house, "Foundation", Vector3(0.0, 0.30, 0.0), Vector3(8.6, 0.60, 6.25), _materials.white)
	_box(house, "Roof_Left", Vector3(0.0, 5.05, -1.42), Vector3(8.85, 0.34, 3.50), roof_material, Vector3(-20.0, 0.0, 0.0))
	_box(house, "Roof_Right", Vector3(0.0, 5.05, 1.42), Vector3(8.85, 0.34, 3.50), roof_material, Vector3(20.0, 0.0, 0.0))
	_box(house, "Chimney", Vector3(2.55, 5.45, -0.85), Vector3(0.70, 1.55, 0.70), _materials.roof_brown)

	var garage_x := -1.85 if garage_left else 1.85
	var door_x := 2.60 if garage_left else -2.60
	_box(house, "GarageDoor", Vector3(garage_x, 1.54, 3.035), Vector3(3.60, 2.75, 0.12), _materials.white)
	for panel_y: float in [0.65, 1.25, 1.85, 2.45]:
		_box(house, "GaragePanel", Vector3(garage_x, panel_y, 3.102), Vector3(3.25, 0.07, 0.035), _materials.concrete)
	_box(house, "FrontDoor", Vector3(door_x, 1.46, 3.06), Vector3(1.10, 2.72, 0.16), _materials.door)
	_box(house, "DoorWindow", Vector3(door_x, 2.12, 3.155), Vector3(0.48, 0.72, 0.06), _materials.window_glow)

	for window_x: float in [-0.48, 0.78]:
		var adjusted_x := window_x + (1.25 if garage_left else -1.25)
		_box(house, "Window", Vector3(adjusted_x, 3.20, 3.075), Vector3(0.95, 0.94, 0.12), _materials.window)
		_box(house, "WindowTopTrim", Vector3(adjusted_x, 3.73, 3.145), Vector3(1.14, 0.11, 0.06), _materials.white)

	_box(house, "FrontStep", Vector3(door_x, 0.16, 3.52), Vector3(1.55, 0.30, 0.92), _materials.concrete)


func _build_mailbox(parent: Node3D, position: Vector3, variation: int) -> void:
	var mailbox := Node3D.new()
	mailbox.name = "Mailbox_%02d" % variation
	mailbox.position = position
	parent.add_child(mailbox)
	_box(mailbox, "Post", Vector3(0.0, 0.72, 0.0), Vector3(0.17, 1.44, 0.17), _materials.wood)
	_box(mailbox, "Box", Vector3(0.0, 1.43, 0.0), Vector3(0.76, 0.48, 0.48), _materials.mail_red)
	_box(mailbox, "Flag", Vector3(0.46, 1.55, 0.0), Vector3(0.09, 0.68, 0.08), _materials.yellow, Vector3(0.0, 0.0, -18.0))


func _build_tree(parent: Node3D, position: Vector3, variation: int) -> void:
	var tree := Node3D.new()
	tree.name = "Tree_%02d" % variation
	tree.position = position
	parent.add_child(tree)
	_cylinder(tree, "Trunk", Vector3(0.0, 1.15, 0.0), 0.25, 2.30, _materials.wood, 8)
	_sphere(tree, "CrownLower", Vector3(0.0, 2.72, 0.0), Vector3(1.12, 1.18, 1.05), _materials.leaf, 9, 5)
	_sphere(tree, "CrownUpper", Vector3(0.20, 3.70, -0.10), Vector3(0.86, 0.95, 0.82), _materials.leaf_light, 9, 5)


func _build_streetlight(parent: Node3D, position: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "Streetlight"
	lamp.position = position
	parent.add_child(lamp)
	_cylinder(lamp, "Pole", Vector3(0.0, 2.25, 0.0), 0.09, 4.50, _materials.metal, 10)
	_box(lamp, "Arm", Vector3(0.0, 4.47, 0.48), Vector3(0.12, 0.12, 1.05), _materials.metal)
	_sphere(lamp, "Lamp", Vector3(0.0, 4.40, 0.96), Vector3(0.22, 0.14, 0.30), _materials.lamp, 10, 5)


func _place_truck_and_cans() -> void:
	var imported_set := ASSET_SET.instantiate()
	imported_set.name = "CollectionAssets"
	add_child(imported_set)

	var truck := imported_set.find_child("GarbageTruck_Root", true, false) as Node3D
	var first_can := imported_set.find_child("ResidentialCan_Root", true, false) as Node3D
	if truck == null or first_can == null:
		push_error("The GLB is missing the expected truck or residential can root.")
		return

	_player_truck = TRUCK_CONTROLLER.new()
	_player_truck.name = "PlayerTruck"
	_player_truck.position = Vector3(33.0, 0.07, 1.42)
	imported_set.add_child(_player_truck)

	truck.reparent(_player_truck, false)
	truck.position = Vector3.ZERO
	truck.rotation = Vector3.ZERO
	_player_truck.attach_visual(truck)

	var collision := CollisionShape3D.new()
	collision.name = "TruckCollision"
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(7.65, 3.25, 2.45)
	collision.shape = collision_shape
	collision.position = Vector3(0.0, 1.62, 0.0)
	_player_truck.add_child(collision)

	first_can.position = Vector3.ZERO
	first_can.rotation = Vector3.ZERO
	var can_visuals: Array[Node3D] = [first_can]
	for _index in 5:
		var duplicate_visual := first_can.duplicate() as Node3D
		imported_set.add_child(duplicate_visual)
		can_visuals.append(duplicate_visual)

	var can_positions: Array[float] = [27.0, 15.0, 3.0, -9.0, -21.0, -31.0]
	for index in can_positions.size():
		var can_target = TRASH_CAN.new()
		can_target.name = "CollectibleCan_%02d" % (index + 1)
		can_target.position = Vector3(can_positions[index], 0.06, 5.02)
		can_target.rotation_degrees.y = -4.0 if index % 2 == 0 else 3.0
		imported_set.add_child(can_target)
		var can_visual := can_visuals[index]
		can_visual.name = "ResidentialCanVisual_%02d" % (index + 1)
		can_visual.reparent(can_target, false)
		can_visual.position = Vector3.ZERO
		can_visual.rotation = Vector3.ZERO
		can_target.configure(can_visual)

	_side_loader = SIDE_LOADER.new()
	_side_loader.name = "SideLoaderController"
	_player_truck.add_child(_side_loader)
	_side_loader.status_changed.connect(_on_collection_status_changed)
	_side_loader.count_changed.connect(_on_collection_count_changed)
	_side_loader.cargo_changed.connect(_on_cargo_changed)
	_side_loader.configure(_player_truck, truck)


func _build_camera() -> void:
	var camera = TRUCK_FOLLOW_CAMERA.new()
	camera.name = "TruckFollowCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.8
	add_child(camera)
	camera.current = true
	camera.attach_to(_player_truck)


func _build_stage_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameUI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(26.0, 24.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.09, 0.11, 0.82)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 13.0
	panel_style.content_margin_bottom = 13.0
	panel.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(panel)

	var label := Label.new()
	label.text = "LITTLE CLEAN CREW\nFirst playable route"
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color("#fff1c7"))
	panel.add_child(label)

	var speed_panel := PanelContainer.new()
	speed_panel.position = Vector2(1110.0, 24.0)
	speed_panel.custom_minimum_size = Vector2(142.0, 94.0)
	var speed_style := StyleBoxFlat.new()
	speed_style.bg_color = Color(0.055, 0.09, 0.11, 0.82)
	speed_style.corner_radius_top_left = 14
	speed_style.corner_radius_top_right = 14
	speed_style.corner_radius_bottom_left = 14
	speed_style.corner_radius_bottom_right = 14
	speed_style.content_margin_left = 18.0
	speed_style.content_margin_right = 18.0
	speed_style.content_margin_top = 10.0
	speed_style.content_margin_bottom = 10.0
	speed_panel.add_theme_stylebox_override("panel", speed_style)
	canvas.add_child(speed_panel)
	_speed_label = Label.new()
	_speed_label.text = "00\nkm/h"
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 20)
	_speed_label.add_theme_color_override("font_color", Color("#fff1c7"))
	speed_panel.add_child(_speed_label)

	var counter_panel := PanelContainer.new()
	counter_panel.position = Vector2(1075.0, 132.0)
	counter_panel.custom_minimum_size = Vector2(177.0, 72.0)
	counter_panel.add_theme_stylebox_override("panel", speed_style)
	canvas.add_child(counter_panel)
	_counter_label = Label.new()
	_counter_label.text = "CANS  0 / 6\nHOPPER  0 PIECES"
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 16)
	_counter_label.add_theme_color_override("font_color", Color("#fff1c7"))
	counter_panel.add_child(_counter_label)

	var controls_panel := PanelContainer.new()
	controls_panel.position = Vector2(260.0, 632.0)
	controls_panel.custom_minimum_size = Vector2(760.0, 66.0)
	var controls_style := StyleBoxFlat.new()
	controls_style.bg_color = Color(0.055, 0.09, 0.11, 0.76)
	controls_style.corner_radius_top_left = 12
	controls_style.corner_radius_top_right = 12
	controls_style.corner_radius_bottom_left = 12
	controls_style.corner_radius_bottom_right = 12
	controls_style.content_margin_left = 18.0
	controls_style.content_margin_right = 18.0
	controls_style.content_margin_top = 9.0
	controls_style.content_margin_bottom = 9.0
	controls_panel.add_theme_stylebox_override("panel", controls_style)
	canvas.add_child(controls_panel)
	_status_label = Label.new()
	_status_label.text = "Drive beside a blue can\nWASD / arrows drive · E / Y picks up · F / RB dumps"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color("#fff1c7"))
	controls_panel.add_child(_status_label)


func _on_collection_status_changed(message: String) -> void:
	if _status_label != null:
		var hint := "WASD / arrows drive · E / Y picks up · F / RB dumps"
		if message.begins_with("Route complete"):
			hint = "Stop and press F / gamepad RB to empty the truck"
		elif message.begins_with("Truck empty"):
			hint = "Press R or gamepad START to play the route again"
		_status_label.text = "%s\n%s" % [message, hint]


func _on_collection_count_changed(collected: int, total: int) -> void:
	_displayed_collected = collected
	_displayed_total = total
	_refresh_counter_label()


func _on_cargo_changed(pieces: int) -> void:
	_displayed_cargo = pieces
	_refresh_counter_label()


func _refresh_counter_label() -> void:
	if _counter_label != null:
		_counter_label.text = "CANS  %d / %d\nHOPPER  %d PIECES" % [
			_displayed_collected,
			_displayed_total,
			_displayed_cargo,
		]


func _align_with_first_can() -> void:
	_player_truck.position = Vector3(27.0, 0.07, 1.42)
	_player_truck.rotation.y = 0.0
	_player_truck.current_speed = 0.0


func _box(
	parent: Node3D,
	label: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _cylinder(
	parent: Node3D,
	label: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material,
	segments: int,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(
	parent: Node3D,
	label: String,
	position: Vector3,
	scale_value: Vector3,
	material: Material,
	radial_segments: int,
	rings: int,
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _capture_stage_two() -> void:
	_player_truck.set_test_input(0.70, 0.16)
	for _frame in 42:
		await get_tree().physics_frame
	_player_truck.clear_test_input()
	for _frame in 10:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://renders/stage2_driving.png")
	var result := screenshot.save_png(output_path)
	if result != OK:
		push_error("Could not save Stage 2 screenshot: %s" % error_string(result))
	else:
		print("Saved Stage 2 screenshot: %s" % output_path)
	get_tree().quit()


func _capture_first_version() -> void:
	_align_with_first_can()
	var frame_budget := 480
	while _side_loader.current_phase != "dumping" and frame_budget > 0:
		await get_tree().process_frame
		frame_budget -= 1
	if frame_budget <= 0:
		push_error("Timed out waiting for the pickup animation to reach its dumping phase.")
		get_tree().quit(1)
		return
	# Wait until the can has tipped and the loose trash has started falling.
	await get_tree().create_timer(0.86).timeout
	for _frame in 3:
		await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://renders/first_playable_pickup.png")
	var result := screenshot.save_png(output_path)
	if result != OK:
		push_error("Could not save first-version screenshot: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("Saved first playable screenshot: %s" % output_path)
	get_tree().quit()


func _capture_rear_dump() -> void:
	Engine.time_scale = 5.0
	_align_with_first_can()
	var pickup_deadline := Time.get_ticks_msec() + 6_000
	while _side_loader.collected_count < 1 and Time.get_ticks_msec() < pickup_deadline:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if _side_loader.collected_count < 1 or not _side_loader.request_rear_dump():
		push_error("Could not prepare the rear-dump preview.")
		get_tree().quit(1)
		return
	var dump_deadline := Time.get_ticks_msec() + 4_000
	while _side_loader.current_phase != "dumping_load" and Time.get_ticks_msec() < dump_deadline:
		await get_tree().process_frame
	await get_tree().create_timer(0.58).timeout
	for _frame in 3:
		await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://renders/rear_dump.png")
	var result := screenshot.save_png(output_path)
	if result != OK:
		push_error("Could not save rear-dump screenshot: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("Saved rear-dump screenshot: %s" % output_path)
	get_tree().quit()


func _capture_start_state() -> void:
	for _frame in 4:
		await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://renders/first_playable_start.png")
	var result := screenshot.save_png(output_path)
	if result != OK:
		push_error("Could not save start-state screenshot: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("Saved first-version start state: %s" % output_path)
	get_tree().quit()


func _run_pickup_smoke_test() -> void:
	_align_with_first_can()
	var deadline_msec := Time.get_ticks_msec() + 10_000
	while _side_loader.collected_count < 1 and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
	if _side_loader.collected_count < 1:
		push_error("Pickup smoke test failed: collection did not finish in time.")
		get_tree().quit(1)
		return
	if _side_loader.busy:
		push_error("Pickup smoke test failed: loader remained busy after collection.")
		get_tree().quit(1)
		return
	if _player_truck.controls_locked:
		push_error("Pickup smoke test failed: driving remained locked after collection.")
		get_tree().quit(1)
		return
	if absf(rad_to_deg(_side_loader.lift_pivot.rotation.x) - (-62.0)) > 0.7:
		push_error("Pickup smoke test failed: loader did not return to its stowed angle.")
		get_tree().quit(1)
		return
	var emptied_count := 0
	for can in get_tree().get_nodes_in_group("collectible_cans"):
		if can.emptied:
			emptied_count += 1
	if emptied_count != 1:
		push_error("Pickup smoke test failed: expected one empty can, found %d." % emptied_count)
		get_tree().quit(1)
		return
	# Let temporary trash timers finish before ending the headless scene. This
	# keeps the smoke-test shutdown clean as well as checking their cleanup path.
	await get_tree().create_timer(1.4).timeout
	if _side_loader.cargo_piece_count() != 10:
		push_error(
			"Pickup smoke test failed: expected 10 hopper pieces, found %d." %
			_side_loader.cargo_piece_count()
		)
		get_tree().quit(1)
		return
	print("Pickup smoke test passed: arm cycled, trash spawned, can returned, and controls unlocked.")
	get_tree().quit()


func _run_rear_dump_smoke_test() -> void:
	Engine.time_scale = 5.0
	_align_with_first_can()
	var pickup_deadline := Time.get_ticks_msec() + 6_000
	while _side_loader.collected_count < 1 and Time.get_ticks_msec() < pickup_deadline:
		await get_tree().process_frame
	if _side_loader.collected_count < 1:
		Engine.time_scale = 1.0
		push_error("Rear-dump smoke test failed: pickup did not finish.")
		get_tree().quit(1)
		return
	if _side_loader.cargo_piece_count() != 10:
		Engine.time_scale = 1.0
		push_error("Rear-dump smoke test failed: pickup did not produce ten hopper pieces.")
		get_tree().quit(1)
		return
	if not _side_loader.request_rear_dump():
		Engine.time_scale = 1.0
		push_error("Rear-dump smoke test failed: controller rejected the dump request.")
		get_tree().quit(1)
		return
	var dump_deadline := Time.get_ticks_msec() + 6_000
	while _side_loader.busy and Time.get_ticks_msec() < dump_deadline:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if _side_loader.busy:
		push_error("Rear-dump smoke test failed: dump animation did not finish.")
		get_tree().quit(1)
		return
	if _side_loader.cargo_piece_count() != 0:
		push_error("Rear-dump smoke test failed: hopper was not emptied.")
		get_tree().quit(1)
		return
	if absf(_side_loader.tailgate_pivot.rotation.z) > 0.01:
		push_error("Rear-dump smoke test failed: tailgate did not close.")
		get_tree().quit(1)
		return
	if _player_truck.controls_locked:
		push_error("Rear-dump smoke test failed: driving remained locked.")
		get_tree().quit(1)
		return
	var dumped_pieces := get_tree().get_nodes_in_group("dumped_trash").size()
	if dumped_pieces != 10:
		push_error("Rear-dump smoke test failed: expected 10 dumped pieces, found %d." % dumped_pieces)
		get_tree().quit(1)
		return
	for dumped_piece in get_tree().get_nodes_in_group("dumped_trash"):
		dumped_piece.queue_free()
	await get_tree().process_frame
	print("Rear-dump smoke test passed: tailgate opened, 10 pieces spilled, hopper cleared, and tailgate closed.")
	get_tree().quit()


func _run_full_route_smoke_test() -> void:
	# Accelerate authored timings while still exercising every real tween, timer,
	# state transition, can wrapper, counter update, and completion condition.
	Engine.time_scale = 6.0
	var route_positions: Array[float] = [27.0, 15.0, 3.0, -9.0, -21.0, -31.0]
	for index in route_positions.size():
		_player_truck.position = Vector3(route_positions[index], 0.07, 1.42)
		_player_truck.rotation.y = 0.0
		_player_truck.current_speed = 0.0
		var expected_count := index + 1
		var deadline_msec := Time.get_ticks_msec() + 4_000
		while _side_loader.collected_count < expected_count and Time.get_ticks_msec() < deadline_msec:
			await get_tree().process_frame
		if _side_loader.collected_count != expected_count:
			Engine.time_scale = 1.0
			push_error(
				"Full-route test failed at can %d: collected %d of %d." % [
					expected_count,
					_side_loader.collected_count,
					_side_loader.total_count,
				]
			)
			get_tree().quit(1)
			return

	Engine.time_scale = 1.0
	if _side_loader.collected_count != 6 or _side_loader.total_count != 6:
		push_error("Full-route test failed: final counter was not 6 / 6.")
		get_tree().quit(1)
		return
	if _side_loader.cargo_piece_count() != 60:
		Engine.time_scale = 1.0
		push_error(
			"Full-route test failed: expected 60 hopper pieces, found %d." %
			_side_loader.cargo_piece_count()
		)
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.5).timeout
	print("Full-route smoke test passed: all six cans were emptied and route completion was reached.")
	get_tree().quit()


func _run_driving_smoke_test() -> void:
	var start_position: Vector3 = _player_truck.global_position
	var start_heading: float = _player_truck.rotation.y
	_player_truck.set_test_input(1.0, 0.28)
	for _frame in 120:
		await get_tree().physics_frame
	_player_truck.set_test_input(0.0, 0.0, true)
	for _frame in 45:
		await get_tree().physics_frame
	_player_truck.clear_test_input()

	var distance: float = start_position.distance_to(_player_truck.global_position)
	var heading_change: float = absf(angle_difference(start_heading, _player_truck.rotation.y))
	if distance < 4.0:
		push_error("Driving smoke test failed: truck moved only %.2f metres." % distance)
		get_tree().quit(1)
		return
	if heading_change < 0.08:
		push_error("Driving smoke test failed: steering changed heading by only %.3f radians." % heading_change)
		get_tree().quit(1)
		return
	if absf(_player_truck.current_speed) > 0.08:
		push_error("Driving smoke test failed: brake left speed at %.3f m/s." % _player_truck.current_speed)
		get_tree().quit(1)
		return

	print(
		"Driving smoke test passed: moved %.2f m, turned %.2f°, and stopped." % [
			distance,
			rad_to_deg(heading_change),
		]
	)
	get_tree().quit()
