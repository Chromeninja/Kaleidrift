class_name TravelerSafetyController
extends RefCounted

enum SafetyState { CLEAR, OPENING, SLIDING, DEPENETRATING, RESTORING_SAFE_TRANSFORM }

const COLLISION_RADIUS_MIN := 0.18
const COLLISION_RADIUS_MAX := 0.22
const MINIMUM_CLEARANCE := 0.18
const SAFE_TRANSFORM_CLEARANCE := 0.35
const RISK_CLEARANCE := 0.55
const EMERGENCY_CLEARANCE := 0.05
const RELEASE_CLEARANCE := 0.80
const CENTER_PROBES := 6
const STEERING_PROBES := 3

var collision_radius := 0.20
var current_clearance := INF
var combined_clearance := INF
var minimum_predicted_clearance := INF
var lookahead_distance := 1.5
var probe_count := 0
var corridor_risk := 0.0
var safety_state := SafetyState.CLEAR
var avoidance_active := false
var recovery_stage := "clear"
var collision_cpu_us := 0
var worst_probe_position := Vector3.ZERO
var projected_path_mid := Vector3.ZERO
var projected_path_end := Vector3.ZERO
var _release_elapsed := 0.0
var _safe_ticks := 0


func set_collision_radius(value: float) -> void:
	collision_radius = clampf(value, COLLISION_RADIUS_MIN, COLLISION_RADIUS_MAX)


func evaluate(rig: PlayerFlightRig, query: SDFQueryService, desired_velocity: Vector3, delta: float) -> Vector3:
	var started := Time.get_ticks_usec()
	probe_count = 0
	avoidance_active = false
	recovery_stage = "clear"
	current_clearance = _sample_clearance(query, rig.position, false, SDFQueryService.QueryMask.STRUCTURE)
	combined_clearance = minf(current_clearance, query.get_hazard_sdf(rig.position) - collision_radius)
	var speed := desired_velocity.length()
	var frame_guard := clampf(delta, 1.0 / 60.0, 0.10)
	lookahead_distance = clampf(speed * 0.75 + speed * frame_guard + collision_radius + MINIMUM_CLEARANCE, 1.5, 8.0)
	var forward := desired_velocity.normalized() if speed > 0.0001 else rig.forward()
	var steering_bias := (rig.right() * rig.steering_state.x - rig.up() * rig.steering_state.y) * minf(0.42, rig.steering_state.length() * 0.42)
	var predicted_forward := (forward + steering_bias).normalized()
	projected_path_mid = rig.position + forward * lookahead_distance * 0.45
	projected_path_end = projected_path_mid + predicted_forward * lookahead_distance * 0.55
	minimum_predicted_clearance = INF
	worst_probe_position = rig.position
	_probe_segment(query, rig.position, projected_path_end, CENTER_PROBES)
	_probe_segment(query, projected_path_mid, projected_path_end + rig.right() * collision_radius, STEERING_PROBES)
	_probe_segment(query, projected_path_mid, projected_path_end - rig.right() * collision_radius, STEERING_PROBES)

	var raw_risk := 1.0 - smoothstep(EMERGENCY_CLEARANCE, RISK_CLEARANCE, minimum_predicted_clearance)
	if minimum_predicted_clearance < RISK_CLEARANCE:
		_release_elapsed = 0.0
		corridor_risk = maxf(corridor_risk, raw_risk)
	elif minimum_predicted_clearance >= RELEASE_CLEARANCE:
		_release_elapsed += delta
		if _release_elapsed >= 0.20:
			corridor_risk = 0.0
	else:
		_release_elapsed = 0.0
		corridor_risk = maxf(corridor_risk, raw_risk)

	var resolved := desired_velocity
	if corridor_risk > 0.001:
		safety_state = SafetyState.OPENING
		recovery_stage = "opening"
	else:
		safety_state = SafetyState.CLEAR

	var deformed_clearance := _sample_clearance(query, rig.position + desired_velocity * delta, true, SDFQueryService.QueryMask.STRUCTURE)
	if deformed_clearance < MINIMUM_CLEARANCE:
		var normal := query.estimate_normal(worst_probe_position, true)
		probe_count += 4
		if normal != Vector3.ZERO:
			var inward := minf(resolved.dot(normal), 0.0)
			var severity := 1.0 - smoothstep(EMERGENCY_CLEARANCE, MINIMUM_CLEARANCE, deformed_clearance)
			resolved -= normal * inward * severity
			resolved += normal * minf(maxf(MINIMUM_CLEARANCE - deformed_clearance, 0.0) * 2.0, speed * 0.30)
			avoidance_active = true
			safety_state = SafetyState.SLIDING
			recovery_stage = "sliding"
		else:
			safety_state = SafetyState.DEPENETRATING
			recovery_stage = "invalid_normal"

	if current_clearance >= SAFE_TRANSFORM_CLEARANCE and minimum_predicted_clearance >= MINIMUM_CLEARANCE:
		_safe_ticks += 1
		if _safe_ticks >= 2:
			rig.validate_safe_transform()
	else:
		_safe_ticks = 0
	collision_cpu_us = Time.get_ticks_usec() - started
	return resolved


func recover_if_embedded(rig: PlayerFlightRig, query: SDFQueryService) -> void:
	var clearance := query.get_clearance(rig.position, collision_radius, SDFQueryService.QueryMask.STRUCTURE, true)
	if clearance >= 0.0:
		return
	for _attempt in range(3):
		var normal := query.estimate_normal(rig.position, true)
		if normal == Vector3.ZERO:
			break
		rig.position += normal * minf(-clearance + 0.02, 0.30)
		clearance = query.get_clearance(rig.position, collision_radius, SDFQueryService.QueryMask.STRUCTURE, true)
		if clearance >= 0.0:
			safety_state = SafetyState.DEPENETRATING
			recovery_stage = "depenetrated"
			return
	rig.restore_last_safe_transform()
	safety_state = SafetyState.RESTORING_SAFE_TRANSFORM
	recovery_stage = "restored_safe_transform"


func state_name() -> String:
	return SafetyState.keys()[safety_state]


func _probe_segment(query: SDFQueryService, start: Vector3, end: Vector3, count: int) -> void:
	for index in range(count):
		var amount := float(index + 1) / float(count)
		var point := start.lerp(end, amount)
		var clearance := _sample_clearance(query, point, false, SDFQueryService.QueryMask.STRUCTURE)
		if clearance < minimum_predicted_clearance:
			minimum_predicted_clearance = clearance
			worst_probe_position = point


func _sample_clearance(query: SDFQueryService, point: Vector3, deformed: bool, mask: int) -> float:
	probe_count += 1
	return query.get_clearance(point, collision_radius, mask, deformed)
