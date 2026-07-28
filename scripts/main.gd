extends Node

const SHADER_PATH := "res://shaders/fractal_flight.gdshader"
const TARGET_FRAME_MS := 1000.0 / 60.0
const AUTO_EVALUATION_SECONDS := 2.0
const AUTO_UPGRADE_SECONDS := 8.0
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "settings"
const HDR_MODE_AUTO := 0
const HDR_MODE_ON := 1
const HDR_MODE_OFF := 2
const TONE_MAP_REINHARD := 0
const TONE_MAP_AGX := 1
const TONE_MAP_LINEAR := 2
const SurvivalSessionScript := preload("res://scripts/gameplay/survival_session.gd")
const ProceduralMusicControllerScript := preload("res://scripts/audio/procedural_music_controller.gd")
const PlatformCapabilitiesScript := preload("res://scripts/platform/platform_capabilities.gd")
const FlightInputAdapterScript := preload("res://scripts/input/flight_input_adapter.gd")
const MUSIC_JOURNEY_SEED := 0x4B414C45494E
const MUSIC_REGION_SIZE := 64.0
const WEB_DEFAULT_QUALITY := 0
const QUALITY_PRESETS := [
	{"name": "Low", "render_scale": 0.45, "steps": 44, "detail": 3, "distance": 46.0},
	{"name": "Medium", "render_scale": 0.64, "steps": 64, "detail": 4, "distance": 62.0},
	{"name": "High", "render_scale": 1.0, "steps": 84, "detail": 5, "distance": 78.0}
]

enum InterfaceState {
	MENU,
	PLAYING,
	GAME_OVER,
}

enum GameMode {
	ENDLESS,
	SURVIVAL,
}

var render_viewport: SubViewport
var render_rect: ColorRect
var output_rect: TextureRect
var shader_material: ShaderMaterial
var hud_layer: CanvasLayer
var safe_root: MarginContainer
var throttle_panel: PanelContainer
var menu_panel: PanelContainer
var main_menu_content: VBoxContainer
var settings_scroll: ScrollContainer
var settings_content: VBoxContainer
var game_over_content: VBoxContainer
var title_label: Label
var metrics_label: Label
var status_label: Label
var throttle_label: Label
var speed_slider: VSlider
var speed_readout: Label
var quality_label: Label
var quality_selector: OptionButton
var reduced_motion_toggle: CheckButton
var music_toggle: CheckButton
var music_volume_slider: HSlider
var music_volume_label: Label
var hdr_mode_selector: OptionButton
var hdr_status_label: Label
var reference_white_slider: HSlider
var peak_brightness_slider: HSlider
var tone_map_selector: OptionButton
var highlight_slider: HSlider
var gamut_slider: HSlider
var hdr_values_label: Label
var hdr_reset_button: Button
var play_button: Button
var survival_button: Button
var settings_button: Button
var exit_button: Button
var settings_back_button: Button
var retry_button: Button
var mode_select_button: Button
var game_over_title: Label
var game_over_result: Label
var gameplay_overlay: Control
var gameplay_hud_panel: PanelContainer
var health_label: Label
var distance_label: Label
var score_label: Label
var damage_flash: ColorRect

var camera_position := Vector3(0.0, 0.0, 2.0)
# A quaternion avoids Euler poles so unrestricted 3D flight stays continuous.
var camera_orientation := Quaternion.IDENTITY
var speed := 2.5
var elapsed := 0.0
var current_quality := 1
var automatic_quality := true
var evaluation_elapsed := 0.0
var stable_fast_elapsed := 0.0
var frame_ms_samples: Array[float] = []
var flight_input: FlightInputAdapter
var interface_state := InterfaceState.MENU
var current_game_mode := GameMode.ENDLESS
var settings_visible := false
var hdr_mode := HDR_MODE_AUTO
var tone_map_mode := TONE_MAP_REINHARD
var reference_white := 1.0
var peak_brightness_limit := 4.0
var highlight_intensity := 1.0
var gamut_intensity := 1.0
var hdr_output_active := false
var internal_hdr_active := false
var output_max_linear_value := 1.0
var _reduced_motion_setting := false
var _music_enabled_setting := true
var _music_volume_setting := 0.7
var _music_started := false
var survival_session
var music_controller: ProceduralMusicController
var damage_flash_strength := 0.0


