extends SceneTree

const FractalLevelsScript := preload("res://scripts/fractal_levels.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene = load("res://main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	assert(is_instance_valid(main_scene.music_controller))
	assert(is_instance_valid(main_scene.music_toggle))
	assert(is_instance_valid(main_scene.music_volume_slider))
	main_scene._start_survival()
	assert(main_scene.survival_session.health.invulnerability_remaining > 4.8)
	for _frame in 10:
		await physics_frame
		await process_frame

	assert(main_scene.survival_session.active)
	assert(main_scene.survival_session.distance_traveled > 0.0)
	assert(main_scene.shader_material.get_shader_parameter("survival_mode"))
	assert(main_scene.gameplay_overlay.visible)
	assert(not main_scene.menu_panel.visible)
	assert(main_scene.health_label.text.contains("SHIELD"))
	assert(main_scene.music_controller.context.game_mode == MusicContext.Mode.SURVIVAL)
	var spawn_forward: Vector3 = main_scene.survival_session.get_spawn_forward()
	var initial_rendered_forward: Vector3 = main_scene.shader_material.get_shader_parameter("camera_forward")
	assert(initial_rendered_forward.dot(spawn_forward) > 0.95)

	var position_before_turn: Vector3 = main_scene.survival_session.position
	var orientation_before_turn: Quaternion = main_scene.camera_orientation
	main_scene._apply_steering_delta(Vector2(180.0, -110.0))
	assert(not main_scene.camera_orientation.is_equal_approx(orientation_before_turn))
	for _frame in 8:
		await physics_frame
		await process_frame
	var position_after_turn: Vector3 = main_scene.survival_session.position
	assert(position_after_turn.distance_to(position_before_turn) > 0.05)
	var rendered_forward: Vector3 = main_scene.shader_material.get_shader_parameter("camera_forward")
	assert(absf(rendered_forward.x) > 0.05)
	assert(absf(rendered_forward.y) > 0.03)

	main_scene.selected_fractal_level = FractalLevelsScript.Type.MIXED
	main_scene._start_survival()
	var mixed_spawn_position: Vector3 = main_scene.survival_session.position
	for _frame in 10:
		await physics_frame
		await process_frame
	assert(main_scene.survival_session.position.distance_to(mixed_spawn_position) > 0.05)

	var session = main_scene.survival_session
	session.world.obstacles.clear()
	session.health.invulnerability_remaining = 0.0
	var rollback_position: Vector3 = session.last_safe_position
	var solid_point := Vector3.ZERO
	var found_solid := false
	for x_index in range(-8, 9):
		if found_solid:
			break
		for y_index in range(-8, 9):
			if found_solid:
				break
			for z_index in range(-8, 9):
				var candidate: Vector3 = session.position \
					+ Vector3(x_index, y_index, z_index) * 0.55
				if session.world.get_world_sdf(candidate) < 0.0:
					solid_point = candidate
					found_solid = true
					break
	assert(found_solid)
	var wall_direction: Vector3 = session.position.direction_to(solid_point)
	var wall_distance: float = session.position.distance_to(solid_point)
	session.physics_step(1.0, wall_distance, wall_direction)
	assert(session.health.current_health == session.health.maximum_health - 1)
	assert(session.position.is_equal_approx(rollback_position))
	assert(session.health.invulnerability_remaining >= 1.9)

	main_scene.survival_session.health.current_health = 1
	main_scene.survival_session.health.invulnerability_remaining = 0.0
	main_scene.survival_session.health.take_damage(1)
	await process_frame
	assert(not main_scene.survival_session.active)
	assert(main_scene.game_over_content.visible)
	assert(main_scene.interface_state == 2)

	print("Survival integration test passed.")
	main_scene.queue_free()
	await process_frame
	quit()
