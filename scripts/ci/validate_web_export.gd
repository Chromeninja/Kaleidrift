extends SceneTree

const REQUIRED_FILES := ["index.html", "index.js", "index.wasm", "index.pck"]


func _init() -> void:
	for file_name in REQUIRED_FILES:
		var path := "build/web/%s" % file_name
		assert(FileAccess.file_exists(path), "Missing Web export file: %s" % path)
	print("Web export validation passed.")
	quit()
