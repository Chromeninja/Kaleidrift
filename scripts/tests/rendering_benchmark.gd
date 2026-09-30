extends SceneTree

const STEP := 1.0 / 60.0
var options := {}
var game
var route: Array[Transform3D] = []
var optional_properties := {}


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendering benchmark requires a real display and GPU; headless results are invalid.")
		quit(2)
		return
	var output := str(options.get("output", "res://build/performance/run"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	# Redirect all persistence in this in-memory copy; never touch player data.
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var isolated := output.path_join("session_%d" % Time.get_ticks_usec())
	for filename in ["settings.cfg", "characters.cfg", "controller_input.log"]:
		source = source.replace("user://" + filename, isolated + "_" + filename)
	if options.has("shader"):
		source = source.replace("res://shaders/fractal_flight.gdshader", str(options.shader))
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(options.get("width", 1280)), int(options.get("height", 720)))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://main.tscn").instantiate()
	game.set_script(script)
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.selected_fractal_level = int(options.get("fractal", 0))
	game._music_enabled_setting = false
	game.music_controller.set_music_enabled(false)
	if str(options.get("mode", "endless")) == "survival":
		game._start_survival()
	else:
		game._start_endless()
	game._selected_view_mode = StringName(str(options.get("view", "immersive")))
	game.view_mode_controller.set_view_mode(game._selected_view_mode, game.flight_rig)
	var quality := clampi(int(options.get("quality", 2)), 0, 2)
	var auto_mode := str(options.get("scenario", "fixed")) == "auto"
	game.automatic_quality = auto_mode
	game.quality_controller.reset(quality, auto_mode)
	game._apply_quality(quality)
	var viewports: Array[Viewport] = [root, game.render_viewport, game.traveler_viewport]
	for viewport in viewports:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	_build_route()
	for object in [game, game.safety_controller]:
		var names := {}
		for property in object.get_property_list():
			names[property.name] = true
		optional_properties[object.get_instance_id()] = names
	var warmup := maxi(1, int(options.get("warmup", 120)))
	var count := maxi(1, int(options.get("frames", 600)))
	var samples: Array[float] = []
	var cpu_samples: Array[float] = []
	var gpu_samples: Array[float] = []
	var transitions: Array = []
	var rows: Array = []
	var previous_quality := ""
	var last_tick := Time.get_ticks_usec()
	for frame in range(warmup + count):
		var tick := Time.get_ticks_usec()
		var wall_ms := float(tick - last_tick) / 1000.0
		last_tick = tick
		game._application_focused = true
		var pose := route[frame % route.size()]
		game.flight_rig.reset_state(pose.origin, pose.basis.get_rotation_quaternion(), 0.0)
		game.elapsed = float(frame) * STEP
		var cpu_start := Time.get_ticks_usec()
		game._physics_process(STEP)
		# Feed real timing to adaptive quality, while keeping simulation/route fixed.
		var saved_warmup: float = game.quality_controller.warmup_seconds
		var saved_elapsed: float = game.quality_controller.elapsed
		var saved_cooldown: float = game.quality_controller.cooldown_remaining
		game.quality_controller.warmup_seconds = INF
		game._process(STEP)
		game.quality_controller.warmup_seconds = saved_warmup
		game.quality_controller.elapsed = saved_elapsed
		game.quality_controller.cooldown_remaining = saved_cooldown
		if game.quality_controller.sample(wall_ms / 1000.0, wall_ms):
			game._apply_resolved_quality()
		var cpu_ms := float(Time.get_ticks_usec() - cpu_start) / 1000.0
		await process_frame
		await RenderingServer.frame_post_draw
		var gpu_ms := 0.0
		for viewport in viewports:
			gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
		var quality_key := "%d:%.3f" % [game.current_quality, game.quality_controller.resolved_scale]
		if quality_key != previous_quality:
			transitions.append({"frame": frame - warmup, "quality": quality_key, "wall_ms": wall_ms})
			previous_quality = quality_key
		if frame >= warmup:
			samples.append(wall_ms)
			cpu_samples.append(cpu_ms)
			gpu_samples.append(gpu_ms)
			rows.append({"frame": frame - warmup, "wall_ms": wall_ms, "script_ms": cpu_ms, "gpu_ms": gpu_ms, "quality": quality_key, "camera_cpu_us": _optional_property(game, "camera_cpu_us"), "safety_cpu_us": _optional_property(game.safety_controller, "collision_cpu_us"), "render_resize_count": _optional_property(game, "render_resize_count")})
	# Readback and PNG compression happen only after measured frames.
	game.quality_controller.automatic = false
	game.quality_controller.warmup_seconds = INF
	var capture_count := maxi(0, int(options.get("capture_frames", 3)))
	var contiguous := options.has("capture_frames")
	for snapshot in range(capture_count):
		var pose_index := snapshot % route.size() if contiguous else snapshot * route.size() / 3
		var pose := route[pose_index]
		game.flight_rig.reset_state(pose.origin, pose.basis.get_rotation_quaternion(), 0.0)
		game.elapsed = float(pose_index) * STEP
		game._physics_process(STEP)
		if snapshot == 0 or not contiguous:
			game.view_mode_controller.camera_controller.reset_from_transform(game.flight_rig.transform)
		game._process(STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%d.png" % snapshot))
	var result := {"options": options, "engine": Engine.get_version_info(), "gpu": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_video_adapter_api_version(), "renderer": RenderingServer.get_current_rendering_method(), "window": str(root.size), "wall_ms": _summary(samples), "script_ms": _summary(cpu_samples), "gpu_ms": _summary(gpu_samples), "transitions": transitions, "frames": rows, "route": "fixed indexed near-surface orbit; 360 poses; 1/60 simulation step"}
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	if file == null:
		push_error("Could not write benchmark results")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t"))
	print("Rendering benchmark: ", JSON.stringify(result.wall_ms), " GPU: ", JSON.stringify(result.gpu_ms), " -> ", output)
	game.queue_free()
	for cleanup in range(4):
		await process_frame
	quit()


func _build_route() -> void:
	var center: Vector3 = game.flight_rig.position
	# Locate a surface once, outside the measured work, then orbit nearby.
	var nearest := center
	var nearest_distance := INF
	for index in range(240):
		var candidate := center + Vector3(float(index) * 0.025, 0.0, 0.0)
		var distance: float = absf(game.sdf_query.get_structure_sdf(candidate, false))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	for index in range(360):
		var angle := TAU * float(index) / 360.0
		var candidate := nearest + Vector3(cos(angle) * 0.65, sin(angle) * 0.25, 0.65)
		var safe: Vector3 = game.sdf_query.find_safe_position(candidate, game.safety_controller.collision_radius + 0.05)
		var direction := nearest - safe
		if direction.length_squared() < 0.001:
			direction = Vector3.FORWARD
		route.append(Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), safe))


func _summary(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {"mean": total / sorted.size(), "p90": sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.90)) - 1)], "p95": sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)], "max": sorted[-1]}


func _optional_property(object: Object, property_name: String) -> Variant:
	if optional_properties.get(object.get_instance_id(), {}).has(property_name):
		return object.get(property_name)
	return null
