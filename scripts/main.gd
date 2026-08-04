extends Node

const SHADER_PATH := "res://shaders/fractal_flight.gdshader"
const NATIVE_TARGET_FRAME_MS := 1000.0 / 60.0
const WEB_TARGET_FRAME_MS := 1000.0 / 30.0
const METRICS_UPDATE_SECONDS := 0.25
const HUD_UPDATE_SECONDS := 0.10
const MUSIC_CONTEXT_UPDATE_SECONDS := 0.10
const CONTROLLER_UI_UPDATE_SECONDS := 0.25
const HDR_UPDATE_SECONDS := 0.25
const SETTINGS_PATH := "user://settings.cfg"
const CONTROLLER_LOG_PATH := "user://controller_input.log"
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
const FractalLevelsScript := preload("res://scripts/fractal_levels.gd")
const AdaptiveQualityControllerScript := preload("res://scripts/performance/adaptive_quality_controller.gd")
const PerformanceDiagnosticsOverlayScript := preload("res://scripts/performance/performance_diagnostics_overlay.gd")
const PlayerFlightRigScript := preload("res://scripts/flight/player_flight_rig.gd")
const FlightControllerScript := preload("res://scripts/flight/flight_controller.gd")
const WorldStateScript := preload("res://scripts/world/world_state.gd")
const SDFQueryServiceScript := preload("res://scripts/world/sdf_query_service.gd")
const TravelerSafetyControllerScript := preload("res://scripts/flight/traveler_safety_controller.gd")
const CorridorOpeningControllerScript := preload("res://scripts/world/corridor_opening_controller.gd")
const ViewModeControllerScript := preload("res://scripts/view/view_mode_controller.gd")
const SettingsStoreScript := preload("res://scripts/settings/settings_store.gd")
const FractalRendererScript := preload("res://scripts/rendering/fractal_renderer.gd")
const TRAVELER_CATALOG_PATH := "res://resources/travelers/default_catalog.tres"
const MUSIC_JOURNEY_SEED := 0x4B414C45494E
const MUSIC_REGION_SIZE := 64.0
const QUALITY_PRESETS := [
	{"name": "Low", "base_render_scale": 0.45, "minimum_auto_scale": 0.32, "steps": 44, "detail": 3, "fractal_iterations": 4, "distance": 46.0},
	{"name": "Medium", "base_render_scale": 0.64, "minimum_auto_scale": 0.45, "steps": 64, "detail": 4, "fractal_iterations": 6, "distance": 62.0},
	{"name": "High", "base_render_scale": 1.0, "minimum_auto_scale": 0.64, "steps": 84, "detail": 5, "fractal_iterations": 8, "distance": 78.0}
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
var traveler_viewport: SubViewport
var traveler_output_rect: TextureRect
var traveler_world_root: Node3D
var traveler_camera: Camera3D
var traveler_visual: Node3D
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
var performance_diagnostics_toggle: CheckButton
var view_mode_selector: OptionButton
var traveler_selector: OptionButton
var primary_color_picker: ColorPickerButton
var accent_color_picker: ColorPickerButton
var diagnostics_overlay
var status_label: Label
var throttle_label: Label
var speed_slider: VSlider
var speed_readout: Label
var quality_label: Label
var quality_selector: OptionButton
var fractal_selector: OptionButton
var fractal_description: Label
var reduced_motion_toggle: CheckButton
var music_toggle: CheckButton
var music_volume_slider: HSlider
var music_volume_label: Label
var controller_deadzone_slider: HSlider
var controller_deadzone_label: Label
var controller_calibration_label: Label
var controller_calibrate_button: Button
var controller_reset_button: Button
var controller_diagnostics_label: Label
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
var gameplay_menu_button: Button
var gameplay_hud_panel: PanelContainer
var health_label: Label
var health_pips: Array[ColorRect] = []
var shield_label: Label
var distance_label: Label
var score_label: Label
var damage_flash: ColorRect

var camera_position := Vector3(0.0, 0.0, 2.0)
# A quaternion avoids Euler poles so unrestricted 3D flight stays continuous.
var camera_orientation := Quaternion.IDENTITY
var speed := 2.5
var elapsed := 0.0
var current_quality := 1
var manual_quality := 1
var automatic_quality := true
var quality_controller: AdaptiveQualityController
var flight_input: FlightInputAdapter
var flight_rig: PlayerFlightRig
var flight_controller: FlightController
var world_state: WorldState
var sdf_query: SDFQueryService
var safety_controller: TravelerSafetyController
var corridor_controller: CorridorOpeningController
var view_mode_controller: ViewModeController
var traveler_catalog: TravelerCatalog
var traveler_definition: TravelerDefinition
var settings_store
var fractal_renderer
var interface_state := InterfaceState.MENU
var current_game_mode := GameMode.ENDLESS
var selected_fractal_level := FractalLevelsScript.Type.FOLD
var settings_visible := false
var hdr_mode := HDR_MODE_AUTO
var tone_map_mode := TONE_MAP_AGX
var reference_white := 1.0
var peak_brightness_limit := 4.0
var highlight_intensity := 1.0
var gamut_intensity := 1.0
var hdr_output_requested := false
var internal_hdr_active := false
var output_max_linear_value := 1.0
var _performance_diagnostics_setting := false
var _reduced_motion_setting := false
var _music_enabled_setting := true
var _music_volume_setting := 0.7
var _controller_deadzone_setting := FlightInputAdapterScript.DEFAULT_DEADZONE
var _controller_outer_deadzone_setting := FlightInputAdapterScript.DEFAULT_OUTER_DEADZONE
var _controller_response_curve_setting := FlightInputAdapterScript.DEFAULT_RESPONSE_CURVE
var _music_started := false
var _last_steering_source := "none"
var _controller_diagnostics: Array[String] = []
var _last_controller_log_time_ms := 0
var survival_session
var music_controller: ProceduralMusicController
var damage_flash_strength := 0.0
var _fullscreen_sync_elapsed := 0.0
var _metrics_elapsed := 0.0
var _hud_elapsed := 0.0
var _music_context_elapsed := 0.0
var _controller_ui_elapsed := 0.0
var _hdr_update_elapsed := 0.0
var _last_shader_fractal_type := -1
var _last_shader_fractal_iterations := -1
var _last_shader_survival_mode := false
var _last_shader_world_seed := NAN
var _last_shader_obstacles: Array[Vector4] = []
var settings_save_count := 0
var _application_focused := true
var _selected_view_mode: StringName = &"immersive"
var _selected_traveler_id: StringName = &"glowing_orb"
var _traveler_primary_color := Color(0.18, 0.92, 1.0)
var _traveler_accent_color := Color(1.0, 0.22, 0.82)


func _ready() -> void:
	current_quality = PlatformCapabilities.default_quality()
	manual_quality = current_quality
	flight_input = FlightInputAdapterScript.new()
	flight_rig = PlayerFlightRigScript.new()
	flight_rig.name = "PlayerFlightRig"
	add_child(flight_rig)
	flight_controller = FlightControllerScript.new()
	world_state = WorldStateScript.new()
	world_state.journey_seed = MUSIC_JOURNEY_SEED
	world_state.variation_seed = fposmod(float(MUSIC_JOURNEY_SEED), 10000.0)
	sdf_query = SDFQueryServiceScript.new(world_state)
	safety_controller = TravelerSafetyControllerScript.new()
	corridor_controller = CorridorOpeningControllerScript.new()
	view_mode_controller = ViewModeControllerScript.new()
	settings_store = SettingsStoreScript.new(SETTINGS_PATH)
	_load_settings()
	flight_rig.reset_state(camera_position, camera_orientation, speed)
	_sync_world_state_for_physics()
	flight_rig.position = sdf_query.find_safe_position(flight_rig.position, safety_controller.collision_radius)
	flight_rig.validate_safe_transform()
	camera_position = flight_rig.position
	quality_controller = AdaptiveQualityControllerScript.new(
		QUALITY_PRESETS,
		WEB_TARGET_FRAME_MS if _is_web_platform() else NATIVE_TARGET_FRAME_MS,
		current_quality
	)
	quality_controller.reset(current_quality, automatic_quality)
	flight_input.deadzone = _controller_deadzone_setting
	flight_input.outer_deadzone = _controller_outer_deadzone_setting
	flight_input.response_curve = _controller_response_curve_setting
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
	fractal_renderer = FractalRendererScript.new()
	fractal_renderer.bind(shader_material)
	traveler_catalog = load(TRAVELER_CATALOG_PATH) as TravelerCatalog
	_select_traveler(_selected_traveler_id)
	view_mode_controller.set_view_mode(_selected_view_mode, flight_rig)
	_build_hud()
	if is_instance_valid(quality_selector):
		quality_selector.select(0 if automatic_quality else manual_quality + 1)
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
	if is_instance_valid(controller_deadzone_slider):
		controller_deadzone_slider.value = _controller_deadzone_setting
	if is_instance_valid(performance_diagnostics_toggle):
		performance_diagnostics_toggle.button_pressed = _performance_diagnostics_setting
	_sync_view_controls()
	_sync_diagnostics_visibility()
	_update_controller_ui()
	if is_instance_valid(fractal_selector):
		fractal_selector.select(selected_fractal_level)
		fractal_description.text = FractalLevelsScript.description(selected_fractal_level)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	get_window().output_max_linear_value_changed.connect(_on_output_max_linear_value_changed)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	status_label.text = "Drag anywhere to steer • Throttle centered below"
	_sync_render_activity()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_command()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
		flight_input.reset()
		_record_controller_diagnostic("application focus out; controller reset")
		_sync_render_activity()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true
		_record_controller_diagnostic("application focus in")
		_sync_render_activity()


func _physics_process(delta: float) -> void:
	if (interface_state != InterfaceState.PLAYING and current_game_mode != GameMode.ENDLESS) or not _application_focused:
		return
	_sync_world_state_for_physics()
	flight_rig.begin_physics_step()
	var previous_transform := flight_rig.transform
	if current_game_mode == GameMode.SURVIVAL:
		survival_session.begin_external_step(delta, flight_rig.position)
	var desired_velocity := flight_controller.get_desired_velocity(flight_rig)
	var resolved_velocity := safety_controller.evaluate(flight_rig, sdf_query, desired_velocity, delta)
	corridor_controller.update(world_state, safety_controller, flight_rig, delta)
	flight_rig.integrate_velocity(resolved_velocity, delta)
	safety_controller.recover_if_embedded(flight_rig, sdf_query)
	if current_game_mode == GameMode.SURVIVAL:
		if sdf_query.segment_hits_hazard(previous_transform.origin, flight_rig.position, safety_controller.collision_radius):
			flight_rig.transform = previous_transform
			flight_rig.orientation = previous_transform.basis.get_rotation_quaternion().normalized()
			survival_session.register_external_hazard_hit(previous_transform.origin)
		else:
			survival_session.complete_external_step(previous_transform.origin, flight_rig.position, flight_rig.requested_speed)
			world_state.set_obstacles(survival_session.get_shader_obstacles())
	_sync_world_state_for_physics()
	camera_position = flight_rig.position
	camera_orientation = flight_rig.orientation


func _process(delta: float) -> void:
	_fullscreen_sync_elapsed += delta
	if _fullscreen_sync_elapsed >= 0.1:
		_fullscreen_sync_elapsed = 0.0
		_sync_gameplay_menu_visibility()
	if interface_state == InterfaceState.PLAYING:
		if _application_focused:
			var joypad_thrust := flight_input.joypad_thrust()
			if joypad_thrust >= 0.0 and is_instance_valid(speed_slider):
				var thrust_speed := lerpf(speed_slider.min_value, speed_slider.max_value, joypad_thrust)
				if not is_equal_approx(speed, thrust_speed):
					_on_speed_changed(thrust_speed)
			var joypad_look := flight_input.joypad_look(delta)
			if joypad_look != Vector2.ZERO:
				_last_steering_source = "joypad %d" % flight_input.active_joypad_id
				_record_controller_diagnostic(flight_input.last_joypad_diagnostic)
				_apply_steering_delta(joypad_look)
		var keyboard_steering := flight_input.keyboard_delta(delta)
		if keyboard_steering != Vector2.ZERO:
			_record_controller_diagnostic("keyboard steering applied")
			_last_steering_source = "keyboard"
			_apply_steering_delta(keyboard_steering)
	_controller_ui_elapsed += delta
	if settings_visible and _controller_ui_elapsed >= CONTROLLER_UI_UPDATE_SECONDS:
		_controller_ui_elapsed = 0.0
		_update_controller_ui()
	elapsed += delta
	var window_size := get_viewport().get_visible_rect().size
	var portrait := window_size.y > window_size.x
	var presentation := view_mode_controller.update(
		flight_rig,
		sdf_query,
		traveler_definition.camera_distance if traveler_definition != null else 2.8,
		traveler_definition.camera_height if traveler_definition != null else 0.72,
		traveler_definition.camera_look_ahead if traveler_definition != null else 1.0,
		portrait,
		_reduced_motion_setting,
		delta
	)
	camera_position = presentation.origin
	camera_orientation = presentation.basis.get_rotation_quaternion().normalized()
	var basis := presentation.basis.orthonormalized()
	var forward := -basis.z.normalized()
	var right := basis.x.normalized()
	var up := basis.y.normalized()
	fractal_renderer.set_camera_transform(presentation)
	shader_material.set_shader_parameter("elapsed_time", elapsed)
	var active_fractal_type := world_state.fractal_type
	var active_fractal_iterations := WorldState.GEOMETRY_ITERATIONS
	var active_world_seed: float = world_state.variation_seed
	if active_fractal_type != _last_shader_fractal_type:
		shader_material.set_shader_parameter("fractal_type", active_fractal_type)
		_last_shader_fractal_type = active_fractal_type
	if active_fractal_iterations != _last_shader_fractal_iterations:
		shader_material.set_shader_parameter("fractal_iterations", active_fractal_iterations)
		_last_shader_fractal_iterations = active_fractal_iterations
	if is_nan(_last_shader_world_seed) or not is_equal_approx(active_world_seed, _last_shader_world_seed):
		shader_material.set_shader_parameter("world_variation_seed", active_world_seed)
		_last_shader_world_seed = active_world_seed
	if current_game_mode == GameMode.SURVIVAL and is_instance_valid(survival_session):
		survival_session.set_fractal_level(active_fractal_type)
		survival_session.set_fractal_iterations(active_fractal_iterations)
	var survival_mode := current_game_mode == GameMode.SURVIVAL
	if survival_mode != _last_shader_survival_mode:
		shader_material.set_shader_parameter("survival_mode", survival_mode)
		_last_shader_survival_mode = survival_mode
	if current_game_mode == GameMode.SURVIVAL:
		var shader_obstacles: Array[Vector4] = survival_session.get_shader_obstacles()
		if shader_obstacles != _last_shader_obstacles:
			shader_material.set_shader_parameter("survival_obstacles", shader_obstacles)
			_last_shader_obstacles = shader_obstacles.duplicate()
	_sync_corridor_shader_parameters()
	_sync_traveler_presentation(presentation)
	_hud_elapsed += delta
	if current_game_mode == GameMode.SURVIVAL and _hud_elapsed >= HUD_UPDATE_SECONDS:
		_hud_elapsed = 0.0
		_update_survival_hud()
	_music_context_elapsed += delta
	if _music_context_elapsed >= MUSIC_CONTEXT_UPDATE_SECONDS:
		_music_context_elapsed = 0.0
		_update_music_context()
	damage_flash_strength = maxf(damage_flash_strength - delta * 2.8, 0.0)
	if is_instance_valid(damage_flash):
		damage_flash.color = Color(1.0, 0.12, 0.18, damage_flash_strength * 0.42)
	_hdr_update_elapsed += delta
	if hdr_output_requested and _hdr_update_elapsed >= HDR_UPDATE_SECONDS:
		_hdr_update_elapsed = 0.0
		_update_output_max_linear_value(get_window().get_output_max_linear_value())

	var frame_ms := delta * 1000.0
	if is_instance_valid(diagnostics_overlay) and interface_state == InterfaceState.PLAYING:
		diagnostics_overlay.add_frame_sample(frame_ms)
	if interface_state == InterfaceState.PLAYING and _application_focused and quality_controller.sample(delta, frame_ms):
		_apply_resolved_quality()
	_metrics_elapsed += delta
	if _metrics_elapsed >= METRICS_UPDATE_SECONDS:
		_metrics_elapsed = 0.0
		_update_metrics(frame_ms)


func _input(event: InputEvent) -> void:
	if _is_user_activation_event(event):
		_start_music()
	if event is InputEventJoypadButton and event.pressed and interface_state != InterfaceState.PLAYING:
		if event.button_index == JOY_BUTTON_A:
			_start_endless()
			get_viewport().set_input_as_handled()
			return
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
	if event.is_action_pressed("toggle_view") and interface_state == InterfaceState.PLAYING:
		view_mode_controller.toggle(flight_rig)
		_selected_view_mode = view_mode_controller.view_mode
		_sync_view_controls()
		_save_settings()
		get_viewport().set_input_as_handled()
		return
	# Pointer/touch steering is valid only after a mode has entered active flight.
	# Ignoring events in menus also prevents a play-button transition from leaving
	# a stale drag stream attached to the camera.
	if interface_state == InterfaceState.PLAYING:
		if event is InputEventJoypadMotion:
			return
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_show_main_menu()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == JOY_BUTTON_Y:
				_reset_flight()
				get_viewport().set_input_as_handled()
				return
		var steering_delta := flight_input.consume(event, _is_over_hud_control)
		if steering_delta != Vector2.ZERO:
			_last_steering_source = "pointer"
			_record_controller_diagnostic("pointer steering applied")
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

	traveler_viewport = SubViewport.new()
	traveler_viewport.name = "TravelerViewport"
	traveler_viewport.transparent_bg = true
	traveler_viewport.own_world_3d = true
	traveler_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	traveler_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(traveler_viewport)
	traveler_world_root = Node3D.new()
	traveler_world_root.name = "TravelerWorld"
	traveler_viewport.add_child(traveler_world_root)
	traveler_camera = Camera3D.new()
	traveler_camera.name = "TravelerCamera"
	traveler_camera.fov = 82.0
	traveler_camera.near = 0.03
	traveler_camera.far = 50.0
	traveler_world_root.add_child(traveler_camera)
	traveler_camera.current = true
	traveler_output_rect = TextureRect.new()
	traveler_output_rect.name = "TravelerDisplay"
	traveler_output_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	traveler_output_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	traveler_output_rect.stretch_mode = TextureRect.STRETCH_SCALE
	traveler_output_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	traveler_output_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	traveler_output_rect.texture = traveler_viewport.get_texture()
	traveler_output_rect.visible = false
	add_child(traveler_output_rect)


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


func _mode_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_mode_button_theme(button: Button, background: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _mode_button_style(background, border))
	button.add_theme_stylebox_override("hover", _mode_button_style(background.lightened(0.12), border.lightened(0.15)))
	button.add_theme_stylebox_override("pressed", _mode_button_style(background.darkened(0.12), border))
	button.add_theme_stylebox_override("focus", _mode_button_style(background, Color.WHITE))
	button.add_theme_color_override("font_color", Color(0.97, 0.99, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


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
	var fractal_title := Label.new()
	fractal_title.text = "FLIGHT WORLD"
	fractal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fractal_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	main_menu_content.add_child(fractal_title)
	fractal_selector = OptionButton.new()
	for level in range(FractalLevelsScript.Type.MIXED + 1):
		fractal_selector.add_item(FractalLevelsScript.display_name(level), level)
	fractal_selector.item_selected.connect(_on_fractal_selected)
	main_menu_content.add_child(fractal_selector)
	fractal_description = Label.new()
	fractal_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fractal_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fractal_description.add_theme_color_override("font_color", Color(0.68, 0.84, 0.95))
	main_menu_content.add_child(fractal_description)
	var endless_description := Label.new()
	endless_description.text = "ENDLESS\nRelax, explore, and pass through the shifting world."
	endless_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endless_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	endless_description.add_theme_color_override("font_color", Color(0.68, 0.84, 0.95))
	main_menu_content.add_child(endless_description)
	play_button = Button.new()
	play_button.text = "∞  Fly Endless"
	play_button.tooltip_text = "Endless mode: relaxed, collision-free exploration"
	_apply_mode_button_theme(play_button, Color(0.025, 0.34, 0.40), Color(0.22, 0.92, 0.90))
	play_button.pressed.connect(_start_endless)
	main_menu_content.add_child(play_button)
	var survival_description := Label.new()
	survival_description.text = "SURVIVAL\nExplore freely, dodge hazards, and protect your health."
	survival_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survival_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survival_description.add_theme_color_override("font_color", Color(0.94, 0.74, 0.82))
	main_menu_content.add_child(survival_description)
	survival_button = Button.new()
	survival_button.text = "◇  Start Survival"
	survival_button.tooltip_text = "Survival mode: avoid hazards and protect your health"
	_apply_mode_button_theme(survival_button, Color(0.48, 0.16, 0.08), Color(1.0, 0.68, 0.20))
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
	performance_diagnostics_toggle = CheckButton.new()
	performance_diagnostics_toggle.text = "Performance diagnostics"
	performance_diagnostics_toggle.tooltip_text = "Always show FPS, frame graph, rendering, HDR, and engine metrics during gameplay"
	performance_diagnostics_toggle.toggled.connect(_on_performance_diagnostics_toggled)
	settings_content.add_child(performance_diagnostics_toggle)
	var traveler_divider := HSeparator.new()
	settings_content.add_child(traveler_divider)
	var traveler_title := Label.new()
	traveler_title.text = "VIEW / TRAVELER"
	traveler_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	traveler_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	settings_content.add_child(traveler_title)
	view_mode_selector = OptionButton.new()
	view_mode_selector.add_item("Immersive view")
	view_mode_selector.set_item_metadata(0, "immersive")
	view_mode_selector.add_item("Traveler view")
	view_mode_selector.set_item_metadata(1, "traveler")
	view_mode_selector.item_selected.connect(_on_view_mode_selected)
	settings_content.add_child(view_mode_selector)
	traveler_selector = OptionButton.new()
	if traveler_catalog != null:
		for definition in traveler_catalog.travelers:
			if definition != null:
				traveler_selector.add_item(definition.display_name)
				traveler_selector.set_item_metadata(traveler_selector.item_count - 1, String(definition.identifier))
	traveler_selector.item_selected.connect(_on_traveler_selected)
	settings_content.add_child(traveler_selector)
	primary_color_picker = ColorPickerButton.new()
	primary_color_picker.text = "Primary color"
	primary_color_picker.color = _traveler_primary_color
	primary_color_picker.color_changed.connect(_on_traveler_primary_color_changed)
	settings_content.add_child(primary_color_picker)
	accent_color_picker = ColorPickerButton.new()
	accent_color_picker.text = "Accent color"
	accent_color_picker.color = _traveler_accent_color
	accent_color_picker.color_changed.connect(_on_traveler_accent_color_changed)
	settings_content.add_child(accent_color_picker)
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
	var controller_divider := HSeparator.new()
	settings_content.add_child(controller_divider)
	var controller_title := Label.new()
	controller_title.text = "CONTROLLER INPUT"
	controller_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_title.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	settings_content.add_child(controller_title)
	controller_deadzone_label = Label.new()
	controller_deadzone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_content.add_child(controller_deadzone_label)
	controller_deadzone_slider = HSlider.new()
	controller_deadzone_slider.min_value = 0.05
	controller_deadzone_slider.max_value = 0.60
	controller_deadzone_slider.step = 0.01
	controller_deadzone_slider.value = _controller_deadzone_setting
	controller_deadzone_slider.value_changed.connect(_on_controller_deadzone_changed)
	settings_content.add_child(controller_deadzone_slider)
	controller_calibration_label = Label.new()
	controller_calibration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_calibration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_content.add_child(controller_calibration_label)
	controller_calibrate_button = Button.new()
	controller_calibrate_button.text = "Calibrate neutral stick"
	controller_calibrate_button.pressed.connect(_calibrate_controller)
	settings_content.add_child(controller_calibrate_button)
	controller_reset_button = Button.new()
	controller_reset_button.text = "Reset controller settings"
	controller_reset_button.pressed.connect(_reset_controller_settings)
	settings_content.add_child(controller_reset_button)
	controller_diagnostics_label = Label.new()
	controller_diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controller_diagnostics_label.add_theme_color_override("font_color", Color(0.67, 0.83, 0.94))
	settings_content.add_child(controller_diagnostics_label)
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
	gameplay_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	gameplay_overlay.visible = false
	hud_layer.add_child(gameplay_overlay)

	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.color = Color(1.0, 0.12, 0.18, 0.0)
	gameplay_overlay.add_child(damage_flash)

	gameplay_menu_button = Button.new()
	gameplay_menu_button.name = "GameplayMenuButton"
	gameplay_menu_button.text = "☰  Menu"
	gameplay_menu_button.tooltip_text = "Return to the main menu"
	gameplay_menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	gameplay_menu_button.pressed.connect(_show_main_menu)
	gameplay_overlay.add_child(gameplay_menu_button)
	gameplay_menu_button.visible = PlatformCapabilities.should_show_inflight_menu()
	diagnostics_overlay = PerformanceDiagnosticsOverlayScript.new()
	diagnostics_overlay.name = "PerformanceDiagnostics"
	diagnostics_overlay.visible = false
	gameplay_overlay.add_child(diagnostics_overlay)

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
	var health_pips_container := HBoxContainer.new()
	health_pips_container.alignment = BoxContainer.ALIGNMENT_END
	health_pips_container.add_theme_constant_override("separation", 5)
	content.add_child(health_pips_container)
	for _pip_index in range(5):
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(18.0, 10.0)
		pip.color = Color(0.18, 0.24, 0.30)
		health_pips_container.add_child(pip)
		health_pips.append(pip)
	shield_label = Label.new()
	shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shield_label.add_theme_color_override("font_color", Color(0.48, 0.90, 1.0))
	shield_label.visible = false
	content.add_child(shield_label)
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
	flight_controller.apply_steering_delta(flight_rig, delta_pixels)
	camera_orientation = flight_rig.orientation


func _is_over_hud_control(position: Vector2) -> bool:
	if interface_state == InterfaceState.PLAYING:
		return (
			(throttle_panel.visible and throttle_panel.get_global_rect().has_point(position))
			or (is_instance_valid(gameplay_menu_button) and gameplay_menu_button.get_global_rect().has_point(position))
			or (gameplay_hud_panel.visible and gameplay_hud_panel.get_global_rect().has_point(position))
		)
	return (
		throttle_panel.get_global_rect().has_point(position)
		or menu_panel.get_global_rect().has_point(position)
	)


func _on_speed_changed(value: float) -> void:
	speed = value
	flight_controller.set_speed(flight_rig, value)
	if is_instance_valid(speed_readout):
		speed_readout.text = "%.2f×" % speed


func _on_quality_selected(index: int) -> void:
	automatic_quality = index == 0
	if automatic_quality:
		current_quality = PlatformCapabilities.default_quality()
		quality_controller.reset(current_quality, true)
	else:
		manual_quality = clampi(index - 1, 0, QUALITY_PRESETS.size() - 1)
		current_quality = manual_quality
		quality_controller.reset(current_quality, false)
	_apply_resolved_quality()
	_save_settings()

func _on_fractal_selected(index: int) -> void:
	selected_fractal_level = clampi(index, FractalLevelsScript.Type.FOLD, FractalLevelsScript.Type.MIXED)
	if is_instance_valid(fractal_description):
		fractal_description.text = FractalLevelsScript.description(selected_fractal_level)
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


func _on_controller_deadzone_changed(value: float) -> void:
	_controller_deadzone_setting = clampf(value, 0.05, 0.60)
	flight_input.deadzone = _controller_deadzone_setting
	_update_controller_ui()
	_save_settings()


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected:
		flight_input.reset_joypad(device_id)
	_update_controller_ui()


func _calibrate_controller() -> void:
	if not flight_input.calibrate_active_joypad():
		controller_calibration_label.text = "Move a stick, release it, then press calibrate again."
		return
	controller_calibration_label.text = "Neutral calibrated for controller %d" % flight_input.active_joypad_id
	_save_settings()


func _reset_controller_settings() -> void:
	_controller_deadzone_setting = FlightInputAdapterScript.DEFAULT_DEADZONE
	_controller_outer_deadzone_setting = FlightInputAdapterScript.DEFAULT_OUTER_DEADZONE
	_controller_response_curve_setting = FlightInputAdapterScript.DEFAULT_RESPONSE_CURVE
	flight_input.reset_defaults()
	flight_input.deadzone = _controller_deadzone_setting
	flight_input.outer_deadzone = _controller_outer_deadzone_setting
	flight_input.response_curve = _controller_response_curve_setting
	controller_deadzone_slider.value = _controller_deadzone_setting
	_update_controller_ui()
	_save_settings()


func _update_controller_ui() -> void:
	if not is_instance_valid(controller_deadzone_label) or not is_instance_valid(controller_calibration_label):
		return
	controller_deadzone_label.text = "Stick deadzone  %d%%" % roundi(_controller_deadzone_setting * 100.0)
	if flight_input.active_joypad_id >= 0:
		controller_calibration_label.text = "Controller %d ready • release sticks before calibration" % flight_input.active_joypad_id
	else:
		controller_calibration_label.text = "Move the preferred stick firmly to select it for this flight"
	if is_instance_valid(controller_diagnostics_label):
		var device_lines: Array[String] = []
		for device_id in Input.get_connected_joypads():
			var axes: Vector2 = flight_input.joypad_axis_values.get(str(device_id), Vector2.ZERO)
			device_lines.append("%d %s  X %.3f  Y %.3f" % [device_id, Input.get_joy_name(device_id), axes.x, axes.y])
		var device_summary := "No controllers connected" if device_lines.is_empty() else "\n".join(device_lines)
		controller_diagnostics_label.text = "Diagnostics\nActive: %s • Last source: %s\nRaw/filtered: %s / %s\nDeadzone: %.2f\n%s\nLog: %s" % [str(flight_input.active_joypad_id), _last_steering_source, str(flight_input.joypad_axis_values.get(str(flight_input.active_joypad_id), Vector2.ZERO)), str(flight_input.last_analog_input), _controller_deadzone_setting, device_summary, CONTROLLER_LOG_PATH]


func _record_controller_diagnostic(message: String) -> void:
	if message.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_controller_log_time_ms < 100 and "claimed" not in message:
		return
	_last_controller_log_time_ms = now
	var entry := "%d %s" % [now, message]
	_controller_diagnostics.append(entry)
	if _controller_diagnostics.size() > 80:
		_controller_diagnostics.pop_front()
	var log_file := FileAccess.open(CONTROLLER_LOG_PATH, FileAccess.WRITE_READ)
	if log_file != null:
		log_file.seek_end()
		log_file.store_string(entry + "\n")


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


func _on_performance_diagnostics_toggled(enabled: bool) -> void:
	_performance_diagnostics_setting = enabled
	_sync_diagnostics_visibility()
	_save_settings()


func _on_view_mode_selected(index: int) -> void:
	var value := StringName(str(view_mode_selector.get_item_metadata(index)))
	view_mode_controller.set_view_mode(value, flight_rig)
	_selected_view_mode = view_mode_controller.view_mode
	_save_settings()


func _on_traveler_selected(index: int) -> void:
	_select_traveler(StringName(str(traveler_selector.get_item_metadata(index))))
	_save_settings()


func _on_traveler_primary_color_changed(value: Color) -> void:
	_traveler_primary_color = value
	_configure_traveler_visual()
	_save_settings()


func _on_traveler_accent_color_changed(value: Color) -> void:
	_traveler_accent_color = value
	_configure_traveler_visual()
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
	gameplay_menu_button.custom_minimum_size = Vector2(112.0 * ui_scale, touch_height)
	gameplay_menu_button.offset_left = float(safe_rect.position.x + padding)
	gameplay_menu_button.offset_top = float(safe_rect.position.y + padding)
	gameplay_menu_button.offset_right = gameplay_menu_button.offset_left + gameplay_menu_button.custom_minimum_size.x
	gameplay_menu_button.offset_bottom = gameplay_menu_button.offset_top + touch_height
	var diagnostics_width := minf(float(safe_rect.size.x - padding * 2), (300.0 if portrait else 410.0) * ui_scale)
	var diagnostics_height := (300.0 if portrait else 270.0) * ui_scale
	diagnostics_overlay.offset_left = float(safe_rect.position.x + padding)
	diagnostics_overlay.offset_top = float(safe_rect.end.y - padding) - diagnostics_height
	diagnostics_overlay.offset_right = diagnostics_overlay.offset_left + diagnostics_width
	diagnostics_overlay.offset_bottom = float(safe_rect.end.y - padding)
	diagnostics_overlay.set_ui_scale(ui_scale, portrait)
	quality_selector.custom_minimum_size = Vector2(0.0, touch_height)
	reduced_motion_toggle.custom_minimum_size = Vector2(0.0, touch_height)
	performance_diagnostics_toggle.custom_minimum_size = Vector2(0.0, touch_height)
	for traveler_control in [view_mode_selector, traveler_selector, primary_color_picker, accent_color_picker]:
		traveler_control.custom_minimum_size = Vector2(0.0, touch_height)
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
	shield_label.add_theme_font_size_override("font_size", roundi(12.0 * ui_scale))
	distance_label.add_theme_font_size_override("font_size", body_font)
	score_label.add_theme_font_size_override("font_size", body_font)
	quality_selector.add_theme_font_size_override("font_size", body_font)
	reduced_motion_toggle.add_theme_font_size_override("font_size", body_font)
	performance_diagnostics_toggle.add_theme_font_size_override("font_size", body_font)
	for traveler_control in [view_mode_selector, traveler_selector, primary_color_picker, accent_color_picker]:
		traveler_control.add_theme_font_size_override("font_size", body_font)
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
		gameplay_menu_button,
	]:
		button.add_theme_font_size_override("font_size", body_font)


func _resize_render_target() -> void:
	if not is_instance_valid(render_viewport):
		return
	var window_size := get_viewport().get_visible_rect().size
	var scale := (
		quality_controller.resolved_scale
		if is_instance_valid(quality_controller)
		else float(QUALITY_PRESETS[current_quality]["base_render_scale"])
	)
	var target := Vector2i(maxi(1, roundi(window_size.x * scale)), maxi(1, roundi(window_size.y * scale)))
	render_viewport.size = target
	if is_instance_valid(traveler_viewport):
		traveler_viewport.size = target
	render_rect.size = Vector2(target)
	shader_material.set_shader_parameter("viewport_size", Vector2(target))


func _apply_quality(index: int) -> void:
	current_quality = clamp(index, 0, QUALITY_PRESETS.size() - 1)
	if is_instance_valid(quality_controller):
		quality_controller.resolved_tier = current_quality
	var preset: Dictionary = QUALITY_PRESETS[current_quality]
	shader_material.set_shader_parameter("max_steps", int(preset["steps"]))
	shader_material.set_shader_parameter("detail_iterations", int(preset["detail"]))
	shader_material.set_shader_parameter("max_distance", float(preset["distance"]))
	_resize_render_target()
	if is_instance_valid(status_label):
		status_label.text = "Quality: %s" % str(preset["name"])


func _apply_resolved_quality() -> void:
	_apply_quality(quality_controller.resolved_tier)


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
	hdr_output_requested = false
	get_window().hdr_output_requested = false
	if _platform_supports_hdr_output() and hdr_mode != HDR_MODE_OFF:
		get_window().hdr_output_requested = true
		hdr_output_requested = get_window().hdr_output_requested
	output_max_linear_value = get_window().get_output_max_linear_value() if hdr_output_requested else 1.0
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
		hdr_status_label.text = "Status: SDR output (Godot WebGL 2 renderer)"
		hdr_values_label.text = "WebGL output is SDR even when the display supports HDR. The SDR-safe color grade remains active."
		return
	var status := _get_hdr_status()
	hdr_status_label.text = "Status: %s" % status
	hdr_values_label.text = "Reported %.1fx • Effective %.1fx • White %.2fx • Highlights %.2fx • Gamut %.2fx" % [output_max_linear_value, _get_effective_headroom(), reference_white, highlight_intensity, gamut_intensity]


func _get_hdr_status() -> String:
	return PlatformCapabilities.classify_hdr_output(
		_is_web_platform(),
		hdr_mode == HDR_MODE_OFF,
		_platform_supports_hdr_output(),
		hdr_output_requested,
		internal_hdr_active,
		output_max_linear_value
	)


func _get_effective_headroom() -> float:
	return minf(maxf(output_max_linear_value, 1.0), peak_brightness_limit)


func _reset_hdr_settings() -> void:
	hdr_mode = HDR_MODE_AUTO
	tone_map_mode = TONE_MAP_AGX
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
	var config: ConfigFile = settings_store.load_config()
	if not config.has_section(SETTINGS_SECTION):
		return
	hdr_mode = clampi(int(config.get_value(SETTINGS_SECTION, "hdr_mode", HDR_MODE_AUTO)), HDR_MODE_AUTO, HDR_MODE_OFF)
	var saved_quality := AdaptiveQualityControllerScript.resolve_saved_quality(
		config.get_value(SETTINGS_SECTION, "quality", manual_quality),
		config.get_value(SETTINGS_SECTION, "automatic_quality", automatic_quality),
		PlatformCapabilities.default_quality(),
		QUALITY_PRESETS.size()
	)
	manual_quality = int(saved_quality["manual_tier"])
	selected_fractal_level = clampi(int(config.get_value(SETTINGS_SECTION, "fractal_level", FractalLevelsScript.Type.FOLD)), FractalLevelsScript.Type.FOLD, FractalLevelsScript.Type.MIXED)
	automatic_quality = bool(saved_quality["automatic"])
	current_quality = int(saved_quality["resolved_tier"])
	_reduced_motion_setting = bool(config.get_value(SETTINGS_SECTION, "reduced_motion", false))
	_music_enabled_setting = bool(config.get_value(SETTINGS_SECTION, "music_enabled", true))
	_music_volume_setting = clampf(float(config.get_value(SETTINGS_SECTION, "music_volume", 0.7)), 0.0, 1.0)
	tone_map_mode = clampi(int(config.get_value(SETTINGS_SECTION, "tone_map_mode", TONE_MAP_AGX)), TONE_MAP_REINHARD, TONE_MAP_LINEAR)
	reference_white = clampf(float(config.get_value(SETTINGS_SECTION, "reference_white", 1.0)), 0.5, 2.0)
	peak_brightness_limit = clampf(float(config.get_value(SETTINGS_SECTION, "peak_brightness_limit", 4.0)), 1.0, 20.0)
	highlight_intensity = clampf(float(config.get_value(SETTINGS_SECTION, "highlight_intensity", 1.0)), 0.25, 3.0)
	gamut_intensity = clampf(float(config.get_value(SETTINGS_SECTION, "gamut_intensity", 1.0)), 0.0, 1.5)
	_performance_diagnostics_setting = bool(config.get_value(SETTINGS_SECTION, "performance_diagnostics", false))
	_controller_deadzone_setting = clampf(float(config.get_value(SETTINGS_SECTION, "controller_deadzone", FlightInputAdapterScript.DEFAULT_DEADZONE)), 0.05, 0.60)
	_controller_outer_deadzone_setting = clampf(float(config.get_value(SETTINGS_SECTION, "controller_outer_deadzone", FlightInputAdapterScript.DEFAULT_OUTER_DEADZONE)), 0.0, 0.25)
	_controller_response_curve_setting = clampf(float(config.get_value(SETTINGS_SECTION, "controller_response_curve", FlightInputAdapterScript.DEFAULT_RESPONSE_CURVE)), 0.5, 2.0)
	_selected_view_mode = StringName(str(config.get_value(SETTINGS_SECTION, "view_mode", "immersive")))
	if _selected_view_mode != &"traveler":
		_selected_view_mode = &"immersive"
	_selected_traveler_id = StringName(str(config.get_value(SETTINGS_SECTION, "traveler_id", "glowing_orb")))
	var saved_primary = config.get_value(SETTINGS_SECTION, "traveler_primary_color", _traveler_primary_color)
	if saved_primary is Color:
		_traveler_primary_color = saved_primary
	var saved_accent = config.get_value(SETTINGS_SECTION, "traveler_accent_color", _traveler_accent_color)
	if saved_accent is Color:
		_traveler_accent_color = saved_accent
	var saved_calibration = config.get_value(SETTINGS_SECTION, "controller_calibration", {})
	if saved_calibration is Dictionary:
		flight_input.calibration_offsets = saved_calibration


func _save_settings() -> void:
	settings_save_count += 1
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "hdr_mode", hdr_mode)
	config.set_value(SETTINGS_SECTION, "tone_map_mode", tone_map_mode)
	config.set_value(SETTINGS_SECTION, "reference_white", reference_white)
	config.set_value(SETTINGS_SECTION, "peak_brightness_limit", peak_brightness_limit)
	config.set_value(SETTINGS_SECTION, "highlight_intensity", highlight_intensity)
	config.set_value(SETTINGS_SECTION, "gamut_intensity", gamut_intensity)
	config.set_value(SETTINGS_SECTION, "performance_diagnostics", _performance_diagnostics_setting)
	config.set_value(SETTINGS_SECTION, "quality", manual_quality)
	config.set_value(SETTINGS_SECTION, "fractal_level", selected_fractal_level)
	config.set_value(SETTINGS_SECTION, "automatic_quality", automatic_quality)
	config.set_value(SETTINGS_SECTION, "reduced_motion", reduced_motion_toggle.button_pressed if is_instance_valid(reduced_motion_toggle) else false)
	config.set_value(SETTINGS_SECTION, "music_enabled", _music_enabled_setting)
	config.set_value(SETTINGS_SECTION, "music_volume", _music_volume_setting)
	config.set_value(SETTINGS_SECTION, "controller_deadzone", _controller_deadzone_setting)
	config.set_value(SETTINGS_SECTION, "controller_outer_deadzone", _controller_outer_deadzone_setting)
	config.set_value(SETTINGS_SECTION, "controller_response_curve", _controller_response_curve_setting)
	config.set_value(SETTINGS_SECTION, "controller_calibration", flight_input.calibration_offsets if is_instance_valid(flight_input) else {})
	config.set_value(SETTINGS_SECTION, "settings_schema_version", 2)
	config.set_value(SETTINGS_SECTION, "view_mode", String(_selected_view_mode))
	config.set_value(SETTINGS_SECTION, "traveler_id", String(_selected_traveler_id))
	config.set_value(SETTINGS_SECTION, "traveler_primary_color", _traveler_primary_color)
	config.set_value(SETTINGS_SECTION, "traveler_accent_color", _traveler_accent_color)
	settings_store.save_config(config)


func _update_metrics(latest_frame_ms: float) -> void:
	var preset: Dictionary = QUALITY_PRESETS[current_quality]
	var target_state := "PASS" if quality_controller.get_percentile(0.95) <= quality_controller.target_frame_ms else "OVER"
	var metrics_text := "%d FPS • %.1f ms latest • %s\np90 %.1f • p95 %.1f • %s%s\n%d×%d • %.2f scale • %d steps • %s" % [
		Engine.get_frames_per_second(), latest_frame_ms, target_state,
		quality_controller.get_percentile(0.90), quality_controller.get_percentile(0.95),
		str(preset["name"]), " AUTO" if automatic_quality else " MANUAL",
		render_viewport.size.x, render_viewport.size.y, quality_controller.resolved_scale,
		int(preset["steps"]), FractalLevelsScript.display_name(_last_shader_fractal_type)
	]
	metrics_label.text = metrics_text
	if is_instance_valid(diagnostics_overlay):
		var static_memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
		diagnostics_overlay.set_details(
			"%d FPS  %.1f ms  p90 %.1f  p95 %.1f  %s\n%s %s  %.2fx  %dx%d  %d steps  %s\n%s  %.1fx/%.1fx  %s / %s\nDraw %d  primitives %d  memory %.1f MB  nodes %d  resources %d\nView %s  Traveler %s  radius %.2f\nClear %.3f / %.3f  predicted %.3f  look %.2f  probes %d\nCorridor risk %.2f  strength %.2f  radius %.2f\nSafety %s  avoidance %s  recovery %s  safe age %.1fs\nCamera desired %.2f  actual %.2f  obstruction %.3f  collision %dus" % [
				Engine.get_frames_per_second(), latest_frame_ms,
				quality_controller.get_percentile(0.90), quality_controller.get_percentile(0.95), target_state,
				str(preset["name"]), "AUTO" if automatic_quality else "MANUAL",
				quality_controller.resolved_scale, render_viewport.size.x, render_viewport.size.y,
				int(preset["steps"]), FractalLevelsScript.display_name(_last_shader_fractal_type),
				_get_hdr_status(), output_max_linear_value, _get_effective_headroom(), OS.get_name(), RenderingServer.get_current_rendering_method(),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), static_memory_mb,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
				String(view_mode_controller.view_mode), String(_selected_traveler_id), safety_controller.collision_radius,
				safety_controller.current_clearance, safety_controller.combined_clearance,
				safety_controller.minimum_predicted_clearance, safety_controller.lookahead_distance, safety_controller.probe_count,
				safety_controller.corridor_risk, world_state.corridor_strength, world_state.corridor_radius,
				safety_controller.state_name(), "on" if safety_controller.avoidance_active else "off", safety_controller.recovery_stage,
				flight_rig.last_safe_age,
				view_mode_controller.camera_controller.desired_distance, view_mode_controller.camera_controller.actual_distance,
				view_mode_controller.camera_controller.obstruction_clearance, safety_controller.collision_cpu_us
			]
		)


