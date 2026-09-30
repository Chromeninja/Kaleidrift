extends SceneTree

# Run with a real renderer (not --headless). Optional -- --shader=<baseline>
# exercises the same assertions against a saved earlier shader.
const SIZE := 17
const LIMIT := 4.0
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Raymarch rendering test requires a real rendering backend.")
		quit(2)
		return
	var shader_path := "res://shaders/fractal_flight.gdshader"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			shader_path = argument.trim_prefix("--shader=")
	var source := FileAccess.get_file_as_string(shader_path)
	var output_marker := "\tCOLOR = vec4(color, 1.0);"
	_check(source.contains(output_marker), "Production fragment output marker missing")
	if failures > 0:
		quit(1)
		return
	# Retain the production ray setup, traversal, hit decision, and lighting.
	# Replace only final color with a two-byte depth and hit flag.
	var diagnostic := source.replace(output_marker, """
	float depth_code = floor(clamp(distance_traveled / max_distance, 0.0, 1.0) * 65535.0 + 0.5);
	COLOR = vec4(floor(depth_code / 256.0) / 255.0, mod(depth_code, 256.0) / 255.0, hit ? 1.0 : 0.0, 1.0);
""")
	var shader := Shader.new()
	shader.code = diagnostic
	var normal_call := "estimate_normal(point)"
	if source.contains("estimate_normal(vec3 point, float"):
		normal_call = "estimate_normal(point, clamp(distance_traveled / (max(viewport_size.y, 1.0) * 1.15), EPSILON, 0.025), -ray_direction)"
	var normal_shader := Shader.new()
	normal_shader.code = source.replace(output_marker, "\tCOLOR = vec4(hit ? " + normal_call + " * 0.5 + 0.5 : vec3(0.5), 1.0);")
	var material := ShaderMaterial.new()
	material.shader = shader
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rectangle := ColorRect.new()
	rectangle.size = Vector2(SIZE, SIZE)
	rectangle.material = material
	viewport.add_child(rectangle)
	material.set_shader_parameter("viewport_size", Vector2(SIZE, SIZE))
	material.set_shader_parameter("max_steps", 112)
	material.set_shader_parameter("max_distance", LIMIT)
	material.set_shader_parameter("fractal_type", 0)
	var forward := Vector3(-0.58792678, 0.43912976, -0.67934539).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	material.set_shader_parameter("camera_forward", forward)
	material.set_shader_parameter("camera_right", right)
	material.set_shader_parameter("camera_up", up)
	var query := SDFQueryService.new(WorldState.new())
	var origin := Vector3(0.51044004, 4.54594718, 4.85098526) - forward * 0.02
	var checked := 0
	var previous_hits: Dictionary = {}
	for pose in range(2):
		material.shader = shader
		var camera := origin + right * float(pose) * 0.0002
		material.set_shader_parameter("camera_position", camera)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var hit_samples: Array[Dictionary] = []
		_check(not image.is_empty(), "GPU depth image is empty")
		for y in [4, 6, 8, 10, 12]:
			for x in [4, 6, 8, 10, 12]:
				var screen := (Vector2(x + 0.5, y + 0.5) * 2.0 - Vector2(SIZE, SIZE)) / float(SIZE)
				var ray := (forward * 1.15 + right * screen.x - up * screen.y).normalized()
				var pixel := image.get_pixel(x, y)
				var hit := pixel.b > 0.5
				var depth := (roundf(pixel.r * 255.0) * 256.0 + roundf(pixel.g * 255.0)) / 65535.0 * LIMIT
				var reference := _reference_depth(query, camera, ray)
				var label := "pose=%d pixel=(%d,%d)" % [pose, x, y]
				_check(hit == (reference < LIMIT), "GPU/reference hit disagreement: " + label)
				if hit:
					hit_samples.append({"pixel": Vector2i(x, y), "point": camera + ray * depth})
					var residual := query.get_structure_sdf(camera + ray * depth, false)
					_check(residual >= -0.0005, "GPU marched inside surface: %s residual=%f" % [label, residual])
					# Compare against a much finer CPU traversal. Allow the actual
					# pixel footprint, hit tolerance, and a grazing-angle margin.
					var tolerance := maxf(0.0025, depth / (SIZE * 1.15) * 0.5)
					_check(absf(reference - depth) <= tolerance * 4.0 + 0.001, "GPU/reference depth disagreement: " + label)
				if pose == 1:
					_check(previous_hits[Vector2i(x, y)] == hit, "Adjacent camera pose changed near-surface coverage: " + label)
				previous_hits[Vector2i(x, y)] = hit
				checked += 1
		material.shader = normal_shader
		await process_frame
		await RenderingServer.frame_post_draw
		var normals := viewport.get_texture().get_image()
		for sample in hit_samples:
			var coordinate: Vector2i = sample.pixel
			var encoded := normals.get_pixelv(coordinate)
			var normal := Vector3(encoded.r, encoded.g, encoded.b) * 2.0 - Vector3.ONE
			var reference_normal := query.estimate_normal(sample.point, false)
			_check(normal.is_finite() and absf(normal.length() - 1.0) < 0.03, "GPU normal is invalid at " + str(coordinate))
			_check(normal.dot(reference_normal) > 0.97, "GPU/CPU normal disagreement at " + str(coordinate))
	print("Raymarch GPU checks: ", checked, " rays; failures=", failures, "; GPU=", RenderingServer.get_video_adapter_name())
	viewport.queue_free()
	quit(0 if failures == 0 else 1)


func _reference_depth(query: SDFQueryService, origin: Vector3, ray: Vector3) -> float:
	var distance := 0.02
	for iteration in range(2048):
		var field := query.get_structure_sdf(origin + ray * distance, false)
		if field < 0.00005:
			return distance
		distance += field * 0.1
		if distance >= LIMIT:
			return LIMIT
	return LIMIT
