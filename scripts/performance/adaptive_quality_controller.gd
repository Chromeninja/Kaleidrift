class_name AdaptiveQualityController
extends RefCounted

const SAMPLE_LIMIT := 180

var presets: Array
var target_frame_ms: float
var evaluation_seconds: float
var warmup_seconds: float
var downgrade_cooldown_seconds: float
var upgrade_cooldown_seconds: float
var scale_step: float

var automatic := true
var resolved_tier := 0
var resolved_scale := 1.0
var elapsed := 0.0
var evaluation_elapsed := 0.0
var cooldown_remaining := 0.0
var stable_fast_elapsed := 0.0
var samples: Array[float] = []


static func resolve_saved_quality(
	saved_quality: Variant,
	saved_automatic: Variant,
	default_tier: int,
	preset_count: int
) -> Dictionary:
	var maximum_tier := maxi(preset_count - 1, 0)
	var manual_tier := clampi(int(saved_quality), 0, maximum_tier)
	var enable_automatic := bool(saved_automatic)
	return {
		"manual_tier": manual_tier,
		"automatic": enable_automatic,
		"resolved_tier": clampi(default_tier if enable_automatic else manual_tier, 0, maximum_tier),
	}


func _init(
	new_presets: Array,
	new_target_frame_ms: float,
	start_tier: int,
	new_evaluation_seconds: float = 2.0,
	new_warmup_seconds: float = 10.0,
	new_downgrade_cooldown_seconds: float = 4.0,
	new_upgrade_cooldown_seconds: float = 8.0,
	new_scale_step: float = 0.05
) -> void:
	presets = new_presets
	target_frame_ms = new_target_frame_ms
	evaluation_seconds = new_evaluation_seconds
	warmup_seconds = new_warmup_seconds
	downgrade_cooldown_seconds = new_downgrade_cooldown_seconds
	upgrade_cooldown_seconds = new_upgrade_cooldown_seconds
	scale_step = new_scale_step
	set_manual_tier(start_tier)
	automatic = true


func reset(new_tier: int, enable_automatic: bool) -> void:
	set_manual_tier(new_tier)
	automatic = enable_automatic
	elapsed = 0.0
	evaluation_elapsed = 0.0
	cooldown_remaining = 0.0
	stable_fast_elapsed = 0.0
	samples.clear()


func set_manual_tier(tier: int) -> void:
	resolved_tier = clampi(tier, 0, presets.size() - 1)
	resolved_scale = float(presets[resolved_tier]["base_render_scale"])


func sample(delta: float, frame_ms: float) -> bool:
	elapsed += delta
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if not automatic:
		return false
	if elapsed < warmup_seconds:
		return false
	if is_finite(frame_ms) and frame_ms > 0.0:
		samples.append(frame_ms)
		if samples.size() > SAMPLE_LIMIT:
			samples.pop_front()
	evaluation_elapsed += delta
	if evaluation_elapsed < evaluation_seconds or cooldown_remaining > 0.0:
		return false
	evaluation_elapsed = 0.0
	if samples.is_empty():
		return false

	var p90 := get_percentile(0.90)
	var p95 := get_percentile(0.95)
	var slow_threshold := target_frame_ms * 1.02
	var fast_threshold := target_frame_ms * 0.78
	if p95 > slow_threshold:
		stable_fast_elapsed = 0.0
		return _decrease_cost()
	if p90 < fast_threshold:
		stable_fast_elapsed += evaluation_seconds
		if stable_fast_elapsed >= upgrade_cooldown_seconds:
			stable_fast_elapsed = 0.0
			return _increase_quality()
	else:
		stable_fast_elapsed = 0.0
	return false


func _decrease_cost() -> bool:
	var minimum_scale := float(presets[resolved_tier]["minimum_auto_scale"])
	if resolved_scale > minimum_scale + 0.001:
		resolved_scale = maxf(minimum_scale, resolved_scale - scale_step)
	elif resolved_tier > 0:
		resolved_tier -= 1
		resolved_scale = float(presets[resolved_tier]["base_render_scale"])
	else:
		return false
	cooldown_remaining = downgrade_cooldown_seconds
	samples.clear()
	return true


func _increase_quality() -> bool:
	var base_scale := float(presets[resolved_tier]["base_render_scale"])
	if resolved_scale < base_scale - 0.001:
		resolved_scale = minf(base_scale, resolved_scale + scale_step)
	elif resolved_tier < presets.size() - 1:
		resolved_tier += 1
		resolved_scale = float(presets[resolved_tier]["minimum_auto_scale"])
	else:
		return false
	cooldown_remaining = upgrade_cooldown_seconds
	samples.clear()
	return true


func get_percentile(percentile: float) -> float:
	if samples.is_empty():
		return 0.0
	var sorted_samples := samples.duplicate()
	sorted_samples.sort()
	var index := clampi(
		roundi(clampf(percentile, 0.0, 1.0) * float(sorted_samples.size() - 1)),
		0,
		sorted_samples.size() - 1
	)
	return sorted_samples[index]


func is_cooling_down() -> bool:
	return cooldown_remaining > 0.0
