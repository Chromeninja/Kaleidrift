extends SceneTree

const CharacterStoreScript := preload("res://scripts/travelers/character_store.gd")
const CharacterProfileScript := preload("res://scripts/travelers/character_profile.gd")
const Catalog := preload("res://resources/travelers/default_catalog.tres")
const TEST_PATH := "user://character_store_test.cfg"


func _init() -> void:
	_remove_test_file()
	_test_fresh_profile_and_legacy_migration()
	_test_create_duplicate_select_delete_and_reload()
	_test_corrupt_and_invalid_profile_fallback()
	_remove_test_file()
	print("Character store tests passed.")
	quit()


func _test_fresh_profile_and_legacy_migration() -> void:
	var store = CharacterStoreScript.new(TEST_PATH)
	var legacy_primary := Color(0.4, 0.5, 0.6)
	var legacy_accent := Color(0.7, 0.2, 0.3)
	store.load_profiles(Catalog, &"geometric_bird", legacy_primary, legacy_accent)
	assert(store.profiles.size() == 1)
	var profile = store.get_active_profile(Catalog)
	assert(profile.traveler_id == &"geometric_bird")
	assert(profile.primary_color == legacy_primary)
	assert(profile.accent_color == legacy_accent)
	assert(not profile.profile_id.is_empty())


func _test_create_duplicate_select_delete_and_reload() -> void:
	var store = CharacterStoreScript.new(TEST_PATH)
	store.load_profiles(Catalog, &"glowing_orb", CharacterProfileScript.DEFAULT_PRIMARY, CharacterProfileScript.DEFAULT_ACCENT)
	var original = store.get_active_profile(Catalog)
	var new_profile = store.create_profile(Catalog, &"geometric_bird", Color.RED, Color.BLUE, "Scout")
	assert(store.add_profile(new_profile, Catalog))
	var duplicate = new_profile.duplicate_profile()
	duplicate.profile_id = &""
	duplicate.display_name = "Scout"
	assert(store.add_profile(duplicate, Catalog))
	assert(store.profiles.size() == 3)
	assert(store.profiles[2].display_name != store.profiles[1].display_name)
	var selected = store.select_profile(store.profiles[1].profile_id, Catalog)
	assert(selected.profile_id == store.profiles[1].profile_id)
	var reloaded = CharacterStoreScript.new(TEST_PATH)
	reloaded.load_profiles(Catalog, &"glowing_orb", CharacterProfileScript.DEFAULT_PRIMARY, CharacterProfileScript.DEFAULT_ACCENT)
	assert(reloaded.profiles.size() == 3)
	assert(reloaded.active_profile_id == selected.profile_id)
	var replacement = reloaded.delete_profile(selected.profile_id, Catalog)
	assert(reloaded.profiles.size() == 2)
	assert(replacement != null)
	assert(reloaded.find_profile(original.profile_id) != null)


func _test_corrupt_and_invalid_profile_fallback() -> void:
	var config := ConfigFile.new()
	config.set_value("characters", "profiles", [{
		"profile_id": "broken",
		"display_name": "",
		"traveler_id": "missing",
		"primary_color": Color(2.0, -1.0, 0.5),
		"accent_color": Color(0.2, 0.3, 0.4),
		"glow_intensity": 99.0,
		"trail_style": "invalid",
	}])
	config.set_value("characters", "active_profile_id", "broken")
	assert(config.save(TEST_PATH) == OK)
	var store = CharacterStoreScript.new(TEST_PATH)
	store.load_profiles(Catalog, &"glowing_orb", CharacterProfileScript.DEFAULT_PRIMARY, CharacterProfileScript.DEFAULT_ACCENT)
	var profile = store.get_active_profile(Catalog)
	assert(profile.traveler_id == &"glowing_orb")
	assert(profile.display_name == "Traveler")
	assert(profile.primary_color.r == 1.0 and profile.primary_color.g == 0.0)
	assert(profile.glow_intensity == 8.0)
	assert(profile.trail_style == &"default")


func _remove_test_file() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
