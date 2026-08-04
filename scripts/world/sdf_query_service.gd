class_name SDFQueryService
extends RefCounted

const FractalLevelsScript := preload("res://scripts/fractal_levels.gd")
const SurvivalWorldScript := preload("res://scripts/gameplay/survival_world.gd")

enum QueryMask { STRUCTURE = 1, HAZARDS = 2, ALL = 3 }

var state: WorldState


func _init(new_state: WorldState) -> void:
	state = new_state


func get_structure_sdf(point: Vector3, include_deformation := true) -> float:
	if not point.is_finite():
		return -INF
	var structure := _get_base_structure_sdf(point)
	if include_deformation and state.corridor_active and state.corridor_strength > 0.0001:
		var corridor := minf(
			_capsule_sdf(point, state.corridor_start, state.corridor_mid, state.corridor_radius),
			_capsule_sdf(point, state.corridor_mid, state.corridor_end, state.corridor_radius)
		)
		var opened := maxf(structure, -corridor)
		structure = lerpf(structure, opened, clampf(state.corridor_strength, 0.0, 1.0))
	return structure


func get_hazard_sdf(point: Vector3) -> float:
	var result := INF
	for obstacle in state.obstacles:
		if obstacle.w > 0.0:
			result = minf(result, point.distance_to(Vector3(obstacle.x, obstacle.y, obstacle.z)) - obstacle.w)
	return result


func get_sdf(point: Vector3, mask := QueryMask.ALL, include_deformation := true) -> float:
	var result := INF
	if mask & QueryMask.STRUCTURE:
		result = get_structure_sdf(point, include_deformation)
	if mask & QueryMask.HAZARDS:
		result = minf(result, get_hazard_sdf(point))
	return result


func get_clearance(point: Vector3, radius: float, mask := QueryMask.ALL, include_deformation := true) -> float:
	return get_sdf(point, mask, include_deformation) - radius


func estimate_normal(point: Vector3, include_deformation := true, mask := QueryMask.STRUCTURE) -> Vector3:
	const EPSILON := 0.012
	var e1 := Vector3(1.0, -1.0, -1.0)
	var e2 := Vector3(-1.0, -1.0, 1.0)
	var e3 := Vector3(-1.0, 1.0, -1.0)
	var e4 := Vector3(1.0, 1.0, 1.0)
	var normal := (
		e1 * get_sdf(point + e1 * EPSILON, mask, include_deformation)
		+ e2 * get_sdf(point + e2 * EPSILON, mask, include_deformation)
		+ e3 * get_sdf(point + e3 * EPSILON, mask, include_deformation)
		+ e4 * get_sdf(point + e4 * EPSILON, mask, include_deformation)
	)
	return normal.normalized() if normal.is_finite() and normal.length_squared() > 0.000001 else Vector3.ZERO


func segment_hits_hazard(start: Vector3, end: Vector3, radius: float) -> bool:
	for obstacle in state.obstacles:
		if obstacle.w <= 0.0:
			continue
		var center := Vector3(obstacle.x, obstacle.y, obstacle.z)
		var combined := obstacle.w + radius
		if _distance_squared_to_segment(center, start, end) <= combined * combined:
			return true
	return false


func find_safe_position(origin: Vector3, radius: float, required_clearance := 0.35) -> Vector3:
	if get_clearance(origin, radius, QueryMask.ALL, false) >= required_clearance:
		return origin
	var best := origin
	var best_clearance := get_clearance(origin, radius, QueryMask.ALL, false)
	for x_index in range(-6, 7):
		for y_index in range(-6, 7):
			for z_index in range(-6, 7):
				var candidate := origin + Vector3(x_index, y_index, z_index) * 0.65
				var clearance := get_clearance(candidate, radius, QueryMask.ALL, false)
				if clearance > best_clearance:
					best = candidate
					best_clearance = clearance
				if clearance >= required_clearance:
					return candidate
	return best


func _get_base_structure_sdf(point: Vector3) -> float:
	var fractal := _fractal_sdf(point)
	if state.fractal_type != FractalLevelsScript.Type.FOLD:
		return fractal
	return minf(_gyroid_sdf(point), fractal)


func _fractal_sdf(point: Vector3) -> float:
	if state.fractal_type == FractalLevelsScript.Type.FOLD:
		return _fold_sdf(point)
	return SurvivalWorldScript.get_fractal_sdf(
		point,
		state.fractal_type,
		state.geometry_iterations,
		state.variation_seed
	)


func _fold_sdf(point: Vector3) -> float:
	var p := Vector3(
		fposmod(point.x + 4.0, 8.0) - 4.0,
		fposmod(point.y + 4.0, 8.0) - 4.0,
		fposmod(point.z + 4.0, 8.0) - 4.0
	)
	var scale := 1.0
	for iteration in range(WorldState.GEOMETRY_ITERATIONS):
		p = p.abs() - Vector3(1.12, 0.96, 1.06)
		var xy := Vector2(p.x, p.y).rotated(-0.20 - float(iteration) * 0.18)
		p.x = xy.x
		p.y = xy.y
		var yz := Vector2(p.y, p.z).rotated(0.31 - float(iteration) * 0.11)
		p.y = yz.x
		p.z = yz.y
		p *= 1.34
		scale *= 1.34
	return p.length() / scale - 0.24


func _gyroid_sdf(point: Vector3) -> float:
	var region_wave := sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16
	return absf(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave)


func _capsule_sdf(point: Vector3, start: Vector3, end: Vector3, radius: float) -> float:
	var segment := end - start
	var amount := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
	return (point - start - segment * amount).length() - radius


func _distance_squared_to_segment(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment := end - start
	var amount := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
	return point.distance_squared_to(start + segment * amount)