func _ready() -> void:
	current_quality = PlatformCapabilities.default_quality()
	flight_input = FlightInputAdapterScript.new()
	_load_settings()
	survival_session = SurvivalSessionScript.new()
	survival_session.name = "SurvivalSession"
	add_child(survival_session)
	survival_session.health_changed.connect(_on_survival_health_changed)
	survival_session.damaged.connect(_on_survival_damaged)
	survival_session.game_over.connect(_on_survival_game_over)
	music_controller = ProceduralMusicControllerScript.new()
	music_controller.name = "ProceduralMusic"
	add_child(music_controller)
	music_controller.set_music_enabled(_music_enabled_setting)
	music_controller.set_volume_linear(_music_volume_setting)
	if not PlatformCapabilities.needs_audio_activation():
		_start_music()
	_build_render_pipeline()
	_build_hud()
	_resize_render_target()
	_apply_quality(current_quality)
	_apply_hdr_settings()
	_sync_hdr_controls()
	if is_instance_valid(reduced_motion_toggle):
		reduced_motion_toggle.button_pressed = _reduced_motion_setting
	if is_instance_valid(music_toggle):
		music_toggle.button_pressed = _music_enabled_setting
	if is_instance_valid(music_volume_slider):
		music_volume_slider.value = _music_volume_setting * 100.0
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	get_window().output_max_linear_value_changed.connect(_on_output_max_linear_value_changed)
	status_label.text = "Drag anywhere to steer • Throttle centered below"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_command()


func _physics_process(delta: float) -> void:
	if interface_state != InterfaceState.PLAYING or current_game_mode != GameMode.SURVIVAL:
		return
	var basis := Basis(camera_orientation).orthonormalized()
	var forward := -basis.z.normalized()
	survival_session.physics_step(delta, speed, forward)
	camera_position = survival_session.position


func _process(delta: float) -> void:
	if interface_state == InterfaceState.PLAYING:
		var keyboard_steering := flight_input.keyboard_delta(delta)
		if keyboard_steering != Vector2.ZERO:
			_apply_steering_delta(keyboard_steering)
	elapsed += delta
	var basis := Basis(camera_orientation).orthonormalized()
	var forward := -basis.z.normalized()
	var right := basis.x.normalized()
	var up := basis.y.normalized()
	if current_game_mode == GameMode.ENDLESS:
		camera_position += forward * speed * delta
	shader_material.set_shader_parameter("camera_position", camera_position)
	shader_material.set_shader_parameter("camera_forward", forward)
	shader_material.set_shader_parameter("camera_right", right)
	shader_material.set_shader_parameter("camera_up", up)
	shader_material.set_shader_parameter("elapsed_time", elapsed)
	shader_material.set_shader_parameter("survival_mode", current_game_mode == GameMode.SURVIVAL)
	if current_game_mode == GameMode.SURVIVAL:
		shader_material.set_shader_parameter(
			"survival_obstacles",
			survival_session.get_shader_obstacles()
		)
		_update_survival_hud()
	_update_music_context()
	damage_flash_strength = maxf(damage_flash_strength - delta * 2.8, 0.0)
	if is_instance_valid(damage_flash):
		damage_flash.color = Color(1.0, 0.12, 0.18, damage_flash_strength * 0.42)
	if hdr_output_active:
		_update_output_max_linear_value(get_window().get_output_max_linear_value())

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
	if _is_user_activation_event(event):
		_start_music()
	if event.is_action_pressed("ui_cancel"):
		_handle_back_command()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_hud"):
		if interface_state == InterfaceState.PLAYING:
			_show_main_menu()
		else:
			_start_endless()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("reset_flight"):
		_reset_flight()
		return
	# Pointer/touch steering is valid only after a mode has entered active flight.
	# Ignoring events in menus also prevents a play-button transition from leaving
	# a stale drag stream attached to the camera.
	if interface_state == InterfaceState.PLAYING:
		var steering_delta := flight_input.consume(event, _is_over_hud_control)
		if steering_delta != Vector2.ZERO:
			_apply_steering_delta(steering_delta)


func _build_render_pipeline() -> void:
	get_viewport().use_hdr_2d = _should_use_internal_hdr()
	render_viewport = SubViewport.new()
	render_viewport.name = "KaleiDriftViewport"
	render_viewport.disable_3d = true
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	render_viewport.transparent_bg = false
	render_viewport.use_hdr_2d = _should_use_internal_hdr()
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
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_root.add_child(overlay)
	_build_throttle(overlay)
	_build_menu_panel(overlay)
	_build_gameplay_overlay()
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
	throttle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	throttle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
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


