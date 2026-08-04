extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene = load("res://main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene._start_endless()
	await physics_frame
	await process_frame
	assert(main_scene.view_mode_controller.view_mode == ViewModeController.IMMERSIVE)
	assert(not main_scene.traveler_output_rect.visible)
	var rig_transform: Transform3D = main_scene.flight_rig.transform
	var rig_speed: float = main_scene.flight_rig.requested_speed
	main_scene.view_mode_controller.set_view_mode(ViewModeController.TRAVELER, main_scene.flight_rig)
	main_scene._selected_view_mode = ViewModeController.TRAVELER
	assert(main_scene.flight_rig.transform.is_equal_approx(rig_transform))
	assert(is_equal_approx(main_scene.flight_rig.requested_speed, rig_speed))
	await process_frame
	assert(main_scene.traveler_output_rect.visible)
	assert(main_scene.traveler_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	assert(is_instance_valid(main_scene.traveler_visual))
	var quality_independent_point: Vector3 = main_scene.flight_rig.position + Vector3(0.3, -0.2, 0.4)
	var quality_independent_sdf: float = main_scene.sdf_query.get_structure_sdf(quality_independent_point, false)
	for quality_tier in range(main_scene.QUALITY_PRESETS.size()):
		main_scene._apply_quality(quality_tier)
		assert(main_scene.world_state.geometry_iterations == WorldState.GEOMETRY_ITERATIONS)
		assert(is_equal_approx(main_scene.sdf_query.get_structure_sdf(quality_independent_point, false), quality_independent_sdf))
	main_scene._select_traveler(&"geometric_bird")
	assert(main_scene.traveler_definition.identifier == &"geometric_bird")
	assert(is_equal_approx(main_scene.safety_controller.collision_radius, 0.20))
	main_scene._traveler_primary_color = Color(0.3, 0.8, 1.0)
	main_scene._traveler_accent_color = Color(1.0, 0.4, 0.2)
	main_scene._configure_traveler_visual()
	main_scene.view_mode_controller.set_view_mode(ViewModeController.IMMERSIVE, main_scene.flight_rig)
	main_scene._selected_view_mode = ViewModeController.IMMERSIVE
	await process_frame
	assert(not main_scene.traveler_output_rect.visible)
	main_scene.queue_free()
	for _cleanup_frame in range(4):
		await process_frame
	await create_timer(0.10).timeout
	print("Traveler integration test passed.")
	quit()
