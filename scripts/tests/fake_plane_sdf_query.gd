class_name FakePlaneSDFQuery
extends SDFQueryService

var plane_normal := Vector3(0.0, 0.0, 1.0)
var plane_offset := 0.0


func _init() -> void:
	super(WorldState.new())


func configure(normal: Vector3, offset: float) -> void:
	plane_normal = normal.normalized()
	plane_offset = offset


func get_structure_sdf(point: Vector3, _include_deformation := true) -> float:
	return point.dot(plane_normal) - plane_offset


func get_hazard_sdf(_point: Vector3) -> float:
	return INF


func get_sdf(point: Vector3, _mask := QueryMask.ALL, _include_deformation := true) -> float:
	return get_structure_sdf(point)


func get_clearance(point: Vector3, radius: float, _mask := QueryMask.ALL, _include_deformation := true) -> float:
	return get_structure_sdf(point) - radius


func estimate_normal(_point: Vector3, _include_deformation := true, _mask := QueryMask.STRUCTURE) -> Vector3:
	return plane_normal
