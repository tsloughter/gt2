extends SceneTree

var _respawn_count := 0
var _respawn_valid := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 6.0
	for route_path in ["res://scripts/neighborhood.gd", "res://scripts/front_load_level.gd"]:
		var route = load(route_path).new()
		root.add_child(route)
		var truck: TruckController = route._player_truck
		var camera: Camera3D = root.get_camera_3d()
		# Capture the authored spawn before gravity settles the truck onto the road.
		var spawn := truck.global_transform
		truck.respawned.connect(func() -> void:
			_respawn_count += 1
			_respawn_valid = _respawn_valid and truck.global_transform.is_equal_approx(spawn)
			_respawn_valid = _respawn_valid and is_zero_approx(truck.current_speed) and truck.velocity.is_zero_approx()
			_respawn_valid = _respawn_valid and camera.global_position.is_equal_approx(spawn.origin + camera.world_offset)
		)
		# Collect a real load first so exits also exercise preservation of cargo
		# and route progress, including the loader's returned/stowed state.
		truck.position.x = 28.6 if "front_load" in route_path else 27.0
		var deadline := Time.get_ticks_msec() + 8000
		while route._side_loader.collected_count < 1 and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _expect(route._side_loader.collected_count == 1, "Initial pickup failed"):
			return
		if not _expect(truck.is_on_floor() and truck.position.y > -0.1, "Truck fell through the road during pickup"):
			return
		var cargo: Array = route._side_loader._cargo_pieces.duplicate()
		for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 720)]:
			root.size = viewport_size
			root.content_scale_size = viewport_size
			await process_frame
			for end: float in [-1.0, 1.0]:
				for throttle: float in [-1.0, 1.0]:
					var before := _respawn_count
					truck.position = Vector3(end * 37.0, spawn.origin.y, spawn.origin.z)
					truck.rotation.y = PI if end * throttle > 0.0 else 0.0
					truck.current_speed = 0.0
					camera.snap_to_target()
					truck.set_test_input(throttle, 0.0)
					var drove_past_end := false
					var tail_still_visible := false
					var fell_below_road := false
					deadline = Time.get_ticks_msec() + 8000
					while _respawn_count == before and Time.get_ticks_msec() < deadline:
						await process_frame
						if _respawn_count != before:
							break
						if absf(truck.position.x) > 39.0:
							drove_past_end = true
						if truck.position.y < spawn.origin.y - 2.0 and truck.velocity.y < -1.0:
							fell_below_road = true
						if not _expect(camera.global_position.y >= spawn.origin.y + camera.world_offset.y - 0.01, "Camera followed the truck down into the void"):
							return
						if not camera.is_position_in_frustum(truck.global_position) and truck.is_model_in_view(camera):
							tail_still_visible = true
					truck.set_test_input(0.0, 0.0, true)
					if not _expect(drove_past_end and tail_still_visible, "Truck must drive past the end and remain until its whole model leaves the view"):
						return
					if not _expect(fell_below_road, "Truck must fall under gravity before respawning"):
						return
					if not _expect(_respawn_count == before + 1 and _respawn_valid, "Truck failed to respawn safely with its camera reset"):
						return
					if not _expect(route._side_loader.collected_count == 1 and route._side_loader._cargo_pieces == cargo, "Respawn changed route progress or cargo"):
						return
		print("Road-exit test passed for %s: falls at both ends, forward/reverse, fixed camera height, two viewport sizes, retained cargo." % route.route_title)
		root.remove_child(route)
		route.queue_free()
		await process_frame
	quit(0)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
