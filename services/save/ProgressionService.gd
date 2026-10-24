extends Node


signal total_candy_changed(total_candy: int)
signal world_completed(world_id: StringName, candy_amount: int)
signal world_progress_changed(completed_worlds: int, available_worlds: int)


const DIR_PATH: String = "user://saves/"
const FILENAME: String = "progression.json"
const MAX_PLAYER_NAME_LENGTH: int = 20
## Add future world ids here when their playable scenes are integrated.
const AVAILABLE_WORLD_IDS: Array[StringName] = [&"candy_bucket", &"labyrinth", &"chaseween", &"faction_territory"]

var data: Progression


func init() -> void:
	if data != null:
		return

	DirAccess.make_dir_recursive_absolute(DIR_PATH)
	data = _load()


func save(progression: Progression) -> void:
	data = progression
	DirAccess.make_dir_recursive_absolute(DIR_PATH)
	var content: String = _serialize(progression)
	var file: FileAccess = FileAccess.open(DIR_PATH + FILENAME, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save progression: %s" % FileAccess.get_open_error())
		return

	file.store_string(content)
	file.close()


## Starts a fresh run while keeping the save schema and legacy fields intact.
func start_new_game() -> void:
	_ensure_initialized()
	var saved_player_name: String = data.player_name
	data = Progression.new(0, 0, [], false, saved_player_name)
	save(data)
	total_candy_changed.emit(data.total_candy)
	_emit_world_progress_changed()


## Records a world result once. Returns false for invalid or completed worlds.
func complete_world(world_id: StringName, candy_amount: int) -> bool:
	_ensure_initialized()
	if not AVAILABLE_WORLD_IDS.has(world_id) or candy_amount < 0:
		return false
	if data.completed_worlds.has(world_id):
		return false

	data.total_candy += candy_amount
	data.completed_worlds.append(world_id)
	if _get_completed_world_count(data) == AVAILABLE_WORLD_IDS.size():
		data.finale_seen = false
	save(data)
	world_completed.emit(world_id, candy_amount)
	total_candy_changed.emit(data.total_candy)
	_emit_world_progress_changed()
	return true


func get_total_candy() -> int:
	_ensure_initialized()
	return data.total_candy


func get_player_name() -> String:
	_ensure_initialized()
	return data.player_name


func set_player_name(player_name: String) -> bool:
	_ensure_initialized()
	var sanitized_name: String = _sanitize_player_name(player_name)
	if sanitized_name.is_empty():
		return false
	if data.player_name == sanitized_name:
		return true

	data.player_name = sanitized_name
	save(data)
	return true


func is_world_completed(world_id: StringName) -> bool:
	_ensure_initialized()
	if not AVAILABLE_WORLD_IDS.has(world_id):
		return false
	return data.completed_worlds.has(world_id)


func get_completed_world_count() -> int:
	_ensure_initialized()
	return _get_completed_world_count(data)


func get_available_world_count() -> int:
	return AVAILABLE_WORLD_IDS.size()


func are_all_worlds_completed() -> bool:
	return (
		get_available_world_count() > 0
		and get_completed_world_count() == get_available_world_count()
	)


func should_show_finale() -> bool:
	_ensure_initialized()
	return are_all_worlds_completed() and not data.finale_seen


func mark_finale_seen() -> bool:
	if not should_show_finale():
		return false

	data.finale_seen = true
	save(data)
	return true


func clear() -> void:
	DirAccess.remove_absolute(DIR_PATH + FILENAME)
	data = Progression.new()
	total_candy_changed.emit(data.total_candy)
	_emit_world_progress_changed()


func _load() -> Progression:
	if FileAccess.file_exists(DIR_PATH + FILENAME):
		var file: FileAccess = FileAccess.open(DIR_PATH + FILENAME, FileAccess.READ)
		if file == null:
			push_error("Unable to load progression: %s" % FileAccess.get_open_error())
			return Progression.new()

		var loaded_data: Progression = _parse(file.get_as_text())
		file.close()
		return loaded_data
	return Progression.new()


func _serialize(progression: Progression) -> String:
	var completed_worlds: Array[String] = []
	for world_id: StringName in progression.completed_worlds:
		completed_worlds.append(String(world_id))

	return JSON.stringify({
		"coins": progression.coins,
		"total_candy": progression.total_candy,
		"completed_worlds": completed_worlds,
		"finale_seen": progression.finale_seen,
		"player_name": progression.player_name,
	})


func _parse(json: String) -> Progression:
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		push_warning("Invalid progression save. Starting with empty progression.")
		return Progression.new()

	var dict: Dictionary = parsed as Dictionary
	var completed_worlds: Array[StringName] = []
	var saved_worlds: Variant = dict.get("completed_worlds", [])
	if saved_worlds is Array:
		for saved_world: Variant in saved_worlds:
			var world_id := StringName(str(saved_world))
			if _is_valid_world_id(world_id) and not completed_worlds.has(world_id):
				completed_worlds.append(world_id)

	return Progression.new(
		maxi(0, int(dict.get("coins", 0))),
		maxi(0, int(dict.get("total_candy", 0))),
		completed_worlds,
		bool(dict.get("finale_seen", false)),
		_sanitize_player_name(str(dict.get("player_name", "")))
	)


func _ensure_initialized() -> void:
	if data == null:
		init()


func _get_completed_world_count(progression: Progression) -> int:
	var completed_count: int = 0
	for world_id: StringName in AVAILABLE_WORLD_IDS:
		if progression.completed_worlds.has(world_id):
			completed_count += 1
	return completed_count


func _emit_world_progress_changed() -> void:
	world_progress_changed.emit(
		get_completed_world_count(),
		get_available_world_count()
	)


func _is_valid_world_id(world_id: StringName) -> bool:
	var id_text: String = String(world_id)
	return (
		not id_text.is_empty()
		and id_text.is_valid_identifier()
		and id_text == id_text.to_snake_case()
	)


func _sanitize_player_name(raw_name: String) -> String:
	var sanitized_name: String = ""
	for index: int in raw_name.length():
		var codepoint: int = raw_name.unicode_at(index)
		if (
			codepoint >= 32
			and not (codepoint >= 127 and codepoint <= 159)
			and codepoint != 0x2028
			and codepoint != 0x2029
		):
			sanitized_name += String.chr(codepoint)
	return sanitized_name.strip_edges().left(MAX_PLAYER_NAME_LENGTH).strip_edges()
