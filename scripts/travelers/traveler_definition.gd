class_name TravelerDefinition
extends Resource

@export var identifier: StringName = &"glowing_orb"
@export var display_name := "Glowing Orb"
@export var visual_scene: PackedScene
@export var visual_scale := 1.0
@export var default_primary_color := Color(0.18, 0.92, 1.0)
@export var default_accent_color := Color(1.0, 0.22, 0.82)
@export_range(0.0, 8.0, 0.05) var glow_intensity := 2.2
@export var trail_profile: TravelerTrailProfile
@export_range(0.18, 0.22, 0.01) var gameplay_collision_radius := 0.20
@export var camera_distance := 2.8
@export var camera_height := 0.72
@export var camera_look_ahead := 1.0
@export var animation_profile: Resource


func normalized_collision_radius() -> float:
	return clampf(gameplay_collision_radius, 0.18, 0.22)


func is_valid_definition() -> bool:
	return not identifier.is_empty() and visual_scene != null