func _build_menu_panel(parent: Control) -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := _panel_style()
	style.bg_color = Color(0.01, 0.025, 0.06, 0.9)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	menu_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(menu_panel)

	var views := Control.new()
	views.custom_minimum_size = Vector2(300, 0)
	menu_panel.add_child(views)

	main_menu_content = VBoxContainer.new()
	main_menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_content.alignment = BoxContainer.ALIGNMENT_CENTER
	main_menu_content.add_theme_constant_override("separation", 14)
	views.add_child(main_menu_content)
	title_label = Label.new()
	title_label.text = "KALEIDRIFT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	main_menu_content.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = "FRACTAL FLIGHT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.78, 0.94))
	main_menu_content.add_child(subtitle)
	var endless_description := Label.new()
	endless_description.text = "ENDLESS\nRelax, explore, and pass through the shifting world."
	endless_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endless_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	endless_description.add_theme_color_override("font_color", Color(0.68, 0.84, 0.95))
	main_menu_content.add_child(endless_description)
	play_button = Button.new()
	play_button.text = "Fly Endless"
	play_button.pressed.connect(_start_endless)
	main_menu_content.add_child(play_button)
	var survival_description := Label.new()
	survival_description.text = "SURVIVAL\nExplore freely, dodge hazards, and protect your health."
	survival_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survival_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survival_description.add_theme_color_override("font_color", Color(0.94, 0.74, 0.82))
	main_menu_content.add_child(survival_description)
	survival_button = Button.new()
	survival_button.text = "Start Survival"
	survival_button.pressed.connect(_start_survival)
	main_menu_content.add_child(survival_button)
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_show_settings)
	main_menu_content.add_child(settings_button)
	exit_button = Button.new()
	exit_button.text = "Exit Game"
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	exit_button.visible = not _is_web_platform()
	main_menu_content.add_child(exit_button)

	settings_scroll = ScrollContainer.new()
	settings_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.visible = false
	views.add_child(settings_scroll)
	settings_content = VBoxContainer.new()
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_content.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_content.add_theme_constant_override("separation", 9)
	settings_scroll.add_child(settings_content)
	var settings_title := Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	settings_content.add_child(settings_title)
	metrics_label = Label.new()
	metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_content.add_child(metrics_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.67, 0.83, 0.94))
	settings_content.add_child(status_label)
	var divider := HSeparator.new()
	settings_content.add_child(divider)
	quality_label = Label.new()
	quality_label.text = "RENDER QUALITY"
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	settings_content.add_child(quality_label)
	quality_selector = OptionButton.new()
	quality_selector.add_item("Automatic")
	for preset in QUALITY_PRESETS:
		quality_selector.add_item(str(preset["name"]))
	quality_selector.item_selected.connect(_on_quality_selected)
	settings_content.add_child(quality_selector)
	reduced_motion_toggle = CheckButton.new()
	reduced_motion_toggle.text = "Reduced motion"
	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
	settings_content.add_child(reduced_motion_toggle)
	var audio_divider := HSeparator.new()
	settings_content.add_child(audio_divider)
	var audio_title := Label.new()
	audio_title.text = "MUSIC"
	audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	settings_content.add_child(audio_title)
	music_toggle = CheckButton.new()
	music_toggle.text = "Procedural music"
	music_toggle.button_pressed = _music_enabled_setting
	music_toggle.toggled.connect(_on_music_toggled)
	settings_content.add_child(music_toggle)
	music_volume_label = Label.new()
	music_volume_label.text = "Music volume  %d%%" % roundi(_music_volume_setting * 100.0)
	music_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_content.add_child(music_volume_label)
	music_volume_slider = HSlider.new()
	music_volume_slider.min_value = 0.0
	music_volume_slider.max_value = 100.0
	music_volume_slider.step = 1.0
	music_volume_slider.value = _music_volume_setting * 100.0
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	settings_content.add_child(music_volume_slider)
	var hdr_divider := HSeparator.new()
	settings_content.add_child(hdr_divider)
	var hdr_title := Label.new()
	hdr_title.text = "HDR / COLOR"
	hdr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	settings_content.add_child(hdr_title)
	hdr_mode_selector = OptionButton.new()
	hdr_mode_selector.add_item("HDR: Automatic")
	hdr_mode_selector.add_item("HDR: On")
	hdr_mode_selector.add_item("HDR: Off")
	hdr_mode_selector.item_selected.connect(_on_hdr_mode_selected)
	settings_content.add_child(hdr_mode_selector)
	hdr_status_label = Label.new()
	hdr_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_content.add_child(hdr_status_label)
	hdr_values_label = Label.new()
	hdr_values_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_content.add_child(hdr_values_label)
	reference_white_slider = _make_hdr_slider(0.5, 2.0, 0.05, reference_white, "Reference white")
	settings_content.add_child(reference_white_slider)
	reference_white_slider.value_changed.connect(_on_reference_white_changed)
	peak_brightness_slider = _make_hdr_slider(1.0, 20.0, 0.25, peak_brightness_limit, "Peak brightness")
	settings_content.add_child(peak_brightness_slider)
	peak_brightness_slider.value_changed.connect(_on_peak_brightness_changed)
	tone_map_selector = OptionButton.new()
	tone_map_selector.add_item("Tone map: Reinhard")
	tone_map_selector.add_item("Tone map: AgX")
	tone_map_selector.add_item("Tone map: Linear")
	tone_map_selector.item_selected.connect(_on_tone_map_selected)
	settings_content.add_child(tone_map_selector)
	highlight_slider = _make_hdr_slider(0.25, 3.0, 0.05, highlight_intensity, "Highlights")
	settings_content.add_child(highlight_slider)
	highlight_slider.value_changed.connect(_on_highlight_changed)
	gamut_slider = _make_hdr_slider(0.0, 1.5, 0.05, gamut_intensity, "Color gamut")
	settings_content.add_child(gamut_slider)
	gamut_slider.value_changed.connect(_on_gamut_changed)
	hdr_reset_button = Button.new()
	hdr_reset_button.text = "Reset HDR settings"
	hdr_reset_button.pressed.connect(_reset_hdr_settings)
	settings_content.add_child(hdr_reset_button)
	settings_back_button = Button.new()
	settings_back_button.text = "Back"
	settings_back_button.pressed.connect(_show_main_menu)
	settings_content.add_child(settings_back_button)

	game_over_content = VBoxContainer.new()
	game_over_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_content.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_content.add_theme_constant_override("separation", 14)
	game_over_content.visible = false
	views.add_child(game_over_content)
	game_over_title = Label.new()
	game_over_title.text = "RUN OVER"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.78))
	game_over_content.add_child(game_over_title)
	game_over_result = Label.new()
	game_over_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_result.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	game_over_content.add_child(game_over_result)
	retry_button = Button.new()
	retry_button.text = "Retry Survival"
	retry_button.pressed.connect(_start_survival)
	game_over_content.add_child(retry_button)
	mode_select_button = Button.new()
	mode_select_button.text = "Choose Mode"
	mode_select_button.pressed.connect(_show_main_menu)
	game_over_content.add_child(mode_select_button)