func _sync_diagnostics_visibility() -> void:
	if is_instance_valid(diagnostics_overlay):
		diagnostics_overlay.visible = _performance_diagnostics_setting and interface_state == InterfaceState.PLAYING


func get_performance_p90_ms() -> float:
	return quality_controller.get_percentile(0.90)


func get_performance_p95_ms() -> float:
	return quality_controller.get_percentile(0.95)


func get_resolved_render_scale() -> float:
	return quality_controller.resolved_scale


func get_resolved_quality_tier() -> int:
	return quality_controller.resolved_tier


func is_quality_transition_cooling_down() -> bool:
	return quality_controller.is_cooling_down()


func _start_endless() -> void:
	current_game_mode = GameMode.ENDLESS
	survival_session.stop()
	survival_button.text = "◇  Start Survival"
	speed_slider.min_value = 0.25
	speed = clampf(speed, speed_slider.min_value, speed_slider.max_value)
	speed_slider.value = speed
	_reset_endless_flight()
	_start_playing()


func _start_survival() -> void:
	if current_game_mode == GameMode.SURVIVAL and survival_session.active and interface_state == InterfaceState.MENU:
		_start_playing()
		return
	current_game_mode = GameMode.SURVIVAL
	speed_slider.min_value = 1.5
	speed = maxf(speed, speed_slider.min_value)
	speed_slider.value = speed
	# Mixed Drift selects a concrete fractal by the player's region. Resolve it
	# from the spawn position as well, so collision does not switch worlds on the
	# first frame and strand the player inside a wall.
	var active_level := _get_survival_fractal_level(Vector3(0.0, 0.0, 2.0))
	for _settle_attempt in range(2):
		survival_session.start(active_level, WorldState.GEOMETRY_ITERATIONS)
		var spawn_level := _get_survival_fractal_level(survival_session.position)
		if spawn_level == active_level:
			break
		active_level = spawn_level
	var spawn_forward: Vector3 = survival_session.get_spawn_forward().normalized()
	var spawn_up := Vector3.UP
	if absf(spawn_forward.dot(spawn_up)) > 0.999:
		spawn_up = Vector3.FORWARD
	camera_orientation = Basis.looking_at(spawn_forward, spawn_up).get_rotation_quaternion().normalized()
	camera_position = survival_session.position
	flight_rig.reset_state(camera_position, camera_orientation, speed)
	_sync_world_state_for_physics()
	flight_rig.position = sdf_query.find_safe_position(flight_rig.position, safety_controller.collision_radius)
	flight_rig.validate_safe_transform()
	survival_session.position = flight_rig.position
	camera_position = flight_rig.position
	survival_button.text = "◇  Resume Survival"
	_start_playing()


