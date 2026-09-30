class_name MenuNavigationController
extends RefCounted

signal screen_changed(screen: StringName, previous: StringName)

const HOME := &"home"
const GAME_SELECT := &"game_select"
const WORLD_SELECT := &"world_select"
const TRAVELER := &"traveler"
const SETTINGS := &"settings"
const ADVANCED_SETTINGS := &"advanced_settings"
const PAUSE := &"pause"
const RESULTS := &"results"

var current_screen: StringName = HOME
var history: Array[StringName] = []


func reset(screen: StringName = HOME) -> void:
	var previous := current_screen
	current_screen = screen
	history.clear()
	screen_changed.emit(current_screen, previous)


func open(screen: StringName, remember := true) -> void:
	if screen == current_screen:
		return
	var previous := current_screen
	if remember:
		history.append(current_screen)
	current_screen = screen
	screen_changed.emit(current_screen, previous)


func back() -> StringName:
	if history.is_empty():
		return current_screen
	var previous := current_screen
	current_screen = history.pop_back()
	screen_changed.emit(current_screen, previous)
	return current_screen


func can_go_back() -> bool:
	return not history.is_empty()
