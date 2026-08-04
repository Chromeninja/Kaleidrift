class_name TravelerVisual
extends Node3D

const TRAIL_STYLES := [&"default", &"short", &"long"]

@export_enum("orb", "geometric_bird") var visual_kind := "orb"

var primary_color := Color(0.18, 0.92, 1.0)
var accent_color := Color(1.0, 0.22, 0.82)
var glow_intensity := 2.2
var trail_style: StringName = &"default"
var steering := Vector2.ZERO
var _fragments: Array[Node3D] = []
var _primary_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _elapsed := 0.0
var _base_visual_scale := 1.0


func _ready() -> void:
	_primary_material = _make_material(primary_color)
	_accent_material = _make_material(accent_color)
	if visual_kind == "geometric_bird":
		_build_geometric_bird()
	else:
		_build_orb()


func configure(primary: Color, accent: Color, glow: float, new_trail_style: StringName = &"default") -> void:
	primary_color = primary
	accent_color = accent
	glow_intensity = glow
	trail_style = new_trail_style if new_trail_style in TRAIL_STYLES else &"default"
	if is_instance_valid(_primary_material):
		_configure_material(_primary_material, primary_color)
	if is_instance_valid(_accent_material):
		_configure_material(_accent_material, accent_color)
	_apply_trail_style()


func set_visual_scale(value: float) -> void:
	_base_visual_scale = maxf(value, 0.01)


func set_flight_state(new_steering: Vector2, speed: float) -> void:
	steering = new_steering
	var target_roll := clampf(-new_steering.x * 0.14, -0.14, 0.14)
	rotation.z = lerp_angle(rotation.z, target_roll, 0.18)
	scale = Vector3.ONE * _base_visual_scale * (1.0 + minf(speed / 8.0, 1.0) * 0.025)


func _process(delta: float) -> void:
	_elapsed += delta
	if visual_kind == "orb":
		for index in range(_fragments.size()):
			var angle := _elapsed * (0.8 + float(index) * 0.18) + TAU * float(index) / maxf(float(_fragments.size()), 1.0)
			_fragments[index].position = Vector3(cos(angle) * 0.46, sin(angle * 1.3) * 0.24, sin(angle) * 0.30)
	else:
		for index in range(_fragments.size()):
			_fragments[index].rotation.z = sin(_elapsed * 2.2 + float(index)) * 0.08


func _build_orb() -> void:
	_add_mesh(SphereMesh.new(), Vector3.ONE * 0.28, Vector3.ZERO, _primary_material)
	for index in range(3):
		var fragment := Node3D.new()
		add_child(fragment)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.13, 0.18, 0.10)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _accent_material if index % 2 == 0 else _primary_material
		fragment.add_child(instance)
		_fragments.append(fragment)
	_apply_trail_style()


func _build_geometric_bird() -> void:
	var body := PrismMesh.new()
	body.size = Vector3(0.26, 0.22, 0.78)
	_add_mesh(body, Vector3.ONE, Vector3.ZERO, _primary_material)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.34, 0.0, 0.04)
		wing.rotation.z = side * 0.18
		add_child(wing)
		var wing_mesh := PrismMesh.new()
		wing_mesh.size = Vector3(0.58, 0.06, 0.42)
		var instance := MeshInstance3D.new()
		instance.mesh = wing_mesh
		instance.material_override = _accent_material
		wing.add_child(instance)
		_fragments.append(wing)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.10, 0.12, 0.36)
	_add_mesh(tail, Vector3.ONE, Vector3(0.0, 0.0, 0.48), _primary_material)
	_apply_trail_style()


func _apply_trail_style() -> void:
	var multiplier := 1.0
	if trail_style == &"short":
		multiplier = 0.72
	elif trail_style == &"long":
		multiplier = 1.35
	for fragment in _fragments:
		fragment.scale = Vector3.ONE * multiplier


func _add_mesh(mesh: PrimitiveMesh, mesh_scale: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = mesh_scale
	instance.position = offset
	instance.material_override = material
	add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_configure_material(material, color)
	return material


func _configure_material(material: StandardMaterial3D, color: Color) -> void:
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow_intensity
