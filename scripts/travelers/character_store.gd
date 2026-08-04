class_name CharacterStore
extends RefCounted

const CharacterProfileScript := preload("res://scripts/travelers/character_profile.gd")
const SECTION := "characters"
const SCHEMA_VERSION := 1
const MAX_PROFILES := 12

var path: String
var profiles: Array = []
var active_profile_id: StringName = &""
var _next_profile_number := 1


func _init(new_path: String) -> void:
	path = new_path


func load_profiles(catalog: TravelerCatalog, legacy_traveler_id: StringName, legacy_primary: Color, legacy_accent: Color) -> void:
	profiles.clear()
	active_profile_id = &""
	var config := ConfigFile.new()
	var load_error := config.load(path)
	if load_error == OK and config.has_section(SECTION):
		var saved_profiles = config.get_value(SECTION, "profiles", [])
		if saved_profiles is Array:
			for value in saved_profiles:
				if profiles.size() >= MAX_PROFILES:
					break
				var profile = CharacterProfileScript.from_dictionary(value, catalog)
				if profile != null and find_profile(profile.profile_id) == null:
					profiles.append(profile)
		active_profile_id = StringName(str(config.get_value(SECTION, "active_profile_id", "")))
	if profiles.is_empty():
		var migrated = create_profile(catalog, legacy_traveler_id, legacy_primary, legacy_accent, "Traveler")
		profiles.append(migrated)
		active_profile_id = migrated.profile_id
		_save()
	ensure_active_profile(catalog)


func ensure_active_profile(catalog: TravelerCatalog):
	var active = find_profile(active_profile_id)
	if active == null and not profiles.is_empty():
		active = profiles[0]
		active_profile_id = active.profile_id
	if active != null:
		active.sanitize(catalog)
	return active


func get_active_profile(catalog: TravelerCatalog):
	return ensure_active_profile(catalog)


func find_profile(profile_id: StringName):
	for profile in profiles:
		if profile.profile_id == profile_id:
			return profile
	return null


func create_profile(catalog: TravelerCatalog, traveler_id: StringName = &"glowing_orb", primary := CharacterProfileScript.DEFAULT_PRIMARY, accent := CharacterProfileScript.DEFAULT_ACCENT, requested_name := "Traveler"):
	var profile = CharacterProfileScript.new()
	profile.profile_id = _new_profile_id()
	profile.display_name = _unique_name(requested_name)
	profile.traveler_id = traveler_id
	profile.primary_color = primary
	profile.accent_color = accent
	var definition = catalog.find_definition(traveler_id) if catalog != null else null
	profile.glow_intensity = definition.glow_intensity if definition != null else 2.2
	profile.sanitize(catalog)
	return profile


func add_profile(profile, catalog: TravelerCatalog) -> bool:
	if profile == null or profiles.size() >= MAX_PROFILES:
		return false
	var copy = profile.duplicate_profile()
	if copy.profile_id.is_empty() or find_profile(copy.profile_id) != null:
		copy.profile_id = _new_profile_id()
	copy.display_name = _unique_name(copy.display_name)
	copy.sanitize(catalog)
	profiles.append(copy)
	return _save()


func update_profile(profile, catalog: TravelerCatalog) -> bool:
	if profile == null:
		return false
	var stored = find_profile(profile.profile_id)
	if stored == null:
		return false
	var copy = profile.duplicate_profile()
	copy.sanitize(catalog)
	copy.display_name = _unique_name(copy.display_name, copy.profile_id)
	var index = profiles.find(stored)
	profiles[index] = copy
	return _save()


func select_profile(profile_id: StringName, catalog: TravelerCatalog):
	var profile = find_profile(profile_id)
	if profile == null:
		return ensure_active_profile(catalog)
	active_profile_id = profile.profile_id
	_save()
	return profile


func delete_profile(profile_id: StringName, catalog: TravelerCatalog):
	if profiles.size() <= 1:
		return ensure_active_profile(catalog)
	var profile = find_profile(profile_id)
	if profile == null:
		return ensure_active_profile(catalog)
	profiles.erase(profile)
	if active_profile_id == profile_id:
		active_profile_id = profiles[0].profile_id
	_save()
	return ensure_active_profile(catalog)


func _new_profile_id() -> StringName:
	while true:
		var candidate := StringName("character_%03d" % _next_profile_number)
		_next_profile_number += 1
		if find_profile(candidate) == null:
			return candidate
	return &"character_fallback"


func _unique_name(requested: String, ignored_id: StringName = &"") -> String:
	var base := requested.strip_edges().left(24)
	if base.is_empty():
		base = "Traveler"
	var candidate := base
	var suffix := 2
	while _name_exists(candidate, ignored_id):
		candidate = "%s %d" % [base.left(20), suffix]
		suffix += 1
	return candidate


func _name_exists(name: String, ignored_id: StringName) -> bool:
	for profile in profiles:
		if profile.profile_id != ignored_id and profile.display_name.nocasecmp_to(name) == 0:
			return true
	return false


func _save() -> bool:
	var config := ConfigFile.new()
	var encoded: Array[Dictionary] = []
	for profile in profiles:
		encoded.append(profile.to_dictionary())
	config.set_value(SECTION, "schema_version", SCHEMA_VERSION)
	config.set_value(SECTION, "active_profile_id", String(active_profile_id))
	config.set_value(SECTION, "profiles", encoded)
	return config.save(path) == OK
