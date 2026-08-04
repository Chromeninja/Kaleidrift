class_name WorldState
extends RefCounted

const MAX_OBSTACLES := 8
const GEOMETRY_ITERATIONS := 6

var journey_seed := 0
var variation_seed := 0.0
var region_id := 0
var fractal_type := 0
var geometry_iterations := GEOMETRY_ITERATIONS
var survival_mode := false
var obstacles: Array[Vector4] = []

var corridor_active := false
var corridor_strength := 0.0
var corridor_radius := 0.0
var corridor_start := Vector3.ZERO
var corridor_mid := Vector3.ZERO
var corridor_end := Vector3.ZERO


func _init() -> void:
	obstacles.resize(MAX_OBSTACLES)
	clear_obstacles()


func clear_obstacles() -> void:
	for index in range(MAX_OBSTACLES):
		obstacles[index] = Vector4(0.0, 0.0, 0.0, -1.0)


func set_obstacles(source: Array[Vector4]) -> void:
	for index in range(MAX_OBSTACLES):
		obstacles[index] = source[index] if index < source.size() else Vector4(0.0, 0.0, 0.0, -1.0)


func clear_corridor() -> void:
	corridor_active = false
	corridor_strength = 0.0
	corridor_radius = 0.0
