extends SceneTree

const FractalLevelsScript := preload("res://scripts/fractal_levels.gd")


func _init() -> void:
	_test_determinism_and_deformation()
	_test_hazard_query_parity()
	print("World query tests passed.")
	quit()


func _test_determinism_and_deformation() -> void:
	var state := WorldState.new()
	state.fractal_type = FractalLevelsScript.Type.FOLD
	state.variation_seed = 321.0
	var query := SDFQueryService.new(state)
	var point := Vector3(1.25, -0.75, 2.5)
	var first := query.get_structure_sdf(point, false)
	assert(is_finite(first))
	assert(is_equal_approx(first, query.get_structure_sdf(point, false)))
	state.corridor_active = true
	state.corridor_strength = 1.0
	state.corridor_radius = 0.5
	state.corridor_start = point - Vector3.FORWARD
	state.corridor_mid = point
	state.corridor_end = point + Vector3.FORWARD
	assert(query.get_structure_sdf(point, true) >= first)
	for level in [
		FractalLevelsScript.Type.MANDELBOX,
		FractalLevelsScript.Type.MANDELBULB,
		FractalLevelsScript.Type.KIFS,
		FractalLevelsScript.Type.MENGER,
	]:
		state.fractal_type = level
		state.clear_corridor()
		var value := query.get_structure_sdf(point, false)
		assert(is_finite(value))
		assert(is_equal_approx(value, query.get_structure_sdf(point, false)))


func _test_hazard_query_parity() -> void:
	var state := WorldState.new()
	state.obstacles[0] = Vector4(1.0, 2.0, 3.0, 0.5)
	var query := SDFQueryService.new(state)
	assert(is_equal_approx(query.get_hazard_sdf(Vector3(1.0, 2.0, 3.0)), -0.5))
	assert(query.segment_hits_hazard(Vector3(1.0, 2.0, 1.0), Vector3(1.0, 2.0, 5.0), 0.2))
	state.clear_obstacles()
	assert(not query.segment_hits_hazard(Vector3.ZERO, Vector3.ONE, 0.2))
