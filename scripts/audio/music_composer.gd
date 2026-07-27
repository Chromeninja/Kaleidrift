class_name MusicComposer
extends RefCounted

const SCALES := [
	[0, 3, 5, 7, 10],
	[0, 2, 3, 5, 7, 9, 10],
	[0, 2, 4, 7, 9],
	[0, 2, 4, 6, 7, 9, 11],
]
const CHORD_TRANSITIONS := [
	[0, 3, 4],
	[4, 0, 3],
	[3, 4, 0],
	[0, 4, 1],
	[0, 3, 1],
]

var journey_seed := 0
var region_id := 0
var root_midi := 48
var scale: Array = SCALES[0]
var chord_degree := 0
var phrase_index := 0
var melody_degree := 2
var rng := RandomNumberGenerator.new()


func configure(new_journey_seed: int, new_region_id: int) -> void:
	journey_seed = new_journey_seed
	region_id = new_region_id
	rng.seed = _combined_seed(journey_seed, region_id)
	root_midi = 45 + rng.randi_range(0, 7)
	scale = SCALES[rng.randi_range(0, SCALES.size() - 1)]
	chord_degree = rng.randi_range(0, mini(4, scale.size() - 1))
	melody_degree = mini(2, scale.size() - 1)
	phrase_index = 0


func advance_chord() -> void:
	var choices: Array = CHORD_TRANSITIONS[chord_degree % CHORD_TRANSITIONS.size()]
	chord_degree = int(choices[rng.randi_range(0, choices.size() - 1)]) % scale.size()
	phrase_index += 1


func chord_notes() -> Array[int]:
	var notes: Array[int] = []
	for offset in [0, 2, 4]:
		var degree: int = chord_degree + offset
		var octave := floori(float(degree) / float(scale.size()))
		notes.append(root_midi + int(scale[degree % scale.size()]) + octave * 12)
	return notes


func next_melody_note() -> int:
	var movement_roll := rng.randf()
	var movement := 0
	if movement_roll < 0.24:
		movement = -1
	elif movement_roll > 0.76:
		movement = 1
	melody_degree = clampi(melody_degree + movement, 0, scale.size() - 1)
	return root_midi + 12 + int(scale[melody_degree])


func should_rest(rest_probability: float) -> bool:
	return rng.randf() < rest_probability


func euclidean_pattern(pulses: int, steps: int, rotation: int = 0) -> Array[bool]:
	var pattern: Array[bool] = []
	for step in steps:
		var current := posmod(step + rotation, steps)
		pattern.append(posmod(current * pulses, steps) < pulses)
	return pattern


func _combined_seed(first: int, second: int) -> int:
	return int((first * 1103515245 + second * 2654435761) & 0x7fffffff)
