class_name ViewModeController
extends RefCounted

const IMMERSIVE := &"immersive"
const TRAVELER := &"traveler"

var view_mode: StringName = IMMERSIVE
var camera_controller := ThirdPersonCameraController.new()
var presentation_transform := Transform3D.IDENTITY


func set_view_mode(value: StringName, rig: PlayerFlightRig) -> void:
	view_mode = TRAVELER if value == TRAVELER else IMMERSIVE
	if rig != null:
		camera_controller.reset_from_transform(rig.transform)


func toggle(rig: PlayerFlightRig) -> void:
	set_view_mode(TRAVELER if view_mode == IMMERSIVE else IMMERSIVE, rig)


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
	if view_mode == IMMERSIVE:
		presentation_transform = rig.transform
	else:
		presentation_transform = camera_controller.update(rig, query, distance, height, look_ahead, portrait, reduced_motion, delta)
	return presentation_transform
