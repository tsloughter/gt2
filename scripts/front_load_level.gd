extends "res://scripts/neighborhood.gd"

const FRONT_LOADER := preload("res://scripts/front_loader.gd")
const DUMPSTER_POSITIONS := [22.0, 4.0, -14.0]


func _ready() -> void:
	route_title = "Front loader · Market Lane"
	container_label = "DUMPSTERS"
	_displayed_total = DUMPSTER_POSITIONS.size()
	super._ready()
	_refresh_counter_label()
	var args := OS.get_cmdline_user_args()
	if "--smoke-front-route" in args:
		_run_front_route_test.call_deferred()
	elif "--capture-front" in args:
		_capture_front.call_deferred()


func _build_house_lots() -> void:
	var shops := Node3D.new()
	shops.name = "MarketLane"
	add_child(shops)
	var names := ["CORNER MARKET", "SUNSHINE BAKERY", "THE WORKSHOP"]
	var colors := ["house_coral", "house_yellow", "house_blue"]
	for index in DUMPSTER_POSITIONS.size():
		var x: float = DUMPSTER_POSITIONS[index]
		_box(shops, "Shop", Vector3(x, 2.2, -11.5), Vector3(13.0, 4.4, 7.0), _materials[colors[index]])
		_box(shops, "FlatRoof", Vector3(x, 4.5, -11.5), Vector3(13.5, 0.25, 7.5), _materials.roof_blue)
		_box(shops, "StoreWindow", Vector3(x, 2.1, -7.95), Vector3(8.0, 2.1, 0.1), _materials.window)
		_box(shops, "Awning", Vector3(x, 3.45, -7.3), Vector3(9.0, 0.22, 1.7), _materials.white)
		var sign := Label3D.new()
		sign.text = names[index]
		sign.position = Vector3(x, 3.95, -7.93)
		sign.font_size = 58
		sign.pixel_size = 0.007
		shops.add_child(sign)
		_build_tree(shops, Vector3(x + 7.2, 0.0, -8.5), index)
		# Mark each service bay with a pad and yellow corner lines.
		_box(shops, "DumpsterPad", Vector3(x, 0.015, 1.42), Vector3(4.2, 0.035, 4.3), _materials.driveway)
		for z: float in [-0.7, 3.55]:
			_box(shops, "BayLine", Vector3(x, 0.04, z), Vector3(4.2, 0.025, 0.12), _materials.yellow)
		var bay := Label3D.new()
		bay.text = "PICKUP %d" % (index + 1)
		bay.position = Vector3(x + 4.0, 0.055, 1.42)
		bay.rotation_degrees.x = -90.0
		bay.rotation_degrees.z = 90.0
		bay.font_size = 42
		bay.pixel_size = 0.012
		shops.add_child(bay)


func _place_truck_and_cans() -> void:
	var imported := ASSET_SET.instantiate()
	add_child(imported)
	var truck := imported.find_child("GarbageTruck_Root", true, false) as Node3D
	_player_truck = TRUCK_CONTROLLER.new()
	_player_truck.name = "PlayerFrontLoader"
	_player_truck.position = Vector3(33.0, 0.07, 1.42)
	add_child(_player_truck)
	truck.reparent(_player_truck, false)
	truck.transform = Transform3D.IDENTITY
	imported.queue_free()
	var side_arm := truck.find_child("SideLoader_BasePivot", true, false)
	truck.remove_child(side_arm)
	side_arm.queue_free()
	_build_front_forks(truck)
	_player_truck.attach_visual(truck)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.65, 3.25, 2.45)
	collision.shape = shape
	collision.position = Vector3(0.0, 1.62, 0.0)
	_player_truck.add_child(collision)
	for index in DUMPSTER_POSITIONS.size():
		_build_dumpster(index)
	_side_loader = FRONT_LOADER.new()
	_side_loader.name = "FrontLoaderController"
	_player_truck.add_child(_side_loader)
	_side_loader.status_changed.connect(_on_collection_status_changed)
	_side_loader.count_changed.connect(_on_collection_count_changed)
	_side_loader.cargo_changed.connect(_on_cargo_changed)
	_side_loader.configure(_player_truck, truck)


