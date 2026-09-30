extends SceneTree


class AnalyticQuery extends SDFQueryService:
	var wall_z := INF

	func _init() -> void:
		super(WorldState.new())

	func get_structure_sdf(point: Vector3, _include_deformation := true) -> float:
		return wall_z - point.z


func _init() -> void:
	_test_immediate_retraction()
	_test_rapid_turn_interpolation()
	_test_smooth_recovery_and_reduced_motion()
	print("Camera safety tests passed.")
	quit()


func _assert_safe(camera: ThirdPersonCameraController, rig: PlayerFlightRig, query: SDFQueryService, result: Transform3D) -> void:
	assert(result.origin.is_finite())
	assert(result.basis.is_finite())
	assert(query.get_clearance(result.origin, camera.CAMERA_RADIUS) >= camera.MIN_CLEARANCE)
	assert(is_equal_approx(camera.actual_distance, rig.position.distance_to(result.origin)))


func _test_immediate_retraction() -> void:
	var rig := PlayerFlightRig.new()
	var query := AnalyticQuery.new()
	var camera := ThirdPersonCameraController.new()
	camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 1.0 / 60.0)
	query.wall_z = 0.8
	var rig_before := rig.transform
	var result := camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 1.0 / 60.0)
	_assert_safe(camera, rig, query, result)
	assert(result.origin.z < 0.63)
	assert(rig.transform == rig_before)
	assert(not query.state.corridor_active)
	rig.free()


func _test_rapid_turn_interpolation() -> void:
	var rig := PlayerFlightRig.new()
	var query := AnalyticQuery.new()
	var camera := ThirdPersonCameraController.new()
	camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 1.0 / 60.0)
	# Both endpoints are clear, but the smoothed midpoint intersects a hazard.
	query.state.obstacles[0] = Vector4(1.0, 0.0, 1.0, 0.35)
	rig.set_orientation(Quaternion(Vector3.UP, PI * 0.5))
	var result := camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 0.24 * log(2.0))
	_assert_safe(camera, rig, query, result)
	assert(result.origin.x > 1.9)
	rig.free()


func _test_smooth_recovery_and_reduced_motion() -> void:
	var rig := PlayerFlightRig.new()
	var query := AnalyticQuery.new()
	var camera := ThirdPersonCameraController.new()
	query.wall_z = 0.8
	camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 1.0 / 60.0)
	var retracted := camera.position.z
	query.wall_z = INF
	var result := camera.update(rig, query, 2.0, 0.0, 1.0, false, false, 1.0 / 60.0)
	_assert_safe(camera, rig, query, result)
	assert(result.origin.z > retracted and result.origin.z < 2.0)
	result = camera.update(rig, query, 2.0, 0.0, 1.0, true, true, 1.0 / 60.0)
	_assert_safe(camera, rig, query, result)
	assert(is_equal_approx(result.origin.z, 1.7))
	rig.free()
