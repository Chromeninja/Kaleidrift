class_name ThirdPersonCameraController
extends RefCounted

const CAMERA_RADIUS := 0.12
const SEGMENT_SAMPLES := 8
const REFINEMENT_STEPS := 3

var position := Vector3.ZERO
var orientation := Quaternion.IDENTITY
var desired_distance := 0.0
var actual_distance := 0.0
var obstruction_clearance := INF
var initialized := false


func reset_from_transform(source: Transform3D) -> void:
	position = source.origin
	orientation = source.basis.get_rotation_quaternion().normalized()
	initialized = true


func update(
	rig: PlayerFlightRig,
	query: SDFQueryService,
	distance: float,
	height: float,
	look_ahead: float,
	portrait: bool,
	reduced_motion: bool,
	delta: float
) -> Transform3D:
	var adjusted_distance := distance * (0.85 if portrait else 1.0)
	var adjusted_height := height * (1.15 if portrait else 1.0)
	desired_distance = adjusted_distance
	var target := rig.position + rig.forward() * look_ahead
	var desired := rig.position - rig.forward() * adjusted_distance + rig.up() * adjusted_height
	var clear_amount := 1.0
	obstruction_clearance = INF
	for index in range(1, SEGMENT_SAMPLES + 1):
		var amount := float(index) / float(SEGMENT_SAMPLES)
		var sample := rig.position.lerp(desired, amount)
		var clearance := query.get_clearance(sample, CAMERA_RADIUS, SDFQueryService.QueryMask.ALL, true)
		obstruction_clearance = minf(obstruction_clearance, clearance)
		if clearance < 0.06:
			clear_amount = float(index - 1) / float(SEGMENT_SAMPLES)
			break
	if clear_amount < 1.0:
		var low := maxf(clear_amount - 1.0 / float(SEGMENT_SAMPLES), 0.0)
		var high := minf(clear_amount + 1.0 / float(SEGMENT_SAMPLES), 1.0)
		for _step in range(REFINEMENT_STEPS):
			var middle := (low + high) * 0.5
			if query.get_clearance(rig.position.lerp(desired, middle), CAMERA_RADIUS, SDFQueryService.QueryMask.ALL, true) >= 0.06:
				low = middle
			else:
				high = middle
		clear_amount = low
	var resolved := rig.position.lerp(desired, clear_amount)
	actual_distance = rig.position.distance_to(resolved)
	var up := rig.up()
	if absf(resolved.direction_to(target).dot(up)) > 0.995:
		up = Vector3.UP
	var desired_orientation := Basis.looking_at(resolved.direction_to(target), up).get_rotation_quaternion().normalized()
	var inherited_bank := clampf(-rig.steering_state.x * deg_to_rad(2.0), -deg_to_rad(2.0), deg_to_rad(2.0))
	desired_orientation = (Quaternion(resolved.direction_to(target), inherited_bank) * desired_orientation).normalized()
	if not initialized or reduced_motion:
		position = resolved
		orientation = desired_orientation
		initialized = true
	else:
		var retracting := resolved.distance_to(rig.position) < position.distance_to(rig.position)
		var position_tau := 0.06 if retracting else 0.24
		position = position.lerp(resolved, 1.0 - exp(-delta / position_tau))
		orientation = orientation.slerp(desired_orientation, 1.0 - exp(-delta / 0.16)).normalized()
	return Transform3D(Basis(orientation), position)
