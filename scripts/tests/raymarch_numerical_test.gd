extends SceneTree

# These fixtures reproduce traversal errors without changing the shared field.
# GPU image checks are still needed to validate the actual shader implementation.
const HIT_EPSILON := 0.0025
const FOLD_STEP_FACTOR := 0.55


func _init() -> void:
	_test_gyroid_step_bound()
	_test_near_surface_minimum_step()
	print("Raymarch numerical tests passed.")
	quit()


func _test_gyroid_step_bound() -> void:
	var query := SDFQueryService.new(WorldState.new())
	# At this exposed gyroid surface the field gradient exceeds 1 / 0.72.
	var origin := Vector3(0.51044004, 4.54594718, 4.85098526)
	var direction := Vector3(-0.58792678, 0.43912976, -0.67934539).normalized()
	var initial := query.get_structure_sdf(origin, false)
	assert(initial > 0.09 and initial < 0.11)
	var legacy_end := origin + direction * initial * 0.72
	assert(query.get_structure_sdf(legacy_end, false) < -0.01)
	var safe_end := origin + direction * initial * FOLD_STEP_FACTOR
	assert(query.get_structure_sdf(safe_end, false) > HIT_EPSILON)
	# For g = sum(sin(x)cos(y)), Cauchy bounds each derivative squared
	# by cos(y)^2 + sin(z)^2. Summing gives |gradient(g)| <= sqrt(3).
	# The varying wall width contributes at most the following extra norm.
	var bound := sqrt(3.0) + Vector2(0.060 * 0.18, 0.052 * 0.16).length()
	assert(bound < 1.75)
	assert(FOLD_STEP_FACTOR * bound < 1.0)
	var position := origin
	var steps := 0
	while query.get_structure_sdf(position, false) >= HIT_EPSILON and steps < 32:
		position += direction * query.get_structure_sdf(position, false) * FOLD_STEP_FACTOR
		assert(query.get_structure_sdf(position, false) >= 0.0)
		steps += 1
	assert(steps < 32)
	print("Gyroid fixture: legacy step overshoots by ", -query.get_structure_sdf(legacy_end, false), "; conservative march converges in ", steps, " steps.")


func _test_near_surface_minimum_step() -> void:
	# A thin slab starts just beyond the hit threshold. An absolute 0.008
	# minimum advances through both faces without ever observing a hit.
	var slab_center := 0.004
	var slab_half_width := 0.001
	var initial := absf(slab_center) - slab_half_width
	assert(initial > HIT_EPSILON)
	var legacy_position := maxf(initial * 0.72, 0.008)
	assert(absf(legacy_position - slab_center) - slab_half_width > HIT_EPSILON)
	var safe_position := initial * FOLD_STEP_FACTOR
	assert(absf(safe_position - slab_center) - slab_half_width < HIT_EPSILON)
