extends SceneTree

const AdaptiveQualityControllerScript := preload("res://scripts/performance/adaptive_quality_controller.gd")

const PRESETS := [
	{"base_render_scale": 0.45, "minimum_auto_scale": 0.32},
	{"base_render_scale": 0.64, "minimum_auto_scale": 0.45},
	{"base_render_scale": 1.00, "minimum_auto_scale": 0.64},
]


func _init() -> void:
	_test_percentiles()
	_test_warmup_and_downgrade()
	_test_upgrade_hysteresis()
	_test_manual_stability()
	_test_saved_settings_compatibility()
	print("Adaptive quality tests passed.")
	quit()


func _controller(tier := 0) -> AdaptiveQualityController:
	return AdaptiveQualityControllerScript.new(PRESETS, 1000.0 / 30.0, tier, 1.0, 2.0, 1.0, 2.0, 0.05)


func _test_percentiles() -> void:
	var controller := _controller()
	controller.samples.assign([10.0, 20.0, 30.0, 40.0, 50.0])
	assert(is_equal_approx(controller.get_percentile(0.90), 50.0))
	assert(is_equal_approx(controller.get_percentile(0.50), 30.0))


func _test_warmup_and_downgrade() -> void:
	var controller := _controller()
	for _index in range(3):
		assert(not controller.sample(0.5, 50.0))
	assert(is_equal_approx(controller.resolved_scale, 0.45))
	var changed := false
	for _index in range(4):
		changed = controller.sample(0.5, 50.0) or changed
	assert(changed)
	assert(controller.resolved_scale < 0.45)
	assert(controller.resolved_scale >= 0.32)
	assert(controller.is_cooling_down())


func _test_upgrade_hysteresis() -> void:
	var controller := _controller()
	controller.warmup_seconds = 0.0
	controller.resolved_scale = 0.32
	var changed := false
	for _index in range(6):
		changed = controller.sample(0.5, 10.0) or changed
	assert(changed)
	assert(controller.resolved_scale > 0.32)


func _test_manual_stability() -> void:
	var controller := _controller(1)
	controller.automatic = false
	for _index in range(20):
		assert(not controller.sample(0.5, 80.0))
	assert(controller.resolved_tier == 1)
	assert(is_equal_approx(controller.resolved_scale, 0.64))


func _test_saved_settings_compatibility() -> void:
	var legacy_auto := AdaptiveQualityControllerScript.resolve_saved_quality(2, true, 0, PRESETS.size())
	assert(legacy_auto["manual_tier"] == 2)
	assert(legacy_auto["resolved_tier"] == 0)
	var legacy_manual := AdaptiveQualityControllerScript.resolve_saved_quality(99, false, 0, PRESETS.size())
	assert(legacy_manual["manual_tier"] == 2)
	assert(legacy_manual["resolved_tier"] == 2)