func _get_survival_fractal_level(position: Vector3) -> int:
	var info := FractalLevelsScript.region_info(
		selected_fractal_level,
		position.z,
		MUSIC_JOURNEY_SEED
	)
	return int(info["active"])


func _start_playing() -> void:
	interface_state = InterfaceState.PLAYING
	settings_visible = false
	safe_root.visible = true
	throttle_panel.visible = false
	menu_panel.visible = false
	gameplay_overlay.visible = true
	gameplay_hud_panel.visible = current_game_mode == GameMode.SURVIVAL
	_sync_diagnostics_visibility()
	flight_input.reset()
	_sync_render_activity()


func _show_main_menu() -> void:
	interface_state = InterfaceState.MENU
	settings_visible = false
	safe_root.visible = true
	throttle_panel.visible = true
	menu_panel.visible = true
	gameplay_overlay.visible = false
	gameplay_hud_panel.visible = false
	_sync_diagnostics_visibility()
	main_menu_content.visible = true
	settings_scroll.visible = false
	game_over_content.visible = false
	survival_button.text = "◇  Resume Survival" if current_game_mode == GameMode.SURVIVAL and survival_session.active else "◇  Start Survival"
	flight_input.reset()
	_sync_render_activity()


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
	flight_rig.reset_state(camera_position, camera_orientation, speed)
	_sync_world_state_for_physics()
	flight_rig.position = sdf_query.find_safe_position(flight_rig.position, safety_controller.collision_radius)
	flight_rig.validate_safe_transform()
	camera_position = flight_rig.position


