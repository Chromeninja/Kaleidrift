class_name ProceduralInstrumentBank
extends RefCounted

const MIX_RATE := 22050

var streams: Dictionary = {}
var _build_order := [&"pad", &"pluck", &"bell", &"bass", &"wash"]
var _build_index := 0


func build_next() -> bool:
	if _build_index >= _build_order.size():
		return true
	var instrument: StringName = _build_order[_build_index]
	match instrument:
		&"pad":
			streams[instrument] = _make_stream(9.5, _pad_sample)
		&"pluck":
			streams[instrument] = _make_stream(0.55, _pluck_sample)
		&"bell":
			streams[instrument] = _make_stream(1.8, _bell_sample)
		&"bass":
			streams[instrument] = _make_stream(1.1, _bass_sample)
		&"wash":
			streams[instrument] = _make_stream(3.4, _wash_sample)
	_build_index += 1
	return _build_index >= _build_order.size()


func is_ready() -> bool:
	return _build_index >= _build_order.size()


func get_stream(instrument: StringName) -> AudioStreamWAV:
	return streams.get(instrument) as AudioStreamWAV


func _make_stream(duration: float, sample_function: Callable) -> AudioStreamWAV:
	var frame_count := ceili(duration * MIX_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	for frame in frame_count:
		var time := float(frame) / float(MIX_RATE)
		var phase := time * TAU * 220.0
		var value: float = clampf(sample_function.call(time, duration, phase), -0.92, 0.92)
		pcm.encode_s16(frame * 2, roundi(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


func _pad_sample(time: float, duration: float, phase: float) -> float:
	var envelope := _soft_envelope(time, duration, 0.7, 1.4)
	var triangle := asin(sin(phase * 0.5)) * (2.0 / PI)
	var wobble := sin(time * TAU * 0.18) * 0.025
	return (sin(phase * 0.5 + wobble) * 0.30 + triangle * 0.12) * envelope


func _pluck_sample(time: float, _duration: float, phase: float) -> float:
	var envelope := exp(-time * 7.5) * minf(time * 70.0, 1.0)
	var triangle := asin(sin(phase)) * (2.0 / PI)
	return (triangle * 0.28 + sin(phase * 2.0) * 0.06) * envelope


func _bell_sample(time: float, duration: float, phase: float) -> float:
	var envelope := exp(-time * 2.3) * _soft_envelope(time, duration, 0.015, 0.25)
	var carrier := sin(phase * 2.0 + sin(phase * 3.01) * 1.5 * exp(-time * 3.0))
	return carrier * envelope * 0.24


func _bass_sample(time: float, _duration: float, phase: float) -> float:
	var envelope := exp(-time * 2.8) * minf(time * 35.0, 1.0)
	return (sin(phase * 0.25) * 0.34 + sin(phase * 0.5) * 0.08) * envelope


func _wash_sample(time: float, duration: float, _phase: float) -> float:
	var envelope := _soft_envelope(time, duration, 0.8, 1.0)
	var noise := sin(time * 137.1) * sin(time * 71.7) * sin(time * 29.3)
	var breath := sin(time * TAU * 0.11) * 0.5 + 0.5
	return noise * breath * envelope * 0.055


func _soft_envelope(time: float, duration: float, attack: float, release: float) -> float:
	return minf(time / attack, 1.0) * minf((duration - time) / release, 1.0)
