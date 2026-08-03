class_name FlightInputAdapter
extends RefCounted

## Normalizes pointer, touch, keyboard, controller, and future sensor inputs.
const POINTER_DEADZONE := 0.5
const DEFAULT_DEADZONE := 0.24
const DEFAULT_OUTER_DEADZONE := 0.05
const DEFAULT_RESPONSE_CURVE := 1.0
const HYSTERESIS_MARGIN := 0.025
const JOYPAD_CLAIM_THRESHOLD := 0.45
const JOY_AXIS_HORIZONTAL := JOY_AXIS_RIGHT_X
const JOY_AXIS_VERTICAL := JOY_AXIS_RIGHT_Y
var deadzone := DEFAULT_DEADZONE
var outer_deadzone := DEFAULT_OUTER_DEADZONE
var response_curve := DEFAULT_RESPONSE_CURVE
var calibration_offsets: Dictionary = {}
var joypad_axis_values: Dictionary = {}
## The first stick deliberately moved during a flight owns analog steering until reset.
## This prevents a second HOTAS/VKB device from injecting its resting-axis noise.
var active_joypad_id := -1
var last_analog_input := Vector2.ZERO
var last_joypad_diagnostic := ""
var steering_touch_id := -1
var steering_mouse_active := false


func consume(event: InputEvent, is_over_hud_control: Callable) -> Vector2:
	if event is InputEventScreenTouch:
		if event.pressed and steering_touch_id == -1 and not is_over_hud_control.call(event.position):
			steering_touch_id = event.index
		elif not event.pressed and event.index == steering_touch_id:
			steering_touch_id = -1
	elif event is InputEventScreenDrag and event.index == steering_touch_id:
		return _filter_pointer_delta(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			steering_mouse_active = not is_over_hud_control.call(event.position)
		else:
			steering_mouse_active = false
	elif event is InputEventMouseMotion and steering_mouse_active:
		return _filter_pointer_delta(event.relative)
	return Vector2.ZERO


func joypad_delta(event: InputEventJoypadMotion, delta: float) -> Vector2:
	if event == null or not is_finite(event.axis_value):
		return Vector2.ZERO
	if event.axis != JOY_AXIS_HORIZONTAL and event.axis != JOY_AXIS_VERTICAL:
		return Vector2.ZERO
	var axis_values: Vector2 = joypad_axis_values.get(str(event.device), Vector2.ZERO)
	if event.axis == JOY_AXIS_HORIZONTAL:
		axis_values.x = event.axis_value
	else:
		axis_values.y = event.axis_value
	joypad_axis_values[str(event.device)] = axis_values
	var raw: Vector2 = axis_values
	var offset: Vector2 = calibration_offsets.get(str(event.device), Vector2.ZERO)
	raw -= offset
	var filtered := _filter_analog_vector(raw)
	if active_joypad_id >= 0 and event.device != active_joypad_id:
		last_joypad_diagnostic = "joypad %d axis %d raw %.3f ignored (active %d)" % [event.device, event.axis, event.axis_value, active_joypad_id]
		return Vector2.ZERO
	if active_joypad_id < 0:
		# Do not let idle drift choose the steering device. The player must make
		# one deliberate deflection before this controller can steer the flight.
		if filtered.length() < JOYPAD_CLAIM_THRESHOLD:
			last_joypad_diagnostic = "joypad %d axis %d raw %.3f ignored (awaiting claim)" % [event.device, event.axis, event.axis_value]
			return Vector2.ZERO
		active_joypad_id = event.device
		last_joypad_diagnostic = "joypad %d claimed steering" % event.device
	if filtered.length_squared() <= 0.0:
		last_joypad_diagnostic = "joypad %d axis %d raw %.3f filtered to zero" % [event.device, event.axis, event.axis_value]
		last_analog_input = Vector2.ZERO
		return Vector2.ZERO
	last_analog_input = filtered
	last_joypad_diagnostic = "joypad %d axis %d raw %.3f filtered (%.3f, %.3f)" % [event.device, event.axis, event.axis_value, filtered.x, filtered.y]
	return filtered * 480.0 * delta


## Poll the standard right stick once per frame, independent of axis-event cadence.
func joypad_look(delta: float) -> Vector2:
	var device_id := active_joypad_id
	if device_id < 0:
		for candidate in Input.get_connected_joypads():
			var candidate_raw := _read_right_stick(candidate)
			var candidate_filtered := _filter_analog_vector(candidate_raw - calibration_offsets.get(str(candidate), Vector2.ZERO))
			if candidate_filtered.length() >= JOYPAD_CLAIM_THRESHOLD:
				device_id = candidate
				active_joypad_id = candidate
				last_joypad_diagnostic = "joypad %d claimed steering" % candidate
				break
	if device_id < 0:
		last_analog_input = Vector2.ZERO
		return Vector2.ZERO
	var raw := _read_right_stick(device_id)
	joypad_axis_values[str(device_id)] = raw
	var offset: Vector2 = calibration_offsets.get(str(device_id), Vector2.ZERO)
	var filtered := _filter_analog_vector(raw - offset)
	last_analog_input = filtered
	last_joypad_diagnostic = "joypad %d frame raw (%.3f, %.3f) filtered (%.3f, %.3f)" % [device_id, raw.x, raw.y, filtered.x, filtered.y]
	return filtered * 480.0 * delta


func _read_right_stick(device_id: int) -> Vector2:
	return Vector2(Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y))


