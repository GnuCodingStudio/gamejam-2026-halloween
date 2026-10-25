class_name LobbyCandyHud
extends CanvasLayer


signal finale_closed

const CAPTURE_DIRECTORY: String = "user://bilans/"
const FINALE_VOLUME_DB: float = -10.0
const SILENT_VOLUME_DB: float = -40.0
const PLAYER_NAME_MAX_FONT_SIZE: int = 38
const PLAYER_NAME_MIN_FONT_SIZE: int = 26
const PLAYER_NAME_MAX_WIDTH: float = 700.0
const STATUS_SUCCESS_COLOR: Color = Color(0.713726, 0.921569, 0.776471)
const STATUS_ERROR_COLOR: Color = Color(1.0, 0.466667, 0.396078)
const STATUS_NEUTRAL_COLOR: Color = Color(0.886275, 0.85098, 0.933333)

@onready var candy_label: Label = %CandyLabel
@onready var worlds_label: Label = %WorldsLabel
@onready var finale_overlay: Control = %FinaleOverlay
@onready var finale_card: Control = %FinaleCard
@onready var name_step: Control = %NameStep
@onready var name_input: LineEdit = %NameInput
@onready var name_error: Label = %NameError
@onready var validate_button: Button = %ValidateButton
@onready var result_step: Control = %ResultStep
@onready var player_name_label: Label = %PlayerNameLabel
@onready var final_score_label: Label = %FinalScoreLabel
@onready var final_worlds_label: Label = %FinalWorldsLabel
@onready var save_button: Button = %SaveButton
@onready var share_button: Button = %ShareButton
@onready var open_folder_button: Button = %OpenFolderButton
@onready var return_button: Button = %ReturnButton
@onready var save_status: Label = %SaveStatus
@onready var actions: Control = %Actions
@onready var hint: Control = %Hint
@onready var finale_audio: AudioStreamPlayer = %FinaleAudio
@onready var lobby_music: AudioStreamPlayer = get_node_or_null("../LobbyMusic") as AudioStreamPlayer

var _capture_in_progress: bool = false
var _finale_closing: bool = false
var _finale_opening: bool = false
var _paused_for_finale: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _tree_was_paused: bool = false
var _last_capture_png: PackedByteArray = PackedByteArray()
var _last_capture_file_name: String = ""
var _last_capture_path: String = ""
var _lobby_music_was_playing: bool = false
var _lobby_music_volume_db: float = 0.0


func _ready() -> void:
	ProgressionService.total_candy_changed.connect(_update_candy_label)
	ProgressionService.world_progress_changed.connect(_update_worlds_label)
	validate_button.pressed.connect(_validate_player_name)
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.text_changed.connect(_on_name_changed)
	save_button.pressed.connect(_save_finale_capture)
	share_button.pressed.connect(_share_finale)
	open_folder_button.pressed.connect(_open_capture_directory)
	return_button.pressed.connect(_dismiss_finale)
	_update_candy_label(ProgressionService.get_total_candy())
	_update_worlds_label(
		ProgressionService.get_completed_world_count(),
		ProgressionService.get_available_world_count()
	)
	_configure_finale_music()
	_configure_platform_actions()
	finale_overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if finale_overlay.visible and event.is_action_pressed(&"exit"):
		get_viewport().set_input_as_handled()
		_dismiss_finale()


func _exit_tree() -> void:
	if not _paused_for_finale:
		return
	get_tree().paused = _tree_was_paused
	Input.mouse_mode = _previous_mouse_mode


func open_finale() -> bool:
	if (
		_finale_opening
		or _finale_closing
		or finale_overlay.visible
		or not ProgressionService.are_all_worlds_completed()
		or SceneTransition.is_transition_active()
	):
		return false

	_finale_opening = true
	if not SceneTransition.run_fade(_prepare_finale, _reveal_finale):
		_finale_opening = false
		return false
	return true