func _build_gameplay_overlay() -> void:
	gameplay_overlay = Control.new()
	gameplay_overlay.name = "GameplayOverlay"
	gameplay_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_overlay.visible = false
	hud_layer.add_child(gameplay_overlay)

	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.color = Color(1.0, 0.12, 0.18, 0.0)
	gameplay_overlay.add_child(damage_flash)

	gameplay_hud_panel = PanelContainer.new()
	gameplay_hud_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gameplay_hud_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var style := _panel_style()
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	gameplay_hud_panel.add_theme_stylebox_override("panel", style)
	gameplay_overlay.add_child(gameplay_hud_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	gameplay_hud_panel.add_child(content)
	health_label = Label.new()
	health_label.text = "HEALTH 5 / 5"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.78))
	content.add_child(health_label)
	distance_label = Label.new()
	distance_label.text = "DISTANCE 0 m"
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	distance_label.add_theme_color_override("font_color", Color(0.80, 0.94, 1.0))
	content.add_child(distance_label)
	score_label = Label.new()
	score_label.text = "SCORE 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_color_override("font_color", Color(0.68, 0.84, 0.95))
	content.add_child(score_label)


func _apply_steering_delta(delta_pixels: Vector2) -> void:
	const SENSITIVITY := 0.0035
	var basis := Basis(camera_orientation).orthonormalized()
	var horizontal_rotation := Quaternion(basis.y, -delta_pixels.x * SENSITIVITY)
	camera_orientation = (horizontal_rotation * camera_orientation).normalized()
	basis = Basis(camera_orientation).orthonormalized()
	var vertical_rotation := Quaternion(basis.x, -delta_pixels.y * SENSITIVITY)
	camera_orientation = (vertical_rotation * camera_orientation).normalized()


func _is_over_hud_control(position: Vector2) -> bool:
	if interface_state == InterfaceState.PLAYING:
		return throttle_panel.visible and throttle_panel.get_global_rect().has_point(position)
	return (
		throttle_panel.get_global_rect().has_point(position)
		or menu_panel.get_global_rect().has_point(position)
	)


func _on_speed_changed(value: float) -> void:
	speed = value
	if is_instance_valid(speed_readout):
		speed_readout.text = "%.2f×" % speed


func _on_quality_selected(index: int) -> void:
	automatic_quality = index == 0
	current_quality = 1 if automatic_quality else clamp(index - 1, 0, QUALITY_PRESETS.size() - 1)
	_apply_quality(current_quality)
	_save_settings()


