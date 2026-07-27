extends Node

const SHADER_PATH := "res://shaders/fractal_flight.gdshader"
const TARGET_FRAME_MS := 1000.0 / 60.0
const AUTO_EVALUATION_SECONDS := 2.0
const AUTO_UPGRADE_SECONDS := 8.0
const QUALITY_PRESETS := [
	{"name": "Low", "render_scale": 0.45, "steps": 44, "detail": 3, "distance": 46.0},
	{"name": "Medium", "render_scale": 0.64, "steps": 64, "detail": 4, "distance": 62.0},
	{"name": "High", "render_scale": 1.0, "steps": 84, "detail": 5, "distance": 78.0}
]


class FlightJoystick:
	extends Control

	signal moved(value: Vector2)

	var knob_offset := Vector2.ZERO
	var touch_id := -1
	var mouse_down := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.46
		draw_circle(center, radius, Color(0.02, 0.07, 0.12, 0.48))
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.55, 0.88, 1.0, 0.58), 2.0, true)
		draw_circle(center + knob_offset, radius * 0.34, Color(0.48, 0.84, 1.0, 0.7))
		draw_arc(center + knob_offset, radius * 0.34, 0.0, TAU, 40, Color(0.9, 0.98, 1.0, 0.9), 2.0, true)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and touch_id == -1:
				touch_id = event.index
				_update_pointer(event.position)
				accept_event()
			elif not event.pressed and event.index == touch_id:
				touch_id = -1
				_release_pointer()
				accept_event()
		elif event is InputEventScreenDrag and event.index == touch_id:
			_update_pointer(event.position)
			accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = event.pressed
			if mouse_down:
				_update_pointer(event.position)
			else:
				_release_pointer()
			accept_event()
		elif event is InputEventMouseMotion and mouse_down:
			_update_pointer(event.position)
			accept_event()

	func _update_pointer(local_position: Vector2) -> void:
		var radius := minf(size.x, size.y) * 0.46
		knob_offset = (local_position - size * 0.5).limit_length(radius)
		moved.emit(knob_offset / radius)
		queue_redraw()

	func _release_pointer() -> void:
		knob_offset = Vector2.ZERO
		moved.emit(Vector2.ZERO)
		queue_redraw()


var render_viewport: SubViewport
var render_rect: ColorRect
var output_rect: TextureRect
var shader_material: ShaderMaterial
var hud_layer: CanvasLayer
var safe_root: MarginContainer
var top_bar: HBoxContainer
var title_label: Label
var metrics_label: Label
var status_label: Label
var speed_slider: VSlider
var speed_readout: Label
var throttle_panel: PanelContainer
var joystick: FlightJoystick
var quality_selector: OptionButton
var reduced_motion_toggle: CheckButton

var camera_position := Vector3(0.0, 0.0, 2.0)
var yaw := 0.0
var pitch := 0.0
var speed := 2.5
var elapsed := 0.0
var current_quality := 1
var automatic_quality := true
var evaluation_elapsed := 0.0
var stable_fast_elapsed := 0.0
var frame_ms_samples: Array[float] = []
var joystick_vector := Vector2.ZERO
var free_drag_active := false
var hud_visible := true


func _ready() -> void:
	_build_render_pipeline()
	_build_hud()
	_resize_render_target()
	_apply_quality(current_quality)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	status_label.text = "Joystick to steer • Throttle on the left"


