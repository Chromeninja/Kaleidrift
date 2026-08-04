class_name PlayerFlightRig
extends Node3D

var orientation := Quaternion.IDENTITY
var velocity := Vector3.ZERO
var requested_speed := 2.5
var steering_state := Vector2.ZERO
var previous_transform := Transform3D.IDENTITY
var last_safe_transform := Transform3D.IDENTITY
var last_safe_age := 0.0


func _ready() -> void:
	_apply_orientation()
	previous_transform = transform
	last_safe_transform = transform


func reset_state(new_position: Vector3, new_orientation: Quaternion, new_speed: float) -> void:
	position = new_position
	orientation = new_orientation.normalized()
	requested_speed = maxf(new_speed, 0.0)
	velocity = forward() * requested_speed
	steering_state = Vector2.ZERO
	_apply_orientation()
	previous_transform = transform
	last_safe_transform = transform
	last_safe_age = 0.0


func begin_physics_step() -> void:
	previous_transform = transform
	last_safe_age += get_physics_process_delta_time()


func integrate_velocity(new_velocity: Vector3, delta: float) -> void:
	velocity = new_velocity if new_velocity.is_finite() else Vector3.ZERO
	position += velocity * maxf(delta, 0.0)


func set_orientation(new_orientation: Quaternion) -> void:
	orientation = new_orientation.normalized()
	_apply_orientation()


func forward() -> Vector3:
	return -Basis(orientation).orthonormalized().z.normalized()


func right() -> Vector3:
	return Basis(orientation).orthonormalized().x.normalized()


func up() -> Vector3:
	return Basis(orientation).orthonormalized().y.normalized()


func validate_safe_transform() -> void:
	last_safe_transform = transform
	last_safe_age = 0.0


func restore_last_safe_transform() -> void:
	transform = last_safe_transform
	orientation = transform.basis.get_rotation_quaternion().normalized()
	_apply_orientation()


func _apply_orientation() -> void:
	basis = Basis(orientation).orthonormalized()
