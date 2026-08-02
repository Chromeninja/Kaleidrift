class_name SurvivalWorld
extends RefCounted

const FractalLevelsScript = preload("res://scripts/fractal_levels.gd")

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
var world_variation_seed := 0.0
var fractal_level := FractalLevelsScript.Type.FOLD
var fractal_iterations := 6
var current_cell := EMPTY_CELL
var neighborhood_revision := 0
var shader_obstacle_build_count := 0

static func variation_seed_for_world_seed(seed: int) -> float:
	return fposmod(float(abs(seed)), 10000.0)


func reset(new_world_seed: int, player_position: Vector3, new_fractal_level: int = FractalLevelsScript.Type.FOLD) -> void:
	obstacles.clear()
	scored_obstacles.clear()
	world_seed = new_world_seed
	world_variation_seed = variation_seed_for_world_seed(new_world_seed)
	fractal_level = new_fractal_level
	current_cell = EMPTY_CELL
	update(player_position)


func update(player_position: Vector3) -> void:
	var player_cell := _cell_for_position(player_position)
	if player_cell == current_cell:
		return
	current_cell = player_cell
	_rebuild_neighborhood()


static func _cell_hash(cell: Vector3, variation_seed: float, channel: float) -> float:
	var value := sin(cell.dot(Vector3(127.1, 311.7, 74.7)) + variation_seed * 0.013 + channel * 19.19) * 43758.5453123
	return value - floorf(value)


static func _warped_lattice_point(point: Vector3, variation_seed: float) -> Vector3:
	var phase := variation_seed * 0.0013
	return point + Vector3(
		sin(point.z * 0.29 + phase) * 1.45 + sin(point.y * 0.17 + phase * 1.7) * 0.55,
		sin(point.z * 0.23 + phase * 2.3) * 1.20 + sin(point.x * 0.19 + phase * 0.7) * 0.45,
		sin(point.x * 0.13 + phase * 1.1) * 0.70 + sin(point.y * 0.16 + phase * 2.9) * 0.55
	)


static func _varied_cell_point(point: Vector3, variation_seed: float) -> Vector3:
	point = _warped_lattice_point(point, variation_seed)
	var cell := Vector3(
		floorf((point.x + 4.0) / 8.0),
		floorf((point.y + 4.0) / 8.0),
		floorf((point.z + 4.0) / 8.0)
	)
	var p := Vector3(
		fposmod(point.x + 4.0, 8.0) - 4.0,
		fposmod(point.y + 4.0, 8.0) - 4.0,
		fposmod(point.z + 4.0, 8.0) - 4.0
	)
	var variation_a := _cell_hash(cell, variation_seed, 0.0)
	var variation_b := _cell_hash(cell, variation_seed, 1.0)
	var variation_c := _cell_hash(cell, variation_seed, 2.0)
	var xy_angle := (variation_a - 0.5) * 0.42
	var xy := Vector2(p.x, p.y).rotated(-xy_angle)
	p.x = xy.x
	p.y = xy.y
	var yz_angle := (variation_b - 0.5) * 0.34
	var yz := Vector2(p.y, p.z).rotated(-yz_angle)
	p.y = yz.x
	p.z = yz.y
	p += Vector3(variation_c - 0.5, variation_a - 0.5, variation_b - 0.5) * 0.50
	return p / lerpf(0.94, 1.06, variation_c)


static func _lane_breaker_sdf(point: Vector3, variation_seed: float) -> float:
	var cell := Vector3(floorf(point.x / 8.0), floorf(point.y / 8.0), floorf(point.z / 8.0))
	var center := cell * 8.0 + Vector3(4.0, 4.0, 4.0) + Vector3(
		_cell_hash(cell, variation_seed, 7.0) * 3.6 - 1.8,
		_cell_hash(cell, variation_seed, 8.0) * 3.6 - 1.8,
		_cell_hash(cell, variation_seed, 9.0) * 3.6 - 1.8
	)
	var shape_scale := Vector3(
		lerpf(0.95, 1.65, _cell_hash(cell, variation_seed, 10.0)),
		lerpf(0.80, 1.45, _cell_hash(cell, variation_seed, 11.0)),
		lerpf(0.95, 1.65, _cell_hash(cell, variation_seed, 12.0))
	)
	return ((point - center) / shape_scale).length() - lerpf(1.00, 1.42, _cell_hash(cell, variation_seed, 13.0))


