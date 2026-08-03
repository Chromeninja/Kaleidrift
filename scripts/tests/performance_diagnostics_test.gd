extends SceneTree

const DiagnosticsOverlayScript := preload("res://scripts/performance/performance_diagnostics_overlay.gd")
const PlatformCapabilitiesScript := preload("res://scripts/platform/platform_capabilities.gd")


func _init() -> void:
	var overlay := DiagnosticsOverlayScript.new()
	root.add_child(overlay)
	for index in range(DiagnosticsOverlayScript.SAMPLE_CAPACITY + 25):
		overlay.add_frame_sample(float(index))
	assert(overlay.get_sample_count() == DiagnosticsOverlayScript.SAMPLE_CAPACITY)
	var samples := overlay.get_samples_oldest_first()
	assert(samples.size() == DiagnosticsOverlayScript.SAMPLE_CAPACITY)
	assert(is_equal_approx(samples[0], 25.0))
	assert(is_equal_approx(samples[-1], float(DiagnosticsOverlayScript.SAMPLE_CAPACITY + 24)))
	overlay.add_frame_sample(NAN)
	assert(overlay.get_sample_count() == DiagnosticsOverlayScript.SAMPLE_CAPACITY)

	assert(PlatformCapabilitiesScript.classify_hdr_output(true, false, false, false, false, 1.0) == "Web SDR")
	assert(PlatformCapabilitiesScript.classify_hdr_output(false, true, true, false, false, 1.0) == "SDR forced")
	assert(PlatformCapabilitiesScript.classify_hdr_output(false, false, true, true, true, 1.0) == "HDR requested (unconfirmed)")
	assert(PlatformCapabilitiesScript.classify_hdr_output(false, false, true, true, true, 2.0) == "HDR output confirmed")
	assert(PlatformCapabilitiesScript.classify_hdr_output(false, false, false, false, true, 1.0) == "Internal HDR (SDR output)")
	assert(PlatformCapabilitiesScript.classify_hdr_output(false, false, false, false, false, 1.0) == "HDR output unsupported")

	print("Performance diagnostics tests passed.")
	overlay.queue_free()
	quit()
