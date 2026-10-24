class_name LobbyCandyHud
extends CanvasLayer


signal finale_closed

const CAPTURE_DIRECTORY: String = "user://bilans/"
const FINALE_VOLUME_DB: float = -6.0
const SILENT_VOLUME_DB: float = -40.0

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
@onready var return_button: Button = %ReturnButton
@onready var save_status: Label = %SaveStatus
@onready var actions: Control = %Actions
@onready var hint: Control = %Hint
@onready var finale_audio: AudioStreamPlayer = %FinaleAudio

var _capture_in_progress: bool = false
var _finale_closing: bool = false
var _finale_opening: bool = false
var _paused_for_finale: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _tree_was_paused: bool = false


func _ready() -> void:
	ProgressionService.total_candy_changed.connect(_update_candy_label)
	ProgressionService.world_progress_changed.connect(_update_worlds_label)
	validate_button.pressed.connect(_validate_player_name)
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.text_changed.connect(_on_name_changed)
	save_button.pressed.connect(_save_finale_capture)
	return_button.pressed.connect(_dismiss_finale)
	_update_candy_label(ProgressionService.get_total_candy())
	_update_worlds_label(
		ProgressionService.get_completed_world_count(),
		ProgressionService.get_available_world_count()
	)
	_configure_finale_music()
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
	candy_label.text = "CANDY : %d" % total_candy


func _update_worlds_label(completed_worlds: int, available_worlds: int) -> void:
	worlds_label.text = "MONDES : %d / %d" % [completed_worlds, available_worlds]


func _prepare_finale() -> void:
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
	validate_button.disabled = false
	return_button.disabled = false


func _validate_player_name() -> void:
	if not ProgressionService.set_player_name(name_input.text):
		name_error.text = "Le pseudo est obligatoire."
		name_input.grab_focus()
		return

	name_input.text = ProgressionService.get_player_name()
	_show_final_result(name_input.text)


func _show_final_result(player_name: String) -> void:
	player_name_label.text = player_name
	_update_finale_summary()
	name_step.hide()
	result_step.show()
	save_button.show()
	save_button.disabled = true
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
		return
	save_button.disabled = false
	save_button.grab_focus()


func _update_finale_summary() -> void:
	final_score_label.text = "%d CANDY" % ProgressionService.get_total_candy()
	final_worlds_label.text = "%d / %d MONDES ACCOMPLIS" % [
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


func _configure_finale_music() -> void:
	if finale_audio.stream is AudioStreamMP3:
		var local_stream: AudioStreamMP3 = finale_audio.stream.duplicate() as AudioStreamMP3
		local_stream.loop = true
		finale_audio.stream = local_stream


func _on_name_submitted(_submitted_name: String) -> void:
	_validate_player_name()


func _on_name_changed(_new_text: String) -> void:
	name_error.text = ""


func _save_finale_capture() -> void:
	if _capture_in_progress or not result_step.visible:
		return

	_capture_in_progress = true
	save_button.disabled = true
	save_status.text = "Enregistrement en cours…"
	actions.hide()
	save_status.hide()
	hint.hide()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		_restore_capture_controls()
		_finish_capture_with_error("La capture PNG nécessite un affichage graphique.")
		return
	await RenderingServer.frame_post_draw

	var viewport_image: Image = get_viewport().get_texture().get_image()
	var capture_rect: Rect2 = finale_card.get_global_rect()
	var region := Rect2i(
		Vector2i(floori(capture_rect.position.x), floori(capture_rect.position.y)),
		Vector2i(ceili(capture_rect.size.x), ceili(capture_rect.size.y))
	)
	region = region.intersection(Rect2i(Vector2i.ZERO, viewport_image.get_size()))
	if region.size.x <= 0 or region.size.y <= 0:
		_restore_capture_controls()
		_finish_capture_with_error("Impossible de cadrer le bilan.")
		return

	var directory_path: String = ProjectSettings.globalize_path(CAPTURE_DIRECTORY)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_error != OK:
		_restore_capture_controls()
		_finish_capture_with_error("Impossible de créer le dossier de capture.")
		return

	var timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var file_name: String = "bilan_halloween_2026_%d.png" % timestamp_ms
	var relative_path: String = CAPTURE_DIRECTORY + file_name
	var absolute_path: String = ProjectSettings.globalize_path(relative_path)
	var capture_image: Image = viewport_image.get_region(region)
	var save_error: Error = capture_image.save_png(absolute_path)
	if save_error != OK:
		_restore_capture_controls()
		_finish_capture_with_error("Échec de l'enregistrement : %s" % error_string(save_error))
		return

	_restore_capture_controls()
	save_status.text = "Image enregistrée :\n%s" % absolute_path
	_capture_in_progress = false
	save_button.disabled = false


func _finish_capture_with_error(message: String) -> void:
	save_status.text = message
	_capture_in_progress = false
	save_button.disabled = false


func _restore_capture_controls() -> void:
	actions.show()
	save_status.show()
	hint.show()


func _dismiss_finale() -> void:
	if _capture_in_progress or _finale_closing or not finale_overlay.visible:
		return

	_finale_closing = true
	validate_button.disabled = true
	save_button.disabled = true
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
