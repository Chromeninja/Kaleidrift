extends SceneTree

const PlatformCapabilitiesScript := preload("res://scripts/platform/platform_capabilities.gd")
const FlightInputAdapterScript := preload("res://scripts/input/flight_input_adapter.gd")


func _init() -> void:
	_test_platform_capabilities()
	_test_input_normalization()
	print("Platform smoke tests passed.")
	quit()


func _test_platform_capabilities() -> void:
	assert(PlatformCapabilitiesScript.default_quality() >= 0)
	assert(PlatformCapabilitiesScript.default_quality() <= 1)
	assert(PlatformCapabilitiesScript.supports_exit() == not PlatformCapabilitiesScript.is_web())


func _test_input_normalization() -> void:
	var adapter = FlightInputAdapterScript.new()
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.position = Vector2(100.0, 100.0)
	touch.pressed = true
	assert(adapter.consume(touch, func(_position: Vector2) -> bool: return false) == Vector2.ZERO)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.relative = Vector2(8.0, -5.0)
	assert(adapter.consume(drag, func(_position: Vector2) -> bool: return false) == Vector2(8.0, -5.0))
	adapter.reset()
	assert(adapter.steering_touch_id == -1)
