extends SceneTree

const STEP := 1.0 / 60.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Keep settings, profiles, and diagnostics separate from the player's files.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/performance"))
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var prefix := "res://build/performance/integration_%d_" % Time.get_ticks_usec()
	for filename in ["settings.cfg", "characters.cfg", "controller_input.log"]:
		source = source.replace("user://" + filename, prefix + filename)
	var isolated_script := GDScript.new()
	isolated_script.source_code = source
	assert(isolated_script.reload() == OK)
	var game = load("res://main.tscn").instantiate()
	game.set_script(isolated_script)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game._application_focused = true
	game._music_enabled_setting = false
	game.music_controller.set_music_enabled(false)
	game._selected_view_mode = ViewModeController.TRAVELER
	game.view_mode_controller.set_view_mode(ViewModeController.TRAVELER, game.flight_rig)
	var camera: ThirdPersonCameraController = game.view_mode_controller.camera_controller
	var menu_position := camera.position
	game._process(STEP)
	assert(game.camera_cpu_us == 0)
	assert(camera.position == menu_position)
	assert(not game._presentation_was_active)
	game._start_endless()
	game._process(STEP)
	assert(camera.initialized and game._presentation_was_active)
	assert(game.traveler_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	game._show_pause_menu()
	menu_position = camera.position
	game._process(STEP)
	assert(game.camera_cpu_us == 0 and camera.position == menu_position)
	# A stale menu camera must reset from the rig before interpolation resumes.
	camera.position = Vector3(10000.0, 10000.0, 10000.0)
	game._resume_playing()
	game._process(STEP)
	assert(camera.initialized and camera.position.distance_to(game.flight_rig.position) < 10.0)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	menu_position = camera.position
	game._process(STEP)
	assert(game.traveler_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	assert(game.camera_cpu_us == 0 and camera.position == menu_position)
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._process(STEP)
	assert(game.traveler_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	_test_resize(game)
	_test_manual_metrics(game)
	game.queue_free()
	for _frame in range(4):
		await process_frame
	await create_timer(0.1).timeout
	print("Performance integration tests passed (synthetic timing; not a GPU benchmark).")
	quit()


func _test_resize(game) -> void:
	game._resize_render_target()
	var count: int = game.render_resize_count
	var original_size: Vector2i = game.render_viewport.size
	game._resize_render_target()
	assert(game.render_resize_count == count)
	game.quality_controller.resolved_scale *= 0.5
	game._resize_render_target()
	assert(game.render_resize_count == count + 1)
	assert(game.render_viewport.size != original_size)
	assert(game.render_viewport.size == game.traveler_viewport.size)
	game._resize_render_target()
	assert(game.render_resize_count == count + 1)


func _test_manual_metrics(game) -> void:
	game.automatic_quality = false
	game.quality_controller.reset(2, false)
	game._apply_quality(2)
	game._update_metrics(16.0)
	assert("WARMUP" in game.metrics_label.text)
	assert("PASS" not in game.metrics_label.text)
	assert("WARMUP" in game.diagnostics_overlay._details)
	assert("PASS" not in game.diagnostics_overlay._details)
	var fixed_scale: float = game.quality_controller.resolved_scale
	# Drive actual main-loop sampling with synthetic slow frames after warmup.
	game.quality_controller.elapsed = game.quality_controller.warmup_seconds
	for _frame in range(12):
		game._process(0.04)
	game._update_metrics(40.0)
	assert(game.get_performance_p90_ms() > 0.0)
	assert(game.get_performance_p95_ms() > 0.0)
	assert(game.current_quality == 2 and game.quality_controller.resolved_tier == 2)
	assert(is_equal_approx(game.quality_controller.resolved_scale, fixed_scale))
	assert("WARMUP" not in game.metrics_label.text)
	assert("OVER" in game.metrics_label.text)
