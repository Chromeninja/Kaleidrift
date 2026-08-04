class_name FractalRenderer
extends RefCounted

var material: ShaderMaterial


func bind(new_material: ShaderMaterial) -> void:
	material = new_material


func set_camera_transform(camera_transform: Transform3D) -> void:
	if material == null:
		return
	var basis := camera_transform.basis.orthonormalized()
	material.set_shader_parameter("camera_position", camera_transform.origin)
	material.set_shader_parameter("camera_forward", -basis.z.normalized())
	material.set_shader_parameter("camera_right", basis.x.normalized())
	material.set_shader_parameter("camera_up", basis.y.normalized())


func set_corridor(state: WorldState) -> void:
	if material == null:
		return
	material.set_shader_parameter("corridor_active", state.corridor_active)
	material.set_shader_parameter("corridor_strength", state.corridor_strength)
	material.set_shader_parameter("corridor_radius", state.corridor_radius)
	material.set_shader_parameter("corridor_start_point", state.corridor_start)
	material.set_shader_parameter("corridor_mid_point", state.corridor_mid)
	material.set_shader_parameter("corridor_end_point", state.corridor_end)