func _update_music_context() -> void:
	if not is_instance_valid(music_controller):
		return
	var region_coordinate := (flight_rig.position.z + MUSIC_REGION_SIZE) / MUSIC_REGION_SIZE
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
		var clearance: float = sdf_query.get_structure_sdf(flight_rig.position, true)
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
	_update_health_display(
		survival_session.health.current_health,
		survival_session.health.maximum_health,
		survival_session.health.invulnerability_remaining
	)
	distance_label.text = "DISTANCE %d m" % floori(survival_session.distance_traveled)
	score_label.text = "SCORE %d" % survival_session.score


func _sync_gameplay_menu_visibility() -> void:
	if not is_instance_valid(gameplay_menu_button):
		return
	if not PlatformCapabilities.should_show_inflight_menu():
		gameplay_menu_button.visible = false
		return
	gameplay_menu_button.visible = interface_state == InterfaceState.PLAYING and not PlatformCapabilities.is_web_fullscreen()


func _sync_world_state_for_physics() -> void:
	var info := FractalLevelsScript.region_info(selected_fractal_level, flight_rig.position.z, MUSIC_JOURNEY_SEED)
	world_state.region_id = int(info["id"])
	world_state.fractal_type = int(info["active"])
	world_state.geometry_iterations = WorldState.GEOMETRY_ITERATIONS
	world_state.survival_mode = current_game_mode == GameMode.SURVIVAL
	if world_state.survival_mode:
		survival_session.set_fractal_level(world_state.fractal_type)
		survival_session.set_fractal_iterations(WorldState.GEOMETRY_ITERATIONS)
		survival_session.world.update(flight_rig.position)
		world_state.variation_seed = survival_session.world.world_variation_seed
		world_state.set_obstacles(survival_session.get_shader_obstacles())
	else:
		world_state.variation_seed = fposmod(float(MUSIC_JOURNEY_SEED), 10000.0)
		world_state.clear_obstacles()