func _update_candy_label(total_candy: int) -> void:
	candy_label.text = tr("LOBBY_CANDY_COUNT") % total_candy


func _update_worlds_label(completed_worlds: int, available_worlds: int) -> void:
	worlds_label.text = tr("LOBBY_WORLDS_COUNT") % [completed_worlds, available_worlds]


func _prepare_finale() -> void:
	_pause_lobby_music()
	_update_finale_summary()
	_show_name_entry()
	_prepare_finale_animation()
	_previous_mouse_mode = Input.mouse_mode
	_tree_was_paused = get_tree().paused
	_paused_for_finale = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finale_overlay.show()


func _reveal_finale() -> void:
	if not finale_overlay.visible or _finale_closing:
		_finale_opening = false
		return

	finale_audio.volume_db = SILENT_VOLUME_DB
	finale_audio.play()
	var entrance: Tween = create_tween().set_parallel(true)
	entrance.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	entrance.tween_property(finale_card, "scale", Vector2.ONE, 0.65)
	entrance.tween_property(finale_card, "modulate:a", 1.0, 0.40)
	entrance.tween_property(finale_audio, "volume_db", FINALE_VOLUME_DB, 1.2)
	await entrance.finished
	if _finale_closing or not finale_overlay.visible:
		_finale_opening = false
		return

	_finale_opening = false
	name_input.grab_focus()
	name_input.select_all()


func _show_name_entry() -> void:
	name_input.text = ProgressionService.get_player_name()
	name_error.text = ""
	save_status.text = ""
	name_step.show()
	result_step.hide()
	save_button.hide()
	share_button.hide()
	open_folder_button.hide()
	validate_button.disabled = false
	return_button.disabled = false


func _validate_player_name() -> void:
	if not ProgressionService.set_player_name(name_input.text):
		name_error.text = tr("LOBBY_NAME_REQUIRED")
		name_input.grab_focus()
		return

	name_input.text = ProgressionService.get_player_name()
	_show_final_result(name_input.text)


func _show_final_result(player_name: String) -> void:
	_reset_export_state()
	player_name_label.text = player_name
	_fit_player_name(player_name)
	_update_finale_summary()
	name_step.hide()
	result_step.show()
	actions.hide()
	save_status.hide()
	hint.hide()
	save_button.show()
	share_button.show()
	open_folder_button.visible = FinaleSharePlatform.is_desktop()
	_capture_in_progress = true
	save_button.disabled = true
	share_button.disabled = true
	open_folder_button.disabled = true
	save_status.text = ""
	result_step.modulate = Color(1.0, 1.0, 1.0, 0.0)
	result_step.scale = Vector2.ONE * 0.96
	result_step.pivot_offset = result_step.size * 0.5
	var reveal: Tween = create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	reveal.tween_property(result_step, "modulate:a", 1.0, 0.40)
	reveal.tween_property(result_step, "scale", Vector2.ONE, 0.48)
	await reveal.finished
	if _finale_closing or not result_step.visible:
		_capture_in_progress = false
		return
	await _prepare_capture_buffer()
	_restore_capture_controls()
	_capture_in_progress = false
	save_button.disabled = false
	share_button.disabled = false
	save_button.grab_focus()


func _update_finale_summary() -> void:
	final_score_label.text = tr("LOBBY_FINAL_SCORE") % ProgressionService.get_total_candy()
	final_worlds_label.text = tr("LOBBY_FINAL_WORLDS") % [
		ProgressionService.get_completed_world_count(),
		ProgressionService.get_available_world_count(),
	]


func _prepare_finale_animation() -> void:
	finale_overlay.modulate = Color.WHITE
	finale_card.pivot_offset = finale_card.size * 0.5
	finale_card.scale = Vector2.ONE * 0.9
	finale_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	finale_audio.volume_db = SILENT_VOLUME_DB
	_finale_closing = false
	_capture_in_progress = false
	_reset_export_state()


