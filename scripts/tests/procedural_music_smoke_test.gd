extends SceneTree

const InstrumentBankScript := preload("res://scripts/audio/procedural_instrument_bank.gd")
const ComposerScript := preload("res://scripts/audio/music_composer.gd")


func _init() -> void:
	_test_instrument_bank()
	_test_composition_is_deterministic()
	_test_euclidean_pattern()
	print("Procedural music smoke tests passed.")
	quit()


func _test_instrument_bank() -> void:
	var bank = InstrumentBankScript.new()
	while not bank.build_next():
		pass
	var total_bytes := 0
	for instrument in [&"pad", &"pluck", &"bell", &"bass", &"wash"]:
		var stream: AudioStreamWAV = bank.get_stream(instrument)
		assert(stream != null)
		assert(stream.mix_rate == 22050)
		assert(stream.format == AudioStreamWAV.FORMAT_16_BITS)
		assert(not stream.stereo)
		assert(not stream.data.is_empty())
		total_bytes += stream.data.size()
	assert(total_bytes < 2 * 1024 * 1024)


func _test_composition_is_deterministic() -> void:
	var first = ComposerScript.new()
	var second = ComposerScript.new()
	first.configure(12345, -7)
	second.configure(12345, -7)
	assert(first.root_midi == second.root_midi)
	assert(first.scale == second.scale)
	assert(first.chord_notes() == second.chord_notes())
	for _step in range(32):
		assert(first.next_melody_note() == second.next_melody_note())
	first.advance_chord()
	second.advance_chord()
	assert(first.chord_notes() == second.chord_notes())


func _test_euclidean_pattern() -> void:
	var composer = ComposerScript.new()
	var sparse_pattern: Array[bool] = composer.euclidean_pattern(3, 8)
	var reduced_pattern: Array[bool] = composer.euclidean_pattern(2, 8)
	assert(sparse_pattern.size() == 8)
	assert(sparse_pattern.count(true) == 3)
	assert(reduced_pattern.count(true) == 2)
