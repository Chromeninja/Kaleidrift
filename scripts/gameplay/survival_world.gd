class_name SurvivalWorld
extends RefCounted

const MAX_RENDER_OBSTACLES := 8
const CELL_SIZE := 10.0
const NEIGHBOR_RADIUS := 1
const WALL_SWEEP_SAMPLES := 4
const EMPTY_CELL := Vector3i(2147483647, 2147483647, 2147483647)

class CourseObstacle:
	var identifier: String
	var position: Vector3
	var radius: float
	var scored := false

	func _init(new_identifier: String, new_position: Vector3, new_radius: float) -> void:
		identifier = new_identifier
		position = new_position
		radius = new_radius


var obstacles: Array[CourseObstacle] = []
var scored_obstacles: Dictionary = {}
var world_seed := 0
var current_cell := EMPTY_CELL


func reset(seed: int, player_position: Vector3) -> void:
	obstacles.clear()
	scored_obstacles.clear()
	world_seed = seed
	current_cell = EMPTY_CELL
	update(player_position)


func update(player_position: Vector3) -> void:
	var player_cell := _cell_for_position(player_position)
	if player_cell == current_cell:
		return
	current_cell = player_cell
	_rebuild_neighborhood()


static func get_world_sdf(point: Vector3) -> float:
	var region_wave := sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16
	var gyroid := absf(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave)
	return gyroid


static func find_safe_spawn(origin: Vector3, required_clearance: float = 0.85) -> Vector3:
	if get_world_sdf(origin) >= required_clearance:
		return origin
	var best_position := origin
	var best_clearance := get_world_sdf(origin)
	for x_index in range(-4, 5):
		for y_index in range(-4, 5):
			for z_index in range(-4, 5):
				var candidate := origin + Vector3(x_index, y_index, z_index) * 1.15
				var clearance := get_world_sdf(candidate)
				if clearance > best_clearance:
					best_clearance = clearance
					best_position = candidate
				if clearance >= required_clearance:
					return candidate
	return best_position


func find_safest_direction(
	origin: Vector3,
	player_radius: float,
	travel_distance: float = 6.0
) -> Vector3:
	var directions: Array[Vector3] = [
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.DOWN,
	]
	var golden_angle := PI * (3.0 - sqrt(5.0))
	for sample_index in 42:
		var y := 1.0 - 2.0 * (float(sample_index) + 0.5) / 42.0
		var radial := sqrt(maxf(1.0 - y * y, 0.0))
		var angle := golden_angle * float(sample_index)
		directions.append(Vector3(cos(angle) * radial, y, sin(angle) * radial))

	var best_direction := Vector3.FORWARD
	var best_clearance := -INF
	for direction in directions:
		var path_clearance := INF
		for distance_index in range(1, 13):
			var distance := travel_distance * float(distance_index) / 12.0
			var sample_position := origin + direction * distance
			path_clearance = minf(
				path_clearance,
				get_clearance_at_position(sample_position, player_radius)
			)
		if path_clearance > best_clearance:
			best_clearance = path_clearance
			best_direction = direction
	return best_direction.normalized()


func get_clearance_at_position(position: Vector3, player_radius: float) -> float:
	var clearance := get_world_sdf(position) - player_radius
	for obstacle in obstacles:
		clearance = minf(
			clearance,
			position.distance_to(obstacle.position) - obstacle.radius - player_radius
		)
	return clearance


func is_position_safe(position: Vector3, player_radius: float, margin: float) -> bool:
	return get_clearance_at_position(position, player_radius) >= margin


func collides_with_world_swept_sphere(
	previous_position: Vector3,
	current_position: Vector3,
	player_radius: float
) -> bool:
	for sample_index in WALL_SWEEP_SAMPLES + 1:
		var amount := float(sample_index) / float(WALL_SWEEP_SAMPLES)
		var sample_position := previous_position.lerp(current_position, amount)
		if get_world_sdf(sample_position) < player_radius:
			return true
	return false


func get_shader_obstacles(player_position: Vector3) -> Array[Vector4]:
	var candidates := obstacles.duplicate()
	candidates.sort_custom(
		func(a: CourseObstacle, b: CourseObstacle) -> bool:
			return a.position.distance_squared_to(player_position) < b.position.distance_squared_to(player_position)
	)
	var packed: Array[Vector4] = []
	for index in MAX_RENDER_OBSTACLES:
		if index < candidates.size():
			var obstacle: CourseObstacle = candidates[index]
			packed.append(Vector4(
				obstacle.position.x,
				obstacle.position.y,
				obstacle.position.z,
				obstacle.radius
			))
		else:
			packed.append(Vector4(0.0, 0.0, 0.0, -1.0))
	return packed


func collides_with_obstacle_swept_sphere(
	previous_position: Vector3,
	current_position: Vector3,
	player_radius: float
) -> bool:
	for obstacle in obstacles:
		var combined_radius := obstacle.radius + player_radius
		if _distance_squared_to_segment(
			obstacle.position,
			previous_position,
			current_position
		) <= combined_radius * combined_radius:
			return true
	return false


func collect_near_misses(
	previous_position: Vector3,
	current_position: Vector3,
	player_radius: float
) -> int:
	var near_misses := 0
	for obstacle in obstacles:
		if obstacle.scored:
			continue
		var contact_distance := obstacle.radius + player_radius
		var near_distance := contact_distance + 0.55
		var distance_squared := _distance_squared_to_segment(
			obstacle.position,
			previous_position,
			current_position
		)
		if distance_squared > contact_distance * contact_distance \
				and distance_squared <= near_distance * near_distance:
			obstacle.scored = true
			scored_obstacles[obstacle.identifier] = true
			near_misses += 1
	return near_misses


func _rebuild_neighborhood() -> void:
	obstacles.clear()
	for x_offset in range(-NEIGHBOR_RADIUS, NEIGHBOR_RADIUS + 1):
		for y_offset in range(-NEIGHBOR_RADIUS, NEIGHBOR_RADIUS + 1):
			for z_offset in range(-NEIGHBOR_RADIUS, NEIGHBOR_RADIUS + 1):
				var cell := current_cell + Vector3i(x_offset, y_offset, z_offset)
				_spawn_cell_obstacle(cell)


func _spawn_cell_obstacle(cell: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for_cell(cell)
	if rng.randf() > 0.62:
		return
	var radius := rng.randf_range(0.48, 0.82)
	var cell_origin := Vector3(cell) * CELL_SIZE
	var identifier := "%d:%d:%d" % [cell.x, cell.y, cell.z]
	for _attempt in 6:
		var candidate := cell_origin + Vector3(
			rng.randf_range(1.2, CELL_SIZE - 1.2),
			rng.randf_range(1.2, CELL_SIZE - 1.2),
			rng.randf_range(1.2, CELL_SIZE - 1.2)
		)
		if get_world_sdf(candidate) <= radius + 0.18:
			continue
		var obstacle := CourseObstacle.new(identifier, candidate, radius)
		obstacle.scored = scored_obstacles.has(identifier)
		obstacles.append(obstacle)
		return


func _seed_for_cell(cell: Vector3i) -> int:
	return (
		world_seed
		^ cell.x * 73856093
		^ cell.y * 19349663
		^ cell.z * 83492791
	)


func _cell_for_position(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / CELL_SIZE),
		floori(world_position.y / CELL_SIZE),
		floori(world_position.z / CELL_SIZE)
	)


func _distance_squared_to_segment(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_squared_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(start + segment * amount)
