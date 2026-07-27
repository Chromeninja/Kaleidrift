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

var render_viewport: SubViewport
var render_rect: ColorRect
var output_rect: TextureRect
var shader_material: ShaderMaterial
var hud_layer: CanvasLayer
var safe_root: MarginContainer
var throttle_panel: PanelContainer
var info_panel: PanelContainer
var title_label: Label
var metrics_label: Label
var status_label: Label
var throttle_label: Label
var speed_slider: VSlider
var speed_readout: Label
var quality_label: Label
var quality_selector: OptionButton
var reduced_motion_toggle: CheckButton
var hide_button: Button

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
var steering_touch_id := -1
var steering_mouse_active := false
var hud_visible := true


func _ready() -> void:
	_build_render_pipeline()
	_build_hud()
	_resize_render_target()
	_apply_quality(current_quality)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	status_label.text = "Drag anywhere to steer • Throttle on the left"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not hud_visible:
			_set_hud_visible(true)
		else:
			get_tree().quit()


func _process(delta: float) -> void:
	elapsed += delta
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
	if event.is_action_pressed("ui_cancel") and not hud_visible:
		_set_hud_visible(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_hud"):
		_set_hud_visible(not hud_visible)
		return
	if event.is_action_pressed("reset_flight"):
		_reset_flight()
		return
	if event is InputEventScreenTouch:
		if event.pressed and steering_touch_id == -1 and not _is_over_hud_control(event.position):
			steering_touch_id = event.index
		elif not event.pressed and event.index == steering_touch_id:
			steering_touch_id = -1
	elif event is InputEventScreenDrag and event.index == steering_touch_id:
		_apply_steering_delta(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			steering_mouse_active = not _is_over_hud_control(event.position)
		else:
			steering_mouse_active = false
	elif event is InputEventMouseMotion and steering_mouse_active:
		_apply_steering_delta(event.relative)


func _build_render_pipeline() -> void:
	render_viewport = SubViewport.new()
	render_viewport.name = "KaleiDriftViewport"
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

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(overlay)
	_build_throttle(overlay)
	_build_info_panel(overlay)
	_update_safe_layout()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.045, 0.075, 0.82)
	style.border_color = Color(0.42, 0.82, 1.0, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 8
	return style


func _build_throttle(parent: Control) -> void:
	throttle_panel = PanelContainer.new()
	throttle_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	throttle_panel.grow_horizontal = Control.GROW_DIRECTION_END
	throttle_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := _panel_style()
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	throttle_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(throttle_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	throttle_panel.add_child(box)
	throttle_label = Label.new()
	throttle_label.text = "THROTTLE"
	throttle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throttle_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	box.add_child(throttle_label)
	speed_slider = VSlider.new()
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	speed_readout.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	box.add_child(speed_readout)


func _build_info_panel(parent: Control) -> void:
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := _panel_style()
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	info_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(info_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	info_panel.add_child(content)
	title_label = Label.new()
	title_label.text = "KALEIDRIFT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	content.add_child(title_label)
	metrics_label = Label.new()
	metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(metrics_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.67, 0.83, 0.94))
	content.add_child(status_label)
	var divider := HSeparator.new()
	content.add_child(divider)
	quality_label = Label.new()
	quality_label.text = "RENDER QUALITY"
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quality_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	content.add_child(quality_label)
	quality_selector = OptionButton.new()
	quality_selector.add_item("Automatic")
	for preset in QUALITY_PRESETS:
		quality_selector.add_item(str(preset["name"]))
	quality_selector.item_selected.connect(_on_quality_selected)
	content.add_child(quality_selector)
	reduced_motion_toggle = CheckButton.new()
	reduced_motion_toggle.text = "Reduced motion"
	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
	content.add_child(reduced_motion_toggle)
	hide_button = Button.new()
	hide_button.text = "Hide interface"
	hide_button.pressed.connect(func() -> void: _set_hud_visible(false))
	content.add_child(hide_button)


func _apply_steering_delta(delta_pixels: Vector2) -> void:
	const SENSITIVITY := 0.0035
	yaw = wrapf(yaw - delta_pixels.x * SENSITIVITY, -PI, PI)
	pitch = wrapf(pitch - delta_pixels.y * SENSITIVITY, -PI, PI)


func _is_over_hud_control(position: Vector2) -> bool:
	if not hud_visible:
		return false
	return (
		throttle_panel.get_global_rect().has_point(position)
		or info_panel.get_global_rect().has_point(position)
	)


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
	var short_side := float(mini(window_size.x, window_size.y))
	var ui_scale := clampf(short_side / 720.0, 0.85, 2.2)
	var padding := maxi(roundi(14.0 * ui_scale), roundi(short_side * 0.022))
	safe_root.add_theme_constant_override("margin_left", safe_rect.position.x + padding)
	safe_root.add_theme_constant_override("margin_top", safe_rect.position.y + padding)
	safe_root.add_theme_constant_override("margin_right", window_size.x - safe_rect.end.x + padding)
	safe_root.add_theme_constant_override("margin_bottom", window_size.y - safe_rect.end.y + padding)

	var portrait := window_size.y > window_size.x
	var available_height := float(safe_rect.size.y - padding * 2)
	var throttle_width := clampf(
		float(window_size.x) * (0.24 if portrait else 0.13),
		100.0 * ui_scale,
		180.0 * ui_scale
	)
	var throttle_height := available_height * (0.66 if portrait else 0.82)
	throttle_panel.custom_minimum_size = Vector2(throttle_width, throttle_height)
	throttle_panel.position = Vector2(0.0, -throttle_height * 0.5)
	speed_slider.custom_minimum_size = Vector2(64.0 * ui_scale, 180.0 * ui_scale)

	var info_width := clampf(
		float(window_size.x) * (0.60 if portrait else 0.34),
		250.0 * ui_scale,
		410.0 * ui_scale
	)
	info_panel.custom_minimum_size = Vector2(info_width, 0.0)
	var touch_height := 50.0 * ui_scale
	quality_selector.custom_minimum_size = Vector2(0.0, touch_height)
	reduced_motion_toggle.custom_minimum_size = Vector2(0.0, touch_height)
	hide_button.custom_minimum_size = Vector2(0.0, touch_height)

	var body_font := roundi(14.0 * ui_scale)
	title_label.add_theme_font_size_override("font_size", roundi(22.0 * ui_scale))
	metrics_label.add_theme_font_size_override("font_size", body_font)
	status_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	quality_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	throttle_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	speed_readout.add_theme_font_size_override("font_size", roundi(18.0 * ui_scale))
	quality_selector.add_theme_font_size_override("font_size", body_font)
	reduced_motion_toggle.add_theme_font_size_override("font_size", body_font)
	hide_button.add_theme_font_size_override("font_size", body_font)


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
		status_label.text = "Quality: %s" % str(preset["name"])


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
	metrics_label.text = "%d FPS • %.1f ms • %s\n%s • %d×%d • %d steps" % [
		Engine.get_frames_per_second(), latest_frame_ms, target_state, str(preset["name"]),
		render_viewport.size.x, render_viewport.size.y, int(preset["steps"])
	]


func _set_hud_visible(visible: bool) -> void:
	hud_visible = visible
	safe_root.visible = visible
	steering_touch_id = -1
	steering_mouse_active = false


func _reset_flight() -> void:
	camera_position = Vector3(0.0, 0.0, 2.0)
	yaw = 0.0
	pitch = 0.0
	speed = 2.5
	if is_instance_valid(speed_slider):
		speed_slider.value = speed
	status_label.text = "Flight reset"