## Returns left-stick thrust as 0..1. Up is maximum thrust, down is minimum.
func joypad_thrust() -> float:
	var device_id := active_joypad_id
	if device_id < 0:
		var connected := Input.get_connected_joypads()
		if connected.is_empty():
			return -1.0
		device_id = connected[0]
	var raw := -Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	if not is_finite(raw):
		return -1.0
	var magnitude := absf(raw)
	if magnitude <= deadzone:
		return -1.0
	var normalized := clampf((magnitude - deadzone) / maxf(1.0 - deadzone - outer_deadzone, 0.01), 0.0, 1.0)
	normalized = pow(normalized, maxf(response_curve, 0.1))
	return clampf((normalized * signf(raw) + 1.0) * 0.5, 0.0, 1.0)


func set_calibration(device_id: int, offset: Vector2) -> void:
	calibration_offsets[str(device_id)] = offset


func calibrate_active_joypad() -> bool:
	if active_joypad_id < 0 or not joypad_axis_values.has(str(active_joypad_id)):
		return false
	calibration_offsets[str(active_joypad_id)] = joypad_axis_values[str(active_joypad_id)]
	return true


func clear_calibration(device_id: int) -> void:
	calibration_offsets.erase(str(device_id))


func reset_joypad(device_id: int) -> void:
	joypad_axis_values.erase(str(device_id))
	if active_joypad_id == device_id:
		active_joypad_id = -1
		last_analog_input = Vector2.ZERO


func reset_defaults() -> void:
	deadzone = DEFAULT_DEADZONE
	outer_deadzone = DEFAULT_OUTER_DEADZONE
	response_curve = DEFAULT_RESPONSE_CURVE
	calibration_offsets.clear()
	joypad_axis_values.clear()
	reset()


func _filter_analog_vector(value: Vector2) -> Vector2:
	if not value.is_finite():
		return Vector2.ZERO
	var magnitude := minf(value.length(), 1.0)
	var release_deadzone := maxf(deadzone - HYSTERESIS_MARGIN, 0.0)
	if magnitude <= release_deadzone:
		return Vector2.ZERO
	var usable_range := maxf(1.0 - deadzone - outer_deadzone, 0.01)
	var normalized_magnitude := clampf((magnitude - deadzone) / usable_range, 0.0, 1.0)
	normalized_magnitude = pow(normalized_magnitude, maxf(response_curve, 0.1))
	return value.normalized() * normalized_magnitude


func keyboard_delta(delta: float) -> Vector2:
	var horizontal := float(Input.is_action_pressed("steer_right")) - float(Input.is_action_pressed("steer_left"))
	var vertical := float(Input.is_action_pressed("steer_down")) - float(Input.is_action_pressed("steer_up"))
	var steering := Vector2(horizontal, vertical)
	if not steering.is_finite() or steering == Vector2.ZERO:
		return Vector2.ZERO
	return steering * 480.0 * delta


func _filter_pointer_delta(delta: Vector2) -> Vector2:
	if not delta.is_finite() or delta.length_squared() <= POINTER_DEADZONE * POINTER_DEADZONE:
		return Vector2.ZERO
	return delta


func reset() -> void:
	steering_touch_id = -1
	steering_mouse_active = false
	active_joypad_id = -1
	last_analog_input = Vector2.ZERO
