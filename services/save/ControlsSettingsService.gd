extends Node

const HIDDEN_GROUP := &"particles_hidden_by_settings"

var dir_path := "user://saves/"
var filename := "controls.json"

var data: ControlsSettings


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	data = _load()


func save(settings: ControlsSettings) -> void:
	data = settings

	var file := FileAccess.open(dir_path + filename, FileAccess.WRITE)
	file.store_string(_serialize(settings))
	file.close()


# TODO
func set_particles_enabled(enabled: bool) -> void:
	data.particles = enabled
	save(data)


func _load() -> ControlsSettings:
	if FileAccess.file_exists(dir_path + filename):
		var file := FileAccess.open(dir_path + filename, FileAccess.READ)
		var loaded_data: ControlsSettings = _parse(file.get_as_text())
		file.close()
		return loaded_data
	return ControlsSettings.new()


func _serialize(settings: ControlsSettings) -> String:
	return JSON.stringify({
		"mouse_sensitivity": settings.mouse_sensitivity
	})


func _parse(json: String) -> ControlsSettings:
	var dict: Dictionary = JSON.parse_string(json)
	var settings: ControlsSettings = ControlsSettings.new()
	settings.mouse_sensitivity = dict.get("mouse_sensitivity", 1.0)
	return settings
