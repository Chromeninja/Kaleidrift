extends SceneTree

const RESOURCES := [
	"res://main.tscn",
	"res://scripts/main.gd",
	"res://scripts/platform/platform_capabilities.gd",
	"res://scripts/input/flight_input_adapter.gd",
	"res://scripts/performance/performance_diagnostics_overlay.gd",
	"res://scripts/flight/player_flight_rig.gd",
	"res://scripts/flight/flight_controller.gd",
	"res://scripts/flight/traveler_safety_controller.gd",
	"res://scripts/world/world_state.gd",
	"res://scripts/world/sdf_query_service.gd",
	"res://scripts/world/corridor_opening_controller.gd",
	"res://scripts/view/view_mode_controller.gd",
	"res://scripts/view/third_person_camera_controller.gd",
	"res://scripts/rendering/fractal_renderer.gd",
	"res://scripts/settings/settings_store.gd",
	"res://resources/travelers/default_catalog.tres",
	"res://shaders/fractal_flight.gdshader",
]


func _init() -> void:
	for resource_path in RESOURCES:
		assert(ResourceLoader.exists(resource_path))
		assert(load(resource_path) != null)
	var scene := load("res://main.tscn") as PackedScene
	assert(scene != null)
	print("Resource load validation passed.")
	quit()