static func get_fractal_sdf(point: Vector3, level: int, iterations: int = 6, variation_seed: float = 0.0) -> float:
	if level == FractalLevelsScript.Type.MANDELBOX:
		var p := Vector3(
			fposmod(point.x + 4.0, 8.0) - 4.0,
			fposmod(point.y + 4.0, 8.0) - 4.0,
			fposmod(point.z + 4.0, 8.0) - 4.0
		)
		var scale := 1.0
		for _iteration in range(iterations):
			p = p.clamp(Vector3(-1.0, -1.0, -1.0), Vector3.ONE) * 2.0 - p
			var radius_squared := p.length_squared()
			var fold_scale := clampf(maxf(0.25, 1.0 / maxf(radius_squared, 0.25)), 0.25, 1.0)
			p *= fold_scale
			scale *= fold_scale
			p = p * 1.42 + Vector3(0.08, -0.04, 0.03)
			scale *= 1.42
		return (p.length() - 1.0) / maxf(absf(scale), 0.001) * 0.62
	if level == FractalLevelsScript.Type.MENGER:
		var p := _varied_cell_point(point, variation_seed)
		var warped_point := _warped_lattice_point(point, variation_seed)
		var cell := Vector3(floorf((warped_point.x + 4.0) / 8.0), floorf((warped_point.y + 4.0) / 8.0), floorf((warped_point.z + 4.0) / 8.0))
		var variation_a := _cell_hash(cell, variation_seed, 0.0)
		var variation_b := _cell_hash(cell, variation_seed, 1.0)
		var value := 1.0
		var scale := 1.0
		for _iteration in range(iterations):
			p = p.abs()
			if p.x < p.y:
				var xy := p.x
				p.x = p.y
				p.y = xy
			if p.x < p.z:
				var xz := p.x
				p.x = p.z
				p.z = xz
			var hole_width := lerpf(0.90, 1.08, variation_a)
			value = minf(value, maxf(p.x - hole_width, maxf(p.y - 1.0, p.z - lerpf(0.92, 1.06, variation_b))) / scale)
			p = p * 3.0 - Vector3(2.0, 2.0, 2.0)
			scale *= 3.0
		return minf(value * 0.48, _lane_breaker_sdf(point, variation_seed))
	if level == FractalLevelsScript.Type.KIFS:
		var warped_point := _warped_lattice_point(point, variation_seed)
		var k_cell := Vector3(floorf((warped_point.x + 4.0) / 8.0), floorf((warped_point.y + 4.0) / 8.0), floorf((warped_point.z + 4.0) / 8.0))
		var k_a := _cell_hash(k_cell, variation_seed, 0.0)
		var k_b := _cell_hash(k_cell, variation_seed, 1.0)
		var k := _varied_cell_point(point, variation_seed) * lerpf(0.78, 0.86, k_a)
		var k_scale := 1.0
		for _iteration in range(iterations):
			k = k.abs()
			if k.x < k.y:
				var ky := k.x
				k.x = k.y
				k.y = ky
			if k.x < k.z:
				var kz := k.x
				k.x = k.z
				k.z = kz
			k = k * 2.0 - Vector3(1.12 + (k_b - 0.5) * 0.16, 1.04, 0.96 + (k_a - 0.5) * 0.16)
			k_scale *= 2.0
		var exterior := Vector3(
			maxf(k.abs().x - 0.32, 0.0),
			maxf(k.abs().y - 0.32, 0.0),
			maxf(k.abs().z - 0.32, 0.0)
		)
		return minf((exterior.length() + minf(maxf(k.x, maxf(k.y, k.z)), 0.0)) / k_scale - 0.035, _lane_breaker_sdf(point, variation_seed))
	if level == FractalLevelsScript.Type.MANDELBULB:
		var warped_point := _warped_lattice_point(point, variation_seed)
		var bulb_cell := Vector3(floorf((warped_point.x + 4.0) / 8.0), floorf((warped_point.y + 4.0) / 8.0), floorf((warped_point.z + 4.0) / 8.0))
		var bulb_a := _cell_hash(bulb_cell, variation_seed, 0.0)
		var bulb_b := _cell_hash(bulb_cell, variation_seed, 1.0)
		var tiled_point := _varied_cell_point(point, variation_seed)
		var bulb_scale := lerpf(0.68, 0.76, bulb_a)
		var z := tiled_point * bulb_scale
		var radius := 0.0
		var derivative := 1.0
		for _iteration in range(iterations):
			radius = z.length()
			if radius > 2.4: break
			var theta := asin(clampf(z.z / maxf(radius, 0.001), -1.0, 1.0))
			var phi := atan2(z.y, z.x)
			var power := lerpf(6.6, 7.4, bulb_b)
			var zr := pow(maxf(radius, 0.001), power)
			derivative = pow(maxf(radius, 0.001), power - 1.0) * power * derivative + 1.0
			theta *= power
			phi *= power
			z = zr * Vector3(cos(theta) * cos(phi), cos(theta) * sin(phi), sin(theta)) + tiled_point * bulb_scale
		return minf(0.5 * log(maxf(radius, 0.001)) * radius / maxf(derivative, 0.001) - 0.035, _lane_breaker_sdf(point, variation_seed))
	return 0.0