func _on_reduced_motion_toggled(enabled: bool) -> void:
	_reduced_motion_setting = enabled
	shader_material.set_shader_parameter("reduced_motion", enabled)
	_save_settings()


func _on_music_toggled(enabled: bool) -> void:
	_music_enabled_setting = enabled
	if is_instance_valid(music_controller):
		music_controller.set_music_enabled(enabled)
	if enabled:
		_start_music()
	_save_settings()


func _on_music_volume_changed(value: float) -> void:
	_music_volume_setting = clampf(value / 100.0, 0.0, 1.0)
	if is_instance_valid(music_volume_label):
		music_volume_label.text = "Music volume  %d%%" % roundi(value)
	if is_instance_valid(music_controller):
		music_controller.set_volume_linear(_music_volume_setting)
	_save_settings()


func _make_hdr_slider(minimum: float, maximum: float, step: float, value: float, label_text: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.tooltip_text = label_text
	slider.accessibility_description = label_text
	return slider


func _on_hdr_mode_selected(index: int) -> void:
	hdr_mode = index
	_apply_hdr_settings()
	_save_settings()


func _on_reference_white_changed(value: float) -> void:
	reference_white = value
	_apply_hdr_settings()
	_save_settings()


func _on_peak_brightness_changed(value: float) -> void:
	peak_brightness_limit = value
	_apply_hdr_settings()
	_save_settings()


func _on_tone_map_selected(index: int) -> void:
	tone_map_mode = index
	_apply_hdr_settings()
	_save_settings()


func _on_highlight_changed(value: float) -> void:
	highlight_intensity = value
	_apply_hdr_settings()
	_save_settings()


func _on_gamut_changed(value: float) -> void:
	gamut_intensity = value
	_apply_hdr_settings()
	_save_settings()


func _on_viewport_size_changed() -> void:
	_resize_render_target()
	_update_safe_layout()


func _update_safe_layout() -> void:
	if not is_instance_valid(safe_root):
		return
	var window_size := Vector2i(get_viewport().get_visible_rect().size)
	var safe_rect := Rect2i(Vector2i.ZERO, window_size)
	if PlatformCapabilities.uses_safe_area():
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
	throttle_panel.anchor_left = 0.0
	throttle_panel.anchor_top = 0.5
	throttle_panel.anchor_right = 0.0
	throttle_panel.anchor_bottom = 0.5
	throttle_panel.offset_left = 0.0
	throttle_panel.offset_top = -throttle_height * 0.5
	throttle_panel.offset_right = throttle_width
	throttle_panel.offset_bottom = throttle_height * 0.5
	speed_slider.custom_minimum_size = Vector2(64.0 * ui_scale, 180.0 * ui_scale)

	var info_width := clampf(
		float(window_size.x) * (0.60 if portrait else 0.34),
		250.0 * ui_scale,
		410.0 * ui_scale
	)
	var menu_height := clampf(
		available_height * (0.78 if portrait else 0.86),
		390.0 * ui_scale,
		620.0 * ui_scale
	)
	menu_panel.custom_minimum_size = Vector2(info_width, menu_height)
	menu_panel.offset_left = -info_width
	menu_panel.offset_top = -menu_height * 0.5
	menu_panel.offset_right = 0.0
	menu_panel.offset_bottom = menu_height * 0.5
	var gameplay_hud_width := 190.0 * ui_scale
	var gameplay_hud_top := float(safe_rect.position.y + padding)
	var gameplay_hud_right := float(window_size.x - safe_rect.end.x + padding)
	gameplay_hud_panel.offset_left = -gameplay_hud_width - gameplay_hud_right
	gameplay_hud_panel.offset_top = gameplay_hud_top
	gameplay_hud_panel.offset_right = -gameplay_hud_right
	gameplay_hud_panel.offset_bottom = gameplay_hud_top + 112.0 * ui_scale
	var touch_height := 50.0 * ui_scale
	quality_selector.custom_minimum_size = Vector2(0.0, touch_height)
	reduced_motion_toggle.custom_minimum_size = Vector2(0.0, touch_height)
	music_toggle.custom_minimum_size = Vector2(0.0, touch_height)
	music_volume_slider.custom_minimum_size = Vector2(0.0, 32.0 * ui_scale)
	for control in [hdr_mode_selector, tone_map_selector, hdr_reset_button]:
		control.custom_minimum_size = Vector2(0.0, touch_height)
	for button in [
		play_button,
		survival_button,
		settings_button,
		exit_button,
		settings_back_button,
		retry_button,
		mode_select_button,
	]:
		button.custom_minimum_size = Vector2(0.0, touch_height)

	var body_font := roundi(14.0 * ui_scale)
	title_label.add_theme_font_size_override("font_size", roundi(22.0 * ui_scale))
	game_over_title.add_theme_font_size_override("font_size", roundi(22.0 * ui_scale))
	game_over_result.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	metrics_label.add_theme_font_size_override("font_size", body_font)
	status_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	quality_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	throttle_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	speed_readout.add_theme_font_size_override("font_size", roundi(18.0 * ui_scale))
	health_label.add_theme_font_size_override("font_size", roundi(16.0 * ui_scale))
	distance_label.add_theme_font_size_override("font_size", body_font)
	score_label.add_theme_font_size_override("font_size", body_font)
	quality_selector.add_theme_font_size_override("font_size", body_font)
	reduced_motion_toggle.add_theme_font_size_override("font_size", body_font)
	music_toggle.add_theme_font_size_override("font_size", body_font)
	music_volume_label.add_theme_font_size_override("font_size", body_font)
	hdr_mode_selector.add_theme_font_size_override("font_size", body_font)
	tone_map_selector.add_theme_font_size_override("font_size", body_font)
	hdr_status_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	hdr_values_label.add_theme_font_size_override("font_size", roundi(11.0 * ui_scale))
	for slider in [reference_white_slider, peak_brightness_slider, highlight_slider, gamut_slider]:
		slider.custom_minimum_size = Vector2(0.0, 28.0 * ui_scale)
		hdr_reset_button.add_theme_font_size_override("font_size", body_font)
	for button in [
		play_button,
		survival_button,
		settings_button,
		exit_button,
		settings_back_button,
		retry_button,
		mode_select_button,
	]:
		button.add_theme_font_size_override("font_size", body_font)


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
	_save_settings()


func _platform_supports_hdr_output() -> bool:
	return (
		not _is_web_platform()
		and DisplayServer.get_name() != "headless"
		and PlatformCapabilities.supports_hdr_output()
	)


func _renderer_supports_internal_hdr() -> bool:
	if _is_web_platform():
		return false
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


func _should_use_internal_hdr() -> bool:
	return hdr_mode != HDR_MODE_OFF and _renderer_supports_internal_hdr()


func _apply_hdr_settings() -> void:
	if not is_instance_valid(shader_material):
		return
	internal_hdr_active = _should_use_internal_hdr()
	get_viewport().use_hdr_2d = internal_hdr_active
	if is_instance_valid(render_viewport):
		render_viewport.use_hdr_2d = internal_hdr_active
	hdr_output_active = false
	get_window().hdr_output_requested = false
	if _platform_supports_hdr_output() and hdr_mode != HDR_MODE_OFF:
		get_window().hdr_output_requested = true
		hdr_output_active = get_window().hdr_output_requested
	output_max_linear_value = get_window().get_output_max_linear_value() if hdr_output_active else 1.0
	shader_material.set_shader_parameter("output_max_linear_value", minf(output_max_linear_value, peak_brightness_limit))
	shader_material.set_shader_parameter("reference_white", reference_white)
	shader_material.set_shader_parameter("highlight_intensity", highlight_intensity)
	shader_material.set_shader_parameter("gamut_intensity", gamut_intensity)
	shader_material.set_shader_parameter("tone_map_mode", tone_map_mode)
	_update_hdr_ui()


func _update_output_max_linear_value(value: float) -> void:
	output_max_linear_value = maxf(value, 1.0)
	if is_instance_valid(shader_material):
		shader_material.set_shader_parameter("output_max_linear_value", minf(output_max_linear_value, peak_brightness_limit))
	_update_hdr_ui()


func _on_output_max_linear_value_changed(value: float) -> void:
	_update_output_max_linear_value(value)


func _update_hdr_ui() -> void:
	if not is_instance_valid(hdr_status_label):
		return
	if _is_web_platform():
		hdr_status_label.text = "Status: Web browsers use SDR output"
		hdr_values_label.text = "Tone mapping and color controls remain available in SDR."
		return
	var status := "Unsupported"
	if hdr_output_active:
		status = "HDR output active"
	elif internal_hdr_active:
		status = "Internal HDR (SDR display output)"
	elif hdr_mode == HDR_MODE_OFF:
		status = "SDR forced"
	hdr_status_label.text = "Status: %s" % status
	hdr_values_label.text = "Peak %.1fx • White %.2fx • Highlights %.2fx • Gamut %.2fx" % [minf(output_max_linear_value, peak_brightness_limit), reference_white, highlight_intensity, gamut_intensity]


func _reset_hdr_settings() -> void:
	hdr_mode = HDR_MODE_AUTO
	tone_map_mode = TONE_MAP_REINHARD
	reference_white = 1.0
	peak_brightness_limit = 4.0
	highlight_intensity = 1.0
	gamut_intensity = 1.0
	_sync_hdr_controls()
	_apply_hdr_settings()
	_save_settings()


func _sync_hdr_controls() -> void:
	if not is_instance_valid(hdr_mode_selector):
		return
	var hdr_controls_enabled := not _is_web_platform()
	hdr_mode_selector.disabled = not hdr_controls_enabled
	reference_white_slider.editable = hdr_controls_enabled
	peak_brightness_slider.editable = hdr_controls_enabled
	hdr_reset_button.disabled = not hdr_controls_enabled
	hdr_mode_selector.select(hdr_mode)
	tone_map_selector.select(tone_map_mode)
	reference_white_slider.value = reference_white
	peak_brightness_slider.value = peak_brightness_limit
	highlight_slider.value = highlight_intensity
	gamut_slider.value = gamut_intensity
	_update_hdr_ui()


func _is_web_platform() -> bool:
	return PlatformCapabilities.is_web()


func _is_user_activation_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _start_music() -> void:
	if _music_started or not _music_enabled_setting or not is_instance_valid(music_controller):
		return
	_music_started = true
	music_controller.start(MUSIC_JOURNEY_SEED)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	hdr_mode = clampi(int(config.get_value(SETTINGS_SECTION, "hdr_mode", HDR_MODE_AUTO)), HDR_MODE_AUTO, HDR_MODE_OFF)
	current_quality = clampi(int(config.get_value(SETTINGS_SECTION, "quality", current_quality)), 0, QUALITY_PRESETS.size() - 1)
	automatic_quality = bool(config.get_value(SETTINGS_SECTION, "automatic_quality", automatic_quality))
	_reduced_motion_setting = bool(config.get_value(SETTINGS_SECTION, "reduced_motion", false))
	_music_enabled_setting = bool(config.get_value(SETTINGS_SECTION, "music_enabled", true))
	_music_volume_setting = clampf(float(config.get_value(SETTINGS_SECTION, "music_volume", 0.7)), 0.0, 1.0)
	tone_map_mode = clampi(int(config.get_value(SETTINGS_SECTION, "tone_map_mode", TONE_MAP_REINHARD)), TONE_MAP_REINHARD, TONE_MAP_LINEAR)
	reference_white = clampf(float(config.get_value(SETTINGS_SECTION, "reference_white", 1.0)), 0.5, 2.0)
	peak_brightness_limit = clampf(float(config.get_value(SETTINGS_SECTION, "peak_brightness_limit", 4.0)), 1.0, 20.0)
	highlight_intensity = clampf(float(config.get_value(SETTINGS_SECTION, "highlight_intensity", 1.0)), 0.25, 3.0)
	gamut_intensity = clampf(float(config.get_value(SETTINGS_SECTION, "gamut_intensity", 1.0)), 0.0, 1.5)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "hdr_mode", hdr_mode)
	config.set_value(SETTINGS_SECTION, "tone_map_mode", tone_map_mode)
	config.set_value(SETTINGS_SECTION, "reference_white", reference_white)
	config.set_value(SETTINGS_SECTION, "peak_brightness_limit", peak_brightness_limit)
	config.set_value(SETTINGS_SECTION, "highlight_intensity", highlight_intensity)
	config.set_value(SETTINGS_SECTION, "gamut_intensity", gamut_intensity)
	config.set_value(SETTINGS_SECTION, "quality", current_quality)
	config.set_value(SETTINGS_SECTION, "automatic_quality", automatic_quality)
	config.set_value(SETTINGS_SECTION, "reduced_motion", reduced_motion_toggle.button_pressed if is_instance_valid(reduced_motion_toggle) else false)
	config.set_value(SETTINGS_SECTION, "music_enabled", _music_enabled_setting)
	config.set_value(SETTINGS_SECTION, "music_volume", _music_volume_setting)
	config.save(SETTINGS_PATH)


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


