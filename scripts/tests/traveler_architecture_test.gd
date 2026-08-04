extends SceneTree

const RigScript := preload("res://scripts/flight/player_flight_rig.gd")
const FlightControllerScript := preload("res://scripts/flight/flight_controller.gd")
const SafetyScript := preload("res://scripts/flight/traveler_safety_controller.gd")
const CorridorScript := preload("res://scripts/world/corridor_opening_controller.gd")
const ViewModeScript := preload("res://scripts/view/view_mode_controller.gd")
const FakeQueryScript := preload("res://scripts/tests/fake_plane_sdf_query.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_authoritative_rig_and_controller()
	_test_prediction_corridor_and_slide()
	_test_view_switch_and_camera_retraction()
	_test_traveler_resources_and_fallback()
	_test_probe_object_stability()
	print("Traveler architecture tests passed.")
	quit()


func _make_rig() -> PlayerFlightRig:
	var rig := RigScript.new()
	root.add_child(rig)
	rig.reset_state(Vector3(0.0, 0.0, 2.0), Quaternion.IDENTITY, 2.5)
	return rig


func _test_authoritative_rig_and_controller() -> void:
	var rig := _make_rig()
	var controller := FlightControllerScript.new()
	var original_orientation := rig.orientation
	controller.apply_steering_delta(rig, Vector2(120.0, -80.0))
	assert(not rig.orientation.is_equal_approx(original_orientation))
	controller.set_speed(rig, 4.0)
	var desired := controller.get_desired_velocity(rig)
	assert(is_equal_approx(desired.length(), 4.0))
	var origin := rig.position
	rig.integrate_velocity(desired, 0.25)
	assert(is_equal_approx(rig.position.distance_to(origin), 1.0))
	rig.queue_free()


func _test_prediction_corridor_and_slide() -> void:
	var rig := _make_rig()
	var query := FakeQueryScript.new()
	query.configure(Vector3(0.0, 0.0, 1.0), 0.0)
	var safety := SafetyScript.new()
	safety.set_collision_radius(0.20)
	var desired := rig.forward() * 8.0
	var resolved := safety.evaluate(rig, query, desired, 0.30)
	assert(safety.corridor_risk > 0.5)
	assert(safety.minimum_predicted_clearance < 0.05)
	assert(safety.probe_count <= 18)
	assert(resolved.dot(Vector3(0.0, 0.0, 1.0)) > desired.dot(Vector3(0.0, 0.0, 1.0)))
	var corridor := CorridorScript.new()
	corridor.update(query.state, safety, rig, 0.1)
	assert(query.state.corridor_active)
	assert(query.state.corridor_radius <= CorridorOpeningController.MAX_RADIUS)
	safety.set_collision_radius(0.01)
	assert(is_equal_approx(safety.collision_radius, TravelerSafetyController.COLLISION_RADIUS_MIN))
	safety.set_collision_radius(1.0)
	assert(is_equal_approx(safety.collision_radius, TravelerSafetyController.COLLISION_RADIUS_MAX))
	rig.queue_free()


func _test_view_switch_and_camera_retraction() -> void:
	var rig := _make_rig()
	var query := FakeQueryScript.new()
	query.configure(Vector3(0.0, 0.0, -1.0), -3.0)
	var view := ViewModeScript.new()
	var rig_transform := rig.transform
	view.set_view_mode(ViewModeController.TRAVELER, rig)
	var camera_transform := view.update(rig, query, 2.8, 0.72, 1.0, false, true, 1.0 / 60.0)
	assert(rig.transform.is_equal_approx(rig_transform))
	assert(view.camera_controller.actual_distance < view.camera_controller.desired_distance + 0.8)
	assert(camera_transform.origin.is_finite())
	view.toggle(rig)
	assert(view.view_mode == ViewModeController.IMMERSIVE)
	assert(view.update(rig, query, 2.8, 0.72, 1.0, true, true, 1.0 / 60.0).is_equal_approx(rig.transform))
	rig.queue_free()


func _test_traveler_resources_and_fallback() -> void:
	var catalog := load("res://resources/travelers/default_catalog.tres") as TravelerCatalog
	assert(catalog != null)
	assert(catalog.travelers.size() == 2)
	var orb := catalog.find_definition(&"glowing_orb")
	var bird := catalog.find_definition(&"geometric_bird")
	assert(orb != null and bird != null)
	assert(orb.visual_scene != null and bird.visual_scene != null)
	assert(is_equal_approx(orb.gameplay_collision_radius, bird.gameplay_collision_radius))
	assert(catalog.find_definition(&"missing").identifier == &"glowing_orb")


func _test_probe_object_stability() -> void:
	var rig := _make_rig()
	var query := FakeQueryScript.new()
	query.configure(Vector3(0.0, 0.0, 1.0), -20.0)
	var safety := SafetyScript.new()
	for _warmup in range(20):
		safety.evaluate(rig, query, rig.forward() * 2.5, 1.0 / 60.0)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_before := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for _sample in range(10_000):
		safety.evaluate(rig, query, rig.forward() * 2.5, 1.0 / 60.0)
	assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before)
	assert(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) == resources_before)
	rig.queue_free()
