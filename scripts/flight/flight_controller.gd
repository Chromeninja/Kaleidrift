class_name FlightController
extends RefCounted

const STEERING_SENSITIVITY := 0.0035

var steering_input := Vector2.ZERO


func apply_steering_delta(rig: PlayerFlightRig, delta_pixels: Vector2) -> void:
	if rig == null or not delta_pixels.is_finite() or delta_pixels == Vector2.ZERO:
		return
	var orientation := rig.orientation
	var basis := Basis(orientation).orthonormalized()
	var horizontal_rotation := Quaternion(basis.y, -delta_pixels.x * STEERING_SENSITIVITY)
	orientation = (horizontal_rotation * orientation).normalized()
	basis = Basis(orientation).orthonormalized()
	var vertical_rotation := Quaternion(basis.x, -delta_pixels.y * STEERING_SENSITIVITY)
	orientation = (vertical_rotation * orientation).normalized()
	steering_input = delta_pixels.normalized()
	rig.steering_state = steering_input
	rig.set_orientation(orientation)


func set_speed(rig: PlayerFlightRig, new_speed: float) -> void:
	if rig != null:
		rig.requested_speed = maxf(new_speed, 0.0)


func get_desired_velocity(rig: PlayerFlightRig) -> Vector3:
	if rig == null:
		return Vector3.ZERO
	return rig.forward() * rig.requested_speed


func reset() -> void:
	steering_input = Vector2.ZERO