func _build_front_forks(truck: Node3D) -> void:
	var orange := _material("Loader orange", Color("#f6ac36"), 0.4, 0.25)
	var lift := Node3D.new()
	lift.name = "FrontLoaderLift"
	lift.position = Vector3(-1.0, 2.8, 0.0)
	truck.add_child(lift)
	for side: float in [-1.0, 1.0]:
		var z := side * 1.65
		_box(truck, "FrontArmMount", Vector3(-1.0, 2.6, z), Vector3(0.65, 1.0, 0.35), orange)
		_beam(lift, Vector3(0.0, 0.0, z), Vector3(-4.7, 0.3, z), 0.24, orange)
		_beam(lift, Vector3(-4.7, 0.3, z), Vector3(-5.6, -1.9, z), 0.24, orange)
		_beam(lift, Vector3(-0.3, -0.18, z), Vector3(-2.6, 0.1, z), 0.12, _materials.metal)
	var carriage := Node3D.new()
	carriage.name = "ForkCarriage"
	carriage.position = FRONT_LOADER.FORK_OFFSET
	lift.add_child(carriage)
	for side: float in [-1.0, 1.0]:
		_box(carriage, "Fork", Vector3(0.0, 0.0, side * 1.43), Vector3(2.65, 0.13, 0.16), _materials.metal)
		_box(carriage, "ForkPin", Vector3(0.0, 0.0, side * 1.65), Vector3(0.38, 0.38, 0.25), orange)


