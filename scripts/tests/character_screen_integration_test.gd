extends SceneTree

const CharacterStoreScript := preload("res://scripts/travelers/character_store.gd")
const CharacterProfileScript := preload("res://scripts/travelers/character_profile.gd")
const TEST_PATH := "user://character_screen_integration_test.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var main_scene = load("res://main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	main_scene.character_store = CharacterStoreScript.new(TEST_PATH)
	main_scene.character_store.load_profiles(main_scene.traveler_catalog, &"glowing_orb", CharacterProfileScript.DEFAULT_PRIMARY, CharacterProfileScript.DEFAULT_ACCENT)
	main_scene._apply_active_character()
	var rig_transform: Transform3D = main_scene.flight_rig.transform
	var rig_velocity: Vector3 = main_scene.flight_rig.velocity
	main_scene._show_character_screen()
	assert(main_scene.character_scroll.visible)
	assert(not main_scene.settings_scroll.visible)
	assert(main_scene.character_preview_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	assert(is_instance_valid(main_scene.character_preview_visual))
	main_scene._on_character_primary_color_changed(Color(0.3, 0.8, 1.0))
	assert(main_scene.flight_rig.transform.is_equal_approx(rig_transform))
	assert(main_scene.flight_rig.velocity.is_equal_approx(rig_velocity))
	main_scene._request_character_back()
	assert(main_scene.character_discard_dialog.visible)
	main_scene.character_discard_dialog.hide()
	main_scene._character_dirty = false
	var count_before = main_scene.character_store.profiles.size()
	main_scene._create_character_profile()
	main_scene.character_name_edit.text = "Nova"
	main_scene._on_character_editor_changed("Nova")
	main_scene._on_character_traveler_selected(1)
	assert(main_scene._save_character_profile())
	assert(main_scene.character_store.profiles.size() == count_before + 1)
	main_scene._use_character_profile()
	assert(main_scene.active_character_profile.display_name == "Nova")
	assert(main_scene.traveler_definition.identifier == &"geometric_bird")
	assert(main_scene.flight_rig.transform.is_equal_approx(rig_transform))
	main_scene._show_settings()
	assert(main_scene.settings_scroll.visible)
	assert(not main_scene.character_scroll.visible)
	assert(not _tree_contains_text(main_scene.settings_content, "Primary color"))
	assert(not _tree_contains_text(main_scene.settings_content, "Accent color"))
	main_scene._show_main_menu()
	assert(main_scene.main_menu_content.visible)
	assert(is_instance_valid(main_scene.character_button))
	main_scene.queue_free()
	for _cleanup_frame in range(4):
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Character screen integration test passed.")
	quit()


func _tree_contains_text(node: Node, expected: String) -> bool:
	if node is Button and node.text == expected:
		return true
	if node is ColorPickerButton and node.text == expected:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, expected):
			return true
	return false
