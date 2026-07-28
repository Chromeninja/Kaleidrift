class_name FlightInputAdapter
extends RefCounted

## Normalizes pointer, touch, keyboard, controller, and future sensor inputs.
const POINTER_DEADZONE := 0.5
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


func keyboard_delta(delta: float) -> Vector2:
	var horizontal := Input.get_axis("ui_left", "ui_right")
	var vertical := Input.get_axis("ui_up", "ui_down")
	var steering := Vector2(horizontal, vertical)
	if steering.length_squared() < 0.01:
		return Vector2.ZERO
	return steering * 480.0 * delta


func _filter_pointer_delta(delta: Vector2) -> Vector2:
	if not delta.is_finite() or delta.length_squared() <= POINTER_DEADZONE * POINTER_DEADZONE:
		return Vector2.ZERO
	return delta


func reset() -> void:
	steering_touch_id = -1
	steering_mouse_active = false