func _beam(parent: Node3D, start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var beam := _box(parent, "LiftArm", (start + end) * 0.5, Vector3(start.distance_to(end), width, width), material)
	beam.rotation.z = atan2(end.y - start.y, end.x - start.x)


func _build_dumpster(index: int) -> void:
	var dumpster = TRASH_CAN.new()
	dumpster.name = "Dumpster_%02d" % (index + 1)
	dumpster.container_group = "collectible_dumpsters"
	dumpster.marker_height = 2.65
	dumpster.position = Vector3(DUMPSTER_POSITIONS[index], 0.06, 1.42)
	add_child(dumpster)
	var visual := Node3D.new()
	dumpster.add_child(visual)
	var green := _material("Dumpster green", Color("#268a70"), 0.62, 0.18)
	var dark := _materials.metal as Material
	_box(visual, "Floor", Vector3(0.0, 0.28, 0.0), Vector3(2.35, 0.18, 2.55), green)
	for x: float in [-1.12, 1.12]:
		_box(visual, "EndWall", Vector3(x, 1.15, 0.0), Vector3(0.13, 1.8, 2.55), green)
	for z: float in [-1.23, 1.23]:
		_box(visual, "SideWall", Vector3(0.0, 1.15, z), Vector3(2.35, 1.8, 0.13), green)
		for x: float in [-0.8, 0.0, 0.8]:
			_box(visual, "ReinforcingRib", Vector3(x, 1.15, z * 1.04), Vector3(0.09, 1.6, 0.08), _materials.grass_dark)
		# Open-ended sleeves, visibly surrounding the truck's steel fork tines.
		var pocket_z := signf(z) * 1.43
		for y: float in [0.81, 1.02]:
			_box(visual, "PocketRail", Vector3(0.0, y, pocket_z), Vector3(2.35, 0.07, 0.34), dark)
		_box(visual, "PocketOuter", Vector3(0.0, 0.915, signf(z) * 1.59), Vector3(2.35, 0.27, 0.07), dark)
	var lid := Node3D.new()
	lid.name = "ResidentialCan_LidPivot"
	lid.position = Vector3(1.18, 2.08, 0.0)
	visual.add_child(lid)
	_box(lid, "DumpsterLid", Vector3(-1.18, 0.0, 0.0), Vector3(2.52, 0.14, 2.72), dark)
	for z: float in [-0.67, 0.67]:
		_box(lid, "LidHandle", Vector3(-2.0, 0.13, z), Vector3(0.15, 0.15, 0.4), _materials.yellow)
	for x: float in [-0.88, 0.88]:
		for z: float in [-1.0, 1.0]:
			_box(visual, "Foot", Vector3(x, 0.12, z), Vector3(0.3, 0.24, 0.28), dark)
	var label := Label3D.new()
	label.text = "CLEAN CREW  %02d" % (index + 1)
	label.position = Vector3(0.0, 1.55, 1.31)
	label.font_size = 40
	label.pixel_size = 0.008
	visual.add_child(label)
	dumpster.configure(visual)


func _build_camera() -> void:
	super._build_camera()
	var camera = get_viewport().get_camera_3d()
	camera.world_offset = Vector3(-9.0, 12.5, 18.0)
	camera.size = 22.0
	camera.look_height = 2.5
	camera.snap_to_target()


func _capture_front() -> void:
	_player_truck.position.x = DUMPSTER_POSITIONS[0] + 6.6
	await _side_loader.phase_changed
	while _side_loader.current_phase != "dumping":
		await _side_loader.phase_changed
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://renders/front_loader_pickup.png")
	_side_loader._stop_hydraulics()
	_side_loader._rattle.stop()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()


func _run_front_route_test() -> void:
	Engine.time_scale = 6.0
	await get_tree().process_frame
	var dumpsters := get_tree().get_nodes_in_group("collectible_dumpsters")
	# Reject targets at the side, behind, and at a mismatched heading.
	for pose: Vector3 in [Vector3(22.0, 0.07, -2.0), Vector3(16.0, 0.07, 1.42), Vector3(28.6, 0.07, 3.0)]:
		_player_truck.position = pose
		if _side_loader._find_best_can() != null:
			push_error("Front route failed: invalid approach accepted")
			get_tree().quit(1)
			return
	_player_truck.position = Vector3(28.6, 0.07, 1.42)
	_player_truck.rotation.y = PI
	if _side_loader._find_best_can() != null:
		push_error("Front route failed: backward approach accepted")
		get_tree().quit(1)
		return
	_player_truck.rotation.y = 0.0
	for index in dumpsters.size():
		var dumpster = dumpsters[index]
		var original: Transform3D = dumpster.global_transform
		_player_truck.position = Vector3(DUMPSTER_POSITIONS[index] + 6.6, 0.07, 1.42)
		_player_truck.current_speed = 0.0
		var deadline := Time.get_ticks_msec() + 8000
		while _side_loader.collected_count <= index and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if _side_loader.collected_count != index + 1 or not dumpster.emptied or not dumpster.global_transform.is_equal_approx(original):
			push_error("Front route failed: dumpster was not emptied and returned to its pad")
			get_tree().quit(1)
			return
		if _side_loader.busy or _player_truck.controls_locked or absf(_side_loader.lift_pivot.rotation.z) > 0.01:
			push_error("Front route failed: forks or driving did not reset")
			get_tree().quit(1)
			return
	if _side_loader.total_count != 3 or _side_loader.cargo_piece_count() != 30 or not _check_hopper_containment():
		push_error("Front route failed: incorrect route total or hopper load")
		get_tree().quit(1)
		return
	if not _side_loader.request_rear_dump():
		push_error("Front route failed: rear dump rejected")
		get_tree().quit(1)
		return
	var dump_deadline := Time.get_ticks_msec() + 8000
	while _side_loader.busy and Time.get_ticks_msec() < dump_deadline:
		await get_tree().process_frame
	if _side_loader.busy or _side_loader.cargo_piece_count() != 0 or _player_truck.controls_locked or get_tree().get_nodes_in_group("dumped_trash").size() != 30:
		push_error("Front route failed: rear dump did not complete")
		get_tree().quit(1)
		return
	Engine.time_scale = 1.0
	for piece in get_tree().get_nodes_in_group("dumped_trash"):
		piece.queue_free()
	# As in the side-loader dump check, allow stopped audio to leave the mixer.
	await get_tree().create_timer(0.25).timeout
	print("Front route passed: approach checks, three overhead pickups, dumpster returns, hopper containment, and rear dump.")
	get_tree().quit()