func _start_endless() -> void:
	current_game_mode = GameMode.ENDLESS
	survival_session.stop()
	_reset_endless_flight()
	speed_slider.min_value = 0.25
	_start_playing()


func _start_survival() -> void:
	current_game_mode = GameMode.SURVIVAL
	speed_slider.min_value = 1.5
	speed = maxf(speed, speed_slider.min_value)
	speed_slider.value = speed
	survival_session.start()
	var spawn_forward: Vector3 = survival_session.get_spawn_forward().normalized()
	var spawn_up := Vector3.UP
	if absf(spawn_forward.dot(spawn_up)) > 0.999:
		spawn_up = Vector3.FORWARD
	camera_orientation = Basis.looking_at(spawn_forward, spawn_up).get_rotation_quaternion().normalized()
	camera_position = survival_session.position
	_start_playing()


func _start_playing() -> void:
	interface_state = InterfaceState.PLAYING
	settings_visible = false
	safe_root.visible = true
	throttle_panel.visible = false
	menu_panel.visible = false
	gameplay_overlay.visible = current_game_mode == GameMode.SURVIVAL
	flight_input.reset()


func _show_main_menu() -> void:
	if current_game_mode == GameMode.SURVIVAL:
		survival_session.stop()
	interface_state = InterfaceState.MENU
	settings_visible = false
	safe_root.visible = true
	throttle_panel.visible = true
	menu_panel.visible = true
	gameplay_overlay.visible = false
	main_menu_content.visible = true
	settings_scroll.visible = false
	game_over_content.visible = false
	flight_input.reset()