func _process(delta: float) -> void:
	elapsed += delta
	if joystick_vector.length_squared() > 0.0001:
		_apply_steering_delta(joystick_vector * 420.0 * delta)

	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var forward := -basis.z.normalized()
	var right := basis.x.normalized()
	var up := basis.y.normalized()
	camera_position += forward * speed * delta
	shader_material.set_shader_parameter("camera_position", camera_position)
	shader_material.set_shader_parameter("camera_forward", forward)
	shader_material.set_shader_parameter("camera_right", right)
	shader_material.set_shader_parameter("camera_up", up)
	shader_material.set_shader_parameter("elapsed_time", elapsed)

	var frame_ms := delta * 1000.0
	frame_ms_samples.append(frame_ms)
	if frame_ms_samples.size() > 120:
		frame_ms_samples.pop_front()
	evaluation_elapsed += delta
	if automatic_quality and evaluation_elapsed >= AUTO_EVALUATION_SECONDS:
		_evaluate_automatic_quality()
		evaluation_elapsed = 0.0
	_update_metrics(frame_ms)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		_set_hud_visible(not hud_visible)
		return
	if event.is_action_pressed("reset_flight"):
		_reset_flight()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not hud_visible and event.position.x < 120.0 and event.position.y < 120.0:
			_set_hud_visible(true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# When the HUD is hidden, retain the original desktop drag-anywhere steering.
		if not hud_visible and event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
			free_drag_active = event.pressed
	elif event is InputEventMouseMotion and free_drag_active:
		_apply_steering_delta(event.relative)


func _build_render_pipeline() -> void:
	render_viewport = SubViewport.new()
	render_viewport.name = "FractalViewport"
	render_viewport.disable_3d = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.transparent_bg = false
	add_child(render_viewport)

	render_rect = ColorRect.new()
	render_rect.name = "FractalShader"
	render_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	render_viewport.add_child(render_rect)
	shader_material = ShaderMaterial.new()
	shader_material.shader = load(SHADER_PATH) as Shader
	render_rect.material = shader_material

	output_rect = TextureRect.new()
	output_rect.name = "Display"
	output_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output_rect.stretch_mode = TextureRect.STRETCH_SCALE
	output_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	output_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_rect.texture = render_viewport.get_texture()
	add_child(output_rect)


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)

	safe_root = MarginContainer.new()
	safe_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(safe_root)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	safe_root.add_child(layout)

	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	layout.add_child(top_bar)
	title_label = Label.new()
	title_label.text = "PHYCO • FRACTAL FLIGHT"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.80, 0.93, 1.0))
	top_bar.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	quality_selector = OptionButton.new()
	quality_selector.add_item("Auto")
	for preset in QUALITY_PRESETS:
		quality_selector.add_item(str(preset["name"]))
	quality_selector.item_selected.connect(_on_quality_selected)
	top_bar.add_child(quality_selector)
	reduced_motion_toggle = CheckButton.new()
	reduced_motion_toggle.text = "Reduced motion"
	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
	top_bar.add_child(reduced_motion_toggle)
	var hide_button := Button.new()
	hide_button.text = "Hide"
	hide_button.pressed.connect(func() -> void: _set_hud_visible(false))
	top_bar.add_child(hide_button)

	metrics_label = Label.new()
	metrics_label.add_theme_font_size_override("font_size", 15)
	layout.add_child(metrics_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.67, 0.83, 0.94))
	layout.add_child(status_label)

	var controls := Control.new()
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(controls)
	_build_throttle(controls)
	joystick = FlightJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	joystick.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	joystick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	joystick.moved.connect(func(value: Vector2) -> void: joystick_vector = value)
	controls.add_child(joystick)
	_update_safe_layout()


