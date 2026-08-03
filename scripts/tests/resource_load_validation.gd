extends SceneTree

const RESOURCES := [
	"res://main.tscn",
	"res://scripts/main.gd",
	"res://scripts/platform/platform_capabilities.gd",
	"res://scripts/input/flight_input_adapter.gd",
	"res://scripts/performance/performance_diagnostics_overlay.gd",
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