func _show_settings() -> void:
	settings_visible = true
	main_menu_content.visible = false
	settings_scroll.visible = true
	game_over_content.visible = false
	flight_input.reset()


func _handle_back_command() -> void:
	if interface_state == InterfaceState.PLAYING:
		_show_main_menu()
	elif settings_visible or interface_state == InterfaceState.GAME_OVER:
		_show_main_menu()


func _reset_flight() -> void:
	if current_game_mode == GameMode.SURVIVAL:
		_start_survival()
		status_label.text = "Survival run reset"
		return
	_reset_endless_flight()
	status_label.text = "Flight reset"


func _reset_endless_flight() -> void:
	camera_position = Vector3(0.0, 0.0, 2.0)
	camera_orientation = Quaternion.IDENTITY
	speed = 2.5
	if is_instance_valid(speed_slider):
		speed_slider.value = speed


func _update_music_context() -> void:
	if not is_instance_valid(music_controller):
		return
	var region_coordinate := (camera_position.z + MUSIC_REGION_SIZE) / MUSIC_REGION_SIZE
	var region_id := floori(region_coordinate)
	var region_fraction := region_coordinate - floorf(region_coordinate)
	var boundary_distance := minf(region_fraction, 1.0 - region_fraction)
	var region_blend := 1.0 - smoothstep(0.0, 0.16, boundary_distance)
	var music_mode := MusicContext.Mode.MENU
	if interface_state == InterfaceState.PLAYING:
		music_mode = (
			MusicContext.Mode.SURVIVAL
			if current_game_mode == GameMode.SURVIVAL
			else MusicContext.Mode.ENDLESS
		)
	var proximity := 0.0
	if current_game_mode == GameMode.SURVIVAL and is_instance_valid(survival_session):
		var clearance: float = survival_session.world.get_world_sdf(camera_position)
		proximity = 1.0 - smoothstep(0.25, 1.5, clearance)
	var context := MusicContext.new(
		MUSIC_JOURNEY_SEED,
		region_id,
		region_blend,
		music_mode,
		inverse_lerp(0.25, 8.0, speed),
		proximity,
		region_blend,
		_reduced_motion_setting,
		interface_state == InterfaceState.GAME_OVER
	)
	music_controller.set_context(context)