func _sync_corridor_shader_parameters() -> void:
	fractal_renderer.set_corridor(world_state)


func _select_traveler(identifier: StringName) -> void:
	if traveler_catalog == null:
		return
	traveler_definition = traveler_catalog.find_definition(identifier)
	if traveler_definition == null:
		return
	_selected_traveler_id = traveler_definition.identifier
	safety_controller.set_collision_radius(traveler_definition.normalized_collision_radius())
	if is_instance_valid(traveler_visual):
		traveler_visual.queue_free()
	traveler_visual = traveler_definition.visual_scene.instantiate() as Node3D
	if traveler_visual == null:
		return
	traveler_visual.name = "TravelerVisual"
	traveler_world_root.add_child(traveler_visual)
	if traveler_visual.has_method("set_visual_scale"):
		traveler_visual.set_visual_scale(traveler_definition.visual_scale)
	_configure_traveler_visual()
	_sync_view_controls()


func _configure_traveler_visual() -> void:
	if is_instance_valid(traveler_visual) and traveler_visual.has_method("configure"):
		traveler_visual.configure(_traveler_primary_color, _traveler_accent_color, traveler_definition.glow_intensity)


func _sync_traveler_presentation(presentation: Transform3D) -> void:
	if not is_instance_valid(traveler_viewport):
		return
	var traveler_enabled := view_mode_controller.view_mode == ViewModeController.TRAVELER and interface_state == InterfaceState.PLAYING
	traveler_output_rect.visible = traveler_enabled
	traveler_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if traveler_enabled else SubViewport.UPDATE_DISABLED
	if not traveler_enabled:
		return
	traveler_camera.transform = presentation
	if is_instance_valid(traveler_visual):
		traveler_visual.position = flight_rig.position
		traveler_visual.quaternion = flight_rig.orientation
		if traveler_visual.has_method("set_flight_state"):
			traveler_visual.set_flight_state(flight_rig.steering_state, flight_rig.velocity.length())


