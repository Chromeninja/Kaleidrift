class_name PlatformCapabilities
extends RefCounted

## Centralizes runtime platform decisions. Gameplay should not query OS directly.
static func is_web() -> bool:
	return OS.has_feature("web")


static func supports_haptics() -> bool:
	return OS.has_feature("android")


static func supports_exit() -> bool:
	return not is_web()


static func supports_hdr_output() -> bool:
	return not is_web() and DisplayServer.get_name() != "headless" and OS.get_name() in ["Windows", "macOS", "iOS", "visionOS"]


static func uses_safe_area() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or is_web()


static func default_quality() -> int:
	return 0 if is_web() else 1


static func needs_audio_activation() -> bool:
	return is_web()
