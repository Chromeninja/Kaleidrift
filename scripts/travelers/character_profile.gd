class_name CharacterProfile
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PRIMARY := Color(0.18, 0.92, 1.0)
const DEFAULT_ACCENT := Color(1.0, 0.22, 0.82)
const TRAIL_STYLES := [&"default", &"short", &"long"]

var profile_id: StringName = &""
var display_name := "Traveler"
var traveler_id: StringName = &"glowing_orb"
var primary_color := DEFAULT_PRIMARY
var accent_color := DEFAULT_ACCENT
var glow_intensity := 2.2
var trail_style: StringName = &"default"
var schema_version := SCHEMA_VERSION


func duplicate_profile():
	var copy = get_script().new()
	copy.profile_id = profile_id
	copy.display_name = display_name
	copy.traveler_id = traveler_id
	copy.primary_color = primary_color
	copy.accent_color = accent_color
	copy.glow_intensity = glow_intensity
	copy.trail_style = trail_style
	copy.schema_version = schema_version
	return copy


func sanitize(catalog: TravelerCatalog) -> void:
	if catalog == null or not catalog.has_definition(traveler_id):
		traveler_id = &"glowing_orb"
	profile_id = StringName(str(profile_id).strip_edges())
	display_name = display_name.strip_edges().left(24)
	if display_name.is_empty():
		display_name = "Traveler"
	primary_color = _sanitize_color(primary_color, DEFAULT_PRIMARY)
	accent_color = _sanitize_color(accent_color, DEFAULT_ACCENT)
	glow_intensity = clampf(glow_intensity if is_finite(glow_intensity) else 2.2, 0.0, 8.0)
	if trail_style not in TRAIL_STYLES:
		trail_style = &"default"
	schema_version = SCHEMA_VERSION


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"profile_id": String(profile_id),
		"display_name": display_name,
		"traveler_id": String(traveler_id),
		"primary_color": primary_color,
		"accent_color": accent_color,
		"glow_intensity": glow_intensity,
		"trail_style": String(trail_style),
	}


static func from_dictionary(value: Variant, catalog: TravelerCatalog):
	if not value is Dictionary:
		return null
	var data: Dictionary = value
	var profile = load("res://scripts/travelers/character_profile.gd").new()
	profile.profile_id = StringName(str(data.get("profile_id", "")))
	profile.display_name = str(data.get("display_name", "Traveler"))
	profile.traveler_id = StringName(str(data.get("traveler_id", "glowing_orb")))
	var saved_primary = data.get("primary_color", DEFAULT_PRIMARY)
	if saved_primary is Color:
		profile.primary_color = saved_primary
	var saved_accent = data.get("accent_color", DEFAULT_ACCENT)
	if saved_accent is Color:
		profile.accent_color = saved_accent
	profile.glow_intensity = float(data.get("glow_intensity", 2.2))
	profile.trail_style = StringName(str(data.get("trail_style", "default")))
	profile.sanitize(catalog)
	return profile if not profile.profile_id.is_empty() else null


static func _sanitize_color(value: Color, fallback: Color) -> Color:
	if not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a):
		return fallback
	return Color(clampf(value.r, 0.0, 1.0), clampf(value.g, 0.0, 1.0), clampf(value.b, 0.0, 1.0), clampf(value.a, 0.0, 1.0))
