class_name SideLoaderController
extends Node

signal status_changed(message: String)
signal count_changed(collected: int, total: int)
signal cargo_changed(pieces: int)
signal phase_changed(phase: String)
signal pickup_completed(can: Node3D)
signal dump_completed(pieces: int)

const AUTO_PICKUP_DELAY := 0.72
const STOPPED_SPEED := 0.72
const STOW_ANGLE := -62.0
const LIFT_ANGLE := -108.0
const COUNTER_LIFT_ANGLE := 108.0
# Tip 94 degrees inward from the counter-lift pose, toward the hopper. Positive
# X rotation points the can away from the truck on the passenger-side loader.
const TIP_ANGLE := 14.0
const PIECES_PER_CAN := 10
const TAILGATE_OPEN_ANGLE := 102.0
const CARGO_ENTRY_TIME := 1.05
const HOPPER_FLOOR_Y := 2.40

var truck
var visual_root: Node3D
var lift_pivot: Node3D
var extension_pivot: Node3D
var grabber_pivot: Node3D
var left_claw: Node3D
var right_claw: Node3D
var hopper: Node3D
var tailgate_pivot: Node3D
var current_phase := "driving"
var collected_count := 0
var total_count := 0
var busy := false

var _target_can
var _auto_timer := 0.0
var _manual_was_pressed := false
var _dump_was_pressed := false
var _left_open_position := Vector3.ZERO
var _right_open_position := Vector3.ZERO
var _cargo_root: Node3D
var _cargo_pieces: Array[MeshInstance3D] = []
var _last_status := ""
var _rng := RandomNumberGenerator.new()
var _hydraulics: AudioStreamPlayer3D
var _chime: AudioStreamPlayer
var _rattle: AudioStreamPlayer3D


func configure(truck_controller, truck_visual: Node3D) -> void:
	truck = truck_controller
	visual_root = truck_visual
	lift_pivot = visual_root.find_child("SideLoader_LiftPivot", true, false) as Node3D
	extension_pivot = visual_root.find_child("SideLoader_ExtensionPivot", true, false) as Node3D
	grabber_pivot = visual_root.find_child("SideLoader_GrabberPivot", true, false) as Node3D
	left_claw = visual_root.find_child("SideLoader_LeftClawPivot", true, false) as Node3D
	right_claw = visual_root.find_child("SideLoader_RightClawPivot", true, false) as Node3D
	hopper = visual_root.find_child("Hopper_Opening", true, false) as Node3D
	if lift_pivot == null or grabber_pivot == null or left_claw == null or right_claw == null:
		push_error("Side-loader model is missing one or more required pivot nodes.")
		set_process(false)
		return

	_left_open_position = left_claw.position
	_right_open_position = right_claw.position
	_setup_cargo_hold()
	_setup_tailgate()
	lift_pivot.rotation.x = deg_to_rad(STOW_ANGLE)
	grabber_pivot.rotation.x = deg_to_rad(-STOW_ANGLE)
	_rng.seed = 20260912
	_setup_audio()
	call_deferred("_refresh_total")


func _refresh_total() -> void:
	total_count = get_tree().get_nodes_in_group("collectible_cans").size()
	count_changed.emit(collected_count, total_count)


func _process(delta: float) -> void:
	if truck == null:
		return

	var dump_pressed := _rear_dump_pressed()
	var dump_just_pressed := dump_pressed and not _dump_was_pressed
	_dump_was_pressed = dump_pressed
	if busy:
		return
	if dump_just_pressed and not _cargo_pieces.is_empty():
		if absf(truck.current_speed) > STOPPED_SPEED:
			_set_status("Stop the truck before opening the back door")
		else:
			_run_rear_dump()
		return
	if total_count > 0 and collected_count >= total_count:
		if _cargo_pieces.is_empty():
			_set_status("Truck empty! Great job!")
		else:
			_set_status("Route complete! Press F or gamepad RB to dump the load")
		return

	var manual_pressed := _manual_pickup_pressed()
	var manual_just_pressed := manual_pressed and not _manual_was_pressed
	_manual_was_pressed = manual_pressed
	var next_target = _find_best_can()
	_set_target(next_target)

	if _target_can == null:
		_auto_timer = 0.0
		_set_status("Drive beside a blue can")
		return

	if absf(truck.current_speed) > STOPPED_SPEED:
		_auto_timer = 0.0
		_set_status("Slow down beside the glowing can")
		return

	_auto_timer += delta
	var progress := clampf(_auto_timer / AUTO_PICKUP_DELAY, 0.0, 1.0)
	_set_status("Arm ready… %d%%   •   E / ENTER / Y" % roundi(progress * 100.0))
	if _auto_timer >= AUTO_PICKUP_DELAY or manual_just_pressed:
		var can_to_collect = _target_can
		_set_target(null)
		_run_pickup(can_to_collect)


