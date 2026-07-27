class_name MusicContext
extends RefCounted

enum Mode {
	MENU,
	ENDLESS,
	SURVIVAL,
}

var journey_seed: int
var region_id: int
var region_blend: float
var game_mode: int
var speed_normalized: float
var surface_proximity: float
var transition_intensity: float
var reduced_motion: bool
var paused: bool


func _init(
	new_journey_seed: int = 0,
	new_region_id: int = 0,
	new_region_blend: float = 0.0,
	new_game_mode: int = Mode.MENU,
	new_speed_normalized: float = 0.0,
	new_surface_proximity: float = 0.0,
	new_transition_intensity: float = 0.0,
	new_reduced_motion: bool = false,
	new_paused: bool = false
) -> void:
	journey_seed = new_journey_seed
	region_id = new_region_id
	region_blend = clampf(new_region_blend, 0.0, 1.0)
	game_mode = new_game_mode
	speed_normalized = clampf(new_speed_normalized, 0.0, 1.0)
	surface_proximity = clampf(new_surface_proximity, 0.0, 1.0)
	transition_intensity = clampf(new_transition_intensity, 0.0, 1.0)
	reduced_motion = new_reduced_motion
	paused = new_paused
