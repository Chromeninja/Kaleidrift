class_name SettingsStore
extends RefCounted

var path: String


func _init(new_path: String) -> void:
	path = new_path


func load_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(path)
	return config


func save_config(config: ConfigFile) -> Error:
	return config.save(path)