func _find_best_can():
	var best_can = null
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("collectible_cans"):
		if candidate.emptied:
			continue
		var local_position: Vector3 = truck.to_local(candidate.global_position)
		if absf(local_position.x) > 1.75:
			continue
		if local_position.z < 2.55 or local_position.z > 5.15:
			continue
		var score := absf(local_position.x) + absf(local_position.z - 3.65) * 0.24
		if score < best_score:
			best_score = score
			best_can = candidate
	return best_can


func _set_target(next_target) -> void:
	if _target_can == next_target:
		return
	if _target_can != null:
		_target_can.set_targeted(false)
	_target_can = next_target
	_auto_timer = 0.0
	if _target_can != null:
		_target_can.set_targeted(true)


func _manual_pickup_pressed() -> bool:
	var pressed := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)
	for joypad_id in Input.get_connected_joypads():
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_Y)
	return pressed


func _rear_dump_pressed() -> bool:
	var pressed := Input.is_key_pressed(KEY_F)
	for joypad_id in Input.get_connected_joypads():
		pressed = pressed or Input.is_joy_button_pressed(joypad_id, JOY_BUTTON_RIGHT_SHOULDER)
	return pressed


func cargo_piece_count() -> int:
	return _cargo_pieces.size()


func request_rear_dump() -> bool:
	if busy or truck == null or _cargo_pieces.is_empty():
		return false
	if absf(truck.current_speed) > STOPPED_SPEED:
		return false
	_run_rear_dump()
	return true


func _run_pickup(can) -> void:
	busy = true
	truck.set_controls_locked(true)
	can.prepare_for_pickup()
	_set_phase("extending", "Extending the side-loader arm…")
	_start_hydraulics()

	var deploy := create_tween().set_parallel(true)
	deploy.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deploy.tween_property(lift_pivot, "rotation:x", 0.0, 0.78)
	deploy.tween_property(grabber_pivot, "rotation:x", 0.0, 0.78)
	await deploy.finished

	_set_phase("grabbing", "Grab! Holding the can safely")
	var close_claws := create_tween().set_parallel(true)
	close_claws.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	close_claws.tween_property(left_claw, "position", _left_open_position + Vector3(0.14, 0.0, 0.0), 0.28)
	close_claws.tween_property(right_claw, "position", _right_open_position - Vector3(0.14, 0.0, 0.0), 0.28)
	await close_claws.finished
	can.attach_to_loader(grabber_pivot)

	_set_phase("lifting", "Up it goes!")
	var lift := create_tween().set_parallel(true)
	lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	lift.tween_property(lift_pivot, "rotation:x", deg_to_rad(LIFT_ANGLE), 1.14)
	lift.tween_property(grabber_pivot, "rotation:x", deg_to_rad(COUNTER_LIFT_ANGLE), 1.14)
	await lift.finished

	_set_phase("dumping", "Tip, shake, and empty!")
	if can.lid_pivot != null:
		var open_lid := create_tween()
		open_lid.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		open_lid.tween_property(can.lid_pivot, "rotation:x", deg_to_rad(-112.0), 0.34)
	var tip := create_tween()
	tip.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tip.tween_property(grabber_pivot, "rotation:x", deg_to_rad(TIP_ANGLE), 0.62)
	await tip.finished
	_rattle.play()
	# Keep the can tipped until every piece has entered the actual cavity.
	await _spawn_trash(can.dump_origin()).finished

	_set_phase("returning", "Returning the empty can")
	var untilt := create_tween().set_parallel(true)
	untilt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	untilt.tween_property(grabber_pivot, "rotation:x", deg_to_rad(COUNTER_LIFT_ANGLE), 0.46)
	if can.lid_pivot != null:
		untilt.tween_property(can.lid_pivot, "rotation:x", 0.0, 0.46)
	await untilt.finished

	var lower := create_tween().set_parallel(true)
	lower.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	lower.tween_property(lift_pivot, "rotation:x", 0.0, 1.05)
	lower.tween_property(grabber_pivot, "rotation:x", 0.0, 1.05)
	await lower.finished
	can.return_home()

	var open_claws := create_tween().set_parallel(true)
	open_claws.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_claws.tween_property(left_claw, "position", _left_open_position, 0.25)
	open_claws.tween_property(right_claw, "position", _right_open_position, 0.25)
	await open_claws.finished

	_set_phase("stowing", "Arm tucked away—ready to drive!")
	var stow := create_tween().set_parallel(true)
	stow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stow.tween_property(lift_pivot, "rotation:x", deg_to_rad(STOW_ANGLE), 0.66)
	stow.tween_property(grabber_pivot, "rotation:x", deg_to_rad(-STOW_ANGLE), 0.66)
	await stow.finished
	_stop_hydraulics()

	can.mark_emptied()
	collected_count += 1
	count_changed.emit(collected_count, total_count)
	_chime.play()
	truck.set_controls_locked(false)
	busy = false
	_set_phase("driving", "Great pickup! Find the next blue can")
	pickup_completed.emit(can)
	if collected_count >= total_count:
		_set_status("Route complete! Press F or gamepad RB to dump the load")