func _update_survival_hud() -> void:
	if not is_instance_valid(distance_label):
		return
	var protection: float = survival_session.health.invulnerability_remaining
	if protection > 0.0:
		health_label.text = "SHIELD %.1fs  HEALTH %d / %d" % [
			protection,
			survival_session.health.current_health,
			survival_session.health.maximum_health,
		]
	else:
		health_label.text = "HEALTH %d / %d" % [
			survival_session.health.current_health,
			survival_session.health.maximum_health,
		]
	distance_label.text = "DISTANCE %d m" % floori(survival_session.distance_traveled)
	score_label.text = "SCORE %d" % survival_session.score


func _on_survival_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "HEALTH %d / %d" % [current, maximum]


func _on_survival_damaged() -> void:
	damage_flash_strength = 0.20 if _reduced_motion_setting else 0.85
	if PlatformCapabilities.supports_haptics():
		Input.vibrate_handheld(80, 0.55)


func _on_survival_game_over(distance: float, final_score: int) -> void:
	interface_state = InterfaceState.GAME_OVER
	flight_input.reset()
	safe_root.visible = true
	throttle_panel.visible = false
	menu_panel.visible = true
	gameplay_overlay.visible = false
	main_menu_content.visible = false
	settings_scroll.visible = false
	game_over_content.visible = true
	game_over_result.text = "Distance: %d m\nScore: %d" % [floori(distance), final_score]