static func get_base_world_sdf(point: Vector3, level: int = FractalLevelsScript.Type.FOLD, iterations: int = 6, variation_seed: float = 0.0) -> float:
	if level != FractalLevelsScript.Type.FOLD:
		return get_fractal_sdf(point, level, iterations, variation_seed)
	var region_wave := sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16
	var gyroid := absf(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave)
	return gyroid

func get_world_sdf(point: Vector3) -> float:
	var region_wave := sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16
	var gyroid := absf(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave)
	if fractal_level != FractalLevelsScript.Type.FOLD:
		return get_fractal_sdf(point, fractal_level, fractal_iterations, world_variation_seed)
	return gyroid


static func find_safe_spawn(origin: Vector3, required_clearance: float = 0.85, level: int = FractalLevelsScript.Type.FOLD, iterations: int = 6, variation_seed: float = 0.0) -> Vector3:
	if get_base_world_sdf(origin, level, iterations, variation_seed) >= required_clearance:
		return origin
	var best_position := origin
	var best_clearance := get_base_world_sdf(origin, level, iterations, variation_seed)
	for x_index in range(-6, 7):
		for y_index in range(-6, 7):
			for z_index in range(-6, 7):
				var candidate := origin + Vector3(x_index, y_index, z_index) * 1.15
				var clearance := get_base_world_sdf(candidate, level, iterations, variation_seed)
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
	for sample_index in range(42):
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
	for sample_index in range(WALL_SWEEP_SAMPLES + 1):
		var amount := float(sample_index) / float(WALL_SWEEP_SAMPLES)
		var sample_position := previous_position.lerp(current_position, amount)
		if get_world_sdf(sample_position) < player_radius:
			return true
	return false


func get_shader_obstacles(player_position: Vector3) -> Array[Vector4]:
	shader_obstacle_build_count += 1
	var candidates := obstacles.duplicate()
	candidates.sort_custom(
		func(a: CourseObstacle, b: CourseObstacle) -> bool:
			return a.position.distance_squared_to(player_position) < b.position.distance_squared_to(player_position)
	)
	var packed: Array[Vector4] = []
	for index in range(MAX_RENDER_OBSTACLES):
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
	neighborhood_revision += 1


func _spawn_cell_obstacle(cell: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for_cell(cell)
	if rng.randf() > 0.62:
		return
	var radius := rng.randf_range(0.48, 0.82)
	var cell_origin := Vector3(cell) * CELL_SIZE
	var identifier := "%d:%d:%d" % [cell.x, cell.y, cell.z]
	for _attempt in range(6):
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