func _setup_cargo_hold() -> void:
	_cargo_root = Node3D.new()
	_cargo_root.name = "HopperCargo"
	visual_root.add_child(_cargo_root)
	cargo_changed.emit(0)


func _setup_tailgate() -> void:
	var tailgate := visual_root.find_child("Rear_Tailgate", true, false) as Node3D
	if tailgate == null:
		push_error("The garbage-truck model is missing Rear_Tailgate.")
		return
	tailgate_pivot = Node3D.new()
	tailgate_pivot.name = "RearTailgatePivot"
	# The imported panel is 2.27 metres tall and centered at y=2.08.
	tailgate_pivot.position = Vector3(tailgate.position.x, tailgate.position.y + 1.135, tailgate.position.z)
	visual_root.add_child(tailgate_pivot)
	tailgate.reparent(tailgate_pivot, true)


func _run_rear_dump() -> void:
	busy = true
	truck.set_controls_locked(true)
	_chime.stop()
	_set_phase("opening_tailgate", "Opening the back door…")
	_start_hydraulics()

	if tailgate_pivot != null:
		var open_gate := create_tween()
		open_gate.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		open_gate.tween_property(tailgate_pivot, "rotation:z", deg_to_rad(TAILGATE_OPEN_ANGLE), 0.82)
		await open_gate.finished

	_set_phase("dumping_load", "Out comes the trash!")
	var dumped_count := _release_cargo()
	_rattle.play()
	await get_tree().create_timer(1.85).timeout

	_set_phase("closing_tailgate", "Closing the back door…")
	if tailgate_pivot != null:
		var close_gate := create_tween()
		close_gate.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		close_gate.tween_property(tailgate_pivot, "rotation:z", 0.0, 0.76)
		await close_gate.finished

	_stop_hydraulics()
	_rattle.stop()
	truck.set_controls_locked(false)
	busy = false
	_set_phase("driving", "Truck empty! Great job!")
	dump_completed.emit(dumped_count)


func _set_phase(phase: String, message: String) -> void:
	current_phase = phase
	phase_changed.emit(phase)
	_set_status(message)


func _set_status(message: String) -> void:
	if message == _last_status:
		return
	_last_status = message
	status_changed.emit(message)


func _setup_audio() -> void:
	_hydraulics = AudioStreamPlayer3D.new()
	_hydraulics.name = "HydraulicSound"
	_hydraulics.stream = _looping_wav("res://assets/audio/hydraulics.wav")
	_hydraulics.volume_db = -8.0
	_hydraulics.max_distance = 38.0
	add_child(_hydraulics)

	_chime = AudioStreamPlayer.new()
	_chime.name = "PickupChime"
	_chime.stream = load("res://assets/audio/pickup_chime.wav")
	_chime.volume_db = -5.0
	add_child(_chime)

	_rattle = AudioStreamPlayer3D.new()
	_rattle.name = "TrashRattle"
	_rattle.stream = load("res://assets/audio/trash_rattle.wav")
	_rattle.volume_db = -4.0
	_rattle.max_distance = 40.0
	add_child(_rattle)


func _looping_wav(path: String) -> AudioStream:
	var stream := load(path).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _start_hydraulics() -> void:
	if not _hydraulics.playing:
		_hydraulics.play()


func _stop_hydraulics() -> void:
	_hydraulics.stop()