func _build_throttle(parent: Control) -> void:
	throttle_panel = PanelContainer.new()
	throttle_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	throttle_panel.grow_horizontal = Control.GROW_DIRECTION_END
	throttle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.06, 0.10, 0.58)
	panel_style.border_color = Color(0.45, 0.82, 1.0, 0.38)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(18)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	throttle_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(throttle_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	throttle_panel.add_child(box)
	var label := Label.new()
	label.text = "THROTTLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	box.add_child(label)
	speed_slider = VSlider.new()
	speed_slider.custom_minimum_size = Vector2(58, 130)
	speed_slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speed_slider.min_value = 0.25
	speed_slider.max_value = 8.0
	speed_slider.step = 0.05
	speed_slider.value = speed
	speed_slider.value_changed.connect(_on_speed_changed)
	box.add_child(speed_slider)
	speed_readout = Label.new()
	speed_readout.text = "%.2f×" % speed
	speed_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_readout.add_theme_font_size_override("font_size", 15)
	speed_readout.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	box.add_child(speed_readout)


func _apply_steering_delta(delta_pixels: Vector2) -> void:
	const SENSITIVITY := 0.0035
	yaw -= delta_pixels.x * SENSITIVITY
	pitch = clamp(pitch - delta_pixels.y * SENSITIVITY, -1.45, 1.45)


func _on_speed_changed(value: float) -> void:
	speed = value
	if is_instance_valid(speed_readout):
		speed_readout.text = "%.2f×" % speed


func _on_quality_selected(index: int) -> void:
	automatic_quality = index == 0
	current_quality = 1 if automatic_quality else clamp(index - 1, 0, QUALITY_PRESETS.size() - 1)
	_apply_quality(current_quality)


func _on_reduced_motion_toggled(enabled: bool) -> void:
	shader_material.set_shader_parameter("reduced_motion", enabled)


func _on_viewport_size_changed() -> void:
	_resize_render_target()
	_update_safe_layout()


func _update_safe_layout() -> void:
	if not is_instance_valid(safe_root):
		return
	var window_size := Vector2i(get_viewport().get_visible_rect().size)
	var safe_rect := Rect2i(Vector2i.ZERO, window_size)
	if OS.has_feature("android"):
		var reported_safe_area := DisplayServer.get_display_safe_area()
		if reported_safe_area.size.x > 0 and reported_safe_area.size.y > 0:
			safe_rect = reported_safe_area
	var padding := maxi(12, int(mini(window_size.x, window_size.y) * 0.025))
	safe_root.add_theme_constant_override("margin_left", safe_rect.position.x + padding)
	safe_root.add_theme_constant_override("margin_top", safe_rect.position.y + padding)
	safe_root.add_theme_constant_override("margin_right", window_size.x - safe_rect.end.x + padding)
	safe_root.add_theme_constant_override("margin_bottom", window_size.y - safe_rect.end.y + padding)

	var short_side := minf(window_size.x, window_size.y)
	var joystick_size := clampf(short_side * 0.27, 132.0, 190.0)
	joystick.custom_minimum_size = Vector2(joystick_size, joystick_size)
	throttle_panel.custom_minimum_size = Vector2(
		clampf(short_side * 0.15, 82.0, 98.0),
		clampf(window_size.y * 0.40, 190.0, 265.0)
	)
	var portrait := window_size.y > window_size.x
	title_label.visible = not portrait or window_size.x >= 650
	reduced_motion_toggle.text = "Reduced" if portrait else "Reduced motion"


func _resize_render_target() -> void:
	if not is_instance_valid(render_viewport):
		return
	var window_size := get_viewport().get_visible_rect().size
	var scale := float(QUALITY_PRESETS[current_quality]["render_scale"])
	var target := Vector2i(maxi(1, roundi(window_size.x * scale)), maxi(1, roundi(window_size.y * scale)))
	render_viewport.size = target
	render_rect.size = Vector2(target)
	shader_material.set_shader_parameter("viewport_size", Vector2(target))


func _apply_quality(index: int) -> void:
	current_quality = clamp(index, 0, QUALITY_PRESETS.size() - 1)
	var preset: Dictionary = QUALITY_PRESETS[current_quality]
	shader_material.set_shader_parameter("max_steps", int(preset["steps"]))
	shader_material.set_shader_parameter("detail_iterations", int(preset["detail"]))
	shader_material.set_shader_parameter("max_distance", float(preset["distance"]))
	_resize_render_target()
	if is_instance_valid(status_label):
		status_label.text = "Quality changed to %s" % str(preset["name"])


func _evaluate_automatic_quality() -> void:
	if frame_ms_samples.is_empty():
		return
	var sorted_samples := frame_ms_samples.duplicate()
	sorted_samples.sort()
	var percentile_index := mini(sorted_samples.size() - 1, int(float(sorted_samples.size() - 1) * 0.90))
	var p90_ms: float = sorted_samples[percentile_index]
	if p90_ms > 19.5 and current_quality > 0:
		stable_fast_elapsed = 0.0
		_apply_quality(current_quality - 1)
	elif p90_ms < 15.2 and current_quality < QUALITY_PRESETS.size() - 1:
		stable_fast_elapsed += AUTO_EVALUATION_SECONDS
		if stable_fast_elapsed >= AUTO_UPGRADE_SECONDS:
			stable_fast_elapsed = 0.0
			_apply_quality(current_quality + 1)
	else:
		stable_fast_elapsed = 0.0


func _update_metrics(latest_frame_ms: float) -> void:
	var preset: Dictionary = QUALITY_PRESETS[current_quality]
	var target_state := "PASS" if latest_frame_ms <= TARGET_FRAME_MS else "OVER"
	metrics_label.text = "%d FPS • %.1f ms • %s • %s • %d×%d • %d steps" % [
		Engine.get_frames_per_second(), latest_frame_ms, target_state, str(preset["name"]),
		render_viewport.size.x, render_viewport.size.y, int(preset["steps"])
	]


func _set_hud_visible(visible: bool) -> void:
	hud_visible = visible
	for child in hud_layer.get_children():
		child.visible = visible
	if not visible:
		status_label.text = ""
		joystick_vector = Vector2.ZERO


func _reset_flight() -> void:
	camera_position = Vector3(0.0, 0.0, 2.0)
	yaw = 0.0
	pitch = 0.0
	speed = 2.5
	if is_instance_valid(speed_slider):
		speed_slider.value = speed
	status_label.text = "Flight reset"
