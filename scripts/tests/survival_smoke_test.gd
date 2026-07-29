extends SceneTree

const HealthComponentScript := preload("res://scripts/gameplay/health_component.gd")
const SurvivalWorldScript := preload("res://scripts/gameplay/survival_world.gd")
const FractalLevelsScript := preload("res://scripts/fractal_levels.gd")


func _init() -> void:
	_test_world_cells_are_deterministic()
	_test_open_world_has_free_space_and_solids()
	_test_selected_worlds_have_safe_spawns()
	_test_swept_collisions()
	_test_health_invulnerability()
	print("Survival smoke tests passed.")
	quit()


func _test_world_cells_are_deterministic() -> void:
	var first_course = SurvivalWorldScript.new()
	var second_course = SurvivalWorldScript.new()
	var start := Vector3(1.0, 2.0, 3.0)
	first_course.reset(12345, start)
	second_course.reset(12345, start)
	_assert_obstacles_match(first_course.obstacles, second_course.obstacles)

	var original_obstacles = first_course.get_shader_obstacles(start)
	first_course.update(Vector3(42.0, -31.0, 27.0))
	first_course.update(start)
	var revisited_obstacles = first_course.get_shader_obstacles(start)
	assert(original_obstacles == revisited_obstacles)


func _test_open_world_has_free_space_and_solids() -> void:
	var world = SurvivalWorldScript.new()
	var safe_spawn: Vector3 = SurvivalWorld.find_safe_spawn(Vector3(0.0, 0.0, 2.0))
	assert(world.get_world_sdf(safe_spawn) >= 0.85)
	world.reset(12345, safe_spawn)
	var safe_direction: Vector3 = world.find_safest_direction(safe_spawn, 0.22)
	assert(is_equal_approx(safe_direction.length(), 1.0))
	var path_position := safe_spawn
	for _step in range(20):
		var next_position := path_position + safe_direction * 0.1
		assert(not world.collides_with_world_swept_sphere(
			path_position,
			next_position,
			0.22
		))
		assert(world.get_clearance_at_position(next_position, 0.22) > 0.0)
		path_position = next_position

	var open_samples := 0
	var solid_samples := 0
	for x_index in range(-5, 6):
		for y_index in range(-5, 6):
			for z_index in range(-5, 6):
				var point := Vector3(x_index, y_index, z_index) * 1.7
				if world.get_world_sdf(point) > 0.22:
					open_samples += 1
				else:
					solid_samples += 1
	assert(open_samples > 100)
	assert(solid_samples > 100)

	var directions := [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.UP,
		Vector3.DOWN,
		Vector3.FORWARD,
		Vector3.BACK,
	]
	for direction in directions:
		var probe := safe_spawn
		var moved_through_open_space := false
		for _step in range(20):
			var next_probe: Vector3 = probe + direction * 0.08
			if world.collides_with_world_swept_sphere(probe, next_probe, 0.22):
				break
			probe = next_probe
			moved_through_open_space = true
		assert(moved_through_open_space)


func _test_swept_collisions() -> void:
	var world = SurvivalWorldScript.new()
	var start := SurvivalWorld.find_safe_spawn(Vector3(0.0, 0.0, 2.0))
	world.reset(67890, start)
	assert(not world.obstacles.is_empty())
	var obstacle = world.obstacles[0]
	var obstacle_start: Vector3 = obstacle.position + Vector3(0.0, 0.0, 2.0)
	var obstacle_end: Vector3 = obstacle.position - Vector3(0.0, 0.0, 2.0)
	assert(world.collides_with_obstacle_swept_sphere(
		obstacle_start,
		obstacle_end,
		0.22
	))

	var solid_point := Vector3.ZERO
	var found_solid := false
	for x_index in range(-8, 9):
		if found_solid:
			break
		for y_index in range(-8, 9):
			if found_solid:
				break
			for z_index in range(-8, 9):
				var candidate := Vector3(x_index, y_index, z_index) * 0.55
				if world.get_world_sdf(candidate) < 0.0:
					solid_point = candidate
					found_solid = true
					break
	assert(found_solid)
	assert(world.collides_with_world_swept_sphere(start, solid_point, 0.22))


func _test_selected_worlds_have_safe_spawns() -> void:
	for level in [
		FractalLevelsScript.Type.MANDELBOX,
		FractalLevelsScript.Type.MANDELBULB,
		FractalLevelsScript.Type.KIFS,
		FractalLevelsScript.Type.MENGER,
	]:
		var world = SurvivalWorldScript.new()
		var variation_seed := SurvivalWorld.variation_seed_for_world_seed(12345)
		var spawn := SurvivalWorld.find_safe_spawn(Vector3(0.0, 0.0, 2.0), 0.85, level, 6, variation_seed)
		world.reset(12345, spawn, level)
		# Some dense fractals do not expose a 0.85-unit void at this scale;
		# the spawn search still guarantees clearance beyond the player radius.
		assert(world.get_world_sdf(spawn) >= 0.30)
		var direction: Vector3 = world.find_safest_direction(spawn, 0.22)
		assert(not world.collides_with_world_swept_sphere(
			spawn,
			spawn + direction * 0.1,
			0.22
		))


func _test_health_invulnerability() -> void:
	var health = HealthComponentScript.new()
	health.reset()
	health.grant_invulnerability(5.0)
	assert(not health.take_damage(1))
	health.tick(5.0)
	assert(health.take_damage(1))
	assert(health.current_health == health.maximum_health - 1)
	assert(not health.take_damage(1))
	health.tick(health.invulnerability_seconds)
	assert(health.take_damage(1))


func _assert_obstacles_match(first: Array, second: Array) -> void:
	assert(first.size() == second.size())
	for index in range(first.size()):
		assert(first[index].identifier == second[index].identifier)
		assert(first[index].position.is_equal_approx(second[index].position))
		assert(is_equal_approx(first[index].radius, second[index].radius))