func _spawn_trash(origin: Vector3) -> Tween:
	var colors: Array[Color] = [
		Color("#f1cf45"),
		Color("#ef7c62"),
		Color("#7cc7e8"),
		Color("#eee5d0"),
		Color("#9bce68"),
	]
	var collection := create_tween().set_parallel(true)
	var first_slot := _cargo_pieces.size()
	var local_origin := _cargo_root.to_local(origin)
	for index in PIECES_PER_CAN:
		var size := Vector3(
			_rng.randf_range(0.20, 0.30),
			0.22,
			_rng.randf_range(0.18, 0.24),
		)
		var piece := _create_trash_visual(size, colors[index % colors.size()])
		piece.name = "HopperPiece_%02d" % (first_slot + index + 1)
		_cargo_root.add_child(piece)
		var start := local_origin + Vector3(
			_rng.randf_range(-0.10, 0.10),
			_rng.randf_range(0.0, 0.08),
			_rng.randf_range(-0.08, 0.08),
		)
		var landing := _cargo_slot(first_slot + index)
		var yaw := _rng.randf_range(-0.15, 0.15)
		piece.position = start
		piece.visible = false
		var delay := float(index) * 0.035
		collection.tween_method(
			_animate_trash_entry.bind(piece, start, landing, yaw),
			0.0, 1.0, CARGO_ENTRY_TIME,
		).set_delay(delay)
		collection.tween_callback(_settle_trash_piece.bind(piece)).set_delay(delay + CARGO_ENTRY_TIME)
	return collection


func _cargo_slot(index: int) -> Vector3:
	# Thirty non-overlapping slots per layer; spread successive pieces across
	# the floor. Two layers hold the route's sixty pieces entirely below the rim.
	var cell := (index * 17) % 30
	var layer := floori(float(index) / 30.0)
	return Vector3(
		0.18 + float(cell % 6) * 0.43,
		HOPPER_FLOOR_Y + 0.11 + float(layer) * 0.22,
		-0.60 + float(floori(float(cell) / 6.0)) * 0.30,
	)


func _animate_trash_entry(progress: float, piece: MeshInstance3D, start: Vector3, landing: Vector3, yaw: float) -> void:
	piece.visible = true
	var entry := Vector3(landing.x, hopper.position.y + 0.35, landing.z)
	if progress < 0.55:
		# Clear the rim before descending. Using the truck's frame keeps the
		# same piece contained despite body lean or a different truck heading.
		var travel := progress / 0.55
		piece.position = start.bezier_interpolate(
			start + Vector3.UP * 0.90, entry + Vector3.UP * 0.45, entry, travel,
		)
		piece.rotation = Vector3(0.0, yaw + TAU * (1.0 - travel), 0.0)
	else:
		var fall := (progress - 0.55) / 0.45
		piece.position = entry.lerp(landing, fall * fall)
		piece.rotation = Vector3(0.0, yaw, 0.0)


func _settle_trash_piece(piece: MeshInstance3D) -> void:
	# Retain the very same mesh that entered the opening, at its landing pose.
	# Cargo travels with the truck; physics resumes only when it is rear-dumped.
	_cargo_pieces.append(piece)
	cargo_changed.emit(_cargo_pieces.size())


func _create_trash_visual(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	piece.material_override = material
	return piece


func _release_cargo() -> int:
	var pieces := _cargo_pieces.duplicate()
	_cargo_pieces.clear()
	cargo_changed.emit(0)
	var rear_direction: Vector3 = truck.global_transform.basis.x.normalized()
	var side_direction: Vector3 = truck.global_transform.basis.z.normalized()

	for index in pieces.size():
		var piece := pieces[index] as MeshInstance3D
		if not is_instance_valid(piece):
			continue
		var box_mesh := piece.mesh as BoxMesh
		var size := box_mesh.size

		var body := RigidBody3D.new()
		body.name = "DumpedTrash_%02d" % (index + 1)
		body.mass = 0.07
		body.gravity_scale = 1.25
		body.collision_layer = 2
		body.collision_mask = 1
		body.add_to_group("dumped_trash")
		get_tree().current_scene.add_child(body)
		body.global_position = visual_root.to_global(Vector3(
			4.18 + _rng.randf_range(-0.18, 0.22),
			1.34 + _rng.randf_range(-0.12, 0.54),
			_rng.randf_range(-0.82, 0.82),
		))
		body.rotation = Vector3(
			_rng.randf_range(-0.5, 0.5),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-0.5, 0.5),
		)
		piece.reparent(body, false)
		piece.position = Vector3.ZERO
		piece.rotation = Vector3.ZERO

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		body.linear_velocity = (
			rear_direction * _rng.randf_range(2.6, 4.4)
			+ Vector3.UP * _rng.randf_range(0.8, 2.0)
			+ side_direction * _rng.randf_range(-1.3, 1.3)
		)
		body.angular_velocity = Vector3(
			_rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-8.0, 8.0),
		)

		var cleanup := Timer.new()
		cleanup.one_shot = true
		cleanup.wait_time = 6.0
		cleanup.timeout.connect(body.queue_free)
		body.add_child(cleanup)
		cleanup.start()

	return pieces.size()