func _sync_view_controls() -> void:
	if is_instance_valid(view_mode_selector):
		view_mode_selector.select(1 if _selected_view_mode == &"traveler" else 0)
	if is_instance_valid(traveler_selector):
		for index in range(traveler_selector.item_count):
			if StringName(str(traveler_selector.get_item_metadata(index))) == _selected_traveler_id:
				traveler_selector.select(index)
				break
	if is_instance_valid(primary_color_picker):
		primary_color_picker.color = _traveler_primary_color
	if is_instance_valid(accent_color_picker):
		accent_color_picker.color = _traveler_accent_color


func _sync_render_activity() -> void:
	if not is_instance_valid(render_viewport):
		return
	render_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
		if _application_focused and (interface_state == InterfaceState.PLAYING or current_game_mode == GameMode.ENDLESS)
		else SubViewport.UPDATE_ONCE
	)


func _on_survival_health_changed(current: int, maximum: int) -> void:
	_update_health_display(current, maximum, survival_session.health.invulnerability_remaining)


func _update_health_display(current: int, maximum: int, protection: float) -> void:
	if not is_instance_valid(health_label):
		return
	health_label.text = "HEALTH %d / %d" % [current, maximum]
	var ratio := float(current) / float(maxi(maximum, 1))
	var active_color := Color(0.28, 0.93, 0.62)
	if ratio <= 0.4:
		active_color = Color(1.0, 0.32, 0.30)
	elif ratio <= 0.7:
		active_color = Color(1.0, 0.74, 0.22)
	for pip_index in health_pips.size():
		health_pips[pip_index].color = active_color if pip_index < current else Color(0.18, 0.24, 0.30)
	shield_label.visible = protection > 0.0
	if protection > 0.0:
		shield_label.text = "SHIELD %.1fs" % protection


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
	_sync_diagnostics_visibility()
	_sync_render_activity()
