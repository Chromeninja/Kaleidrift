class_name PlatformCapabilities
extends RefCounted

## Centralizes runtime platform decisions. Gameplay should not query OS directly.
static func is_web() -> bool:
	return OS.has_feature("web")


static func is_mobile_web() -> bool:
	if not is_web():
		return false
	var result = JavaScriptBridge.eval(
		"Boolean((navigator.userAgentData && navigator.userAgentData.mobile) || " +
		"/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent) || " +
		"(/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1))"
	)
	return bool(result)


static func should_show_inflight_menu() -> bool:
	return is_mobile_web()


static func is_web_fullscreen() -> bool:
	if not is_web():
		return false
	return bool(JavaScriptBridge.eval("window.kaleidriftIsFullscreen ? window.kaleidriftIsFullscreen() : Boolean(document.fullscreenElement)"))


static func supports_haptics() -> bool:
	return OS.has_feature("android")


static func supports_exit() -> bool:
	return not is_web()


static func supports_hdr_output() -> bool:
	return not is_web() and DisplayServer.get_name() != "headless" and OS.get_name() in ["Windows", "macOS", "iOS", "visionOS"]


static func classify_hdr_output(
	web_output: bool,
	forced_off: bool,
	platform_supported: bool,
	output_requested: bool,
	internal_hdr: bool,
	reported_headroom: float
) -> String:
	if web_output:
		return "Web SDR"
	if forced_off:
		return "SDR forced"
	if output_requested and reported_headroom > 1.01:
		return "HDR output confirmed"
	if output_requested:
		return "HDR requested (unconfirmed)"
	if internal_hdr:
		return "Internal HDR (SDR output)"
	if not platform_supported:
		return "HDR output unsupported"
	return "SDR output"


static func uses_safe_area() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or is_web()


static func default_quality() -> int:
	return 0 if is_web() else 1


static func needs_audio_activation() -> bool:
	return is_web()
