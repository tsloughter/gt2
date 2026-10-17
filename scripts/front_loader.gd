extends "res://scripts/side_loader.gd"

## Twin arms rotate over the cab; the fork carriage counter-rotates to keep
## the dumpster upright until it is above the hopper.
const LIFT_ROTATION := -130.0
const FORK_OFFSET := Vector3(-5.6, -1.9, 0.0)


func configure(truck_controller, truck_visual: Node3D) -> void:
	truck = truck_controller
	visual_root = truck_visual
	container_group = "collectible_dumpsters"
	approach_message = "Drive straight toward a green dumpster"
	slow_message = "Stop with the dumpster between the front forks"
	ready_message = "Front forks ready"
	lift_pivot = visual_root.get_node("FrontLoaderLift")
	grabber_pivot = lift_pivot.get_node("ForkCarriage")
	hopper = visual_root.find_child("Hopper_Opening", true, false)
	_setup_cargo_hold()
	_setup_tailgate()
	_rng.seed = 20261003
	_setup_audio()
	call_deferred("_refresh_total")


func _find_best_can():
	var best = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group(container_group):
		if candidate.emptied:
			continue
		var relative: Vector3 = truck.to_local(candidate.global_position)
		# Require an approach from the front, with matching fork-pocket heading.
		if relative.x < -7.7 or relative.x > -5.7 or absf(relative.z) > 0.65:
			continue
		if truck.global_basis.x.dot(candidate.global_basis.x) < 0.94:
			continue
		var distance := absf(relative.x + 6.6) + absf(relative.z)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _run_pickup(dumpster) -> void:
	busy = true
	truck.set_controls_locked(true)
	dumpster.prepare_for_pickup()
	_set_phase("grabbing", "Forks in! Holding the dumpster safely")
	_start_hydraulics()
	# A small alignment assist seats the forks into the pockets without moving
	# the dumpster from its parking pad.
	var aligned_position: Vector3 = dumpster.global_position + dumpster.global_basis.x * 6.6
	aligned_position.y = truck.global_position.y
	var align := create_tween().set_parallel(true)
	align.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	align.tween_property(truck, "global_position", aligned_position, 0.45)
	align.tween_property(truck, "rotation:y", truck.rotation.y + angle_difference(truck.rotation.y, dumpster.rotation.y), 0.45)
	await align.finished
	dumpster.attach_to_loader(grabber_pivot)

	_set_phase("lifting", "Up and over the cab!")
	await _move_arms(LIFT_ROTATION, -LIFT_ROTATION, 1.8).finished
	_set_phase("dumping", "Tip the dumpster into the hopper!")
	var tip := create_tween().set_parallel(true)
	tip.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tip.tween_property(grabber_pivot, "rotation:z", deg_to_rad(-15.0), 0.7)
	tip.tween_property(dumpster.lid_pivot, "rotation:z", deg_to_rad(-115.0), 0.7)
	await tip.finished
	_rattle.play()
	await _spawn_trash(dumpster.dump_origin()).finished

	_set_phase("returning", "Returning the empty dumpster")
	var untilt := create_tween().set_parallel(true)
	untilt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	untilt.tween_property(grabber_pivot, "rotation:z", deg_to_rad(-LIFT_ROTATION), 0.65)
	untilt.tween_property(dumpster.lid_pivot, "rotation:z", 0.0, 0.65)
	await untilt.finished
	await _move_arms(0.0, 0.0, 1.8).finished
	dumpster.return_home()
	_stop_hydraulics()
	dumpster.mark_emptied()
	collected_count += 1
	count_changed.emit(collected_count, total_count)
	_chime.play()
	truck.set_controls_locked(false)
	busy = false
	_set_phase("driving", "Great pickup! Find the next green dumpster")
	pickup_completed.emit(dumpster)


func _move_arms(lift_degrees: float, fork_degrees: float, duration: float) -> Tween:
	var motion := create_tween().set_parallel(true)
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(lift_pivot, "rotation:z", deg_to_rad(lift_degrees), duration)
	motion.tween_property(grabber_pivot, "rotation:z", deg_to_rad(fork_degrees), duration)
	return motion
