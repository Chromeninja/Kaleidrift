class_name PerformanceDiagnosticsOverlay
extends Control

const SAMPLE_CAPACITY := 180
const GRAPH_HEIGHT := 68.0
const GRAPH_PADDING := 8.0
const GRAPH_MAX_MS := 50.0

var _samples := PackedFloat32Array()
var _write_index := 0
var _sample_count := 0
var _details := ""
var _font := ThemeDB.fallback_font
var _font_size := 12
var _panel := StyleBoxFlat.new()


func _init() -> void:
	_samples.resize(SAMPLE_CAPACITY)
	_panel.bg_color = Color(0.006, 0.018, 0.030, 0.88)
	_panel.border_color = Color(0.30, 0.72, 0.92, 0.56)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(10)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func add_frame_sample(frame_ms: float) -> void:
	if not is_finite(frame_ms) or frame_ms < 0.0:
		return
	_samples[_write_index] = frame_ms
	_write_index = (_write_index + 1) % SAMPLE_CAPACITY
	_sample_count = mini(_sample_count + 1, SAMPLE_CAPACITY)


func set_details(details: String) -> void:
	_details = details
	queue_redraw()


func set_ui_scale(ui_scale: float, portrait: bool) -> void:
	_font_size = maxi(10, roundi((10.0 if portrait else 11.0) * ui_scale))
	queue_redraw()


func get_sample_count() -> int:
	return _sample_count


func get_samples_oldest_first() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(_sample_count)
	var start := (_write_index - _sample_count + SAMPLE_CAPACITY) % SAMPLE_CAPACITY
	for index in range(_sample_count):
		result[index] = _samples[(start + index) % SAMPLE_CAPACITY]
	return result


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var graph_rect := Rect2(
		Vector2(GRAPH_PADDING, GRAPH_PADDING),
		Vector2(maxf(size.x - GRAPH_PADDING * 2.0, 1.0), GRAPH_HEIGHT)
	)
	draw_rect(graph_rect, Color(0.0, 0.0, 0.0, 0.58), true)
	_draw_graph_grid(graph_rect)
	_draw_frame_graph(graph_rect)
	draw_multiline_string(
		_font,
		Vector2(GRAPH_PADDING, GRAPH_PADDING + GRAPH_HEIGHT + float(_font_size) + 5.0),
		_details,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - GRAPH_PADDING * 2.0,
		_font_size,
		-1,
		Color(0.76, 0.92, 1.0, 0.96)
	)


func _draw_graph_grid(rect: Rect2) -> void:
	for target_ms in [16.67, 33.33]:
		var normalized := clampf(float(target_ms) / GRAPH_MAX_MS, 0.0, 1.0)
		var y := rect.end.y - normalized * rect.size.y
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.45, 0.63, 0.72, 0.28), 1.0)


func _draw_frame_graph(rect: Rect2) -> void:
	if _sample_count < 2:
		return
	var start := (_write_index - _sample_count + SAMPLE_CAPACITY) % SAMPLE_CAPACITY
	var previous := Vector2.ZERO
	for index in range(_sample_count):
		var sample := _samples[(start + index) % SAMPLE_CAPACITY]
		var x := rect.position.x + float(index) / float(_sample_count - 1) * rect.size.x
		var normalized := clampf(sample / GRAPH_MAX_MS, 0.0, 1.0)
		var point := Vector2(x, rect.end.y - normalized * rect.size.y)
		if index > 0:
			draw_line(previous, point, Color(0.28, 0.92, 1.0, 0.95), 1.5, true)
		previous = point
