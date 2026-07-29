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
	assert(PlatformCapabilitiesScript.should_show_inflight_menu() == PlatformCapabilitiesScript.is_mobile_web())
	if not PlatformCapabilitiesScript.is_web():
		assert(not PlatformCapabilitiesScript.is_mobile_web())
		assert(not PlatformCapabilitiesScript.is_web_fullscreen())


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
	assert(adapter._filter_analog_vector(Vector2.ZERO) == Vector2.ZERO)
	assert(adapter._filter_analog_vector(Vector2(0.10, 0.0)) == Vector2.ZERO)
	assert(adapter.active_joypad_id == -1)
	var filtered := adapter._filter_analog_vector(Vector2(0.50, 0.0))
	assert(filtered.x > 0.0 and filtered.x < 1.0)
	adapter.set_calibration(7, Vector2(0.30, 0.0))
	var joy := InputEventJoypadMotion.new()
	joy.device = 7
	joy.axis = JOY_AXIS_LEFT_X
	joy.axis_value = 0.30
	assert(adapter.joypad_delta(joy, 1.0) == Vector2.ZERO)
	joy.axis_value = 1.0
	assert(adapter.joypad_delta(joy, 1.0).x > 0.0)
	var second_joy := InputEventJoypadMotion.new()
	second_joy.device = 8
	second_joy.axis = JOY_AXIS_LEFT_Y
	second_joy.axis_value = 1.0
	assert(adapter.joypad_delta(second_joy, 1.0) == Vector2.ZERO)
	adapter.reset()
	var drifting_joy := InputEventJoypadMotion.new()
	drifting_joy.device = 9
	drifting_joy.axis = JOY_AXIS_LEFT_Y
	drifting_joy.axis_value = 0.20
	assert(adapter.joypad_delta(drifting_joy, 1.0) == Vector2.ZERO)
	assert(adapter.active_joypad_id == -1)
