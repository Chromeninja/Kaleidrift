class_name SurvivalSession
extends Node

const FractalLevelsScript = preload("res://scripts/fractal_levels.gd")

signal health_changed(current: int, maximum: int)
signal damaged
signal game_over(distance: float, score: int)

const COURSE_SEED := 0x4B414C45
const PLAYER_RADIUS := 0.18
const NEAR_MISS_SCORE := 25
const SPAWN_GRACE_SECONDS := 5.0
const HIT_RECOVERY_SECONDS := 0.28
const SAFE_POSITION_MARGIN := 0.55

var world := SurvivalWorld.new()
var health: HealthComponent
var position := Vector3.ZERO
var previous_position := position
var last_safe_position := position
var spawn_forward := Vector3.FORWARD
var distance_traveled := 0.0
var score := 0
var recovery_remaining := 0.0
var active := false
var fractal_level := FractalLevelsScript.Type.FOLD
var fractal_iterations := 6
var _cached_shader_obstacles: Array[Vector4] = []
var _cached_obstacle_position := Vector3(INF, INF, INF)
var _cached_neighborhood_revision := -1


func _ready() -> void:
	health = HealthComponent.new()
	health.name = "Health"
	add_child(health)
	health.health_changed.connect(_on_health_health_changed)
	health.damaged.connect(_on_health_damaged)
	health.depleted.connect(_on_health_depleted)


func start(new_fractal_level: int = FractalLevelsScript.Type.FOLD, new_fractal_iterations: int = 6) -> void:
	fractal_level = new_fractal_level
	set_fractal_iterations(new_fractal_iterations)
	world.reset(COURSE_SEED, Vector3(0.0, 0.0, 2.0), fractal_level)
	position = world.find_safe_spawn(
		Vector3(0.0, 0.0, 2.0),
		0.85,
		fractal_level,
		fractal_iterations,
		world.world_variation_seed
	)
	previous_position = position
	last_safe_position = position
	distance_traveled = 0.0
	score = 0
	recovery_remaining = 0.0
	active = true
	world.reset(COURSE_SEED, position, fractal_level)
	health.reset()
	health.grant_invulnerability(SPAWN_GRACE_SECONDS)
	spawn_forward = world.find_safest_direction(position, PLAYER_RADIUS)
	_invalidate_shader_obstacles()


func stop() -> void:
	active = false

func set_fractal_level(new_fractal_level: int) -> void:
	if fractal_level == new_fractal_level:
		return
	fractal_level = new_fractal_level
	world.fractal_level = new_fractal_level
	world.current_cell = SurvivalWorld.EMPTY_CELL
	world.update(position)
	_invalidate_shader_obstacles()


func set_fractal_iterations(new_fractal_iterations: int) -> void:
	fractal_iterations = maxi(new_fractal_iterations, 1)
	world.fractal_iterations = fractal_iterations


func physics_step(delta: float, forward_speed: float, forward_direction: Vector3) -> void:
	if not active:
		return
	health.tick(delta)
	world.update(position)
	if recovery_remaining > 0.0:
		recovery_remaining = maxf(recovery_remaining - delta, 0.0)
		previous_position = position
		return

	previous_position = position
	var movement := forward_direction.normalized() * maxf(forward_speed, 0.0) * delta
	var candidate_position := position + movement
	var hit_wall := world.collides_with_world_swept_sphere(
		previous_position,
		candidate_position,
		PLAYER_RADIUS
	)
	var hit_obstacle := world.collides_with_obstacle_swept_sphere(
		previous_position,
		candidate_position,
		PLAYER_RADIUS
	)
	if hit_wall or hit_obstacle:
		recovery_remaining = HIT_RECOVERY_SECONDS
		if hit_wall:
			position = last_safe_position
			world.update(position)
			health.take_damage(1)
		else:
			position = previous_position
			health.take_damage(1)
		return

	position = candidate_position
	distance_traveled += movement.length()
	score = maxi(score, roundi(distance_traveled * _speed_multiplier(forward_speed)))
	world.update(position)
	if world.is_position_safe(position, PLAYER_RADIUS, SAFE_POSITION_MARGIN):
		last_safe_position = position
	var near_misses := world.collect_near_misses(
		previous_position,
		position,
		PLAYER_RADIUS
	)
	if near_misses > 0:
		score += near_misses * NEAR_MISS_SCORE


func begin_external_step(delta: float, rig_position: Vector3) -> void:
	if not active:
		return
	health.tick(delta)
	position = rig_position
	world.update(position)


func complete_external_step(previous: Vector3, current: Vector3, forward_speed: float) -> void:
	if not active:
		return
	previous_position = previous
	position = current
	var movement_distance := previous.distance_to(current)
	distance_traveled += movement_distance
	score = maxi(score, roundi(distance_traveled * _speed_multiplier(forward_speed)))
	world.update(position)
	var near_misses := world.collect_near_misses(previous, current, PLAYER_RADIUS)
	if near_misses > 0:
		score += near_misses * NEAR_MISS_SCORE


func register_external_hazard_hit(previous: Vector3) -> void:
	if not active:
		return
	previous_position = previous
	position = previous
	recovery_remaining = HIT_RECOVERY_SECONDS
	health.take_damage(1)


func get_shader_obstacles() -> Array[Vector4]:
	if (
		_cached_shader_obstacles.is_empty()
		or _cached_neighborhood_revision != world.neighborhood_revision
		or position.distance_squared_to(_cached_obstacle_position) >= 0.0625
	):
		_cached_shader_obstacles = world.get_shader_obstacles(position)
		_cached_obstacle_position = position
		_cached_neighborhood_revision = world.neighborhood_revision
	return _cached_shader_obstacles


func _invalidate_shader_obstacles() -> void:
	_cached_shader_obstacles.clear()
	_cached_obstacle_position = Vector3(INF, INF, INF)
	_cached_neighborhood_revision = -1


func get_spawn_forward() -> Vector3:
	return spawn_forward


func _speed_multiplier(forward_speed: float) -> float:
	return 1.0 + maxf(forward_speed - 2.5, 0.0) * 0.12


func _on_health_depleted() -> void:
	active = false
	game_over.emit(distance_traveled, score)


func _on_health_health_changed(current: int, maximum: int) -> void:
	health_changed.emit(current, maximum)


func _on_health_damaged(_amount: int) -> void:
	damaged.emit()