func _configure_finale_music() -> void:
	if finale_audio.stream is AudioStreamMP3:
		var local_stream: AudioStreamMP3 = finale_audio.stream.duplicate() as AudioStreamMP3
		local_stream.loop = true
		finale_audio.stream = local_stream


func _configure_platform_actions() -> void:
	open_folder_button.visible = FinaleSharePlatform.is_desktop()
	open_folder_button.disabled = true


func _fit_player_name(player_name: String) -> void:
	var font: Font = player_name_label.get_theme_font("font")
	for font_size: int in range(PLAYER_NAME_MAX_FONT_SIZE, PLAYER_NAME_MIN_FONT_SIZE - 1, -1):
		var text_width: float = font.get_string_size(
			player_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
		if text_width <= PLAYER_NAME_MAX_WIDTH:
			player_name_label.add_theme_font_size_override("font_size", font_size)
			return
	player_name_label.add_theme_font_size_override("font_size", PLAYER_NAME_MIN_FONT_SIZE)


func _on_name_submitted(_submitted_name: String) -> void:
	_validate_player_name()


func _on_name_changed(_new_text: String) -> void:
	name_error.text = ""


func _save_finale_capture() -> void:
	if _capture_in_progress or not result_step.visible:
		return
	if DisplayServer.get_name() == "headless":
		_finish_capture_with_error(tr("LOBBY_CAPTURE_NEEDS_DISPLAY"))
		return
	if _last_capture_png.is_empty() or _last_capture_file_name.is_empty():
		_finish_capture_with_error(tr("LOBBY_CAPTURE_NOT_READY"))
		return

	_capture_in_progress = true
	_set_action_buttons_disabled(true)
	_set_status(tr("LOBBY_SAVING"), STATUS_NEUTRAL_COLOR)
	var save_error: Error = _deliver_capture(_last_capture_png, _last_capture_file_name)
	if save_error != OK:
		_finish_capture_with_error(tr("LOBBY_SAVE_FAILED") % error_string(save_error))
		return

	_capture_in_progress = false
	_set_action_buttons_disabled(false)
	if FinaleSharePlatform.is_web():
		_set_status(tr("LOBBY_DOWNLOAD_STARTED") % _last_capture_file_name, STATUS_SUCCESS_COLOR)
	else:
		_set_status(tr("LOBBY_IMAGE_SAVED") % _last_capture_path, STATUS_SUCCESS_COLOR)


func _prepare_capture_buffer() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_image: Image = _capture_finale_card()
	if capture_image.is_empty():
		return
	_last_capture_png = capture_image.save_png_to_buffer()
	if not _last_capture_png.is_empty():
		_last_capture_file_name = _build_capture_file_name(ProgressionService.get_player_name())


func _capture_finale_card() -> Image:
	var viewport_image: Image = get_viewport().get_texture().get_image()
	var capture_rect: Rect2 = finale_card.get_global_rect()
	var region := Rect2i(
		Vector2i(floori(capture_rect.position.x), floori(capture_rect.position.y)),
		Vector2i(ceili(capture_rect.size.x), ceili(capture_rect.size.y))
	)
	region = region.intersection(Rect2i(Vector2i.ZERO, viewport_image.get_size()))
	if region.size.x <= 0 or region.size.y <= 0:
		return Image.new()
	return viewport_image.get_region(region)


func _deliver_capture(png_buffer: PackedByteArray, file_name: String) -> Error:
	if FinaleSharePlatform.is_web():
		FinaleSharePlatform.download_png(png_buffer, file_name)
		_last_capture_path = ""
		return OK

	var directory_path: String = ProjectSettings.globalize_path(CAPTURE_DIRECTORY)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_error != OK:
		return directory_error

	_last_capture_path = _find_available_capture_path(directory_path, file_name)
	var file: FileAccess = FileAccess.open(_last_capture_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(png_buffer)
	return file.get_error()


func _find_available_capture_path(directory_path: String, file_name: String) -> String:
	var candidate: String = directory_path.path_join(file_name)
	if not FileAccess.file_exists(candidate):
		return candidate

	var base_name: String = file_name.trim_suffix(".png")
	var suffix: int = 2
	while FileAccess.file_exists(directory_path.path_join("%s_%d.png" % [base_name, suffix])):
		suffix += 1
	return directory_path.path_join("%s_%d.png" % [base_name, suffix])


func _build_capture_file_name(player_name: String) -> String:
	var safe_name: String = ""
	for index: int in range(player_name.length()):
		var character: String = player_name.substr(index, 1)
		var codepoint: int = character.unicode_at(0)
		var is_ascii_letter: bool = (
			(codepoint >= 65 and codepoint <= 90)
			or (codepoint >= 97 and codepoint <= 122)
		)
		var is_digit: bool = codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_digit or codepoint >= 128:
			safe_name += character.to_lower()
		elif character == "-" or character == "_" or character == " ":
			safe_name += "_" if character == " " else character
		elif not safe_name.ends_with("_"):
			safe_name += "_"

	while safe_name.contains("__"):
		safe_name = safe_name.replace("__", "_")
	while safe_name.begins_with("_"):
		safe_name = safe_name.trim_prefix("_")
	while safe_name.ends_with("_"):
		safe_name = safe_name.trim_suffix("_")
	if safe_name.is_empty():
		safe_name = "aventurier"
	return "halloween2026_bilan_%s.png" % safe_name


func _share_finale() -> void:
	if _capture_in_progress or not result_step.visible:
		return

	var share_text: String = _build_share_text()
	if FinaleSharePlatform.is_web():
		await _share_finale_on_web(share_text)
		return

	if FinaleSharePlatform.copy_text(share_text):
		var message: String = tr("LOBBY_SCORE_COPIED")
		if not _last_capture_path.is_empty():
			message += " " + tr("LOBBY_IMAGE_READY")
		_set_status(message, STATUS_SUCCESS_COLOR)
		return
	_set_status(tr("LOBBY_SHARE_AND_CLIPBOARD_UNAVAILABLE"), STATUS_ERROR_COLOR)


func _share_finale_on_web(share_text: String) -> void:
	share_button.disabled = true
	var share_mode: String = FinaleSharePlatform.start_web_share(
		share_text,
		_last_capture_png,
		_last_capture_file_name
	)
	if share_mode == "unavailable":
		share_button.disabled = false
		if FinaleSharePlatform.copy_text(share_text):
			_set_status(tr("LOBBY_SHARE_UNAVAILABLE_COPIED"), STATUS_SUCCESS_COLOR)
		else:
			_set_status(tr("LOBBY_SHARE_UNAVAILABLE_BROWSER"), STATUS_ERROR_COLOR)
		return
	if share_mode == "error":
		share_button.disabled = false
		_set_status(tr("LOBBY_SHARE_OPEN_FAILED"), STATUS_ERROR_COLOR)
		return

	if share_mode == "pending_image":
		_set_status(tr("LOBBY_SHARE_PENDING_IMAGE"), STATUS_NEUTRAL_COLOR)
	else:
		_set_status(
			tr("LOBBY_SHARE_TEXT_ONLY"),
			STATUS_NEUTRAL_COLOR
		)
	await _poll_web_share_result()


func _poll_web_share_result() -> void:
	for _attempt: int in range(600):
		await get_tree().create_timer(0.1, true).timeout
		if _finale_closing or not finale_overlay.visible:
			return
		var status: String = FinaleSharePlatform.get_web_share_status()
		if status == "pending" or status.is_empty():
			continue
		share_button.disabled = false
		match status:
			"success_image":
				_set_status(tr("LOBBY_SHARE_SUCCESS_IMAGE"), STATUS_SUCCESS_COLOR)
			"success_text":
				_set_status(tr("LOBBY_SHARE_SUCCESS_TEXT"), STATUS_SUCCESS_COLOR)
			"cancelled":
				_set_status(tr("LOBBY_SHARE_CANCELLED"), STATUS_NEUTRAL_COLOR)
			_:
				_set_status(tr("LOBBY_SHARE_FAILED"), STATUS_ERROR_COLOR)
		return
	share_button.disabled = false
	_set_status(tr("LOBBY_SHARE_NO_RESPONSE"), STATUS_ERROR_COLOR)


func _build_share_text() -> String:
	return tr("LOBBY_SHARE_TEXT") % [
		ProgressionService.get_player_name(),
		ProgressionService.get_total_candy(),
	]


func _open_capture_directory() -> void:
	if _last_capture_path.is_empty() or not FinaleSharePlatform.is_desktop():
		_set_status(tr("LOBBY_SAVE_FIRST"), STATUS_NEUTRAL_COLOR)
		return
	var open_error: Error = FinaleSharePlatform.open_directory(_last_capture_path.get_base_dir())
	if open_error == OK:
		_set_status(tr("LOBBY_FOLDER_OPENED"), STATUS_SUCCESS_COLOR)
	else:
		_set_status(tr("LOBBY_FOLDER_OPEN_FAILED") % error_string(open_error), STATUS_ERROR_COLOR)


func _finish_capture_with_error(message: String) -> void:
	_set_status(message, STATUS_ERROR_COLOR)
	_capture_in_progress = false
	_set_action_buttons_disabled(false)


func _restore_capture_controls() -> void:
	actions.show()
	save_status.show()
	hint.show()


func _set_action_buttons_disabled(disabled: bool) -> void:
	save_button.disabled = disabled
	share_button.disabled = disabled
	return_button.disabled = disabled
	open_folder_button.disabled = disabled or _last_capture_path.is_empty()


func _set_status(message: String, color: Color) -> void:
	save_status.text = message
	save_status.add_theme_color_override("font_color", color)


func _reset_export_state() -> void:
	_last_capture_png = PackedByteArray()
	_last_capture_file_name = ""
	_last_capture_path = ""
	open_folder_button.disabled = true


func _dismiss_finale() -> void:
	if _capture_in_progress or _finale_closing or not finale_overlay.visible:
		return

	_finale_closing = true
	validate_button.disabled = true
	save_button.disabled = true
	share_button.disabled = true
	open_folder_button.disabled = true
	return_button.disabled = true
	name_input.release_focus()
	var exit_tween: Tween = create_tween().set_parallel(true)
	exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(finale_overlay, "modulate:a", 0.0, 0.30)
	exit_tween.tween_property(finale_card, "scale", Vector2.ONE * 0.96, 0.30)
	exit_tween.tween_property(finale_audio, "volume_db", SILENT_VOLUME_DB, 0.45)
	await exit_tween.finished

	finale_audio.stop()
	finale_overlay.hide()
	finale_overlay.modulate = Color.WHITE
	_finale_closing = false
	_finale_opening = false
	_paused_for_finale = false
	get_tree().paused = _tree_was_paused
	Input.mouse_mode = _previous_mouse_mode
	finale_closed.emit()
	_resume_lobby_music()


func _pause_lobby_music() -> void:
	if not is_instance_valid(lobby_music):
		return
	_lobby_music_was_playing = lobby_music.playing
	_lobby_music_volume_db = lobby_music.volume_db
	lobby_music.volume_db = SILENT_VOLUME_DB
	lobby_music.stream_paused = true


func _resume_lobby_music() -> void:
	if not is_instance_valid(lobby_music) or not _lobby_music_was_playing:
		return
	lobby_music.stream_paused = false
	var resume_tween: Tween = create_tween()
	resume_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	resume_tween.tween_property(lobby_music, "volume_db", _lobby_music_volume_db, 0.8)
