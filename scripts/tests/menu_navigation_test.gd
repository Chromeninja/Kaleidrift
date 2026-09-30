extends SceneTree

const Navigation := preload("res://scripts/ui/menu_navigation_controller.gd")


func _init() -> void:
	var navigation = Navigation.new()
	assert(navigation.current_screen == &"home")
	navigation.open(&"game_select")
	navigation.open(&"world_select")
	assert(navigation.back() == &"game_select")
	assert(navigation.back() == &"home")
	assert(not navigation.can_go_back())
	navigation.open(&"settings")
	navigation.reset(&"pause")
	assert(navigation.current_screen == &"pause")
	assert(not navigation.can_go_back())
	print("Menu navigation tests passed.")
	quit()
