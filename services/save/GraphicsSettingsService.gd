extends Node

const HIDDEN_GROUP := &"particles_hidden_by_settings"

var dir_path := "user://saves/"
var filename := "graphics.json"

var data: GraphicsSettings


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	data = _load()
	get_tree().node_added.connect(_on_node_added)
	_apply_to_existing_particles()


func save(settings: GraphicsSettings) -> void:
	data = settings

	var file := FileAccess.open(dir_path + filename, FileAccess.WRITE)
	file.store_string(_serialize(settings))
	file.close()


func set_particles_enabled(enabled: bool) -> void:
	data.particles = enabled
	save(data)
	_apply_to_existing_particles()


func _on_node_added(node: Node) -> void:
	if not data.particles and _is_particles(node):
		_hide(node)


func _apply_to_existing_particles() -> void:
	if data.particles:
		_restore_hidden_particles()
	else:
		_hide_all_particles()


func _hide_all_particles() -> void:
	for node in get_tree().root.find_children("*", "", true, false):
		if _is_particles(node):
			_hide(node)


func _restore_hidden_particles() -> void:
	for node in get_tree().get_nodes_in_group(HIDDEN_GROUP):
		node.remove_from_group(HIDDEN_GROUP)
		node.set("visible", true)


func _hide(node: Node) -> void:
	node.add_to_group(HIDDEN_GROUP)
	node.set("visible", false)


func _is_particles(node: Node) -> bool:
	return node is GPUParticles2D \
		or node is GPUParticles3D \
		or node is CPUParticles2D \
		or node is CPUParticles3D


func _load() -> GraphicsSettings:
	if FileAccess.file_exists(dir_path + filename):
		var file := FileAccess.open(dir_path + filename, FileAccess.READ)
		var loaded_data: GraphicsSettings = _parse(file.get_as_text())
		file.close()
		return loaded_data
	return GraphicsSettings.new()


func _serialize(settings: GraphicsSettings) -> String:
	return JSON.stringify({
		"particles": settings.particles
	})


func _parse(json: String) -> GraphicsSettings:
	var dict: Dictionary = JSON.parse_string(json)
	var settings: GraphicsSettings = GraphicsSettings.new()
	settings.particles = dict.get("particles", true)
	return settings
