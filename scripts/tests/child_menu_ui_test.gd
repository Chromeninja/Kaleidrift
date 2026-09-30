extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene = load("res://main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	assert(main_scene.menu_navigation.current_screen == &"home")
	assert(main_scene.home_play_button.visible)
	assert(main_scene.home_play_button.text.contains("PLAY"))
	assert(main_scene.current_game_mode == 0 or main_scene.current_game_mode == 1)
	main_scene.current_game_mode = 1
	main_scene._update_mode_card_labels()
	assert(main_scene.home_play_button.text.contains("CHALLENGE"))
	main_scene._show_game_select()
	assert(main_scene.game_select_content.visible)
	assert(not main_scene.main_menu_content.visible)
	main_scene._show_world_select()
	assert(main_scene.world_select_content.get_parent().visible)
	main_scene._navigate_back()
	assert(main_scene.game_select_content.visible)
	main_scene._show_main_menu()
	assert(main_scene.main_menu_content.visible)
	assert(main_scene.home_play_button.custom_minimum_size.y >= 48.0)
	main_scene.queue_free()
	for _cleanup_frame in range(4):
		await process_frame
	print("Child menu UI tests passed.")
	quit()
